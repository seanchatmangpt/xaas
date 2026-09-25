"""Freeze court for the WD Case Study 2 submission.

The submission header names a frozen subject SHA and the STOGAF court report
digest. These tests read the real document, the real git object store and
re-run the real court script on `git archive <frozen subject>`. No doubles.
A missing git object (shallow CI checkout) is a named skip, never a pass.
"""

from __future__ import annotations

import hashlib
import io
import re
import subprocess
import sys
import tarfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs" / "case-studies" / "wd-fa" / "19-SEPTEMBER-25-SUBMISSION.md"

SUBJECT = re.compile(
    r"^\*\*Frozen subject:\*\* `seanchatmangpt/xaas@([0-9a-f]{40})`", re.MULTILINE
)
DIGEST = re.compile(
    r"^\*\*Court report:\*\* `wd-cs2-stogaf-semantic-report\.json` sha256 `([0-9a-f]{64})`",
    re.MULTILINE,
)
STALE = (
    "failed at the RDF/SHACL/SPARQL court",
    "failed at formatting",
    "1ebbaff4d8e74ef82c833984b435d7e32c3f875a",
)


def _text() -> str:
    return DOC.read_text(encoding="utf-8")


def _subject() -> str:
    found = SUBJECT.findall(_text())
    assert len(found) == 1, found
    return found[0]


def _digest() -> str:
    found = DIGEST.findall(_text())
    assert len(found) == 1, found
    return found[0]


def _has_object(sha: str) -> bool:
    return (
        subprocess.run(
            ["git", "cat-file", "-e", f"{sha}^{{commit}}"], cwd=ROOT, capture_output=True
        ).returncode
        == 0
    )


def test_header_declares_freeze_subject_and_digest() -> None:
    text = _text()
    assert "**Freeze:** FROZEN 2026-09-25" in text
    assert re.fullmatch(r"[0-9a-f]{40}", _subject())
    assert re.fullmatch(r"[0-9a-f]{64}", _digest())


def test_stale_ci_claims_are_absent() -> None:
    text = _text()
    for phrase in STALE:
        assert phrase not in text, phrase


def test_non_claims_survive_the_freeze() -> None:
    text = _text()
    assert "does **not** claim that the current PR head is globally ALIVE" in text
    assert "no measured WD MTTR reduction" in text


def test_frozen_subject_is_an_ancestor_of_head() -> None:
    sha = _subject()
    if not _has_object(sha):
        pytest.skip(f"git object {sha} absent (shallow checkout); ancestry not observable")
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", sha, "HEAD"], cwd=ROOT, capture_output=True
    )
    assert result.returncode == 0, result.stderr


def test_court_report_digest_replays_on_frozen_subject(tmp_path: Path) -> None:
    sha = _subject()
    if not _has_object(sha):
        pytest.skip(f"git object {sha} absent (shallow checkout); replay not observable")
    archive = subprocess.run(
        ["git", "archive", sha, "scripts/stogaf_semantic_court.py", "priv/packs/wd_cs2_pack",
         "docs/case-studies/wd-fa/presentation"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    ).stdout
    tree = tmp_path / "subject"
    tree.mkdir()
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        tar.extractall(tree, filter="data")
    report = tmp_path / "report.json"
    subprocess.run(
        [
            sys.executable,
            str(tree / "scripts" / "stogaf_semantic_court.py"),
            "--pack",
            str(tree / "priv" / "packs" / "wd_cs2_pack"),
            "--output",
            str(report),
        ],
        cwd=tree,
        check=True,
        capture_output=True,
    )
    assert hashlib.sha256(report.read_bytes()).hexdigest() == _digest()
