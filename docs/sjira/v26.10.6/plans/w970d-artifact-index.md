# W970d — Artifact-manifest index lines for 4 unindexed artifacts (receipt)

- **Lane**: W970d, campaign v26.10.6. Date: 2026-10-07.
- **Subject**: /Users/sac/xaas @ `feat/playwright-surface` (working tree, no commit per lane contract; no build root minted).
- **Task** (from W970c out-of-scope note): add index lines to `docs/cro/ARTIFACT-MANIFEST.md` (W850–W980 wave-table format) for `witness-live-court-note.md`, `delaware-rebuttal-evidence-map.md`, `s3-evidence-pack-replay-validation.md`, `implementation-wave-ledger.md`.
- **O***: artifact files located on disk (`docs/cro/artifacts/`, all 4 exist); receipts located by grep of `docs/sjira/v26.10.6/plans/` for each filename; artifact headers read for self-declared authoring lanes.

## Lines added (ARTIFACT-MANIFEST.md, W850–W980 wave table; section header now reads "lanes W970c + W970d")

| Artifact | Stage | Provenance receipt | test -f |
|---|---|---|---|
| witness-live-court-note.md | S3 | `docs/sjira/v26.10.6/plans/w934-witness-live-note.md` (receipt header names it "author of record") | OK |
| delaware-rebuttal-evidence-map.md | S2 | no plans/ receipt exists — authored lane W525c per artifact header, 2026-10-06; disclosed as receipt-less in the manifest line | OK (artifact); `w525c-*.md` confirmed absent |
| s3-evidence-pack-replay-validation.md | S3 | no dedicated authoring receipt — authored lane W439 per artifact header; nearest plans/ receipt `w861-evidence-pack-refresh.md` (reads it verbatim as "(W439)") | OK (artifact); `w439-*.md` confirmed absent |
| implementation-wave-ledger.md | S3 | `docs/sjira/v26.10.6/plans/w781-wave-ledger-refresh.md` (Terminal-4 append, latest); earlier `w917-ledger-batch-fold.md`, `w650-ledger-terminal2.md`, `w650b-ledger-terminal3.md` | OK |

## Commands/exits

- `find . -name <artifact>` ×4 → all 4 found under `docs/cro/artifacts/` (exit 0)
- `grep -l <artifact> docs/sjira/v26.10.6/plans/*.md` ×4 → provenance mapping above (exit 0)
- `grep -lin delaware w525*.md` → no match; `ls docs/sjira | grep w525c` style checks → `w525c` / `w439` receipt files absent
- `test -f` on w934/w861/w781/w917 receipts → all OK (exit 0)
- Edit applied to `docs/cro/ARTIFACT-MANIFEST.md` (2 edits: section header + 4 table rows); confirmed by successful Edit tool application.

## Standing

ALIVE for the index action itself (lines added, receipts on disk verified). Two
provenance chains are disclosed as receipt-less (delaware W525c, s3-replay W439):
the artifacts stand on their own headers, not on any plans/ receipt — this is
recorded in the manifest rows rather than silently asserted. Nothing committed.
