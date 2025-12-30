#!/usr/bin/env python3
# Usage: codex_review_harvest.py [--min N] [--max N] [--base BRANCH]

import argparse
import json
import shlex
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from typing import Iterable, List, Optional, Set, Tuple


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


def normalize(text: str) -> str:
    return "\n".join(line.rstrip() for line in text.strip().splitlines())


def format_blockquote(text: str) -> str:
    lines = text.strip().splitlines() or [""]
    return "\n".join(f"> {line}" for line in lines)


def render_markdown(
    cmd: List[str],
    base: str,
    min_iters: int,
    max_iters: int,
    total_iters: int,
    findings: List[Finding],
    unique_texts: List[str],
    parse_errors: int,
    failed_iters: List[int],
) -> str:
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cmd_str = " ".join(shlex.quote(part) for part in cmd)
    total_findings = len(findings)
    unique_count = len(unique_texts)

    lines: List[str] = []
    lines.append("# Codex Review Harvest")
    lines.append("")
    lines.append(f"- Timestamp: {now}")
    lines.append(f"- Base: {base}")
    lines.append(f"- Command: `{cmd_str}`")
    lines.append(f"- Iterations: {total_iters} (min {min_iters}, max {max_iters})")
    lines.append(f"- Findings: {total_findings} total, {unique_count} unique")
    if parse_errors:
        lines.append(f"- Parse errors: {parse_errors}")
    if failed_iters:
        joined = ", ".join(str(i) for i in failed_iters)
        lines.append(f"- Failed iterations: {joined}")

    lines.append("")
    lines.append("## Unique Findings")
    if not unique_texts:
        lines.append("")
        lines.append("No findings captured.")
    else:
        for idx, text in enumerate(unique_texts, start=1):
            lines.append("")
            lines.append(f"{idx}.")
            lines.append(format_blockquote(text))

    lines.append("")
    lines.append("## Findings By Iteration")
    if not findings:
        lines.append("")
        lines.append("No findings captured.")
    else:
        for iteration in range(1, total_iters + 1):
            iter_findings = [f for f in findings if f.iteration == iteration]
            lines.append("")
            lines.append(f"### Iteration {iteration}")
            if not iter_findings:
                lines.append("")
                lines.append("No findings captured.")
                continue
            for idx, finding in enumerate(iter_findings, start=1):
                lines.append("")
                lines.append(f"{idx}.")
                lines.append(format_blockquote(finding.text))

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
    unique_seen: Set[str] = set()
    unique_ordered: List[str] = []
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

        new_unique = 0
        for finding in findings:
            all_findings.append(finding)
            norm = normalize(finding.text)
            if norm and norm not in unique_seen:
                unique_seen.add(norm)
                unique_ordered.append(finding.text)
                new_unique += 1

        if not args.quiet:
            if findings:
                for finding in findings:
                    text = normalize(finding.text)
                    if text:
                        print(
                            f"[codex-review-harvest] agent_message: {text}",
                            file=sys.stderr,
                        )
            else:
                print("[codex-review-harvest] agent_message: (none)", file=sys.stderr)
            print(
                f"[codex-review-harvest] Iteration {iteration} done (new unique findings: {new_unique}).",
                file=sys.stderr,
            )

        if iteration >= args.min_iters and new_unique == 0:
            if not args.quiet:
                print(
                    "[codex-review-harvest] Early stop: no new unique findings.",
                    file=sys.stderr,
                )
            break

    output = render_markdown(
        cmd=cmd,
        base=args.base,
        min_iters=args.min_iters,
        max_iters=args.max_iters,
        total_iters=total_iters,
        findings=all_findings,
        unique_texts=unique_ordered,
        parse_errors=parse_errors,
        failed_iters=failed_iters,
    )
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
