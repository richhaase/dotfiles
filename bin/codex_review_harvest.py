#!/usr/bin/env python3
# Usage: codex_review_harvest.py [--workers N] [--base BRANCH]

import argparse
import json
import os
import shlex
import subprocess
import sys
import textwrap
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from typing import Iterable, List, Optional, Tuple


# ─────────────────────────────────────────────────────────────────────────────
# Terminal formatting utilities
# ─────────────────────────────────────────────────────────────────────────────


class Colors:
    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    CYAN = "\033[36m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    RED = "\033[31m"
    MAGENTA = "\033[35m"
    WHITE = "\033[97m"

    @classmethod
    def disable(cls) -> None:
        for attr in dir(cls):
            if attr.isupper() and not attr.startswith("_"):
                setattr(cls, attr, "")


def get_terminal_width() -> int:
    try:
        return os.get_terminal_size().columns
    except OSError:
        return 80


def get_ruler(width: int, char: str = "─") -> str:
    return f"{Colors.DIM}{char * width}{Colors.RESET}"


def wrap_text(text: str, width: int, initial_indent: str = "", subsequent_indent: str = "") -> str:
    """Wrap text to width with proper indentation."""
    return textwrap.fill(
        text,
        width=width,
        initial_indent=initial_indent,
        subsequent_indent=subsequent_indent or initial_indent,
        break_long_words=False,
        break_on_hyphens=False,
    )


@dataclass
class Finding:
    text: str
    iteration: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run codex review in parallel, parse JSONL output, and summarize findings."
        )
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=5,
        help="Parallel review runs to execute (default: 5)",
    )
    parser.add_argument(
        "--base", default="main", help="Base ref for review command (default: main)"
    )
    parser.add_argument(
        "--output-schema",
        default=None,
        help="Pass through to codex exec --output-schema <schema>. Default: unset.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print agent_message entries as they arrive (default: false).",
    )
    return parser.parse_args()


def build_command(base: str, output_schema: Optional[str]) -> List[str]:
    cmd = ["codex", "exec", "--json", "--color", "never", "review", "--base", base]
    if output_schema:
        cmd += ["--output-schema", output_schema]
    return cmd


def iter_json_lines(proc: subprocess.Popen) -> Iterable[dict]:
    assert proc.stdout is not None
    for raw in proc.stdout:
        line = raw.strip()
        if not line:
            continue
        try:
            yield json.loads(line)
        except json.JSONDecodeError:
            # Ignore non-JSON lines; caller will count parse errors based on None.
            yield {"__parse_error__": True, "raw": line}


def collect_findings(
    cmd: List[str], worker_id: int
) -> Tuple[int, List[Finding], int, int]:
    parse_errors = 0
    findings: List[Finding] = []

    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    for event in iter_json_lines(proc):
        if event.get("__parse_error__"):
            parse_errors += 1
            continue

        item = event.get("item")
        if isinstance(item, dict) and item.get("type") == "agent_message":
            text = item.get("text")
            if text:
                findings.append(Finding(text=text, iteration=worker_id))

    exit_code = proc.wait()
    return worker_id, findings, exit_code, parse_errors


GROUP_PROMPT = """# Codex Review Harvest Summarizer

You are grouping results from repeated Codex review runs.

Input: a JSON array of strings, each string is an agent_message from a review run.

Task:
- Cluster messages that describe the same underlying issue.
- Create a short, precise title per group.
- Keep groups distinct; do not merge different issues.
- If something is unique, keep it as its own group.

Output format (JSON only, no extra prose):
{
  "findings": [
    {
      "title": "Short issue title",
      "summary": "1-2 sentence summary.",
      "messages": ["short excerpt 1", "short excerpt 2"]
    }
  ]
}

Rules:
- Return ONLY valid JSON.
- Keep excerpts under ~200 characters each.
- Preserve file paths, flags, branch names, and commands in excerpts when present.
- If the input is empty, return: {"findings": []}
"""


def summarize_findings(messages: List[str]) -> Tuple[dict, int, str, str]:
    if not messages:
        return {"findings": []}, 0, "", ""

    prompt = GROUP_PROMPT.rstrip()
    payload = json.dumps(messages, ensure_ascii=True)
    full_prompt = f"{prompt}\n\nINPUT JSON:\n{payload}\n"

    proc = subprocess.run(
        ["codex", "exec", "--color", "never", "-"],
        input=full_prompt,
        text=True,
        capture_output=True,
    )
    output = proc.stdout.strip()
    stderr = proc.stderr.strip()
    if not output:
        return {"findings": []}, proc.returncode, stderr, output
    try:
        data = json.loads(output)
    except json.JSONDecodeError:
        return (
            {"findings": []},
            1,
            "Failed to parse summarizer JSON output.",
            output,
        )
    return data, proc.returncode, stderr, output


def render_report(
    grouped: dict,
    summarize_exit_code: int,
    summarize_stderr: str,
    summarize_raw: str,
    parse_errors: int,
    failed_iters: List[int],
) -> str:
    c = Colors
    width = min(get_terminal_width(), 90)

    findings = grouped.get("findings")
    if not isinstance(findings, list):
        findings = []

    lines: List[str] = []

    # Handle summarizer errors
    if summarize_exit_code != 0:
        lines.append("")
        lines.append(f"{c.RED}✗ Summarizer Error{c.RESET}")
        lines.append(get_ruler(width))
        lines.append(f"  Exit code: {summarize_exit_code}")
        if summarize_stderr:
            lines.append(f"  Stderr: {summarize_stderr}")
        if summarize_raw:
            lines.append(f"\n  {c.DIM}Raw output:{c.RESET}")
            for line in summarize_raw.splitlines()[:10]:
                lines.append(f"  {c.DIM}{line}{c.RESET}")
        return "\n".join(lines)

    # Warnings (show early so they're not hidden)
    warnings: List[str] = []
    if parse_errors:
        warnings.append(f"JSONL parse errors: {parse_errors}")
    if failed_iters:
        joined = ", ".join(str(i) for i in failed_iters)
        warnings.append(f"Failed workers: {joined}")

    if warnings:
        lines.append("")
        lines.append(f"{c.YELLOW}⚠ Warnings{c.RESET}")
        lines.append(get_ruler(width))
        for warning in warnings:
            lines.append(f"  {c.YELLOW}•{c.RESET} {warning}")
        lines.append("")

    # No findings case
    if not findings:
        lines.append("")
        lines.append(f"{c.GREEN}✓ Review Complete{c.RESET}")
        lines.append(get_ruler(width))
        lines.append(f"  {c.DIM}No findings captured.{c.RESET}")
        return "\n".join(lines)

    # Header
    lines.append("")
    finding_word = "finding" if len(findings) == 1 else "findings"
    lines.append(f"{c.CYAN}{c.BOLD}📋 {len(findings)} {finding_word}{c.RESET}")
    lines.append(get_ruler(width, "━"))

    # Render each finding
    for idx, finding in enumerate(findings, start=1):
        title = str(finding.get("title", "")).strip() or "Untitled"
        summary = str(finding.get("summary", "")).strip()
        messages = finding.get("messages")
        if not isinstance(messages, list):
            messages = []

        lines.append("")
        lines.append(f"{c.YELLOW}{c.BOLD}{idx}.{c.RESET} {c.BOLD}{title}{c.RESET}")
        lines.append(get_ruler(width))

        # Summary
        if summary:
            wrapped = wrap_text(summary, width - 3, initial_indent="   ", subsequent_indent="   ")
            lines.append(wrapped)

        # Messages
        if messages:
            lines.append("")
            lines.append(f"   {c.DIM}Evidence:{c.RESET}")
            for message in messages:
                message_text = str(message).strip()
                if message_text:
                    wrapped = wrap_text(
                        message_text,
                        width - 5,
                        initial_indent=f"   {c.DIM}•{c.RESET} ",
                        subsequent_indent="     ",
                    )
                    lines.append(wrapped)

    lines.append("")
    lines.append(get_ruler(width, "━"))

    return "\n".join(lines)


def main() -> int:
    args = parse_args()

    # Disable colors if stdout is not a TTY
    if not sys.stdout.isatty():
        Colors.disable()

    if args.workers < 1:
        print("--workers must be >= 1", file=sys.stderr)
        return 2

    cmd = build_command(args.base, args.output_schema)
    all_findings: List[Finding] = []
    parse_errors = 0
    failed_iters: List[int] = []

    cmd_str = " ".join(shlex.quote(part) for part in cmd)

    completed = 0
    completed_lock = threading.Lock()
    spinner_stop = threading.Event()
    spinner_enabled = sys.stderr.isatty()
    spinner_state = {"line": ""}
    write_lock = threading.Lock()

    def _clear_line() -> None:
        sys.stderr.write("\r" + " " * 90 + "\r")

    def log(message: str) -> None:
        with write_lock:
            if spinner_enabled:
                _clear_line()
            sys.stderr.write(message + "\n")
            if spinner_enabled and not spinner_stop.is_set():
                sys.stderr.write(spinner_state["line"])
            sys.stderr.flush()

    def spinner() -> None:
        if not spinner_enabled:
            return
        frames = "|/-\\"
        idx = 0
        while not spinner_stop.is_set():
            with completed_lock:
                done = completed
            frame = frames[idx % len(frames)]
            line = (
                f"\r[codex-review-harvest] Running: {done}/{args.workers} complete {frame}"
            )
            with write_lock:
                spinner_state["line"] = line
                sys.stderr.write(line)
                sys.stderr.flush()
            idx += 1
            time.sleep(0.2)
        with completed_lock:
            done = completed
        final_line = (
            f"\r[codex-review-harvest] Running: {done}/{args.workers} complete ✓"
        )
        with write_lock:
            spinner_state["line"] = final_line
            sys.stderr.write(final_line + "\n")
            sys.stderr.flush()

    spinner_thread = threading.Thread(target=spinner, daemon=True)
    spinner_thread.start()

    log(f"[codex-review-harvest] Command: {cmd_str}")
    log(f"[codex-review-harvest] Workers: {args.workers}")

    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = {}
        for worker_id in range(1, args.workers + 1):
            futures[executor.submit(collect_findings, cmd, worker_id)] = worker_id

        for future in as_completed(futures):
            worker_id, findings, exit_code, parse_errs = future.result()
            parse_errors += parse_errs
            if exit_code != 0:
                failed_iters.append(worker_id)
            for finding in findings:
                all_findings.append(finding)
            if args.verbose:
                if findings:
                    for finding in findings:
                        if finding.text:
                            log(
                                f"[codex-review-harvest] agent_message: {finding.text}"
                            )
                else:
                    log("[codex-review-harvest] agent_message: (none)")
            with completed_lock:
                completed += 1

    spinner_stop.set()
    spinner_thread.join(timeout=1)

    grouped, summarize_exit_code, summarize_stderr, summarize_raw = summarize_findings(
        [finding.text for finding in all_findings if finding.text]
    )
    output = render_report(
        grouped=grouped,
        summarize_exit_code=summarize_exit_code,
        summarize_stderr=summarize_stderr,
        summarize_raw=summarize_raw,
        parse_errors=parse_errors,
        failed_iters=failed_iters,
    )
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
