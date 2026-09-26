#!/usr/bin/env python3
"""Post-tag durable re-run of the v26.9.25 AC-13 case-study-schema court (xaas X2).

The tagged receipt ``release/v26.9.25/receipts/case-study-schema.json`` (container
commit 6a63d891) recorded its commands with a scratch ``--output`` path and a
scratch venv interpreter path. Neither is a durable locator. This manufacturer
re-runs the same three commands on the same subject SHA, with:

* ``--output`` relative to the extracted subject directory, and the report
  committed next to this receipt;
* the interpreter recorded as implementation + version + the sha256 of a
  committed requirements lock (``case-study-schema.requirements.lock``), never
  as a filesystem path.

It never edits the tagged receipt: it reads it from git by exact SHA and writes
``case-study-schema.post-tag.json`` with a ``supersedes_locator``.

Stdlib only.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO = "seanchatmangpt/xaas"
RELEASE = "v26.9.25"
SCHEMA = "xaas.release-receipt/v26.9.25+post-tag"
TAGGED_CONTAINER = "6a63d891ea5ce046d23c1e00cc78a2f070aca617"
TAGGED_PATH = f"release/{RELEASE}/receipts/case-study-schema.json"
SUPERSEDES = f"git:{REPO}@{TAGGED_CONTAINER}:{TAGGED_PATH}"
RECEIPT_DIR = f"release/{RELEASE}/receipts"
REPORT_NAME = "case-study-schema.post-tag.semantic-report.json"
LOCK_NAME = "case-study-schema.requirements.lock"
RECEIPT_NAME = "case-study-schema.post-tag.json"
SUBJECT_REPORT = "semantic-report.json"  # --output, relative to <subject-dir>
OUTCOME = re.compile(r"^(\S+::\S+) (PASSED|FAILED|SKIPPED|ERROR|XFAIL|XPASS)\b", re.M)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(obj: object) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def seal(receipt: dict) -> dict:
    receipt.pop("receipt_sha256", None)
    receipt["receipt_sha256"] = sha256(canonical(receipt))
    return receipt


def run(python: str, args: list[str], cwd: Path, env: dict[str, str] | None = None) -> dict:
    proc = subprocess.run([python, *args], cwd=cwd, env=env, capture_output=True)
    out = proc.stdout + proc.stderr
    return {
        "command": " ".join(["python", *args]),
        "cwd": "<subject-dir>",
        "exit_code": proc.returncode,
        "output_sha256": sha256(out),
        "_stdout": proc.stdout.decode("utf-8", "replace"),
        "_output": out.decode("utf-8", "replace"),
    }


def public(step: dict) -> dict:
    return {k: v for k, v in step.items() if not k.startswith("_")}


def tagged_receipt(git_dir: str) -> tuple[dict, str]:
    blob = subprocess.run(
        ["git", "--git-dir", git_dir, "show", f"{TAGGED_CONTAINER}:{TAGGED_PATH}"],
        capture_output=True,
        check=True,
    ).stdout
    return json.loads(blob), sha256(blob)


def interpreter(python: str, lock: Path) -> dict:
    probe = subprocess.run(
        [python, "-c", "import platform,sys;print(platform.python_implementation(), platform.python_version())"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.split()
    return {
        "implementation": probe[0],
        "version": probe[1],
        "requirements_lock": f"{RECEIPT_DIR}/{LOCK_NAME}",
        "requirements_lock_sha256": sha256(lock.read_bytes()),
    }


def pytest_outcomes(output: str) -> dict:
    rows = sorted(f"{node} {status}" for node, status in OUTCOME.findall(output))
    summary = re.findall(r"=+ (.*(?:passed|failed|error).*) in [0-9.]+s =+", output)
    return {
        "summary": summary[-1] if summary else None,
        "outcome_count": len(rows),
        "outcome_digest_sha256": sha256(("\n".join(rows) + "\n").encode("utf-8")),
        "non_passed": [r for r in rows if not r.endswith(" PASSED")],
    }


def manufacture(subject: Path, sha: str, git_dir: str, python: str, lock: Path, out_dir: Path) -> dict:
    tagged, tagged_blob_sha = tagged_receipt(git_dir)
    if tagged.get("subject_sha") != sha:
        raise SystemExit(f"REFUSED:SUBJECT_MISMATCH:{tagged.get('subject_sha')}!={sha}")
    rec_court = next(c for c in tagged["commands"] if "stogaf_semantic_court.py" in c["command"])
    rec_deck = next(c for c in tagged["commands"] if "wd_deck.py" in c["command"])
    rec_tests = next(c for c in tagged["commands"] if "pytest" in c["command"])

    report_path = subject / SUBJECT_REPORT
    if report_path.exists():
        raise SystemExit(f"REFUSED:STALE_REPORT_PRESENT:{SUBJECT_REPORT}")
    court = run(python, ["scripts/stogaf_semantic_court.py", "--pack", "priv/packs/wd_cs2_pack",
                         "--output", SUBJECT_REPORT], subject)
    report_bytes = report_path.read_bytes() if report_path.is_file() else b""
    report = json.loads(report_bytes) if report_bytes else {}
    court["output_path"] = SUBJECT_REPORT
    court["report_file_sha256"] = sha256(report_bytes) if report_bytes else None
    court["recorded_output_sha256"] = rec_court["output_sha256"]
    court["recorded_report_file_sha256"] = rec_court["report_file_sha256"]
    court["output_sha256_match"] = court["output_sha256"] == rec_court["output_sha256"]
    court["report_file_sha256_match"] = court["report_file_sha256"] == rec_court["report_file_sha256"]
    (out_dir / REPORT_NAME).write_bytes(report_bytes)

    deck = run(python, ["tools/wd_deck/wd_deck.py", "case-study", "--check", "--build-dir",
                        "tmp/wd-case-study"], subject)
    match = re.search(r"^\{.*^\}", deck["_stdout"], re.S | re.M)
    deck_report = json.loads(match.group(0)) if match else {}
    case = {
        "case_iri": deck_report.get("case_iri"),
        "case_revision_digest": deck_report.get("case_revision_digest"),
        "generator_identity": deck_report.get("generator_identity"),
        "projections_sha256": deck_report.get("projections_sha256"),
    }
    deck["recorded_output_sha256"] = rec_deck["output_sha256"]
    deck["output_sha256_match"] = deck["output_sha256"] == rec_deck["output_sha256"]
    deck["report_json_sha256"] = sha256(canonical(deck_report)) if deck_report else None
    deck["case_match"] = bool(deck_report) and case == tagged["case"]

    env = dict(os.environ, GIT_DIR=git_dir)
    tests = run(python, ["-m", "pytest", "-v", "-p", "no:cacheprovider",
                         "test/wd_case_study_court_test.py"], subject, env)
    tests.update(pytest_outcomes(tests["_output"]))
    tests["recorded_output_sha256"] = rec_tests["output_sha256"]
    tests["recorded_summary"] = rec_tests.get("summary")
    tests["output_sha256_match"] = tests["output_sha256"] == rec_tests["output_sha256"]
    tests["summary_match"] = tests["summary"] == rec_tests.get("summary")

    checks = {
        "court_exit_0": court["exit_code"] == 0,
        "court_standing_alive": report.get("standing") == "ALIVE",
        "court_output_sha256_equals_recorded": court["output_sha256_match"],
        "court_report_file_sha256_equals_recorded": court["report_file_sha256_match"],
        "court_report_sha256_equals_recorded": report.get("report_sha256") == tagged["court_report"]["report_sha256"],
        "wd_deck_check_exit_0": deck["exit_code"] == 0,
        "wd_deck_no_projection_drift": deck_report.get("drift") == [] and deck_report.get("mode") == "check",
        "wd_deck_case_equals_recorded": deck["case_match"],
        "pytest_exit_0": tests["exit_code"] == 0,
        "pytest_summary_equals_recorded": tests["summary_match"],
        "pytest_no_skips": tests["summary"] is not None and "skipped" not in tests["summary"],
    }
    failed = sorted(k for k, ok in checks.items() if not ok)
    receipt = {
        "schema": SCHEMA,
        "name": "case-study-schema.post-tag",
        "requirement_ids": ["AC-13"],
        "repository": REPO,
        "subject_sha": sha,
        "subject": {"repository": REPO, "sha": sha, "materialization": "git archive <subject_sha> (plain dir)"},
        "supersedes_locator": SUPERSEDES,
        "superseded_receipt": {
            "blob_sha256": tagged_blob_sha,
            "receipt_sha256": tagged["receipt_sha256"],
            "standing": tagged["standing"],
            "edited": False,
        },
        "interpreter": interpreter(python, lock),
        "durable_report": {
            "path": f"{RECEIPT_DIR}/{REPORT_NAME}",
            "locator_form": f"git:{REPO}@<commit containing this receipt>:{RECEIPT_DIR}/{REPORT_NAME}",
            "sha256": court["report_file_sha256"],
        },
        "standing": "ALIVE" if not failed else "REFUSED",
        "refusals": failed,
        "evidence_ceiling": "REPO_LOCAL_FIXTURE",
        "checks": checks,
        "differences_explained": {
            "command_text": (
                "The tagged receipt recorded the interpreter as an absolute path (a system python3.14 "
                "for the court and pytest, and a scratch venv for wd_deck) and --output as an absolute "
                "scratch path. Neither is a durable locator. This receipt records the interpreter as the "
                "token 'python' plus interpreter.{implementation,version,requirements_lock_sha256}, and "
                f"--output as '{SUBJECT_REPORT}', which is relative to <subject-dir>."
            ),
            "court": (
                "The court prints the report payload, not the output path. So its stdout+stderr and the "
                "report bytes do not depend on the path and must equal the recorded "
                "output_sha256/report_file_sha256."
            ),
            "wd_deck": (
                "wd_deck echoes each 'mix ggen_igniter.sync' argv with absolute --pack-dir/--ontology/"
                "--template/--out paths that resolve under <subject-dir>. That makes the raw output hash "
                "depend on the location, so output_sha256 is not expected to match. The recorded case "
                "block (case_iri, case_revision_digest, generator_identity, projections_sha256) is "
                "compared instead."
            ),
            "pytest": (
                "The pytest -v header embeds the interpreter path and rootdir, and the footer embeds the "
                "wall time. So the raw output hash is not expected to match. The summary and the sorted "
                "per-node outcome digest are compared instead."
            ),
        },
        "commands": [public(court), public(deck), public(tests)],
        "non_claims": ["EXTERNAL_STANDING", "WD_ACCEPTANCE", "ST-6 AUTONOMIC", "ST-7 ACTUATED"],
    }
    return receipt


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--subject-dir", required=True, type=Path)
    ap.add_argument("--subject-sha", required=True)
    ap.add_argument("--git-dir", required=True)
    ap.add_argument("--python", required=True, help="interpreter built from --lock (never recorded)")
    ap.add_argument("--lock", required=True, type=Path)
    ap.add_argument("--out-dir", required=True, type=Path)
    args = ap.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.subject_sha):
        raise SystemExit("REFUSED:SUBJECT_SHA_NOT_40_HEX")
    out = args.out_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    receipt = manufacture(args.subject_dir.resolve(), args.subject_sha, args.git_dir, args.python,
                          args.lock.resolve(), out)
    receipt["manufactured_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    receipt["manufacturer"] = f"{RECEIPT_DIR}/rerun_case_study.py"
    seal(receipt)
    (out / RECEIPT_NAME).write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"{receipt['name']}: {receipt['standing']} {receipt['refusals']}")
    return 0 if receipt["standing"] == "ALIVE" else 1


if __name__ == "__main__":
    sys.exit(main())
