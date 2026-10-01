#!/usr/bin/env python3
"""Fail if standing-court canonical pins disagree, or the negative receipt's
adversary_blob differs from `git hash-object` of the adversary file.

Usage: check_standing_court_pins.py [REPO_ROOT]
"""
import json, re, subprocess, sys
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent)
d = root / "release/standing-courts"
wf = root / ".github/workflows/factory-b-failure-immunity.yml"
errs = []

canon = json.loads((d / "failure-immunity.generated.json").read_text())["canonical_commit"]

def walk(o, path=""):
    if isinstance(o, dict):
        for k, v in o.items():
            yield from walk(v, f"{path}.{k}")
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from walk(v, f"{path}[{i}]")
    elif k_is_pin(path):
        yield path, o

def k_is_pin(path):
    return path.rsplit(".", 1)[-1] == "canonical_commit"

for f in sorted(d.glob("*.json")):
    for p, v in walk(json.loads(f.read_text())):
        if v != canon:
            errs.append(f"{f.name}{p}={v} != {canon}")

md = (d / "FAILURE-IMMUNITY.md").read_text()
shas = re.findall(r"chatman-ecosystem@([0-9a-f]{7,40})", md)
if not shas:
    errs.append("FAILURE-IMMUNITY.md: no chatman-ecosystem@<sha> pin")
errs += [f"FAILURE-IMMUNITY.md pin {s} != {canon}" for s in shas if s != canon]

wfs = re.findall(r"^\s*ref:\s*([0-9a-f]{40})\s*$", wf.read_text(), re.M)
if not wfs:
    errs.append(f"{wf.name}: no 40-hex ref pin")
errs += [f"{wf.name} ref {s} != {canon}" for s in wfs if s != canon]

rc = json.loads((d / "replay-mismatch.negative-receipt.json").read_text())
adv = d / "replay-mismatch.adversary.json"
actual = subprocess.check_output(["git", "-C", str(root), "hash-object", str(adv)], text=True).strip()
if rc["subject"]["adversary_blob"] != actual:
    errs.append(f"adversary_blob {rc['subject']['adversary_blob']} != hash-object {actual}")

if errs:
    print("FAIL"); [print(" -", e) for e in errs]; sys.exit(1)
print(f"OK canonical={canon} adversary_blob={actual}")
