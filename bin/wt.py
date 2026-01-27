#!/usr/bin/env python3
# Usage: wt.py <subcommand> [options]
# Subcommands: co, ls, rm, pick, roots, which, info

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from contextlib import contextmanager
import fcntl
from dataclasses import dataclass
from typing import Iterable, List, Optional


STATE_DIR = os.path.join(os.path.expanduser("~"), ".local", "state", "wt")
ROOTS_FILE = os.path.join(STATE_DIR, "roots.json")
LOCK_FILE = os.path.join(STATE_DIR, "roots.lock")
LOCK_TIMEOUT_SECONDS = 5
HOME_DIR = os.path.expanduser("~")


class Colors:
    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    CYAN = "\033[36m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    MAGENTA = "\033[35m"

    _enabled = True

    @classmethod
    def disable(cls) -> None:
        cls._enabled = False

    @classmethod
    def wrap(cls, text: str, *codes: str) -> str:
        if not cls._enabled:
            return text
        return "".join(codes) + text + cls.RESET


def shorten_path(path: str) -> str:
    if path.startswith(HOME_DIR):
        return "~" + path[len(HOME_DIR):]
    return path


def truncate(text: str, width: int, left: bool = False) -> str:
    if len(text) <= width or width <= 3:
        return text[:width] if not left else text[-width:]
    if left:
        return "..." + text[-(width - 3):]
    return text[:width - 3] + "..."


def get_terminal_width() -> int:
    return shutil.get_terminal_size((80, 24)).columns


class WTError(RuntimeError):
    pass


@dataclass
class RootEntry:
    path: str
    branch: str


@dataclass
class WorktreeEntry:
    root: str
    path: str
    branch: Optional[str]


def run_git(args: List[str], *, cwd: Optional[str] = None, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        text=True,
        capture_output=True,
        check=check,
    )


def ensure_state_dir() -> None:
    os.makedirs(STATE_DIR, exist_ok=True)


@contextmanager
def locked_roots():
    ensure_state_dir()
    start = time.time()
    with open(LOCK_FILE, "w", encoding="utf-8") as handle:
        while True:
            try:
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.time() - start > LOCK_TIMEOUT_SECONDS:
                    raise WTError("timed out waiting for roots lock")
                time.sleep(0.05)
        try:
            yield
        finally:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def load_roots() -> List[RootEntry]:
    if not os.path.exists(ROOTS_FILE):
        return []
    try:
        with open(ROOTS_FILE, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        raise WTError(f"failed to read roots: {exc}") from exc
    roots_raw = data.get("roots", [])
    roots = []
    for item in roots_raw:
        path = str(item.get("path", "")).strip()
        branch = str(item.get("branch", "")).strip() or "main"
        if path:
            roots.append(RootEntry(path=os.path.realpath(path), branch=branch))
    return roots


def save_roots(roots: Iterable[RootEntry]) -> None:
    ensure_state_dir()
    tmp_path = f"{ROOTS_FILE}.tmp"
    data = {"roots": [entry.__dict__ for entry in roots]}
    with open(tmp_path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, sort_keys=True)
        handle.write("\n")
    os.replace(tmp_path, ROOTS_FILE)


def with_roots_lock(fn):
    def wrapper(*args, **kwargs):
        with locked_roots():
            return fn(*args, **kwargs)

    return wrapper


def git_default_branch(root: str) -> str:
    try:
        result = run_git(
            ["symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"],
            cwd=root,
        )
        ref = result.stdout.strip()
        if ref:
            return ref.split("/", 1)[-1]
    except subprocess.CalledProcessError:
        pass
    try:
        result = run_git(["config", "--get", "init.defaultBranch"], cwd=root)
        ref = result.stdout.strip()
        if ref:
            return ref
    except subprocess.CalledProcessError:
        pass
    try:
        result = run_git(["symbolic-ref", "--quiet", "--short", "HEAD"], cwd=root)
        ref = result.stdout.strip()
        if ref:
            return ref
    except subprocess.CalledProcessError:
        pass
    return "main"


def normalize_repo_root(path: str) -> str:
    try:
        result = run_git(["rev-parse", "--show-toplevel"], cwd=path)
    except subprocess.CalledProcessError as exc:
        raise WTError(f"{path} is not a git repository") from exc
    return os.path.realpath(result.stdout.strip())


def ensure_worktrees_excluded(common_dir: str) -> None:
    info_dir = os.path.join(common_dir, "info")
    exclude_path = os.path.join(info_dir, "exclude")
    os.makedirs(info_dir, exist_ok=True)
    try:
        with open(exclude_path, "r", encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except OSError:
        lines = []
    if ".worktrees/" not in lines:
        with open(exclude_path, "a", encoding="utf-8") as handle:
            handle.write(".worktrees/\n")


def parse_worktree_list(output: str) -> List[dict]:
    entries = []
    current: dict = {}
    for line in output.splitlines():
        if not line.strip():
            if current:
                entries.append(current)
                current = {}
            continue
        key, _, value = line.partition(" ")
        current[key] = value
    if current:
        entries.append(current)
    return entries


def list_worktrees(root: str) -> List[WorktreeEntry]:
    try:
        result = run_git(["worktree", "list", "--porcelain"], cwd=root)
    except subprocess.CalledProcessError as exc:
        raise WTError(f"failed to list worktrees for {root}") from exc
    entries = []
    for item in parse_worktree_list(result.stdout):
        path = item.get("worktree")
        if not path:
            continue
        branch_ref = item.get("branch")
        branch = None
        if branch_ref:
            if branch_ref.startswith("refs/heads/"):
                branch = branch_ref[len("refs/heads/") :]
            else:
                branch = branch_ref
        entries.append(WorktreeEntry(root=root, path=os.path.realpath(path), branch=branch))
    return entries


def list_all_worktrees(roots: Iterable[RootEntry]) -> List[WorktreeEntry]:
    worktrees: List[WorktreeEntry] = []
    for root in roots:
        try:
            worktrees.extend(list_worktrees(root.path))
        except WTError as exc:
            print(f"wt: {exc}", file=sys.stderr)
    return worktrees


def require_fzf() -> None:
    if not shutil.which("fzf"):
        raise WTError("fzf not found in PATH")


def select_with_fzf(lines: List[str]) -> Optional[str]:
    if not lines:
        return None
    require_fzf()
    proc = subprocess.run(
        ["fzf", "--with-nth=2,3", "--delimiter=\t"],
        input="\n".join(lines),
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0:
        return None
    return proc.stdout.strip()


def pick_worktree(roots: Iterable[RootEntry]) -> Optional[WorktreeEntry]:
    worktrees = list_all_worktrees(roots)
    lines = []
    by_path = {}
    for entry in worktrees:
        repo = os.path.basename(entry.root)
        branch = entry.branch or "(detached)"
        line = f"{entry.path}\t{repo}\t{branch}"
        lines.append(line)
        by_path[entry.path] = entry
    selected = select_with_fzf(lines)
    if not selected:
        return None
    path = selected.split("\t", 1)[0]
    return by_path.get(path)


def pick_root(roots: Iterable[RootEntry]) -> Optional[RootEntry]:
    lines = []
    by_path = {}
    for entry in roots:
        repo = os.path.basename(entry.path)
        line = f"{entry.path}\t{repo}\t{entry.branch}"
        lines.append(line)
        by_path[entry.path] = entry
    selected = select_with_fzf(lines)
    if not selected:
        return None
    path = selected.split("\t", 1)[0]
    return by_path.get(path)


@with_roots_lock
def update_roots(update_fn):
    roots = load_roots()
    updated = update_fn(roots)
    if updated is None:
        updated = roots
    save_roots(updated)
    return updated


def add_root_entry(path: str, branch: Optional[str]) -> RootEntry:
    root_path = normalize_repo_root(path)
    branch_value = branch or git_default_branch(root_path)
    return RootEntry(path=root_path, branch=branch_value)


def ensure_root_registered(root_path: str) -> None:
    def updater(roots: List[RootEntry]) -> List[RootEntry]:
        resolved = os.path.realpath(root_path)
        for entry in roots:
            if entry.path == resolved:
                return roots
        entry = add_root_entry(resolved, None)
        return roots + [entry]

    update_roots(updater)


def format_ls_rows(entries: List[WorktreeEntry]) -> List[str]:
    term_width = get_terminal_width()
    gap = 2

    # Calculate column widths based on content
    repo_width = max((len(os.path.basename(e.root)) for e in entries), default=4)
    branch_width = max((len(e.branch or "-") for e in entries), default=6)

    # Cap widths to leave room for path
    max_repo = min(repo_width, 30)
    max_branch = min(branch_width, 40)
    path_width = max(20, term_width - max_repo - max_branch - gap * 2)

    # Header
    header = (
        Colors.wrap("REPO".ljust(max_repo), Colors.DIM, Colors.CYAN)
        + " " * gap
        + Colors.wrap("BRANCH".ljust(max_branch), Colors.DIM, Colors.GREEN)
        + " " * gap
        + Colors.wrap("PATH", Colors.DIM)
    )
    rows = [header]

    for entry in entries:
        repo = truncate(os.path.basename(entry.root), max_repo)
        branch_raw = entry.branch or "-"
        branch_display = truncate(branch_raw, max_branch)
        path_short = shorten_path(entry.path)
        path_display = truncate(path_short, path_width, left=True)

        # Color branches: yellow for main/master, magenta for detached, green otherwise
        if branch_raw in ("main", "master"):
            branch_color = Colors.YELLOW
        elif branch_raw == "-":
            branch_color = Colors.MAGENTA
        else:
            branch_color = Colors.GREEN

        row = (
            Colors.wrap(repo.ljust(max_repo), Colors.CYAN)
            + " " * gap
            + Colors.wrap(branch_display.ljust(max_branch), branch_color)
            + " " * gap
            + Colors.wrap(path_display, Colors.DIM)
        )
        rows.append(row)

    return rows


def format_roots_rows(entries: List[RootEntry]) -> List[str]:
    if not entries:
        return []

    term_width = get_terminal_width()
    gap = 2

    path_width = max((len(shorten_path(e.path)) for e in entries), default=4)
    branch_width = max((len(e.branch) for e in entries), default=6)

    max_path = min(path_width, term_width - branch_width - gap - 10)

    rows = []
    for entry in entries:
        path_short = shorten_path(entry.path)
        path_display = truncate(path_short, max_path, left=True)
        row = (
            Colors.wrap(path_display.ljust(max_path), Colors.DIM)
            + " " * gap
            + Colors.wrap(entry.branch, Colors.YELLOW)
        )
        rows.append(row)

    return rows


def cmd_roots(args: argparse.Namespace) -> int:
    if args.list:
        roots = load_roots()
        if not roots:
            if getattr(args, "json", False):
                print("[]")
            return 0
        if getattr(args, "json", False):
            data = [{"path": r.path, "branch": r.branch} for r in roots]
            print(json.dumps(data, indent=2))
            return 0
        for line in format_roots_rows(roots):
            print(line)
        return 0
    if args.add:
        entry = add_root_entry(args.add, args.branch)

        def updater(roots: List[RootEntry]) -> List[RootEntry]:
            existing = [r for r in roots if r.path != entry.path]
            return existing + [entry]

        update_roots(updater)
        return 0
    if args.delete is not None:
        def updater(roots: List[RootEntry]) -> List[RootEntry]:
            target = args.delete
            if not target:
                selected = pick_root(roots)
                if not selected:
                    return roots
                target = selected.path
            target = os.path.realpath(target)
            return [r for r in roots if r.path != target]

        update_roots(updater)
        return 0
    raise WTError("roots requires one of -a, -d, or -l")


def cmd_ls(args: argparse.Namespace) -> int:
    def prune_missing(roots: List[RootEntry]) -> List[RootEntry]:
        return [r for r in roots if os.path.exists(r.path)]

    roots = update_roots(prune_missing)

    if args.root:
        target = args.root
        resolved = os.path.realpath(target) if os.path.exists(target) else None
        filtered = [
            r for r in roots
            if r.path == resolved or os.path.basename(r.path) == target
        ]
        if not filtered:
            raise WTError(f"no registered root matches '{target}'")
        roots = filtered
    elif not args.all:
        # Default: show only worktrees for current directory's repo
        try:
            common_dir = run_git(["rev-parse", "--git-common-dir"]).stdout.strip()
            current_root = os.path.realpath(os.path.join(common_dir, ".."))
            roots = [r for r in roots if r.path == current_root]
            if not roots:
                raise WTError("current directory's repo is not registered (use wt ls -a for all)")
        except subprocess.CalledProcessError:
            raise WTError("not inside a git repository (use wt ls -a for all)")

    entries = list_all_worktrees(roots)
    if not entries:
        if args.json:
            print("[]")
        return 0

    if args.json:
        data = [
            {"root": e.root, "path": e.path, "branch": e.branch}
            for e in entries
        ]
        print(json.dumps(data, indent=2))
        return 0

    for line in format_ls_rows(entries):
        print(line)
    return 0


def cmd_pick(_: argparse.Namespace) -> int:
    roots = load_roots()
    entry = pick_worktree(roots)
    if not entry:
        return 1
    print(entry.path)
    return 0


def cmd_co(args: argparse.Namespace) -> int:
    try:
        run_git(["rev-parse", "--is-inside-work-tree"])
    except subprocess.CalledProcessError as exc:
        raise WTError("not inside a git repository") from exc

    branch = args.branch.strip().rstrip("/")
    if not branch:
        raise WTError("branch name cannot be empty")

    common_dir = run_git(["rev-parse", "--git-common-dir"]).stdout.strip()
    root = os.path.realpath(os.path.join(common_dir, ".."))
    ensure_root_registered(root)
    ensure_worktrees_excluded(common_dir)

    wt_path = args.path
    if not wt_path:
        branch_dir = branch.split("/")[-1] or branch
        wt_path = os.path.join(root, ".worktrees", branch_dir)
    wt_path = os.path.realpath(wt_path)

    if os.path.exists(wt_path) and not os.path.isdir(wt_path):
        raise WTError(f"{wt_path} exists and is not a directory")
    if os.path.isdir(wt_path) and os.listdir(wt_path):
        raise WTError(f"{wt_path} exists and is not empty")
    os.makedirs(os.path.dirname(wt_path), exist_ok=True)

    force_flag: List[str] = []
    worktrees = list_worktrees(root)
    if any(entry.branch == branch for entry in worktrees):
        force_flag = ["--force"]

    if run_git(["show-ref", "--verify", "--quiet", f"refs/heads/{branch}"], cwd=root, check=False).returncode == 0:
        run_git(["worktree", "add", *force_flag, wt_path, branch], cwd=root)
    elif run_git(
        ["ls-remote", "--exit-code", "--heads", "origin", branch],
        cwd=root,
        check=False,
    ).returncode == 0:
        run_git(["fetch", "origin", branch], cwd=root)
        run_git(["branch", "--track", branch, f"origin/{branch}"], cwd=root)
        run_git(["worktree", "add", *force_flag, wt_path, branch], cwd=root)
    else:
        run_git(["worktree", "add", *force_flag, "-b", branch, wt_path], cwd=root)

    try:
        resolved = run_git(["rev-parse", "--show-toplevel"], cwd=wt_path).stdout.strip()
    except subprocess.CalledProcessError:
        resolved = wt_path
    print(resolved)
    return 0


def is_branch_merged(root: str, branch: str, base_branch: str) -> bool:
    try:
        result = run_git(["branch", "--merged", base_branch], cwd=root)
    except subprocess.CalledProcessError:
        return False
    merged = [line.strip().lstrip("* ").strip() for line in result.stdout.splitlines()]
    return branch in merged


def cmd_rm(args: argparse.Namespace) -> int:
    # Must be inside a git repository
    try:
        run_git(["rev-parse", "--is-inside-work-tree"])
    except subprocess.CalledProcessError as exc:
        raise WTError("must be inside a git repository to remove worktrees") from exc

    # Get the root of the current repo
    try:
        common_dir = run_git(["rev-parse", "--git-common-dir"]).stdout.strip()
        current_root = os.path.realpath(os.path.join(common_dir, ".."))
    except subprocess.CalledProcessError as exc:
        raise WTError("could not determine git root") from exc

    # Must be on the root worktree, not a child worktree
    try:
        toplevel = run_git(["rev-parse", "--show-toplevel"]).stdout.strip()
        toplevel = os.path.realpath(toplevel)
    except subprocess.CalledProcessError as exc:
        raise WTError("could not determine worktree toplevel") from exc

    if toplevel != current_root:
        raise WTError(f"must be on root worktree to remove worktrees (currently in child worktree)")

    # Only show worktrees from current repo
    worktrees = list_worktrees(current_root)
    # Exclude the root worktree itself from deletion choices
    child_worktrees = [wt for wt in worktrees if wt.path != current_root]

    entry: Optional[WorktreeEntry] = None
    if args.path:
        target = os.path.realpath(args.path)
        for item in child_worktrees:
            if item.path == target:
                entry = item
                break
        if not entry:
            raise WTError(f"worktree not found for {args.path} (must be a child of current repo)")
    else:
        # Pick from child worktrees only
        lines = []
        by_path = {}
        for wt in child_worktrees:
            repo = os.path.basename(wt.root)
            branch = wt.branch or "(detached)"
            line = f"{wt.path}\t{repo}\t{branch}"
            lines.append(line)
            by_path[wt.path] = wt
        selected = select_with_fzf(lines)
        if selected:
            path = selected.split("\t", 1)[0]
            entry = by_path.get(path)
    if not entry:
        return 1

    root = entry.root
    branch = entry.branch
    default_branch = git_default_branch(root)
    force = getattr(args, "force", False)
    delete_branch = getattr(args, "delete_branch", False)

    # Merged branch: safe to remove worktree and delete branch
    if branch and branch != default_branch and is_branch_merged(root, branch, default_branch):
        run_git(["worktree", "remove", entry.path], cwd=root)
        result = run_git(["branch", "-d", branch], cwd=root, check=False)
        if result.returncode != 0:
            msg = result.stderr.strip() or "branch deletion failed"
            print(f"wt: warning: {msg}", file=sys.stderr)
        return 0

    # Default branch: just remove worktree, never delete the branch
    if branch == default_branch:
        run_git(["worktree", "remove", entry.path], cwd=root)
        return 0

    # Unmerged branch: requires --force or interactive confirmation
    if force:
        run_git(["worktree", "remove", "--force", entry.path], cwd=root)
        if delete_branch and branch:
            run_git(["branch", "-D", branch], cwd=root)
        return 0

    prompt_branch = branch or "(detached)"
    response = input(
        f"Branch {prompt_branch} is not merged into {default_branch}. "
        "Force delete? [Y/n] "
    ).strip().lower()
    if response == "n":
        return 0
    run_git(["worktree", "remove", "--force", entry.path], cwd=root)
    if branch:
        run_git(["branch", "-D", branch], cwd=root)
    return 0


def cmd_which(_: argparse.Namespace) -> int:
    try:
        run_git(["rev-parse", "--is-inside-work-tree"])
    except subprocess.CalledProcessError:
        return 1
    try:
        common_dir = run_git(["rev-parse", "--git-common-dir"]).stdout.strip()
        root = os.path.realpath(os.path.join(common_dir, ".."))
        print(root)
        return 0
    except subprocess.CalledProcessError:
        return 1


def cmd_info(args: argparse.Namespace) -> int:
    path = args.path or os.getcwd()
    path = os.path.realpath(path)

    try:
        run_git(["rev-parse", "--is-inside-work-tree"], cwd=path)
    except subprocess.CalledProcessError as exc:
        raise WTError(f"{path} is not inside a git repository") from exc

    try:
        toplevel = run_git(["rev-parse", "--show-toplevel"], cwd=path).stdout.strip()
        toplevel = os.path.realpath(toplevel)
    except subprocess.CalledProcessError as exc:
        raise WTError(f"could not determine worktree toplevel") from exc

    try:
        common_dir = run_git(["rev-parse", "--git-common-dir"], cwd=path).stdout.strip()
        root = os.path.realpath(os.path.join(common_dir, ".."))
    except subprocess.CalledProcessError as exc:
        raise WTError(f"could not determine git common dir") from exc

    # Find matching worktree entry
    worktrees = list_worktrees(root)
    entry = None
    for wt in worktrees:
        if wt.path == toplevel:
            entry = wt
            break

    if not entry:
        raise WTError(f"could not find worktree info for {toplevel}")

    default_branch = git_default_branch(root)
    is_main = entry.path == root

    data = {
        "root": entry.root,
        "path": entry.path,
        "branch": entry.branch,
        "default_branch": default_branch,
        "is_main_worktree": is_main,
    }
    print(json.dumps(data, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Worktree utility")
    parser.add_argument("--no-color", action="store_true", help="disable colored output")
    sub = parser.add_subparsers(dest="command", required=True)

    roots = sub.add_parser("roots", help="manage registered roots")
    roots_group = roots.add_mutually_exclusive_group(required=True)
    roots_group.add_argument("-a", "--add", metavar="PATH", help="add a repo root")
    roots_group.add_argument(
        "-d",
        "--delete",
        nargs="?",
        const="",
        metavar="PATH",
        help="delete a repo root",
    )
    roots_group.add_argument("-l", "--list", action="store_true", help="list repo roots")
    roots.add_argument("--branch", help="default branch for the root")
    roots.add_argument("--json", action="store_true", help="output as JSON (with -l)")
    roots.set_defaults(func=cmd_roots)

    ls = sub.add_parser("ls", help="list worktrees")
    ls.add_argument("root", nargs="?", help="filter by repo root (path or name)")
    ls.add_argument("-a", "--all", action="store_true", help="list worktrees from all registered roots")
    ls.add_argument("--json", action="store_true", help="output as JSON")
    ls.set_defaults(func=cmd_ls)

    co = sub.add_parser("co", help="create a worktree")
    co.add_argument("branch", help="branch name")
    co.add_argument("path", nargs="?", help="worktree path")
    co.set_defaults(func=cmd_co)

    rm = sub.add_parser("rm", help="remove a worktree")
    rm.add_argument("path", nargs="?", help="worktree path")
    rm.add_argument("-f", "--force", action="store_true", help="force remove without prompting")
    rm.add_argument("-D", "--delete-branch", action="store_true", help="also delete the branch (with --force)")
    rm.set_defaults(func=cmd_rm)

    pick = sub.add_parser("pick", help="pick a worktree")
    pick.set_defaults(func=cmd_pick)

    which = sub.add_parser("which", help="print root of current worktree")
    which.set_defaults(func=cmd_which)

    info = sub.add_parser("info", help="show JSON info about a worktree")
    info.add_argument("path", nargs="?", help="worktree path (default: current directory)")
    info.set_defaults(func=cmd_info)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.no_color or not sys.stdout.isatty():
        Colors.disable()

    try:
        return args.func(args)
    except WTError as exc:
        print(f"wt: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
