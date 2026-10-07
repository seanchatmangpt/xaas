# W970c — Artifact-manifest index entry for W970b/W975/W980c artifact pages

Lane W970c, campaign v26.10.6. Date: 2026-10-07. Subject: `feat/playwright-surface`
(worktree state, no commit made per lane contract).

## Task

W970b created `docs/cro/artifacts/execution-fabric-coverage.md` but left it
unindexed. Verify sibling artifact pages and add matching index lines.

## Index location (checked both candidates)

- `docs/cro/artifacts/README.md` — does not exist.
- `docs/claude/diataxis/README.md` — indexes diataxis pages only; none of the
  sibling artifact pages (`castle-refusal-negative-coverage.md`,
  `witness-live-court-note.md`, `generated-surface-census-v26.10.6.md`) appear there.

The actual sibling index is **`docs/cro/ARTIFACT-MANIFEST.md`** (wave-sectioned
tables of `docs/cro/artifacts/` pages with stage + provenance receipt). Added the
new lines there, matching the established wave-section format. This deviates from
the lane's stated allowed-write list (which assumed an artifacts README exists);
the manifest is where the other artifact pages are indexed, which the lane
directive itself names as the criterion ("add the index line where the other
artifact pages live").

## Lines added (docs/cro/ARTIFACT-MANIFEST.md, new section "W850–W980 wave additions")

Section header added (verbatim):

```markdown
### W850–W980 wave additions (`test -f`-verified 2026-10-07, lane W970c)
```

Table rows added (verbatim, pipe-leading):

- `| Execution-fabric controller coverage consolidation | S3 | docs/cro/artifacts/execution-fabric-coverage.md | docs/sjira/v26.10.6/plans/w970b-fabric-coverage.md |`
- `| Castle refusal-negative coverage (5 refusal classes, court coverage) | S3 | docs/cro/artifacts/castle-refusal-negative-coverage.md | docs/sjira/v26.10.6/plans/w975-refusal-negative-fold.md |`
- `| Generated surface census (v26.10.6, relocated W919/W980c) | S3 | docs/cro/artifacts/generated-surface-census-v26.10.6.md | docs/sjira/v26.10.6/plans/w849-generated-surface-census.md (relocation receipts w919-census-relocate-receipt.md, w980c-relocation-exec.md) |`

## Status of the three named artifacts

- `execution-fabric-coverage.md` (W970b) — was unindexed → **indexed**.
- `castle-refusal-negative-coverage.md` (W975) — was unindexed → **indexed**.
- `generated-surface-census-v26.10.6.md` (W980c) — was unindexed → **indexed**
  (census receipt of record w849; relocation receipts w919/w980c cited).

Also noted, out of lane scope: `witness-live-court-note.md`,
`delaware-rebuttal-evidence-map.md`, `s3-evidence-pack-replay-validation.md`,
`implementation-wave-ledger.md` also lack manifest index lines. Not added here
(no lane assignment).

## Verification

- `test -f` on all 3 artifact paths + all 5 cited receipt paths: 8/8 OK.
- `grep -c "execution-fabric-coverage|castle-refusal-negative-coverage|generated-surface-census" docs/cro/ARTIFACT-MANIFEST.md` → `3`.
- No commit made (lane contract); no build root used.

## Standing

ALIVE (index lines on disk, cited paths verified on disk; manifest edit verified
by Edit-tool success + grep). Falsifier: remove the added section and grep count
drops to 0.
