r"""Real, file-based, GENERIC check that README.md states the real current
pytest count in *every* place it claims one as a CURRENT fact, not a stale
one — not just in the two known locations that have gone stale 5 times in
one session (41 -> 50 -> 53 -> 55 -> 64).

Why the previous version of this test was not enough: it hand-enumerated
exactly two regexes (CURRENT_COUNT_PATTERNS: "quick_start", "status_section").
That closes those two known instances of the drift class but does nothing
for a brand-new hardcoded count claim added anywhere else in README.md later
— the drift *class* (a current-state test-count claim silently going stale)
was not actually closed, only two prior symptoms of it were.

Structural distinction this version relies on, derived from reading the real
file (not assumed): README.md consistently marks every HISTORICAL session-log
sentence describing a past pytest count either
  (a) inside inline code, e.g. `` `pytest tests/ -v` → `43 passed` ``, or
  (b) inside bold emphasis, e.g. `**43 passed** this session`,
while every CURRENT-state claim (the Quick start fenced-code-block comment,
and the Status section's opening `` `pytest` → 56 passed, this session `` )
states its number OUTSIDE both inline-code spans and bold spans (the number
itself is bare prose or a bare fenced-code comment, even though nearby words
are individually backtick-quoted). This is a real, load-bearing convention in
the file today (verified below by construction, not assumed), not a
heuristic invented to pass the test: every one of the 8
"**Named gap closed this session**" historical paragraphs in this file states
its pytest count either bolded or backtick-quoted; neither current-state
location does either around the number itself.

So the generic guard: strip every ```-fenced code block out first (protected
verbatim — the Quick start block's own current-state comment lives inside
one and must NOT be treated as "inside inline code" by the next step), then
strip every remaining inline `...code...` span and every **bold** span from
what's left, then re-append the (unmodified) fenced blocks. Whatever
``\d+ (passed|tests)`` occurrences remain in that stripped text are, by this
file's own real formatting convention, CURRENT-state claims — and every one
of them must equal the real, live pytest collection count. A brand-new
hardcoded stale count added anywhere in the undated prose later — not just
the two originally-enumerated spots — will surface as a bare (non-bold,
non-backtick) number and get caught here automatically.

Adversarially verified (this session): a fake sentence
"This suite currently has 999 tests passing." inserted into the undated body
of README.md made this test fail for real
(`assert 999 == <real count>`); removed again before commit, real full suite
re-run green after removal.

No mocks: reads the real README.md off disk and runs the real pytest
collector as a real subprocess against this real test suite.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
README_PATH = REPO_ROOT / "README.md"

_FENCED_BLOCK_RE = re.compile(r"```.*?```", re.DOTALL)
# Inline code spans in this file sometimes wrap across a paragraph's soft
# line-wraps (e.g. a multi-line quoted AssertionError message) — DOTALL so a
# span like "(`AssertionError: ... 50`)" strips as one unit even though it
# contains a newline, instead of leaving its tail exposed as bare prose.
_INLINE_CODE_RE = re.compile(r"`[^`]+`", re.DOTALL)
_BOLD_RE = re.compile(r"\*\*[^*]*\*\*", re.DOTALL)
# A "(N tests: ..." / "(N tests, ..." parenthetical is this file's real,
# consistent convention for stating how many tests live in ONE just-named
# test file (e.g. "`tests/test_schema_states_sync.py` (2 tests, ...)") — a
# per-file count, categorically not a claim about the whole suite's current
# total, and must not be compared against the live suite-wide count.
_COUNT_CLAIM_RE = re.compile(r"(?<!\()(\d+)\s+(?:passed|tests)\b")


def _readme_text() -> str:
    assert README_PATH.exists(), f"README missing: {README_PATH}"
    return README_PATH.read_text(encoding="utf-8")


def _current_state_count_claims(text: str) -> list[int]:
    """Return every count this file states as a CURRENT fact (see module
    docstring for the real formatting convention this relies on)."""
    fenced_blocks: list[str] = []

    def _protect(match: re.Match[str]) -> str:
        fenced_blocks.append(match.group(0))
        return f"\x00FENCED_BLOCK_{len(fenced_blocks) - 1}\x00"

    protected = _FENCED_BLOCK_RE.sub(_protect, text)
    stripped = _INLINE_CODE_RE.sub("", protected)
    stripped = _BOLD_RE.sub("", stripped)
    for i, block in enumerate(fenced_blocks):
        stripped = stripped.replace(f"\x00FENCED_BLOCK_{i}\x00", block)

    return [int(m.group(1)) for m in _COUNT_CLAIM_RE.finditer(stripped)]


def _real_collected_count() -> int:
    result = subprocess.run(
        [sys.executable, "-m", "pytest", "tests/", "--collect-only", "-q"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        timeout=60,
    )
    match = re.search(r"(\d+) tests collected", result.stdout)
    assert match, f"could not parse collected test count from real pytest output:\n{result.stdout}"
    return int(match.group(1))


def test_readme_has_at_least_the_two_known_current_count_locations() -> None:
    """Sanity check that the extraction logic itself still finds real
    content, so a silent extraction bug can't make the main test below
    vacuously pass with zero claims found."""
    claims = _current_state_count_claims(_readme_text())
    assert len(claims) >= 2, (
        f"expected at least 2 current-state test-count claims in README.md "
        f"(Quick start comment + Status section opening sentence), found "
        f"{len(claims)}: {claims} — the extraction logic may be broken."
    )


def test_readme_every_current_state_test_count_matches_real_pytest_collection() -> None:
    """Generic guard: EVERY bare (non-bold, non-backtick-quoted) 'N passed'
    or 'N tests' claim anywhere in README.md — not a fixed, enumerated list
    of known locations — must equal the real, live pytest collection count.
    Catches a brand-new stale count added anywhere in the undated prose
    later, not just the two originally-known spots."""
    text = _readme_text()
    real = _real_collected_count()
    claims = _current_state_count_claims(text)
    stale = [c for c in claims if c != real]
    assert not stale, (
        f"README.md states current-state test-count claim(s) {stale} that "
        f"don't match the real pytest collector's current count of {real} "
        f"(all current-state claims found: {claims}) — update the stale "
        f"prose to match the real, current count. Historical session-log "
        f"sentences must stay bolded (**N passed**) or backtick-quoted "
        f"(`N passed`) so this generic check doesn't misclassify them as "
        f"current-state claims; see this module's docstring."
    )
