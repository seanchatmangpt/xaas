#!/usr/bin/env python3
"""Fail if any .md under docs/claude/diataxis is not linked from its README.md.

Usage: check_diataxis_index.py [diataxis_dir]
"""
import re
import sys
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "docs/claude/diataxis")
readme = root / "README.md"
text = readme.read_text()
linked = {
    (readme.parent / m.split("#")[0]).resolve()
    for m in re.findall(r"\]\(([^)\s]+\.md(?:#[^)]*)?)\)", text)
}
missing = sorted(
    str(p.relative_to(root))
    for p in root.rglob("*.md")
    if p.name != "README.md" or p.parent != root
    if p.resolve() not in linked
)
if missing:
    print("ORPHANS (not linked from README.md):")
    for m in missing:
        print("  " + m)
    sys.exit(1)
print(f"OK: all diataxis .md files linked from README.md ({len(list(root.rglob('*.md')))} files)")
