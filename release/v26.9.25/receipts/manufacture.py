#!/usr/bin/env python3
"""Manufacture the xaas v26.9.25 release receipts from real runs on an exact subject.

Receipts read by the chatman-ecosystem root crown (scripts/release_train/root_crown/evidence.py):
  case-study-schema.json   AC-13  receipt_artifact       (standing ALIVE + 40-char subject_sha)
  wd-evidence-ceiling.json AC-14/F-12 receipt_artifact   (standing ALIVE + 40-char subject_sha)
  cloud-runtime.json       F-09   typed_blocker_allowed  (BLOCKED needs a non-empty `type`)

Every standing is derived from exit codes and parsed outputs of commands this script runs
against --subject-dir (a `git archive <subject_sha>` extraction). Nothing is asserted by hand:
a failed command derives REFUSED/BLOCKED, never ALIVE.

Replay:
  git archive <sha> | tar -x -C DIR; ln -s <checkout>/deps DIR/deps
  MIX_BUILD_ROOT=DIR/_build-receipts python3 manufacture.py --subject-dir DIR --subject-sha <sha> \
      --git-dir <checkout>/.git --wd-deck-python <venv>/bin/python --fabric-log <mix test log> \
      --loopback-receipt <chatgpt-cloud-elixir receipt> --out-dir OUT
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

REPO = "seanchatmangpt/xaas"
RELEASE = "v26.9.25"
SCHEMA = "xaas.release-receipt/v26.9.25"
LOOPBACK_SOURCE = {
    "repository": "seanchatmangpt/chatgpt-cloud-elixir",
    "pr": 42,
    "merge_sha": "d6727fef06b170bc6c3839bbf2a9456e33111920",
    "path": "xaas-runtime/receipts/20260925T100606Z-fabric-live-loopback.receipt.json",
}
CEILING_GATES = ("020_authority_ceiling.rq", "060_claim_ceiling.rq", "070_claim_evidence.rq")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(obj: object) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def run(cmd: list[str], cwd: Path, env: dict[str, str] | None = None) -> dict:
    proc = subprocess.run(cmd, cwd=cwd, env=env, capture_output=True)
    out = proc.stdout + proc.stderr
    return {
        "command": " ".join(cmd),
        "cwd": "<subject-dir>",
        "exit_code": proc.returncode,
        "output_sha256": sha256(out),
        "_stdout": proc.stdout.decode("utf-8", "replace"),
        "_output": out.decode("utf-8", "replace"),
    }


def public(step: dict) -> dict:
    return {k: v for k, v in step.items() if not k.startswith("_")}


def seal(receipt: dict) -> dict:
    receipt["receipt_sha256"] = sha256(canonical(receipt))
    return receipt


def case_study_schema(src: Path, sha: str, out: Path, git_dir: str, wd_python: str) -> tuple[dict, dict]:
    report_path = out / "semantic-report.json"
    court = run(
        [sys.executable, "scripts/stogaf_semantic_court.py", "--pack", "priv/packs/wd_cs2_pack",
         "--output", str(report_path)],
        src,
    )
    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.is_file() else {}
    court["report_file_sha256"] = sha256(report_path.read_bytes()) if report_path.is_file() else None

    deck = run([wd_python, "tools/wd_deck/wd_deck.py", "case-study", "--check", "--build-dir",
                "tmp/wd-case-study"], src)
    match = re.search(r"^\{.*^\}", deck["_stdout"], re.S | re.M)
    deck_report = json.loads(match.group(0)) if match else {}

    env = dict(os.environ, GIT_DIR=git_dir)
    tests = run([sys.executable, "-m", "pytest", "-v", "-p", "no:cacheprovider",
                 "test/wd_case_study_court_test.py"], src, env)
    summary = re.findall(r"=+ (.*(?:passed|failed|error).*) in [0-9.]+s =+", tests["_output"])
    tests["summary"] = summary[-1] if summary else None

    checks = {
        "court_exit_0": court["exit_code"] == 0,
        "court_schema_v2": report.get("schema") == "STOGAF_SEMANTIC_COURT_V2",
        "court_standing_alive": report.get("standing") == "ALIVE",
        "shacl_conforms": report.get("shacl", {}).get("conforms") is True,
        "gate_count_ge_9": int(report.get("gate_count", 0)) >= 9,
        "refusal_rows_0": report.get("refusal_rows") == 0,
        "wd_deck_check_exit_0": deck["exit_code"] == 0,
        "wd_deck_no_projection_drift": deck_report.get("drift") == [] and deck_report.get("mode") == "check",
        "pytest_exit_0": tests["exit_code"] == 0,
        "pytest_no_skips": tests["summary"] is not None and "skipped" not in tests["summary"],
    }
    failed = sorted(k for k, ok in checks.items() if not ok)
    receipt = {
        "schema": SCHEMA,
        "name": "case-study-schema",
        "requirement_ids": ["AC-13"],
        "repository": REPO,
        "subject_sha": sha,
        "subject": {"repository": REPO, "sha": sha, "materialization": "git archive <subject_sha> (plain dir)"},
        "standing": "ALIVE" if not failed else "REFUSED",
        "refusals": failed,
        "evidence_ceiling": "REPO_LOCAL_FIXTURE",
        "case": {
            "case_iri": deck_report.get("case_iri"),
            "case_revision_digest": deck_report.get("case_revision_digest"),
            "generator_identity": deck_report.get("generator_identity"),
            "projections_sha256": deck_report.get("projections_sha256"),
        },
        "court_report": {
            "schema": report.get("schema"),
            "report_sha256": report.get("report_sha256"),
            "inputs_sha256_digest": sha256(canonical(report.get("inputs_sha256", {}))),
            "data_triples": report.get("data_triples"),
            "gate_count": report.get("gate_count"),
            "refusal_rows": report.get("refusal_rows"),
            "shacl_conforms": report.get("shacl", {}).get("conforms"),
        },
        "checks": checks,
        "commands": [public(court), public(deck), public(tests)],
        "non_claims": ["EXTERNAL_STANDING", "WD_ACCEPTANCE", "ST-6 AUTONOMIC", "ST-7 ACTUATED"],
    }
    return seal(receipt), report


def load_controls(src: Path):
    spec = importlib.util.spec_from_file_location("wd_case_study_court_test", src / "test/wd_case_study_court_test.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module.CONTROL_PREFIXES, module.CONTROLS


def wd_evidence_ceiling(src: Path, sha: str, baseline: dict) -> dict:
    prefixes, controls = load_controls(src)
    selected = {name: v for name, v in sorted(controls.items()) if v[1] in CEILING_GATES}
    results, steps = [], []
    with tempfile.TemporaryDirectory() as tmp:
        for name, (body, gate) in selected.items():
            ttl = Path(tmp) / f"{name}.ttl"
            ttl.write_text(prefixes + body, encoding="utf-8")
            report_path = Path(tmp) / f"{name}.report.json"
            real = run([sys.executable, "scripts/stogaf_semantic_court.py", "--pack", "priv/packs/wd_cs2_pack",
                        "--extra", str(ttl), "--output", str(report_path)], src)
            step = public(real)
            step["command"] = (f"python3 scripts/stogaf_semantic_court.py --pack priv/packs/wd_cs2_pack "
                               f"--extra <tmp>/{name}.ttl --output <tmp>/{name}.report.json")
            rep = json.loads(report_path.read_text(encoding="utf-8"))
            rows = {g["gate"]: g["refusal_rows"] for g in rep["gates"]}
            refused = real["exit_code"] == 1 and rep["standing"] == "REFUSED" and rows.get(gate, 0) >= 1
            results.append({
                "control": name,
                "control_ttl_sha256": sha256(ttl.read_bytes()),
                "expected_gate": gate,
                "gate_refusal_rows": rows.get(gate, 0),
                "court_standing": rep["standing"],
                "report_sha256": rep["report_sha256"],
                "refused_by_expected_gate": refused,
            })
            steps.append(step)

    case = json.loads((src / "docs/case-studies/wd-fa/case-study.json").read_text(encoding="utf-8"))
    ledger = json.loads((src / "docs/case-studies/wd-fa/claims-ledger.json").read_text(encoding="utf-8"))
    non_claims = {n["label"] for n in case.get("non_claims", [])}
    claimed_levels = sorted({str(c.get("claimed_level")) for c in ledger["claims"] if c.get("claimed_level")})
    texts = " ".join(c["text"] for c in ledger["claims"])
    gates_covered = sorted({r["expected_gate"] for r in results})
    checks = {
        "baseline_court_alive": baseline.get("standing") == "ALIVE" and baseline.get("refusal_rows") == 0,
        "every_ceiling_control_refused": bool(results) and all(r["refused_by_expected_gate"] for r in results),
        "gates_020_060_070_all_exercised": gates_covered == sorted(CEILING_GATES),
        "evidence_ceiling_repo_local_fixture": case.get("evidence_ceiling") == "REPO_LOCAL_FIXTURE",
        "authority_select_construct_only": case.get("authority_ceiling") in {"NONE", "SELECT", "CONSTRUCT"}
        and all(c["authority_ceiling"] in {"NONE", "SELECT", "CONSTRUCT"} for c in ledger["claims"]),
        "engineer_disposition_required": case.get("human_gate") == "ENGINEER_DISPOSITION_REQUIRED",
        "current_conformance_st4": case.get("current_conformance") == "ST-4 CONSTRAINED",
        "st6_st7_declared_non_claims": {"ST-6 AUTONOMIC", "ST-7 ACTUATED"} <= non_claims,
        "st6_st7_unclaimed_in_ledger": not any(lvl.startswith(("ST-6", "ST-7", "ST6", "ST7")) or "ST6" in lvl
                                               or "ST7" in lvl for lvl in claimed_levels)
        and not re.search(r"ST-?[67]\b", texts),
    }
    failed = sorted(k for k, ok in checks.items() if not ok)
    receipt = {
        "schema": SCHEMA,
        "name": "wd-evidence-ceiling",
        "requirement_ids": ["AC-14", "F-12"],
        "repository": REPO,
        "subject_sha": sha,
        "subject": {"repository": REPO, "sha": sha, "materialization": "git archive <subject_sha> (plain dir)"},
        "standing": "ALIVE" if not failed else "REFUSED",
        "refusals": failed,
        "evidence_ceiling": "REPO_LOCAL_FIXTURE",
        "authority_ceiling": "SELECT_CONSTRUCT_ONLY",
        "human_gate": case.get("human_gate"),
        "current_conformance": case.get("current_conformance"),
        "target_conformance": case.get("target_conformance"),
        "claimed_levels": claimed_levels,
        "unclaimed": ["ST-6 AUTONOMIC", "ST-7 ACTUATED"],
        "baseline_report_sha256": baseline.get("report_sha256"),
        "negative_controls": results,
        "checks": checks,
        "commands": steps,
        "non_claims": sorted(non_claims),
    }
    return seal(receipt)


def cloud_runtime(sha: str, fabric_log: Path, loopback: Path) -> dict:
    raw = loopback.read_bytes()
    lb = json.loads(raw)
    sealed = lb["consequence"]["client_receipts"]["first"]
    replay_ok = sha256(canonical(sealed["sealed_receipt"])) == sealed["identity"]["sealed_receipt_sha256"]
    log = fabric_log.read_bytes()
    text = log.decode("utf-8", "replace")
    exit_match = re.findall(r"^exit=(\d+)$", text, re.M)
    summary = re.findall(r"^(\d+ tests?, \d+ failures?.*)$", text, re.M)
    fabric_exit = int(exit_match[-1]) if exit_match else None
    local_ok = lb.get("standing") == "ALIVE" and lb.get("evidence_ceiling") == "LOCAL_LOOPBACK" and replay_ok
    tests_ok = fabric_exit == 0 and bool(summary) and " 0 failures" in summary[-1]
    cloud_legs = [
        {"leg": b["leg"], "standing": b["standing"], "class": b.get("class"), "broken_term": b["broken_term"]}
        for b in lb.get("blockers", [])
    ]
    receipt = {
        "schema": SCHEMA,
        "name": "cloud-runtime",
        "requirement_ids": ["F-09"],
        "repository": REPO,
        "subject_sha": sha,
        "subject": {"repository": REPO, "sha": sha, "materialization": "git archive <subject_sha> (plain dir)"},
        "standing": "BLOCKED",
        "type": "TRANSPORT_FAILURE:cloud-to-zcode-leg-unreceipted",
        "broken_term": "R_missing_authority",
        "claim": "cloud-to-ZCode execution is NOT claimed; only the local loopback fabric leg is ALIVE",
        "legs": [
            {
                "leg": "fabric local loopback (xaas /internal-api/fabric <- ChatGPTCloud.Xaas client)",
                "standing": "ALIVE" if (local_ok and tests_ok) else "BLOCKED",
                "evidence_ceiling": "LOCAL_LOOPBACK",
                "execution_receipt": {
                    **LOOPBACK_SOURCE,
                    "blob_sha256": sha256(raw),
                    "receipt_sha256": lb.get("receipt_sha256"),
                    "sealed_receipt_sha256": sealed["identity"]["sealed_receipt_sha256"],
                    "sealed_receipt_replay_verified": replay_ok,
                    "server_subject": "seanchatmangpt/xaas@99de79bbf3eadefa15f5bbe52be9d4403b52b84d (ancestor of subject_sha)",
                },
                "subject_tests": {
                    "command": "MIX_ENV=test MIX_TEST_PARTITION=_receipts mix test test/xaas/tunnel "
                    "test/xaas_web/fabric_controller_test.exs",
                    "exit_code": fabric_exit,
                    "summary": summary[-1] if summary else None,
                    "output_sha256": sha256(log),
                },
            },
            *cloud_legs,
        ],
        "transport_receipt": None,
        "execution_receipt": None,
        "non_claims": sorted(set(lb.get("non_claims", [])) | {"CLOUD_TO_ZCODE_EXECUTION"}),
    }
    return seal(receipt)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--subject-dir", required=True, type=Path)
    ap.add_argument("--subject-sha", required=True)
    ap.add_argument("--git-dir", required=True)
    ap.add_argument("--wd-deck-python", required=True)
    ap.add_argument("--fabric-log", required=True, type=Path)
    ap.add_argument("--loopback-receipt", required=True, type=Path)
    ap.add_argument("--out-dir", required=True, type=Path)
    args = ap.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.subject_sha):
        raise SystemExit("REFUSED:SUBJECT_SHA_NOT_40_HEX")
    args.out_dir = args.out_dir.resolve()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    src = args.subject_dir.resolve()
    work = args.out_dir / "work"
    work.mkdir(exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    cs, report = case_study_schema(src, args.subject_sha, work, args.git_dir, args.wd_deck_python)
    ceiling = wd_evidence_ceiling(src, args.subject_sha, report)
    cloud = cloud_runtime(args.subject_sha, args.fabric_log, args.loopback_receipt)
    for receipt in (cs, ceiling, cloud):
        receipt["manufactured_at"] = stamp
        receipt["manufacturer"] = f"release/{RELEASE}/receipts/manufacture.py"
        receipt.pop("receipt_sha256")
        seal(receipt)
        path = args.out_dir / f"{receipt['name']}.json"
        path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"{receipt['name']}: {receipt['standing']} {receipt.get('type', '')} {receipt.get('refusals', '')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
