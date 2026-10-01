#!/usr/bin/env python3
"""Fail (exit 1) iff HANDWRITTEN.md has duplicate ledger rows. Usage: [path]."""
import collections
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "HANDWRITTEN.md"
seen = collections.defaultdict(list)
with open(path, encoding="utf-8") as f:
    for n, line in enumerate(f, 1):
        row = line.rstrip("\n")
        if row.strip() and not row.startswith("#") and " | " in row:
            seen[row].append(n)
dups = {r: v for r, v in seen.items() if len(v) > 1}
for r, v in dups.items():
    print(f"DUPLICATE rows at lines {v}: {r[:80]}")
sys.exit(1 if dups else 0)
