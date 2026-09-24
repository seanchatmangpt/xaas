#!/usr/bin/env python3
"""R1-X-PIN dispatch fence: prove, by a YAML parse of ci_cd.yaml AT THE DISPATCHED SHA
(git show <sha>:.github/workflows/ci_cd.yaml, never the working tree), that a
workflow_dispatch of that SHA on ref <ref> cannot run publish-image or deploy.

Usage: dispatch_fence.py <repo> <sha> <ref>

Holds iff, for both jobs, the job-level `if:` is a pure `&&` conjunction (no `||`, no `!`,
no status function such as always()/failure()/cancelled(), no parentheses) that contains
the conjunct `github.ref == 'refs/heads/main'` AND the dispatched ref is not
refs/heads/main; and the workflow's on.workflow_dispatch exists (the dispatch is lawful).
Exit 0 = FENCE HOLDS FOR THIS DISPATCH, 1 = does not hold / cannot be proven.
"""
import re
import subprocess
import sys

import yaml

JOBS = ("publish-image", "deploy")


def main(repo, sha, ref):
    text = subprocess.run(
        ["git", "-C", repo, "show", f"{sha}:.github/workflows/ci_cd.yaml"],
        capture_output=True, text=True, check=True,
    ).stdout
    doc = yaml.safe_load(text)
    on = doc.get("on", doc.get(True))
    ok = True
    if not isinstance(on, dict) or "workflow_dispatch" not in on:
        print("REFUSED: ci_cd.yaml has no on.workflow_dispatch")
        ok = False
    for job in JOBS:
        cond = (doc.get("jobs", {}).get(job) or {}).get("if")
        print(f"{job}: if = {cond!r}")
        if not isinstance(cond, str):
            print(f"REFUSED: {job} has no job-level if (it would run on any event)")
            ok = False
            continue
        if re.search(r"\|\||!(?!=)|\(|always|failure|cancelled|success", cond):
            print(f"REFUSED: {job} if is not a pure && conjunction")
            ok = False
            continue
        conjuncts = [c.strip() for c in cond.split("&&")]
        if "github.ref == 'refs/heads/main'" not in conjuncts:
            print(f"REFUSED: {job} if has no conjunct github.ref == 'refs/heads/main'")
            ok = False
            continue
        if ref != "refs/heads/main":
            print(f"{job}: conjunct github.ref == 'refs/heads/main' is false for ref {ref}")
    if ref == "refs/heads/main":
        print("REFUSED: the dispatched ref is refs/heads/main")
        ok = False
    print(f"sha {sha} ref {ref}: " + ("FENCE HOLDS FOR THIS DISPATCH" if ok else "FENCE NOT PROVEN"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:4]))
