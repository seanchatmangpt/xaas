#!/usr/bin/env python3
"""Observed-proof probe of the autofde-lab WD FA deterministic triage kernel.

Subject: seanchatmangpt/autofde-lab merge commit eb93405c (PR 170), extracted
with `git archive` into a scratch directory; `--src` names its `src/`.

The probe calls the kernel's real code on its own synthetic fixtures with the
kernel's default `candidate_model=None` (no TPOT ranker: TPOT is not installed
on this host, and the kernel documents the candidate model as non-authoritative
ranking only). It observes the deterministic paths PR 170's court asserts:

  K1 known_a -> ALIVE MODE-A-FIRMWARE, 0 exploratory steps, deterministic basis
  K2 known_b_misleading -> ALIVE MODE-B-SUPPLIER (similarity cannot override)
  K3 incomplete_a -> PARTIAL_ALIVE, no admitted mode
  K4 novel_x -> UNKNOWN, no admitted mode, ESCALATE to failure_analysis
  K5 producer == verifier -> REFUSED:SELF_CERTIFICATION
  K6 a tampered receipt (disposition or authority scope) fails verification
  K7 UNKNOWN -> verified receipt -> MachineExperience -> replay ALIVE
     MODE-X-NOVEL with fewer exploratory steps (3 -> 0)
  K8 an unbound receipt (digest or disposition) is refused
  K9 the work order keeps SELECT_ONLY + ENGINEER_DISPOSITION_REQUIRED
  K10 the FastAPI surface: /health NO_DO; /triage and /a2a SELECT_ONLY

Environment: the PR's court workflow (.github/workflows/wd-fa-court.yml)
installs no `wrapt`; this host's wrapt 2.x lacks `lru_cache`, which the
package root `autofde_lab/__init__.py` touches. Blocking `wrapt` reproduces the
CI environment (the package root then takes its documented
ModuleNotFoundError path). No wd_fa module imports wrapt, and no wd_fa
collaborator is replaced.

Writes canonical JSON (sorted keys) to `--out` and prints one line per check;
exit 0 only when every check holds. Deterministic: no clock, no randomness,
no LLM, no network.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from dataclasses import replace
from pathlib import Path


def run(src: Path) -> dict:
    sys.modules.setdefault("wrapt", None)  # reproduce the CI env (see module doc)
    sys.path.insert(0, src.as_posix())
    from fastapi.testclient import TestClient

    from autofde_lab.wd_fa.api import create_app
    from autofde_lab.wd_fa.domain import Standing, make_work_order
    from autofde_lab.wd_fa.receipts import issue_receipt, verify_receipt
    from autofde_lab.wd_fa.synthetic import RULES, named_cases
    from autofde_lab.wd_fa.triage import compile_experience, triage

    cases = named_cases()
    checks: dict[str, dict] = {}

    def check(key: str, ok: bool, observed: object) -> None:
        checks[key] = {"ok": bool(ok), "observed": observed}

    results = {name: triage(cases[name], RULES) for name in ("known_a", "known_b_misleading", "incomplete_a", "novel_x")}
    ka = results["known_a"]
    check(
        "K1_known_a_alive",
        ka.standing is Standing.ALIVE
        and ka.admitted_mode == "MODE-A-FIRMWARE"
        and ka.exploratory_steps == 0
        and ka.confidence_basis == "DETERMINISTIC_RULE_AND_REQUIRED_EVIDENCE"
        and ka.human_gate == "ENGINEER_DISPOSITION_REQUIRED",
        [ka.standing.value, ka.admitted_mode, ka.exploratory_steps, ka.confidence_basis, ka.human_gate],
    )
    kb = results["known_b_misleading"]
    check(
        "K2_misleading_similarity_cannot_override",
        kb.standing is Standing.ALIVE and kb.admitted_mode == "MODE-B-SUPPLIER",
        [kb.standing.value, kb.admitted_mode, [h.mode_id for h in kb.ranked_hypotheses]],
    )
    ki = results["incomplete_a"]
    check(
        "K3_incomplete_is_partial",
        ki.standing is Standing.PARTIAL_ALIVE and ki.admitted_mode is None and ki.evidence_completeness < 1.0,
        [ki.standing.value, ki.admitted_mode, ki.evidence_completeness, ki.confidence_basis],
    )
    kn = results["novel_x"]
    check(
        "K4_novel_is_unknown",
        kn.standing is Standing.UNKNOWN
        and kn.admitted_mode is None
        and kn.action_type == "ESCALATE"
        and kn.owning_team == "failure_analysis",
        [kn.standing.value, kn.admitted_mode, kn.action_type, kn.owning_team, kn.confidence_basis],
    )

    try:
        issue_receipt(cases["known_a"], ka, producer_id="same", verifier_id="same", observed_disposition="MODE-A-FIRMWARE")
        refused = None
    except ValueError as exc:
        refused = str(exc)
    check("K5_self_certification_refused", refused == "REFUSED:SELF_CERTIFICATION", refused)

    good = issue_receipt(
        cases["known_a"],
        ka,
        producer_id="candidate-producer",
        verifier_id="independent-verifier",
        observed_disposition="MODE-A-FIRMWARE",
    )
    tampered = [
        verify_receipt(good),
        verify_receipt(replace(good, observed_disposition="TAMPERED")),
        verify_receipt(replace(good, authority_scope="EXTERNAL")),
    ]
    check("K6_tampered_receipt_fails", tampered == [True, False, False], tampered)

    novel = cases["novel_x"]
    receipt = issue_receipt(
        novel,
        kn,
        producer_id="candidate-producer",
        verifier_id="independent-verifier",
        observed_disposition="MODE-X-NOVEL",
    )
    try:
        experience = compile_experience(
            novel, kn, receipt, mode_id="MODE-X-NOVEL", next_action="repeat_verified_novel_x_procedure"
        )
    except ValueError as exc:
        check("K7_machine_experience_ratchet", False, ["compile_experience raised", str(exc)])
    else:
        replay = triage(cases["novel_x_replay"], (*RULES, experience.mode))
        check(
            "K7_machine_experience_ratchet",
            verify_receipt(receipt)
            and replay.standing is Standing.ALIVE
            and replay.admitted_mode == "MODE-X-NOVEL"
            and replay.exploratory_steps < kn.exploratory_steps,
            [kn.standing.value, kn.exploratory_steps, replay.standing.value, replay.admitted_mode, replay.exploratory_steps],
        )

    unbound = []
    for bad, mode in ((replace(receipt, receipt_digest="tampered"), "MODE-X-NOVEL"), (receipt, "MODE-WRONG")):
        try:
            compile_experience(novel, kn, bad, mode_id=mode, next_action="repeat_verified_novel_x_procedure")
            unbound.append(None)
        except ValueError as exc:
            unbound.append(str(exc))
    check(
        "K8_unbound_receipt_refused",
        unbound == ["REFUSED:INVALID_RECEIPT", "REFUSED:DISPOSITION_BINDING"],
        unbound,
    )

    order = make_work_order(ka, cases["known_a"])
    check(
        "K9_work_order_keeps_human_gate",
        order.authority == "SELECT_ONLY" and order.human_gate == "ENGINEER_DISPOSITION_REQUIRED",
        [order.authority, order.human_gate, order.action_type, order.owning_team],
    )

    client = TestClient(create_app())
    health = client.get("/health").json()
    known = client.post("/triage", json={"case_name": "known_a"}).json()
    a2a = client.post("/a2a/tasks/analyze_failure", json={"case_name": "novel_x"}).json()
    check(
        "K10_api_is_candidate_surface_only",
        health.get("authority") == "NO_DO"
        and known.get("authority") == "SELECT_ONLY"
        and known.get("human_gate") == "ENGINEER_DISPOSITION_REQUIRED"
        and a2a.get("standing") == "UNKNOWN"
        and a2a.get("authority") == "SELECT_ONLY",
        [health.get("authority"), known.get("authority"), known.get("human_gate"), a2a.get("standing"), a2a.get("authority")],
    )
    return {"probe": "wd_fa_kernel_probe", "candidate_model": None, "checks": checks}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--src", required=True, type=Path, help="src/ of an autofde-lab git archive at the subject commit")
    parser.add_argument("--out", required=True, type=Path, help="canonical JSON observation file to write")
    args = parser.parse_args(argv)
    payload = run(args.src.resolve())
    text = json.dumps(payload, sort_keys=True, separators=(",", ":"), default=str) + "\n"
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(text, encoding="utf-8")
    failed = [key for key, value in sorted(payload["checks"].items()) if not value["ok"]]
    for key, value in sorted(payload["checks"].items()):
        sys.stdout.write(f"{'OK' if value['ok'] else 'FAILED'} {key}\n")
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
    sys.stdout.write(f"PROBE {'OK' if not failed else 'FAILED'}: {len(payload['checks']) - len(failed)}/{len(payload['checks'])} checks; out sha256:{digest}\n")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
