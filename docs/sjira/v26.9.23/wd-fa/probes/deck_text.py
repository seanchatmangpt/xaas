#!/usr/bin/env python3
"""Deterministic text projection of a supplied WD FA deck page (V23-W).

    deck_text.py --zip "<FA Morning Brief System.zip>" --member "<page>.dc.html" --out <txt>

Reads one member of the operator-supplied zip, drops <script> and <style>
elements and every tag, unescapes HTML entities, strips each line and keeps
the non-empty ones (one text node per line), and writes UTF-8 text ending in a
newline. Prints `SUPPLIED <member> zip sha256:<hex> member sha256:<hex> text
sha256:<hex> lines <n>`. The output is a pure function of the member bytes, so
the supply receipt replays byte-identically. Standard library only; no LLM.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import re
import sys
import zipfile
from pathlib import Path


def project(member_bytes: bytes) -> str:
    text = member_bytes.decode("utf-8")
    text = re.sub(r"<script.*?</script>", "", text, flags=re.S)
    text = re.sub(r"<style.*?</style>", "", text, flags=re.S)
    text = re.sub(r"<[^>]+>", "\n", text)
    text = html.unescape(text)
    lines = [line.strip() for line in text.split("\n") if line.strip()]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--zip", required=True, type=Path)
    parser.add_argument("--member", required=True)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args(argv)
    zip_bytes = args.zip.read_bytes()
    with zipfile.ZipFile(args.zip) as archive:
        member = archive.read(args.member)
    text = project(member)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(text.encode("utf-8"))

    def digest(data: bytes) -> str:
        return "sha256:" + hashlib.sha256(data).hexdigest()

    sys.stdout.write(
        f"SUPPLIED {args.member} zip {digest(zip_bytes)} member {digest(member)} "
        f"text {digest(text.encode('utf-8'))} lines {text.count(chr(10))}\n"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
