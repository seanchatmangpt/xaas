# OP Release Tag Cut — v26.9.17 identity fence (operator act + verification)

## Summary

The crown runner's only failing gate (CHI-ID, 1 of 12) is the release identity
fence: it compares `git rev-parse HEAD` against `git rev-list -n 1 <release_tag>`.
The runner constant is already rewired to `v26.9.17` (commit `156cb6fe` on
`fix/autofde-lab-v26.9.17-boundary`); the fence now fails lawfully
(`tag_sha="unreleased"`) because no operator has cut the tag. Tagging is
reserved to the operator; the scratch-clone falsifier already proved the tag
yields 12/12.

## Status

BLOCKED — awaiting operator act (release-identity cut).

## Scope

1. Operator runs (verbatim from certify-prep receipt):
   ```bash
   cd /Users/sac/autofde-lab
   git checkout fix/autofde-lab-v26.9.17-boundary
   git log --oneline -1   # confirm tip 156cb6fe (or tag the NEW tip if branch moved)
   git tag -a v26.9.17 -m "SA2A release v26.9.17" 156cb6feffcc18dc715efb1f17e6760696fd70b6
   .venv/bin/python scripts/run_chicago_qualification.py
   ```
2. Agent verification slice: confirm exit 0, 12/12 gates, `tag_equality=True`,
   `all_objects_conform=True`; commit/refresh the tracked receipt per release
   procedure (operator's call).
3. If more commits land on the branch before the cut: tag the new tip and
   re-run from that checkout (fence checks tag == HEAD).
4. Decide whether `feat/ep2-replay-contract` (`112d7e41`) belongs in v26.9.17
   (see `ep2-certify-integration.md`) — the tag above does NOT include it.

## Key Invariant(s)

- No agent creates, moves, or deletes git tags (release identity is an
  operator cut).
- The fence must keep refusing untagged HEADs after this ticket closes
  (regression guard: `tests/sa2a/conformance/test_crown_release_fence_wiring.py`).

## Relationship to Existing Work

- `certify-prep.md` receipt (wave-4): rewiring `156cb6fe` + tripwire test.
- `boundary-autofde-lab.md`: repair history `64181bb7` → `156cb6fe`.
- Blocks `release-certification-final.md`.

## Falsifiers / What Would Defeat This

- Runner exits 1 with a gate OTHER than CHI-ID failing after the tag —
  defeats "one act from green"; triage the new failure before proceeding.
- `git tag -l` shows the tag but fence still reports `unreleased` — tag/branch
  mismatch (tag not on checked-out HEAD).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | BLOCKED | autofde-lab fix/autofde-lab-v26.9.17-boundary @ 156cb6fe | runner exit 1, 11/12 (only CHI-ID); scratch-clone falsifier exit 0 12/12 | operator tag + re-run + receipt commit |
