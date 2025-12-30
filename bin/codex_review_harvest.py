#!/usr/bin/env python3
# Usage: codex_review_harvest.py [--min N] [--max N] [--base BRANCH]

import argparse
import json
import shlex
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime
from typing import Iterable, List, Optional, Tuple


@dataclass
class Finding:
    text: str
    iteration: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run codex review iteratively, parse JSONL output, and summarize findings as Markdown."
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


def format_blockquote(text: str) -> str:
    lines = text.strip().splitlines() or [""]
    return "\n".join(f"> {line}" for line in lines)


GROUP_PROMPT = """# Codex Review Harvest Summarizer

You are grouping results from repeated Codex review runs.

Input: a JSON array of strings, each string is an agent_message from a review run.

Task:
- Cluster messages that describe the same underlying issue.
- Create a short, precise title per group.
- Keep groups distinct; do not merge different issues.
- If something is unique, keep it as its own group.

Output format (Markdown only, no extra prose):
1. **<Short issue title>**
   - Summary: <1-2 sentences>
   - Messages:
     - <short excerpt from message 1>
     - <short excerpt from message 2>

Rules:
- Use a numbered list for groups.
- Keep excerpts under ~200 characters each.
- Preserve file paths, flags, branch names, and commands in excerpts when present.
- If the input is empty, output: "No findings captured."
"""


def summarize_findings(messages: List[str]) -> Tuple[str, int, str]:
    if not messages:
        return "No findings captured.", 0, ""

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
    if not output:
        output = "No findings captured."
    return output, proc.returncode, proc.stderr.strip()


def render_markdown(
    cmd: List[str],
    base: str,
    workers: int,
    findings: List[Finding],
    parse_errors: int,
    failed_iters: List[int],
    grouped_output: str,
    summarize_exit_code: int,
    summarize_stderr: str,
) -> str:
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cmd_str = " ".join(shlex.quote(part) for part in cmd)
    total_findings = len(findings)

    lines: List[str] = []
    lines.append("# Codex Review Harvest")
    lines.append("")
    lines.append(f"- Timestamp: {now}")
    lines.append(f"- Base: {base}")
    lines.append(f"- Command: `{cmd_str}`")
    lines.append(f"- Workers: {workers}")
    lines.append(f"- Findings: {total_findings} total")
    if parse_errors:
        lines.append(f"- Parse errors: {parse_errors}")
    if failed_iters:
        joined = ", ".join(str(i) for i in failed_iters)
        lines.append(f"- Failed iterations: {joined}")
    if summarize_exit_code != 0:
        lines.append(f"- Summarize exit code: {summarize_exit_code}")
        if summarize_stderr:
            lines.append(f"- Summarize stderr: {summarize_stderr}")

    lines.append("")
    lines.append("## Findings")
    lines.append(grouped_output)
    lines.append("")

    return "\n".join(lines)


def main() -> int:
    args = parse_args()
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

    grouped_output, summarize_exit_code, summarize_stderr = summarize_findings(
        [finding.text for finding in all_findings if finding.text]
    )
    output = render_markdown(
        cmd=cmd,
        base=args.base,
        workers=args.workers,
        findings=all_findings,
        parse_errors=parse_errors,
        failed_iters=failed_iters,
        grouped_output=grouped_output,
        summarize_exit_code=summarize_exit_code,
        summarize_stderr=summarize_stderr,
    )
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
