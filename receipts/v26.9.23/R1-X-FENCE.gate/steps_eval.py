#!/usr/bin/env python3
"""R1-X-FENCE evidence harness: execute the in-job admission and receipt steps of
publish-image and deploy, extracted verbatim (by YAML parse) from the ci_cd.yaml under
judgement, as real bash processes with the GitHub runner's default shell flags
(`bash --noprofile --norc -eo pipefail`) under GITHUB_* scenario environments.

Usage: steps_eval.py <ci_cd.yaml> <scratch_dir>

Admission: the job-level `if:` compares strings case-insensitively (GitHub expression
semantics), so the step's byte-exact bash comparison is the second fence; it must refuse
(exit 64, typed REFUSED[...]) every non-admitted context. Receipts: the steps must write
a JSON receipt whose standing is derived from the actuation outcome and, for publication,
from an independent registry read (`docker buildx imagetools inspect --raw`). The ALIVE
publication case reads a public image from Docker Hub; when the registry is unreachable
that case is reported SKIPPED (visible), never passed.

Exit 0 iff every case matches its expectation.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

import yaml

SHA = "49695d722fb684fd3a34a34d7e1252f76ab50003"
BASH = ["bash", "--noprofile", "--norc", "-eo", "pipefail"]


def step(doc, job, name):
    for s in doc["jobs"][job]["steps"]:
        if s.get("name") == name:
            return s
    raise SystemExit(f"step {name!r} not found in job {job!r}")


def run(script, env, cwd):
    path = Path(cwd) / "step.sh"
    path.write_text(script)
    full = {"PATH": os.environ["PATH"], "HOME": os.environ.get("HOME", "/tmp"), **env}
    return subprocess.run(BASH + [str(path)], env=full, cwd=cwd, capture_output=True, text=True, timeout=120)


def gh(event="workflow_dispatch", ref="refs/heads/main", sha=SHA):
    return {"GITHUB_EVENT_NAME": event, "GITHUB_REF": ref, "GITHUB_SHA": sha,
            "GITHUB_REPOSITORY": "seanchatmangpt/xaas", "GITHUB_RUN_ID": "1", "GITHUB_RUN_ATTEMPT": "1",
            "GITHUB_ACTOR": "operator"}


def main(src, scratch):
    doc = yaml.safe_load(Path(src).read_text())
    work = Path(scratch) / "steps-eval"
    subprocess.run(["rm", "-rf", str(work)], check=True)
    work.mkdir(parents=True)
    ok = True

    admit_cases = [
        ("push main", gh(event="push"), "sha", "r", 64, "REFUSED[NOT_OPERATOR_DISPATCH]"),
        ("dispatch feat/x", gh(ref="refs/heads/feat/x"), "sha", "r", 64, "REFUSED[NOT_MAIN]"),
        ("dispatch main, other sha", gh(), "0" * 40, "r", 64, "REFUSED[HEAD_MOVED]"),
        ("dispatch main, uppercased sha", gh(), "SHA_UPPER", "r", 64, "REFUSED[HEAD_MOVED]"),
        ("dispatch main, empty reason", gh(), "sha", "", 64, "REFUSED[REASON_MISSING]"),
        ("dispatch main, admitted", gh(), "sha", "operator release", 0, ""),
    ]
    for job, name in (("publish-image", "Admit operator publication authority"),
                      ("deploy", "Admit operator deployment authority")):
        s = step(doc, job, name)
        for label, env, expected, reason, want_exit, want_err in admit_cases:
            exp = {"sha": SHA, "SHA_UPPER": SHA.upper()}.get(expected, expected)
            p = run(s["run"], {**env, "EXPECTED_HEAD_SHA": exp, "ACTUATION_REASON": reason}, work)
            good = p.returncode == want_exit and want_err in p.stderr
            ok &= good
            print(f"admit | {job:13s} | {label:30s} | exit={p.returncode} | {p.stderr.strip()[:60]!r} | "
                  f"{'OK' if good else 'MISMATCH'}")

    def receipt_case(job, name, out_file, env, expect):
        nonlocal ok
        s = step(doc, job, name)
        summary = work / "summary.md"
        summary.write_text("")
        (work / out_file).unlink(missing_ok=True)
        p = run(s["run"], {**gh(), "GITHUB_STEP_SUMMARY": str(summary), **env}, work)
        if p.returncode != 0:
            ok = False
            print(f"receipt | {job:13s} | exit={p.returncode} | {p.stderr.strip()[-200:]!r} | MISMATCH")
            return
        r = json.loads((work / out_file).read_text())
        body = {k: v for k, v in r.items() if k != "receipt_sha256"}
        digest_ok = r["receipt_sha256"] == __import__("hashlib").sha256(
            json.dumps(body, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        got = {k: r[k] for k in expect}
        good = got == expect and digest_ok and "receipt" in summary.read_text().lower()
        ok &= good
        print(f"receipt | {job:13s} | exit=0 | {json.dumps(got, sort_keys=True)} | receipt_sha256 "
              f"{'recomputes' if digest_ok else 'MISMATCH'} | {'OK' if good else 'MISMATCH'}")

    pub = ("publish-image", "Manufacture publication receipt", "publish-receipt.json")
    receipt_case(*pub, {"ACTUATION_REASON": "r", "BUILD_OUTCOME": "failure", "IMAGE_TAGS": "",
                        "IMAGE_DIGEST": "", "UNIQUE_TAG": ""},
                 {"executed": True, "verified": False, "standing": "UNKNOWN", "registry_digest": "unobserved"})
    receipt_case(*pub, {"ACTUATION_REASON": "r", "BUILD_OUTCOME": "success", "IMAGE_TAGS": "",
                        "IMAGE_DIGEST": "sha256:" + "0" * 64, "UNIQUE_TAG": ""},
                 {"executed": True, "verified": False, "standing": "UNKNOWN"})
    ref = "docker.io/library/alpine:3.20"
    probe = subprocess.run(["docker", "buildx", "imagetools", "inspect", ref, "--format", "{{json .Manifest}}"],
                           capture_output=True, text=True, timeout=120)
    if probe.returncode != 0:
        print(f"receipt | publish-image | SKIPPED ALIVE case: registry unreachable ({probe.stderr.strip()[:80]!r})")
    else:
        digest = json.loads(probe.stdout)["digest"]
        receipt_case(*pub, {"ACTUATION_REASON": "r", "BUILD_OUTCOME": "success", "IMAGE_TAGS": ref,
                            "IMAGE_DIGEST": digest, "UNIQUE_TAG": ref},
                     {"executed": True, "verified": True, "standing": "ALIVE", "registry_digest": digest})
        receipt_case(*pub, {"ACTUATION_REASON": "r", "BUILD_OUTCOME": "success", "IMAGE_TAGS": ref,
                            "IMAGE_DIGEST": "sha256:" + "f" * 64, "UNIQUE_TAG": ref},
                     {"executed": True, "verified": False, "standing": "UNKNOWN", "registry_digest": digest})
    dep = ("deploy", "Manufacture deployment receipt", "deploy-receipt.json")
    receipt_case(*dep, {"ACTUATION_REASON": "r", "DEPLOY_OUTCOME": "success", "IMAGE_TAG": "ghcr.io/x/xaas:sha-1"},
                 {"executed": True, "verified": False, "standing": "PARTIAL_ALIVE"})
    receipt_case(*dep, {"ACTUATION_REASON": "r", "DEPLOY_OUTCOME": "failure", "IMAGE_TAG": "ghcr.io/x/xaas:sha-1"},
                 {"executed": True, "verified": False, "standing": "UNKNOWN"})
    receipt_case(*dep, {"ACTUATION_REASON": "r", "DEPLOY_OUTCOME": "skipped", "IMAGE_TAG": ""},
                 {"executed": False, "verified": False, "standing": "UNKNOWN"})
    print("STEPS HOLD" if ok else "STEPS BROKEN")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
