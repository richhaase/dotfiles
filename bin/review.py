#!/usr/bin/env python3
# Usage: review.py [--workers N] [--base BRANCH] [--timeout SECS] [--retries N] [--json]
# Env: REVIEW_WORKERS, REVIEW_TIMEOUT, REVIEW_BASE_REF, REVIEW_RETRIES
# Exit: 0=no findings, 1=findings, 2=error, 130=interrupted

import argparse
import asyncio
import json
import os
import shlex
import shutil
import signal
import sys
import textwrap
import time
from dataclasses import dataclass, field
from typing import List, Tuple, TypedDict

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

DEFAULT_WORKERS = int(os.environ.get("REVIEW_WORKERS", 5))
DEFAULT_TIMEOUT = int(os.environ.get("REVIEW_TIMEOUT", 300))
DEFAULT_BASE_REF = os.environ.get("REVIEW_BASE_REF", "main")
DEFAULT_RETRIES = int(os.environ.get("REVIEW_RETRIES", 1))
MAX_REPORT_WIDTH = 90
SPINNER_INTERVAL = 0.2
MAX_RAW_OUTPUT_LINES = 10

# Exit codes (grep-style)
EXIT_NO_FINDINGS = 0
EXIT_FINDINGS = 1
EXIT_ERROR = 2
EXIT_INTERRUPTED = 130


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


# ─────────────────────────────────────────────────────────────────────────────
# Data structures
# ─────────────────────────────────────────────────────────────────────────────


@dataclass
class Finding:
    text: str
    iteration: int


@dataclass
class WorkerResult:
    worker_id: int
    findings: List[Finding]
    exit_code: int
    parse_errors: int
    timed_out: bool
    duration_seconds: float


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


# ─────────────────────────────────────────────────────────────────────────────
# Shared state for async coordination
# ─────────────────────────────────────────────────────────────────────────────


@dataclass
class ReviewState:
    """Shared state for coordinating async tasks."""

    completed: int = 0
    total_workers: int = 0
    interrupted: bool = False
    spinner_stop: asyncio.Event = field(default_factory=asyncio.Event)
    verbose: bool = False
    tasks: List[asyncio.Task] = field(default_factory=list)

    def log(self, msg: str, force: bool = False) -> None:
        """Log a message, clearing spinner line first if needed."""
        if sys.stderr.isatty():
            sys.stderr.write("\r" + " " * 90 + "\r")
        sys.stderr.write(f"[review] {msg}\n")
        sys.stderr.flush()


# ─────────────────────────────────────────────────────────────────────────────
# Core functions
# ─────────────────────────────────────────────────────────────────────────────


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
        "--retries",
        type=int,
        default=DEFAULT_RETRIES,
        help=f"Retry failed workers N times (default: {DEFAULT_RETRIES})",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output JSON instead of formatted report",
    )
    return parser.parse_args()


def build_command(base: str) -> List[str]:
    return ["codex", "exec", "--json", "--color", "never", "review", "--base", base]


async def collect_findings(
    cmd: List[str],
    worker_id: int,
    timeout: int,
    state: ReviewState,
) -> WorkerResult:
    """Collect findings from a single worker using async subprocess."""
    start_time = time.monotonic()
    parse_errors = 0
    findings: List[Finding] = []
    timed_out = False

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
        start_new_session=True,
    )

    try:
        async def read_output() -> None:
            nonlocal parse_errors
            assert proc.stdout is not None
            async for raw_line in proc.stdout:
                line = raw_line.decode().strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    parse_errors += 1
                    continue

                item = event.get("item")
                if isinstance(item, dict) and item.get("type") == "agent_message":
                    text = item.get("text")
                    if text:
                        findings.append(Finding(text=text, iteration=worker_id))
                        if state.verbose:
                            state.log(f"worker {worker_id}: {text}")

        await asyncio.wait_for(read_output(), timeout=timeout)
        await proc.wait()
        exit_code = proc.returncode or 0

    except asyncio.TimeoutError:
        timed_out = True
        exit_code = -1
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            pass
        await proc.wait()

    except asyncio.CancelledError:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            pass
        await proc.wait()
        raise

    duration = time.monotonic() - start_time

    return WorkerResult(
        worker_id=worker_id,
        findings=findings,
        exit_code=exit_code,
        parse_errors=parse_errors,
        timed_out=timed_out,
        duration_seconds=duration,
    )


async def collect_findings_with_retry(
    cmd: List[str],
    worker_id: int,
    timeout: int,
    retries: int,
    state: ReviewState,
) -> WorkerResult:
    """Collect findings with retry on failure or timeout."""
    result: WorkerResult | None = None

    for attempt in range(retries + 1):
        if state.interrupted:
            break

        result = await collect_findings(cmd, worker_id, timeout, state)

        if result.exit_code == 0:
            return result

        if attempt < retries:
            delay = 2**attempt
            reason = "timed out" if result.timed_out else f"exit {result.exit_code}"
            state.log(f"worker {worker_id} {reason}, retry {attempt + 1}/{retries} in {delay}s")

            try:
                await asyncio.sleep(delay)
            except asyncio.CancelledError:
                break

    assert result is not None
    return result


async def run_spinner(state: ReviewState) -> None:
    """Async spinner task."""
    if not sys.stderr.isatty():
        return

    frames = "|/-\\"
    idx = 0

    while not state.spinner_stop.is_set():
        frame = frames[idx % len(frames)]
        line = f"\r[review] Running: {state.completed}/{state.total_workers} complete {frame}"
        sys.stderr.write(line)
        sys.stderr.flush()
        idx += 1

        try:
            await asyncio.wait_for(
                state.spinner_stop.wait(),
                timeout=SPINNER_INTERVAL,
            )
            break
        except asyncio.TimeoutError:
            pass

    # Final state
    final = f"\r[review] Running: {state.completed}/{state.total_workers} complete ✓\n"
    sys.stderr.write(final)
    sys.stderr.flush()


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


async def summarize_findings(
    aggregated: List[AggregatedFinding],
) -> Tuple[GroupedFindings, int, str, str, float]:
    """Summarize findings using LLM (async version)."""
    if not aggregated:
        return GroupedFindings(findings=[]), 0, "", "", 0.0

    start_time = time.monotonic()
    prompt = GROUP_PROMPT.rstrip()
    payload = json.dumps(aggregated, ensure_ascii=True)
    full_prompt = f"{prompt}\n\nINPUT JSON:\n{payload}\n"

    proc = await asyncio.create_subprocess_exec(
        "codex", "exec", "--color", "never", "-",
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )

    stdout_bytes, stderr_bytes = await proc.communicate(input=full_prompt.encode())
    duration = time.monotonic() - start_time

    output = stdout_bytes.decode().strip()
    stderr = stderr_bytes.decode().strip()

    if not output:
        return GroupedFindings(findings=[]), proc.returncode or 0, stderr, output, duration

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

    return data, proc.returncode or 0, stderr, output, duration


def render_report(
    grouped: GroupedFindings,
    summarize_exit_code: int,
    summarize_stderr: str,
    summarize_raw: str,
    parse_errors: int,
    failed_iters: List[int],
    timed_out_iters: List[int] | None = None,
    wall_clock_duration: float | None = None,
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

    # Warnings
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

        if summary:
            wrapped = wrap_text(
                summary, width - 3, initial_indent="   ", subsequent_indent="   "
            )
            lines.append(wrapped)

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
    has_timing = (
        wall_clock_duration is not None
        or worker_durations
        or summarizer_duration is not None
    )
    if has_timing:
        lines.append("")
        lines.append(f"{c.DIM}Timing:{c.RESET}")

        if wall_clock_duration is not None:
            lines.append(
                f"  {c.DIM}workers: {format_duration(wall_clock_duration)}{c.RESET}"
            )

        if worker_durations:
            durations = list(worker_durations.values())
            avg = sum(durations) / len(durations)
            lines.append(
                f"  {c.DIM}  min {format_duration(min(durations))} / "
                f"avg {format_duration(avg)} / "
                f"max {format_duration(max(durations))}{c.RESET}"
            )

        if summarizer_duration is not None:
            lines.append(
                f"  {c.DIM}summarizer: {format_duration(summarizer_duration)}{c.RESET}"
            )

        if wall_clock_duration is not None and summarizer_duration is not None:
            total = wall_clock_duration + summarizer_duration
            lines.append(
                f"  {c.DIM}total: {format_duration(total)}{c.RESET}"
            )

    return "\n".join(lines)


async def async_main(args: argparse.Namespace) -> int:
    """Async entry point."""
    state = ReviewState(
        total_workers=args.workers,
        verbose=args.verbose,
    )

    # Set up signal handlers
    loop = asyncio.get_running_loop()

    def handle_interrupt() -> None:
        if state.interrupted:
            return  # Already handling
        state.interrupted = True
        state.spinner_stop.set()
        sys.stderr.write("\n[review] Interrupted, shutting down...\n")
        sys.stderr.flush()
        # Cancel all running tasks
        for task in state.tasks:
            task.cancel()

    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, handle_interrupt)

    cmd = build_command(args.base)
    cmd_str = " ".join(shlex.quote(part) for part in cmd)

    state.log(f"Command: {cmd_str}")
    state.log(f"Workers: {args.workers}")

    # Start spinner
    spinner_task = asyncio.create_task(run_spinner(state))

    # Track wall-clock time
    workers_start = time.monotonic()

    # Run workers concurrently
    async def run_worker(worker_id: int) -> WorkerResult:
        result = await collect_findings_with_retry(
            cmd, worker_id, args.timeout, args.retries, state
        )
        state.completed += 1
        return result

    # Create tasks and store references for cancellation
    state.tasks = [
        asyncio.create_task(run_worker(i)) for i in range(1, args.workers + 1)
    ]

    try:
        results = await asyncio.gather(*state.tasks, return_exceptions=True)
    except asyncio.CancelledError:
        state.spinner_stop.set()
        await spinner_task
        return EXIT_INTERRUPTED

    workers_duration = time.monotonic() - workers_start

    state.spinner_stop.set()
    await spinner_task

    if state.interrupted:
        return EXIT_INTERRUPTED

    # Process results
    all_findings: List[Finding] = []
    parse_errors = 0
    failed_iters: List[int] = []
    timed_out_iters: List[int] = []
    worker_durations: dict[int, float] = {}
    exception_count = 0

    for result in results:
        if isinstance(result, Exception):
            state.log(f"Worker exception: {result}")
            exception_count += 1
            continue

        parse_errors += result.parse_errors
        worker_durations[result.worker_id] = result.duration_seconds

        if result.timed_out:
            timed_out_iters.append(result.worker_id)
        elif result.exit_code != 0:
            failed_iters.append(result.worker_id)

        all_findings.extend(result.findings)

    # Check if all workers failed
    total_failures = len(failed_iters) + len(timed_out_iters) + exception_count
    if total_failures >= args.workers:
        state.log("All workers failed")
        return EXIT_ERROR

    # Summarize
    aggregated = aggregate_findings(all_findings)
    (
        grouped,
        summarize_exit_code,
        summarize_stderr,
        summarize_raw,
        summarizer_duration,
    ) = await summarize_findings(aggregated)

    # Output
    if args.json:
        output_data = {
            "findings": grouped.get("findings", []),
            "total_workers": args.workers,
            "warnings": {
                "failed_workers": failed_iters,
                "timed_out_workers": timed_out_iters,
                "parse_errors": parse_errors,
            },
            "timing": {
                "workers_seconds": workers_duration,
                "worker_stats": {
                    "min": min(worker_durations.values()) if worker_durations else 0,
                    "avg": sum(worker_durations.values()) / len(worker_durations) if worker_durations else 0,
                    "max": max(worker_durations.values()) if worker_durations else 0,
                },
                "summarizer_seconds": summarizer_duration,
                "total_seconds": workers_duration + (summarizer_duration or 0),
            },
        }
        if summarize_exit_code != 0:
            output_data["summarizer_error"] = {
                "exit_code": summarize_exit_code,
                "stderr": summarize_stderr,
                "raw_output": summarize_raw,
            }
        print(json.dumps(output_data, indent=2))
        if summarize_exit_code != 0:
            return EXIT_ERROR
        findings = grouped.get("findings", [])
        return EXIT_FINDINGS if findings else EXIT_NO_FINDINGS

    output = render_report(
        grouped=grouped,
        summarize_exit_code=summarize_exit_code,
        summarize_stderr=summarize_stderr,
        summarize_raw=summarize_raw,
        parse_errors=parse_errors,
        failed_iters=failed_iters,
        timed_out_iters=timed_out_iters,
        wall_clock_duration=workers_duration,
        worker_durations=worker_durations,
        summarizer_duration=summarizer_duration,
        total_workers=args.workers,
    )
    print(output)

    if summarize_exit_code != 0:
        return EXIT_ERROR
    findings = grouped.get("findings", [])
    return EXIT_FINDINGS if findings else EXIT_NO_FINDINGS


def main() -> int:
    args = parse_args()

    if not sys.stdout.isatty():
        Colors.disable()

    if not check_dependencies():
        return EXIT_ERROR

    if args.workers < 1:
        print("--workers must be >= 1", file=sys.stderr)
        return EXIT_ERROR

    return asyncio.run(async_main(args))


if __name__ == "__main__":
    raise SystemExit(main())
