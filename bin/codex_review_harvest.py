#!/usr/bin/env python3
# Usage: codex_review_harvest.py [--min N] [--max N] [--base BRANCH]

import argparse
import json
import shlex
import subprocess
import sys
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
        "--min",
        dest="min_iters",
        type=int,
        default=5,
        help="Minimum iterations (default: 5)",
    )
    parser.add_argument(
        "--max",
        dest="max_iters",
        type=int,
        default=25,
        help="Maximum iterations (default: 25)",
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
        "--quiet",
        action="store_true",
        help="Suppress progress logs (default: false).",
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


def collect_findings(cmd: List[str], iteration: int) -> Tuple[List[Finding], int, int]:
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
                findings.append(Finding(text=text, iteration=iteration))

    exit_code = proc.wait()
    return findings, exit_code, parse_errors


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
    min_iters: int,
    max_iters: int,
    total_iters: int,
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
    lines.append(f"- Iterations: {total_iters} (min {min_iters}, max {max_iters})")
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
    if args.min_iters < 1:
        print("--min must be >= 1", file=sys.stderr)
        return 2
    if args.max_iters < args.min_iters:
        print("--max must be >= --min", file=sys.stderr)
        return 2

    cmd = build_command(args.base, args.output_schema)
    all_findings: List[Finding] = []
    parse_errors = 0
    failed_iters: List[int] = []

    total_iters = 0
    cmd_str = " ".join(shlex.quote(part) for part in cmd)
    if not args.quiet:
        print(f"[codex-review-harvest] Command: {cmd_str}", file=sys.stderr)
        print(
            f"[codex-review-harvest] Iterations: min={args.min_iters} max={args.max_iters}",
            file=sys.stderr,
        )
    for iteration in range(1, args.max_iters + 1):
        total_iters = iteration
        if not args.quiet:
            print(
                f"[codex-review-harvest] Iteration {iteration} starting...",
                file=sys.stderr,
            )
        findings, exit_code, parse_errs = collect_findings(cmd, iteration)
        parse_errors += parse_errs

        if exit_code != 0:
            failed_iters.append(iteration)

        for finding in findings:
            all_findings.append(finding)

        if not args.quiet:
            if findings:
                for finding in findings:
                    if finding.text:
                        print(
                            f"[codex-review-harvest] agent_message: {finding.text}",
                            file=sys.stderr,
                        )
            else:
                print("[codex-review-harvest] agent_message: (none)", file=sys.stderr)
            print(
                f"[codex-review-harvest] Iteration {iteration} done.",
                file=sys.stderr,
            )

    grouped_output, summarize_exit_code, summarize_stderr = summarize_findings(
        [finding.text for finding in all_findings if finding.text]
    )
    output = render_markdown(
        cmd=cmd,
        base=args.base,
        min_iters=args.min_iters,
        max_iters=args.max_iters,
        total_iters=total_iters,
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
