#!/usr/bin/env python3
"""Turn a runner's results.tsv into a table in the GitHub job summary.

Usage: summarize.py BLOCKDIR TITLE

Exits non-zero if any block failed (or nothing ran), and prints the log of
each failed block so it shows in the job output.
"""
import os
import sys
from pathlib import Path

ICONS = {"pass": "✅", "stubbed": "🟡", "skip": "⏭️", "fail": "❌"}

d, title = Path(sys.argv[1]), sys.argv[2]
results = d / "results.tsv"
rows = []
if results.exists():
    for line in results.read_text(encoding="utf-8-sig").splitlines():
        if line.strip():
            name, status, note = (line.split("\t") + ["", ""])[:3]
            rows.append((name, status, note))


def first_line(name):
    for f in d.glob(name + ".*"):
        if f.suffix in (".bash", ".powershell"):
            return f.read_text(encoding="utf-8").splitlines()[0]
    return ""


lines = [f"### {title}", "", "| Block | First line | Result | Note |", "|---|---|---|---|"]
for name, status, note in rows:
    code = first_line(name).replace("|", "\\|")
    lines.append(f"| {name} | `{code}` | {ICONS.get(status, status)} {status} | {note} |")
counts = {s: sum(1 for r in rows if r[1] == s) for s in ICONS}
lines += ["", ", ".join(f"{n} {s}" for s, n in counts.items() if n) or "no results", ""]
report = "\n".join(lines)
print(report)
if os.environ.get("GITHUB_STEP_SUMMARY"):
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as fh:
        fh.write(report + "\n")

failed = [r for r in rows if r[1] == "fail"]
for name, _, _ in failed:
    log = d / f"{name}.log"
    if log.exists():
        print(f"\n===== {name}.log =====")
        print(log.read_text(encoding="utf-8", errors="replace")[-4000:])
sys.exit(1 if failed or not rows else 0)
