"""Semantic Case Study court for WD Case Study 2 (RFC-0003 instance).

Reads the real claims source (priv/packs/wd_cs2_pack/claims.ttl), the real
generated projections under docs/case-studies/wd-fa/ and the real git object
store, and runs the real court script for the negative controls. No doubles:
each negative control is a real Turtle file added to the real court's graph.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

import pytest
from rdflib import Graph, Namespace, RDF

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "priv" / "packs" / "wd_cs2_pack"
CASE_DIR = ROOT / "docs" / "case-studies" / "wd-fa"
COURT = ROOT / "scripts" / "stogaf_semantic_court.py"
CS = Namespace("urn:xaas:case-study:")
PRES = Namespace("https://ggen.dev/ns/presentation#")
SUBJECT_RE = re.compile(r"^seanchatmangpt/xaas@([0-9a-f]{40})$")


def _claims_graph() -> Graph:
    graph = Graph()
    for name in ("case-study.ttl", "claims.ttl"):
        graph.parse(PACK / name, format="turtle")
    return graph


def _json(name: str) -> dict:
    return json.loads((CASE_DIR / name).read_text(encoding="utf-8"))


def _case_claim_ids() -> set[str]:
    graph = _claims_graph()
    return {str(graph.value(c, CS.claimId)) for c in graph.subjects(RDF.type, CS.Claim)}


def _ledger() -> dict:
    return _json("claims-ledger.json")


def _map() -> dict:
    return _json("SLIDE-EVIDENCE-MAP.json")


def test_projections_share_one_case_revision() -> None:
    headers = [_json("case-study.json"), _ledger(), _map()]
    for key in ("case_id", "case_revision_digest", "generator_identity", "claim_ids"):
        values = {json.dumps(doc[key], sort_keys=True) for doc in headers}
        assert len(values) == 1, (key, values)
    assert re.fullmatch(r"[0-9a-f]{64}", headers[0]["case_revision_digest"])
    assert headers[0]["generator_identity"].startswith("ggen_igniter@")


def test_ledger_is_a_subset_of_the_case() -> None:
    ledger_ids = {claim["claim_id"] for claim in _ledger()["claims"]}
    assert ledger_ids
    assert ledger_ids <= _case_claim_ids()
    assert set(_ledger()["claim_ids"]) == ledger_ids


def test_deck_is_a_subset_of_the_ledger() -> None:
    ledger_ids = {claim["claim_id"] for claim in _ledger()["claims"]}
    rendered = {cid for slide in _map()["slides"] for cid in slide["claim_ids"]}
    assert rendered
    assert rendered <= ledger_ids


def test_ledger_evidence_is_carried_by_the_rendering_slide() -> None:
    slides = {slide["slide"]: slide for slide in _map()["slides"]}
    for claim in _ledger()["claims"]:
        for k in claim["rendered_on_slides"]:
            assert claim["claim_id"] in slides[k]["claim_ids"], (claim["claim_id"], k)
            assert set(claim["evidence"]) <= set(slides[k]["evidence"]), (claim["claim_id"], k)


def test_map_covers_all_fourteen_slides() -> None:
    slides = _map()["slides"]
    assert [slide["slide"] for slide in slides] == list(range(1, 15))
    for slide in slides:
        assert slide["claim_ids"] or slide["no_claim_reason"], slide
        assert not (slide["claim_ids"] and slide["no_claim_reason"]), slide


def test_every_evidence_path_exists_at_its_exact_subject() -> None:
    evidence = _ledger()["evidence"]
    assert evidence
    for item in evidence:
        match = SUBJECT_RE.fullmatch(item["exact_subject"])
        assert match, item
        sha = match.group(1)
        if subprocess.run(["git", "cat-file", "-e", f"{sha}^{{commit}}"], cwd=ROOT, capture_output=True).returncode != 0:
            pytest.skip(f"git object {sha} absent (shallow checkout); evidence paths not observable")
        result = subprocess.run(
            ["git", "cat-file", "-e", f"{sha}:{item['path']}"], cwd=ROOT, capture_output=True
        )
        assert result.returncode == 0, item


def test_no_unknown_claim_is_rendered_as_supported() -> None:
    standing = {claim["claim_id"]: claim["standing"] for claim in _ledger()["claims"]}
    for slide in _map()["slides"]:
        claims = [standing[cid] for cid in slide["claim_ids"]]
        if "UNKNOWN" in claims:
            assert slide["standing"] == "UNKNOWN", slide
        if slide["standing"] == "ALIVE_FIXTURE":
            assert claims and set(claims) == {"ALIVE_FIXTURE"}, slide


def test_every_non_claim_is_stated_in_the_non_claims_document() -> None:
    text = (CASE_DIR / "18-NON-CLAIMS.md").read_text(encoding="utf-8")
    graph = _claims_graph()
    labels = [str(graph.value(n, CS.nonClaimLabel)) for n in graph.subjects(RDF.type, CS.NonClaim)]
    assert len(labels) >= 7
    for label in labels:
        assert label in text, label


def test_assumptions_are_unanswered_questions_sent_via_the_named_contact() -> None:
    doc = _json("case-study.json")
    assumptions = doc["assumptions"]
    assert [a["assumption_id"] for a in assumptions] == ["A1", "A2", "A3"]
    submission = (CASE_DIR / "19-SEPTEMBER-25-SUBMISSION.md").read_text(encoding="utf-8")
    for a in assumptions:
        assert a["answer_status"] == "UNANSWERED"
        assert a["asked_via"] == "Pradyot Kar"
        assert a["asked_on"] == "2026-09-23"
        assert a["question"] in submission


def test_current_conformance_is_below_the_autonomic_target() -> None:
    doc = _json("case-study.json")
    assert doc["current_conformance"] == "ST-4 CONSTRAINED"
    assert doc["target_conformance"] == "ST-6 AUTONOMIC"
    assert doc["authority_ceiling"] in {"NONE", "SELECT", "CONSTRUCT"}


# ---------------------------------------------------------------- negative controls

CONTROL_PREFIXES = """@prefix cs: <urn:xaas:case-study:> .
@prefix stogaf: <urn:xaas:stogaf:> .
@prefix wdcs2: <urn:xaas:wd-cs2:> .
@prefix wdc: <urn:xaas:wd-cs2:claim:> .
@prefix wde: <urn:xaas:wd-cs2:evidence:> .
@prefix wdf: <urn:xaas:wd-cs2:falsifier:> .
@prefix pres: <https://ggen.dev/ns/presentation#> .
@prefix wddeck: <urn:wd:case-study-2:deck:> .
"""


def _claim(cid: str, extra: str, *, falsifier: bool = True, text: str = "A bounded fixture claim.") -> str:
    fals = " ; cs:falsifiedBy wdf:F03" if falsifier else ""
    return (
        f'wdc:{cid} a cs:Claim ; cs:claimId "{cid}" ; cs:claimOf wdcs2:case ;\n'
        f'  cs:claimText "{text}" ; cs:standing "ALIVE_FIXTURE" ;\n'
        f'  cs:evidenceCeiling "REPO_LOCAL_FIXTURE" ; cs:authorityCeiling "CONSTRUCT" ;\n'
        f"  cs:supportedBy wde:E03{fals}{extra} .\n"
    )


CONTROLS = {
    "claim_at_st6": (_claim("C90", " ; cs:claimedLevel stogaf:ST6"), "060_claim_ceiling.rq"),
    "claim_at_st7": (_claim("C91", " ; cs:claimedLevel stogaf:ST7"), "060_claim_ceiling.rq"),
    "claim_text_autonomic": (
        _claim("C92", "", text="The agent runs at ST-6 AUTONOMIC."),
        "060_claim_ceiling.rq",
    ),
    "claim_text_mttr": (
        _claim("C93", "", text="The agent delivers MTTR reduction at WD."),
        "060_claim_ceiling.rq",
    ),
    "claim_without_falsifier": (_claim("C94", "", falsifier=False), "070_claim_evidence.rq"),
    "evidence_on_foreign_subject": (
        'wde:E99 a cs:Evidence ; cs:evidenceId "E99" ; cs:evidencePath "README.md" ;\n'
        '  cs:exactSubject "seanchatmangpt/xaas@0000000000000000000000000000000000000000" ;\n'
        '  cs:validator "design review" ; cs:result "DESIGN_DOCUMENT" .\n'
        + _claim("C95", " ; cs:supportedBy wde:E99"),
        "070_claim_evidence.rq",
    ),
    "claim_rendered_by_undeclared_slide": (
        _claim("C96", " ; cs:renderedBy wddeck:slide-99"),
        "080_deck_projection.rq",
    ),
    "slide_without_claim": (
        'wddeck:slide-98 a pres:Slide ; pres:id "slide-98" ; pres:order 98 ; pres:title "Unbound" .\n',
        "080_deck_projection.rq",
    ),
    "lockOf_block": (
        'wddeck:slide-07-block-99 a pres:Block ;\n  pres:lockOf wddeck:slide-07 ;\n'
        '  pres:order 99 ; pres:role "node" ; pres:title "Dropped" .\n',
        "090_deck_block_integrity.rq",
    ),
    "current_conformance_st7": (
        'wdcs2:architectureEpisode stogaf:currentConformance "ST-7 ACTUATED" .\n',
        "020_authority_ceiling.rq",
    ),
    "authority_drift": (
        'wdcs2:architectureEpisode stogaf:authority "ACTUATE" .\n',
        "020_authority_ceiling.rq",
    ),
    "machine_experience_without_receipt": (
        "wdcs2:strayExperience a stogaf:MachineExperience .\n",
        "040_machine_experience.rq",
    ),
    "requirement_without_standing": (
        "wdcs2:strayRequirement a stogaf:Requirement .\n",
        "050_requirement_traceability.rq",
    ),
    "current_conformance_st6": (
        'wdcs2:architectureEpisode stogaf:currentConformance "ST-6 AUTONOMIC" .\n',
        "020_authority_ceiling.rq",
    ),
}


def _court(tmp_path: Path, *extra: Path) -> tuple[int, dict]:
    output = tmp_path / "report.json"
    args = [sys.executable, str(COURT), "--pack", str(PACK), "--output", str(output)]
    for path in extra:
        args += ["--extra", str(path)]
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True)
    return result.returncode, json.loads(output.read_text(encoding="utf-8"))


def test_court_admits_the_committed_case(tmp_path: Path) -> None:
    code, report = _court(tmp_path)
    assert code == 0, report
    assert report["standing"] == "ALIVE"
    assert report["gate_count"] >= 9
    assert report["refusal_rows"] == 0


@pytest.mark.parametrize("control", sorted(CONTROLS))
def test_negative_control_is_refused_by_its_gate(tmp_path: Path, control: str) -> None:
    body, gate = CONTROLS[control]
    ttl = tmp_path / f"{control}.ttl"
    ttl.write_text(CONTROL_PREFIXES + body, encoding="utf-8")
    code, report = _court(tmp_path, ttl)
    assert code == 1, report
    assert report["standing"] == "REFUSED"
    rows = {g["gate"]: g["refusal_rows"] for g in report["gates"]}
    assert rows[gate] >= 1, (control, rows)
