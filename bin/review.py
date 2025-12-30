#!/usr/bin/env python3
# Usage: review.py [--workers N] [--base BRANCH] [--timeout SECS] [--json]
# Env: REVIEW_WORKERS, REVIEW_TIMEOUT, REVIEW_BASE_REF

import argparse
import json
import logging
import os
import shlex
import shutil
import signal
import subprocess
import sys
import textwrap
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from typing import Iterable, List, Tuple, TypedDict

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

DEFAULT_WORKERS = int(os.environ.get("REVIEW_WORKERS", 5))
DEFAULT_TIMEOUT = int(os.environ.get("REVIEW_TIMEOUT", 300))
DEFAULT_BASE_REF = os.environ.get("REVIEW_BASE_REF", "main")
MAX_REPORT_WIDTH = 90
SPINNER_INTERVAL = 0.2
CLEAR_LINE_WIDTH = 90
MAX_RAW_OUTPUT_LINES = 10


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


def format_duration(seconds: float) -> str:
    """Format duration in human-readable form."""
    if seconds < 60:
        return f"{seconds:.1f}s"
    minutes = int(seconds // 60)
    secs = seconds % 60
    return f"{minutes}m {secs:.1f}s"


def wrap_text(
    text: str, width: int, initial_indent: str = "", subsequent_indent: str = ""
) -> str:
    """Wrap text to width with proper indentation."""
    return textwrap.fill(
        text,
        width=width,
        initial_indent=initial_indent,
        subsequent_indent=subsequent_indent or initial_indent,
        break_long_words=False,
        break_on_hyphens=False,
    )


class SpinnerHandler(logging.Handler):
    """Logging handler that coordinates with spinner output."""

    def __init__(
        self,
        write_lock: threading.Lock,
        spinner_state: dict,
        spinner_stop: threading.Event,
        spinner_enabled: bool,
    ):
        super().__init__()
        self.write_lock = write_lock
        self.spinner_state = spinner_state
        self.spinner_stop = spinner_stop
        self.spinner_enabled = spinner_enabled

    def emit(self, record: logging.LogRecord) -> None:
        try:
            msg = self.format(record)
            with self.write_lock:
                if self.spinner_enabled:
                    sys.stderr.write("\r" + " " * CLEAR_LINE_WIDTH + "\r")
                sys.stderr.write(msg + "\n")
                if self.spinner_enabled and not self.spinner_stop.is_set():
                    sys.stderr.write(self.spinner_state.get("line", ""))
                sys.stderr.flush()
        except Exception:
            self.handleError(record)


@dataclass
class Finding:
    text: str
    iteration: int


@dataclass
class WorkerResult:
    worker_id: int
    findings: List["Finding"]
    exit_code: int
    parse_errors: int
    timed_out: bool
    duration_seconds: float


# ─────────────────────────────────────────────────────────────────────────────
# Type definitions for structured data
# ─────────────────────────────────────────────────────────────────────────────


class FindingGroup(TypedDict):
    title: str
    summary: str
    messages: List[str]
    worker_count: int


class GroupedFindings(TypedDict):
    findings: List[FindingGroup]


class AggregatedFinding(TypedDict):
    text: str
    workers: List[int]


def aggregate_findings(findings: List[Finding]) -> List[AggregatedFinding]:
    """Aggregate findings by text, tracking which workers found each."""
    seen: dict[str, List[int]] = {}
    for f in findings:
        normalized = f.text.strip()
        if normalized:
            if normalized not in seen:
                seen[normalized] = []
            if f.iteration not in seen[normalized]:
                seen[normalized].append(f.iteration)
    return [
        AggregatedFinding(text=text, workers=sorted(workers))
        for text, workers in seen.items()
    ]


# ─────────────────────────────────────────────────────────────────────────────
# Dependency validation
# ─────────────────────────────────────────────────────────────────────────────


def check_dependencies() -> bool:
    """Check that required external tools are available."""
    if shutil.which("codex") is None:
        print("Error: 'codex' not found in PATH", file=sys.stderr)
        return False
    return True


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run codex review in parallel, parse JSONL output, and summarize findings."
        )
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=DEFAULT_WORKERS,
        help=f"Parallel review runs to execute (default: {DEFAULT_WORKERS})",
    )
    parser.add_argument(
        "--base",
        default=DEFAULT_BASE_REF,
        help=f"Base ref for review command (default: {DEFAULT_BASE_REF})",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print agent_message entries as they arrive (default: false).",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=DEFAULT_TIMEOUT,
        help=f"Timeout in seconds per worker (default: {DEFAULT_TIMEOUT})",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output JSON instead of formatted report",
    )
    return parser.parse_args()


def build_command(base: str) -> List[str]:
    cmd = ["codex", "exec", "--json", "--color", "never", "review", "--base", base]
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
    cmd: List[str], worker_id: int, timeout: int = DEFAULT_TIMEOUT
) -> WorkerResult:
    """Collect findings from a single worker."""
    start_time = time.monotonic()
    parse_errors = 0
    findings: List[Finding] = []
    timed_out = False

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

    try:
        exit_code = proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()
        exit_code = -1
        timed_out = True

    duration = time.monotonic() - start_time

    return WorkerResult(
        worker_id=worker_id,
        findings=findings,
        exit_code=exit_code,
        parse_errors=parse_errors,
        timed_out=timed_out,
        duration_seconds=duration,
    )


GROUP_PROMPT = """# Codex Review Summarizer

You are grouping results from repeated Codex review runs.

Input: a JSON array of objects, each with "text" (the finding) and "workers" (list of worker IDs that found it).

Task:
- Cluster messages that describe the same underlying issue.
- Create a short, precise title per group.
- Keep groups distinct; do not merge different issues.
- If something is unique, keep it as its own group.
- Sum up unique worker IDs across clustered messages for worker_count.

Output format (JSON only, no extra prose):
{
  "findings": [
    {
      "title": "Short issue title",
      "summary": "1-2 sentence summary.",
      "messages": ["short excerpt 1", "short excerpt 2"],
      "worker_count": 3
    }
  ]
}

Rules:
- Return ONLY valid JSON.
- Keep excerpts under ~200 characters each.
- Preserve file paths, flags, branch names, and commands in excerpts when present.
- worker_count = number of unique workers that reported any message in this cluster.
- If the input is empty, return: {"findings": []}
"""


def summarize_findings(
    aggregated: List[AggregatedFinding],
) -> Tuple[GroupedFindings, int, str, str, float]:
    """Summarize findings using LLM.

    Returns: (grouped, exit_code, stderr, raw_output, duration_seconds)
    """
    if not aggregated:
        return GroupedFindings(findings=[]), 0, "", "", 0.0

    start_time = time.monotonic()
    prompt = GROUP_PROMPT.rstrip()
    payload = json.dumps(aggregated, ensure_ascii=True)
    full_prompt = f"{prompt}\n\nINPUT JSON:\n{payload}\n"

    proc = subprocess.run(
        ["codex", "exec", "--color", "never", "-"],
        input=full_prompt,
        text=True,
        capture_output=True,
    )
    duration = time.monotonic() - start_time

    output = proc.stdout.strip()
    stderr = proc.stderr.strip()
    if not output:
        return GroupedFindings(findings=[]), proc.returncode, stderr, output, duration
    try:
        data: GroupedFindings = json.loads(output)
    except json.JSONDecodeError:
        return (
            GroupedFindings(findings=[]),
            1,
            "Failed to parse summarizer JSON output.",
            output,
            duration,
        )
    return data, proc.returncode, stderr, output, duration


def render_report(
    grouped: GroupedFindings,
    summarize_exit_code: int,
    summarize_stderr: str,
    summarize_raw: str,
    parse_errors: int,
    failed_iters: List[int],
    timed_out_iters: List[int] | None = None,
    worker_durations: dict[int, float] | None = None,
    summarizer_duration: float | None = None,
    total_workers: int | None = None,
) -> str:
    c = Colors
    width = min(get_terminal_width(), MAX_REPORT_WIDTH)

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
            for line in summarize_raw.splitlines()[:MAX_RAW_OUTPUT_LINES]:
                lines.append(f"  {c.DIM}{line}{c.RESET}")
        return "\n".join(lines)

    # Warnings (show early so they're not hidden)
    warnings: List[str] = []
    if parse_errors:
        warnings.append(f"JSONL parse errors: {parse_errors}")
    if failed_iters:
        joined = ", ".join(str(i) for i in failed_iters)
        warnings.append(f"Failed workers: {joined}")
    if timed_out_iters:
        joined = ", ".join(str(i) for i in timed_out_iters)
        warnings.append(f"Timed out workers: {joined}")

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
        worker_count = finding.get("worker_count", 0)
        if total_workers and worker_count:
            confidence = f" {c.DIM}({worker_count}/{total_workers} workers){c.RESET}"
        else:
            confidence = ""
        lines.append(f"{c.YELLOW}{c.BOLD}{idx}.{c.RESET} {c.BOLD}{title}{c.RESET}{confidence}")
        lines.append(get_ruler(width))

        # Summary
        if summary:
            wrapped = wrap_text(
                summary, width - 3, initial_indent="   ", subsequent_indent="   "
            )
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

    # Timing stats
    if worker_durations or summarizer_duration:
        lines.append("")
        lines.append(f"{c.DIM}Timing:{c.RESET}")

        if worker_durations:
            durations = list(worker_durations.values())
            total = sum(durations)
            avg = total / len(durations)
            min_dur = min(durations)
            max_dur = max(durations)
            lines.append(
                f"  {c.DIM}workers: avg {format_duration(avg)} | "
                f"min {format_duration(min_dur)} | "
                f"max {format_duration(max_dur)} | "
                f"total {format_duration(total)}{c.RESET}"
            )

        if summarizer_duration is not None and summarizer_duration > 0:
            lines.append(
                f"  {c.DIM}summarizer: {format_duration(summarizer_duration)}{c.RESET}"
            )

    return "\n".join(lines)


def main() -> int:
    args = parse_args()

    # Disable colors if stdout is not a TTY
    if not sys.stdout.isatty():
        Colors.disable()

    if not check_dependencies():
        return 1

    if args.workers < 1:
        print("--workers must be >= 1", file=sys.stderr)
        return 2

    cmd = build_command(args.base)
    all_findings: List[Finding] = []
    parse_errors = 0
    failed_iters: List[int] = []
    timed_out_iters: List[int] = []
    worker_durations: dict[int, float] = {}

    cmd_str = " ".join(shlex.quote(part) for part in cmd)

    completed = 0
    completed_lock = threading.Lock()
    spinner_stop = threading.Event()
    spinner_enabled = sys.stderr.isatty()
    spinner_state = {"line": ""}
    write_lock = threading.Lock()
    interrupted = threading.Event()
    executor_ref: List[ThreadPoolExecutor] = []

    def handle_interrupt(sig: int, frame: object) -> None:
        interrupted.set()
        spinner_stop.set()
        with write_lock:
            sys.stderr.write("\n[review] Interrupted, shutting down...\n")
            sys.stderr.flush()
        if executor_ref:
            executor_ref[0].shutdown(wait=False, cancel_futures=True)

    signal.signal(signal.SIGINT, handle_interrupt)
    signal.signal(signal.SIGTERM, handle_interrupt)

    # Set up logging with spinner-aware handler
    handler = SpinnerHandler(write_lock, spinner_state, spinner_stop, spinner_enabled)
    handler.setFormatter(logging.Formatter("[review] %(message)s"))
    logger.addHandler(handler)
    logger.setLevel(logging.DEBUG if args.verbose else logging.INFO)

    def spinner() -> None:
        if not spinner_enabled:
            return
        frames = "|/-\\"
        idx = 0
        while not spinner_stop.is_set():
            with completed_lock:
                done = completed
            frame = frames[idx % len(frames)]
            line = f"\r[review] Running: {done}/{args.workers} complete {frame}"
            with write_lock:
                spinner_state["line"] = line
                sys.stderr.write(line)
                sys.stderr.flush()
            idx += 1
            time.sleep(SPINNER_INTERVAL)
        with completed_lock:
            done = completed
        final_line = f"\r[review] Running: {done}/{args.workers} complete ✓"
        with write_lock:
            spinner_state["line"] = final_line
            sys.stderr.write(final_line + "\n")
            sys.stderr.flush()

    spinner_thread = threading.Thread(target=spinner, daemon=True)
    spinner_thread.start()

    logger.info(f"Command: {cmd_str}")
    logger.info(f"Workers: {args.workers}")

    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        executor_ref.append(executor)
        futures = {}
        for worker_id in range(1, args.workers + 1):
            futures[
                executor.submit(collect_findings, cmd, worker_id, args.timeout)
            ] = worker_id

        for future in as_completed(futures):
            if interrupted.is_set():
                break
            try:
                result: WorkerResult = future.result()
            except Exception:
                continue
            parse_errors += result.parse_errors
            worker_durations[result.worker_id] = result.duration_seconds
            if result.timed_out:
                timed_out_iters.append(result.worker_id)
            elif result.exit_code != 0:
                failed_iters.append(result.worker_id)
            for finding in result.findings:
                all_findings.append(finding)
            dur_str = format_duration(result.duration_seconds)
            if result.findings:
                for finding in result.findings:
                    if finding.text:
                        logger.debug(f"worker {result.worker_id} ({dur_str}): {finding.text}")
            else:
                logger.debug(f"worker {result.worker_id} ({dur_str}): (no findings)")
            with completed_lock:
                completed += 1

    spinner_stop.set()
    spinner_thread.join(timeout=1)

    if interrupted.is_set():
        logger.removeHandler(handler)
        return 130

    # Summarization
    aggregated = aggregate_findings(all_findings)
    (
        grouped,
        summarize_exit_code,
        summarize_stderr,
        summarize_raw,
        summarizer_duration,
    ) = summarize_findings(aggregated)

    # Output
    if args.json:
        worker_durs = list(worker_durations.values())
        output_data = {
            "findings": grouped.get("findings", []),
            "total_workers": args.workers,
            "warnings": {
                "failed_workers": failed_iters,
                "timed_out_workers": timed_out_iters,
                "parse_errors": parse_errors,
            },
            "timing": {
                "workers": {
                    "durations": worker_durations,
                    "total_seconds": sum(worker_durs) if worker_durs else 0,
                    "avg_seconds": sum(worker_durs) / len(worker_durs)
                    if worker_durs
                    else 0,
                    "min_seconds": min(worker_durs) if worker_durs else 0,
                    "max_seconds": max(worker_durs) if worker_durs else 0,
                },
                "summarizer_seconds": summarizer_duration,
            },
        }
        if summarize_exit_code != 0:
            output_data["summarizer_error"] = {
                "exit_code": summarize_exit_code,
                "stderr": summarize_stderr,
                "raw_output": summarize_raw,
            }
        print(json.dumps(output_data, indent=2))
        logger.removeHandler(handler)
        return 0

    output = render_report(
        grouped=grouped,
        summarize_exit_code=summarize_exit_code,
        summarize_stderr=summarize_stderr,
        summarize_raw=summarize_raw,
        parse_errors=parse_errors,
        failed_iters=failed_iters,
        timed_out_iters=timed_out_iters,
        worker_durations=worker_durations,
        summarizer_duration=summarizer_duration,
        total_workers=args.workers,
    )
    print(output)
    logger.removeHandler(handler)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
