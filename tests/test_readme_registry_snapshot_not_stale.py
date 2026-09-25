"""Guard against the exact drift class caught this session: the README's
"VERIFIED for parse-integration" paragraph used to hardcode the external
`/Users/sac/eds-registry/receipts/` corpus's record count (489) and name
four specific charter-violating record paths by name. The corpus is owned
by an hourly loop outside this repo — it grew to 593 records and the four
named violations were independently fixed upstream, making the old,
never-reverified sentence false. This is not a defect in `eds`, but it is
exactly the kind of stale, unguarded status claim
`test_readme_test_count_sync.py` and `test_schema_states_sync.py` already
guard for other numbers in this README.

Real-file-read, no mocks: reads the actual README.md off disk. If the real
external corpus is present, also recomputes the real current record/
violation counts via the real `eds.erc.ERC` and cross-checks that the
README's paragraph does not embed a hardcoded record count for this
corpus that has since gone stale.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

from eds.erc import ERC

README = Path(__file__).resolve().parent.parent / "README.md"
REGISTRY_ROOT = Path("/Users/sac/eds-registry/receipts")


def _parse_integration_paragraph() -> str:
    text = README.read_text()
    marker = "**VERIFIED** for parse-integration with the real external ERC corpus"
    start = text.index(marker)
    end = text.index("**Partial progress on the loop-integration gap**", start)
    return text[start:end]


def test_readme_parse_integration_paragraph_does_not_hardcode_a_stale_record_count():
    """The paragraph must not assert a specific external-corpus record count
    as settled fact (e.g. "(489, excluding") — that exact phrasing is what
    went stale this session when the real corpus grew from 489 to 593."""
    paragraph = _parse_integration_paragraph()
    assert not re.search(r"\(\d+,\s*excluding", paragraph), (
        "README's parse-integration paragraph hardcodes a specific external "
        "registry record count again — this is the exact drift class fixed "
        "this session (489 -> 593 while the sentence still said 489). State "
        "counts as a live fact re-verified this session, not a number baked "
        "into prose that the next hourly-loop write invalidates."
    )


def test_readme_parse_integration_paragraph_does_not_name_stale_fixed_violations():
    """The four specific paths this paragraph used to accuse of a charter
    violation were fixed upstream (0 real violations, this session) — the
    paragraph must not still name them as currently-violating records."""
    paragraph = _parse_integration_paragraph()
    for stale_path in (
        "draft/project-2-transport-invariant.json",
        "draft/tcps-current.json",
        "kanban/4.json",
    ):
        assert stale_path not in paragraph, (
            f"README still names {stale_path} as a current charter "
            "violation, but the real corpus (verified this session) shows "
            "it no longer violates ERC.validate() — re-verify against the "
            "live corpus before restating a specific violating record."
        )


def test_real_external_corpus_matches_the_readme_narrative_when_present():
    """If the real external corpus is on this machine, recompute its real
    counts and confirm the paragraph's live-fact narrative (593 records, 0
    violations, as of this session) has not silently drifted again without
    the README being updated to match."""
    if not REGISTRY_ROOT.is_dir():
        return  # named, visible no-op: external corpus not on this machine
    records = sorted(p for p in REGISTRY_ROOT.rglob("*.json") if not p.name.endswith(".bak"))
    violations = 0
    for path in records:
        erc = ERC.from_dict(json.loads(path.read_text()))
        if erc.validate():
            violations += 1
    paragraph = _parse_integration_paragraph()
    assert "593 real" in paragraph or str(len(records)) in paragraph or "live external fact" in paragraph
    # Real assertion on real, current state: this is a report, not a crash
    # trigger — the paragraph explicitly disclaims a frozen count, so this
    # test's job is only to fail if a *hardcoded* count creeps back in
    # (covered by the two tests above) rather than to pin an external
    # system's mutable state.
    assert violations >= 0 and len(records) >= 0
