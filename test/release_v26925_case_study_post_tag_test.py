"""Court for the post-tag durable AC-13 case-study-schema receipt (xaas X2).

Chicago style: every assertion reads real committed bytes (receipt, report,
lock, tagged receipt) or exercises the real manufacturer functions.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RECEIPTS = ROOT / "release" / "v26.9.25" / "receipts"
POST_TAG = RECEIPTS / "case-study-schema.post-tag.json"
REPORT = RECEIPTS / "case-study-schema.post-tag.semantic-report.json"
LOCK = RECEIPTS / "case-study-schema.requirements.lock"
TAGGED = RECEIPTS / "case-study-schema.json"
LOCATOR = re.compile(r"^git:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9a-f]{40}:[^\s]+$")
NON_DURABLE = re.compile(r"(^|[\s=])(/|~)|/private/|/tmp/|scratchpad|/Users/")


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _canonical(obj: object) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _manufacturer():
    spec = importlib.util.spec_from_file_location("rerun_case_study", RECEIPTS / "rerun_case_study.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_receipt_seal_recomputes() -> None:
    receipt = _load(POST_TAG)
    claimed = receipt.pop("receipt_sha256")
    assert _sha(_canonical(receipt)) == claimed


def test_receipt_is_alive_with_every_check_true() -> None:
    receipt = _load(POST_TAG)
    assert receipt["standing"] == "ALIVE"
    assert receipt["refusals"] == []
    assert receipt["checks"] and all(receipt["checks"].values()), receipt["checks"]


def test_supersedes_the_tagged_receipt_without_editing_it() -> None:
    receipt = _load(POST_TAG)
    tagged_bytes = TAGGED.read_bytes()
    tagged = json.loads(tagged_bytes)
    assert LOCATOR.fullmatch(receipt["supersedes_locator"])
    assert receipt["supersedes_locator"] == (
        "git:seanchatmangpt/xaas@6a63d891ea5ce046d23c1e00cc78a2f070aca617:"
        "release/v26.9.25/receipts/case-study-schema.json"
    )
    assert receipt["superseded_receipt"]["blob_sha256"] == _sha(tagged_bytes)
    assert receipt["superseded_receipt"]["receipt_sha256"] == tagged["receipt_sha256"]
    assert receipt["subject_sha"] == tagged["subject_sha"]


def test_durable_report_bytes_equal_the_recorded_report() -> None:
    receipt = _load(POST_TAG)
    tagged = _load(TAGGED)
    court_recorded = next(c for c in tagged["commands"] if "stogaf_semantic_court.py" in c["command"])
    court_rerun = next(c for c in receipt["commands"] if "stogaf_semantic_court.py" in c["command"])
    data = REPORT.read_bytes()
    assert receipt["durable_report"]["path"] == "release/v26.9.25/receipts/" + REPORT.name
    assert _sha(data) == receipt["durable_report"]["sha256"] == court_recorded["report_file_sha256"]
    assert court_rerun["output_sha256"] == court_recorded["output_sha256"]
    report = json.loads(data)
    claimed = report.pop("report_sha256")
    assert _sha(_canonical(report)) == claimed == tagged["court_report"]["report_sha256"]
    assert report["standing"] == "ALIVE" and report["refusal_rows"] == 0


def test_interpreter_is_version_plus_lock_hash_not_a_path() -> None:
    receipt = _load(POST_TAG)
    interp = receipt["interpreter"]
    assert re.fullmatch(r"\d+\.\d+\.\d+", interp["version"])
    assert interp["requirements_lock"] == "release/v26.9.25/receipts/" + LOCK.name
    assert interp["requirements_lock_sha256"] == _sha(LOCK.read_bytes())
    pins = [line for line in LOCK.read_text(encoding="utf-8").splitlines() if line.strip()]
    assert pins and all(re.fullmatch(r"[A-Za-z0-9_.-]+==[A-Za-z0-9_.+-]+", p) for p in pins)
    assert any(p.startswith("rdflib==") for p in pins) and any(p.startswith("pyshacl==") for p in pins)


def test_no_command_carries_a_non_durable_path() -> None:
    receipt = _load(POST_TAG)
    for step in receipt["commands"]:
        assert step["command"].startswith("python "), step["command"]
        assert not NON_DURABLE.search(step["command"]), step["command"]
        assert step["cwd"] == "<subject-dir>"
    court = next(c for c in receipt["commands"] if "stogaf_semantic_court.py" in c["command"])
    assert court["output_path"] == "semantic-report.json"
    assert "--output semantic-report.json" in court["command"]


def test_pytest_outcome_digest_is_order_and_timing_free() -> None:
    m = _manufacturer()
    a = (
        "rootdir: /x\nt.py::b PASSED [ 50%]\nt.py::a PASSED [100%]\n"
        "============================== 2 passed in 1.00s ===============================\n"
    )
    b = (
        "rootdir: /elsewhere\nt.py::a PASSED [ 50%]\nt.py::b PASSED [100%]\n"
        "============================== 2 passed in 9.99s ===============================\n"
    )
    ra, rb = m.pytest_outcomes(a), m.pytest_outcomes(b)
    assert ra == rb
    assert ra["summary"] == "2 passed" and ra["outcome_count"] == 2 and ra["non_passed"] == []
    failing = m.pytest_outcomes(a.replace("t.py::a PASSED", "t.py::a FAILED"))
    assert failing["outcome_digest_sha256"] != ra["outcome_digest_sha256"]
    assert failing["non_passed"] == ["t.py::a FAILED"]
