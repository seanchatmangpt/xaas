#!/usr/bin/env python3
"""R1-X-FENCE conservation check: conserve.py <base ci_cd.yaml> <new ci_cd.yaml>. Every job other than
publish-image/deploy, every top-level key and the push/pull_request triggers are identical by YAML parse; the
two fenced jobs keep every base step in order (only a step id may be added) and every non-step key."""
import sys, yaml
base = yaml.safe_load(open(sys.argv[1])); new = yaml.safe_load(open(sys.argv[2]))
ok = True
# every top-level key except `on` identical; `on` differs only by workflow_dispatch inputs
for k in set(base) | set(new):
    if k in ("on", True): continue
    if k == "jobs": continue
    same = base.get(k) == new.get(k); ok &= same; print(f"top-level {k!r}: {'identical' if same else 'CHANGED'}")
bon, non = base.get("on", base.get(True)), new.get("on", new.get(True))
rest_same = {k: v for k, v in bon.items() if k != "workflow_dispatch"} == {k: v for k, v in non.items() if k != "workflow_dispatch"}
ok &= rest_same; print(f"on (push/pull_request): {'identical' if rest_same else 'CHANGED'}; workflow_dispatch: {bon.get('workflow_dispatch')!r} -> inputs {sorted((non['workflow_dispatch'] or {}).get('inputs', {}))}")
assert list(base["jobs"]) == list(new["jobs"]), "job set/order changed"
print(f"jobs (order preserved, none deleted): {list(new['jobs'])}")
for j in base["jobs"]:
    b, n = base["jobs"][j], new["jobs"][j]
    if j not in ("publish-image", "deploy"):
        same = b == n; ok &= same; print(f"job {j}: {'identical' if same else 'CHANGED'}"); continue
    keys_same = {k: v for k, v in b.items() if k not in ("if", "steps")} == {k: v for k, v in n.items() if k not in ("if", "steps")}
    ok &= keys_same
    strip = lambda s: {k: v for k, v in s.items() if k != "id"}  # step ids added for receipts are the only allowed edit to a base step
    bsteps = [strip(s) for s in b["steps"]]; nsteps = [strip(s) for s in n["steps"]]
    it = iter(nsteps); subseq = all(any(x == y for y in it) for x in bsteps)
    ok &= subseq
    added = [s.get("name", s.get("uses")) for s in nsteps if s not in bsteps]
    kept = [s for s in n["steps"] if strip(s) in bsteps]
    ids_added = [s.get("name", s.get("uses")) + " id=" + s["id"] for s, bs in zip(kept, b["steps"]) if "id" in s and "id" not in bs]
    print(f"job {j}: non-step keys {'identical' if keys_same else 'CHANGED'}; if {b.get('if')!r} -> {n.get('if')!r}; base steps preserved in order (ignoring added ids): {subseq}; ids added to base steps: {ids_added}; steps added: {added}")
print("CONSERVED" if ok else "NOT CONSERVED"); sys.exit(0 if ok else 1)
