#!/usr/bin/env python3
"""Download a page from the live site and save its code blocks, in page order.

Usage: extract.py [--wait SHA] PAGE OUTDIR

Each block is written to OUTDIR as NNN-<section>.<lang> (e.g. 007-update.bash),
so the runners can execute them in order. --wait polls until the site's
<meta name="revision"> matches SHA, i.e. GitHub Pages has published that commit.
"""
import argparse
import html
import re
import sys
import time
import urllib.request
from pathlib import Path

BASE = "https://install.wiscovitch.org"


def fetch(path):
    # A changing query string skips the Pages CDN cache
    sep = "&" if "?" in path else "?"
    url = f"{BASE}{path}{sep}ci={int(time.time() * 1000)}"
    with urllib.request.urlopen(url, timeout=30) as r:
        return r.read().decode("utf-8")


def wait_for_revision(sha, timeout=900):
    deadline = time.time() + timeout
    while True:
        m = re.search(r'<meta name="revision" content="([0-9a-f]*)"', fetch("/"))
        live = m.group(1) if m else None
        if live == sha:
            print(f"live site is at {sha[:7]}")
            return
        if time.time() > deadline:
            sys.exit(f"timed out: live site is at {live}, expected {sha}")
        print(f"live site at {live and live[:7]}, waiting for {sha[:7]}...")
        time.sleep(15)


def blocks(page):
    section = "top"
    pattern = re.compile(
        r'<h2 id="([^"]+)"'
        r'|<div class="language-(\w+)[^>]*>\s*<div class="highlight">\s*<pre[^>]*>(.*?)</pre>',
        re.S,
    )
    for m in pattern.finditer(page):
        if m.group(1):
            section = m.group(1)
        else:
            code = html.unescape(re.sub(r"<[^>]+>", "", m.group(3))).rstrip("\n")
            yield section, m.group(2), code


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wait")
    ap.add_argument("page")
    ap.add_argument("outdir")
    args = ap.parse_args()

    if args.wait:
        wait_for_revision(args.wait)
    out = Path(args.outdir)
    out.mkdir(parents=True, exist_ok=True)
    found = list(blocks(fetch(args.page)))
    if not found:
        sys.exit(f"no code blocks found on {args.page}")
    for i, (section, lang, code) in enumerate(found, 1):
        (out / f"{i:03d}-{section}.{lang}").write_text(code + "\n", encoding="utf-8", newline="\n")
    print(f"{len(found)} blocks from {args.page} -> {out}")


if __name__ == "__main__":
    main()
