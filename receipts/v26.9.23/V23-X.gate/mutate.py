import subprocess, sys, re
from pathlib import Path
root = Path(sys.argv[1])
script = root / "scripts/sjira/prose_spans.py"
orig = script.read_text()

def suite():
    r = subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "scripts/sjira", "-p", "test_*.py"],
                       cwd=root, capture_output=True, text=True)
    tail = [l for l in r.stderr.splitlines() if l.startswith(("Ran ", "FAILED", "OK"))]
    fails = sorted(set(re.findall(r"(?:FAIL|ERROR): (test_\w+)", r.stderr)))
    return r.returncode, " ".join(tail), fails

MUTS = {
    "m1 check skips source sha256 comparison": ('if digest is not None and str(digest) != sha:', 'if False:'),
    "m2 check skips gate coverage": ('if not covered.get(args.namespace + gate):', 'if False:'),
    "m3 emit takes first match when ambiguous": ('if occurrence is None and len(hits) > 1:', 'if False:'),
    "m4 check skips IRI recomputation": ('if name != expected:', 'if False:'),
    "m5 check skips sourceText comparison": ('if text_lit is not None and span != str(text_lit):', 'if False:'),
    "m6 emit keeps input order": ('resolved.sort(key=lambda c: (c["start"], c["kind"], c["end"], c["local"]))', 'pass'),
    "m7 check accepts any kind": ('if kind is not None and (not isinstance(kind, Literal) or str(kind) not in KINDS):', 'if False:'),
}
code, tail, fails = suite()
print(f"baseline: exit={code} {tail}")
for name, (a, b) in MUTS.items():
    assert orig.count(a) == 1, name
    script.write_text(orig.replace(a, b))
    code, tail, fails = suite()
    print(f"{name}: exit={code} {tail} killed_by={fails}")
    script.write_text(orig)
script.unlink()
code, tail, fails = suite()
print(f"r1 prose_spans.py removed (revert to base, where scripts/sjira/ does not exist): exit={code} {tail} failing={len(fails)}")
script.write_text(orig)
print("restored:", subprocess.run(["git", "status", "--porcelain"], cwd=root, capture_output=True, text=True).stdout or "clean")
