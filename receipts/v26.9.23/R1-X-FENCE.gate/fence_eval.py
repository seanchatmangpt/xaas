#!/usr/bin/env python3
"""R1-X-FENCE evidence harness: evaluate the job-level `if:` of publish-image and deploy
in a ci_cd.yaml under real GitHub-event contexts with nektos/act's expression engine.

Usage: fence_eval.py <ci_cd.yaml> <scratch_dir>

The job conditions and the `on:` block are copied verbatim (by YAML parse) from the file
under judgement into a derived workflow whose steps are a single echo and whose `needs`
are dropped, so each job's own condition is judged in isolation (a job skipped only
because a need was skipped would hide a live condition). act then runs a dry run
(`act <event> -n -v`) per scenario in a fresh git repo whose HEAD is github.sha, and the
harness reads act's own "Skipping job" / "Run Set up job" lines.

Prints one row per (scenario, job): RUN or SKIP, then the fence verdict. Exit 0 iff
no push / pull_request scenario runs either job and only the admitted dispatch runs both.
act's evaluator is a reimplementation of GitHub's expression semantics, not GitHub itself.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

import yaml

JOBS = ("publish-image", "deploy")


def main(src, scratch):
    doc = yaml.safe_load(Path(src).read_text())
    on = doc.get("on", doc.get(True))
    repo = Path(scratch) / "fence-eval-repo"
    subprocess.run(["rm", "-rf", str(repo)], check=True)
    (repo / ".github/workflows").mkdir(parents=True)
    derived = {"name": "fence-eval", "on": on, "jobs": {}}
    for job in JOBS:
        cond = doc["jobs"][job].get("if")
        derived["jobs"][job] = {
            "runs-on": "ubuntu-latest",
            **({"if": cond} if cond is not None else {}),
            "steps": [{"run": f"echo {job}"}],
        }
        print(f"condition {job}: {cond!r}")
    (repo / ".github/workflows/fence.yaml").write_text(yaml.safe_dump(derived, sort_keys=False))
    git = ["git", "-C", str(repo)]
    subprocess.run(git + ["init", "-q", "-b", "main"], check=True)
    subprocess.run(git + ["add", "-A"], check=True)
    subprocess.run(
        git + ["-c", "user.name=fence", "-c", "user.email=fence@local", "commit", "-q", "-m", "fence"],
        check=True,
    )
    sha = subprocess.run(git + ["rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
    print(f"github.sha (derived repo HEAD): {sha}")
    base_repo = {"full_name": "seanchatmangpt/xaas", "name": "xaas", "owner": {"login": "seanchatmangpt"},
                 "default_branch": "main"}
    other = "0" * 40
    scenarios = [
        ("push main", "push", {"ref": "refs/heads/main"}, set()),
        ("push feat/x", "push", {"ref": "refs/heads/feat/x"}, set()),
        ("pull_request -> main", "pull_request",
         {"ref": "refs/pull/1/merge", "number": 1,
          "pull_request": {"number": 1, "head": {"sha": sha, "ref": "feat/x"}, "base": {"ref": "main"}}}, set()),
        ("dispatch main, no inputs", "workflow_dispatch", {"ref": "refs/heads/main", "inputs": {}}, set()),
        ("dispatch main, expected=HEAD, reason", "workflow_dispatch",
         {"ref": "refs/heads/main", "inputs": {"expected_head_sha": sha, "reason": "operator release"}}, set(JOBS)),
        ("dispatch main, expected=other sha, reason", "workflow_dispatch",
         {"ref": "refs/heads/main", "inputs": {"expected_head_sha": other, "reason": "operator release"}}, set()),
        ("dispatch main, expected=HEAD, empty reason", "workflow_dispatch",
         {"ref": "refs/heads/main", "inputs": {"expected_head_sha": sha, "reason": ""}}, set()),
        ("dispatch feat/x, expected=HEAD, reason", "workflow_dispatch",
         {"ref": "refs/heads/feat/x", "inputs": {"expected_head_sha": sha, "reason": "operator release"}}, set()),
    ]
    ok = True
    for label, event, payload, expected_run in scenarios:
        ev = Path(scratch) / "fence-event.json"
        ev.write_text(json.dumps({**payload, "repository": base_repo}))
        proc = subprocess.run(
            ["act", event, "-n", "-v", "-W", ".github/workflows/fence.yaml", "-e", str(ev),
             "-P", "ubuntu-latest=catthehacker/ubuntu:act-latest", "--pull=false",
             "--container-architecture", "linux/amd64"],
            cwd=repo, capture_output=True, text=True, timeout=300,
        )
        out = proc.stdout + proc.stderr
        for job in JOBS:
            # act pads job names to a common width inside the brackets
            ran = re.search(rf"\[fence-eval/{re.escape(job)}\s*\] ⭐ Run Set up job", out) is not None
            skipped = f"Skipping job '{job}'" in out
            if ran == skipped:
                verdict = "INDETERMINATE"
                ok = False
            else:
                verdict = "RUN" if ran else "SKIP"
                if (job in expected_run) != ran:
                    ok = False
                    verdict += " (UNEXPECTED)"
            print(f"act exit={proc.returncode} | {label:45s} | {job:13s} | {verdict}")
        if proc.returncode != 0:
            ok = False
    print("FENCE HOLDS" if ok else "FENCE BROKEN")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
