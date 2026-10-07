# W970e — Artifact-manifest index verification sweep (W970c + W970d lines)

Lane W970e, campaign v26.10.6. Date: 2026-10-07. Subject: `/Users/sac/xaas`
@ `feat/playwright-surface` (working tree, no commit per lane contract).

## Task

Verify the 7 index lines added to `docs/cro/ARTIFACT-MANIFEST.md` by lanes
W970c (3 lines) and W970d (4 lines): every artifact path `test -f`-exists,
every cited receipt exists or is accurately disclosed, no broken paths, no
duplicate entries.

## Verification table (all `test -f` real, 2026-10-07)

| # | Artifact line (manifest) | Artifact path | Cited receipt path(s) | Result |
|---|---|---|---|---|
| 1 | Execution-fabric controller coverage consolidation (W970c) | `docs/cro/artifacts/execution-fabric-coverage.md` — OK | `docs/sjira/v26.10.6/plans/w970b-fabric-coverage.md` — OK | PASS |
| 2 | Castle refusal-negative coverage (W970c) | `docs/cro/artifacts/castle-refusal-negative-coverage.md` — OK | `docs/sjira/v26.10.6/plans/w975-refusal-negative-fold.md` — OK | PASS |
| 3 | Generated surface census (W970c) | `docs/cro/artifacts/generated-surface-census-v26.10.6.md` — OK | `docs/sjira/v26.10.6/plans/w849-generated-surface-census.md` — OK; relocation receipts `w919-census-relocate-receipt.md` — OK, `w980c-relocation-exec.md` — OK | PASS |
| 4 | WitnessLive mount-only read note (W970d) | `docs/cro/artifacts/witness-live-court-note.md` — OK | `docs/sjira/v26.10.6/plans/w934-witness-live-note.md` — OK | PASS |
| 5 | Delaware rebuttal evidence map (W970d) | `docs/cro/artifacts/delaware-rebuttal-evidence-map.md` — OK | none cited — line discloses "no `w525c-*.md` exists in `docs/sjira/v26.10.6/plans/`"; verified true: `plans/` has `w525-title-vi-xiii.md`, `w525b-title-i.md`, `w525d-map-update-sweep.md`, no `w525c-*`. Disclosure accurate. | PASS (disclosed) |
| 6 | S3 evidence pack replay validation (W970d) | `docs/cro/artifacts/s3-evidence-pack-replay-validation.md` — OK | `docs/sjira/v26.10.6/plans/w861-evidence-pack-refresh.md` — OK (verified it names W439) | PASS (disclosed) |
| 7 | Implementation wave ledger (W970d) | `docs/cro/artifacts/implementation-wave-ledger.md` — OK | `docs/sjira/v26.10.6/plans/w781-wave-ledger-refresh.md` — OK; `w917-ledger-batch-fold.md` — OK; `w650*/ledger-terminal*` — glob matches real files `w650-ledger-terminal2.md`, `w650b-ledger-terminal3.md`, `w650c-terminal-census.md` (no bare `w650-ledger-terminal.md` exists; glob, not a specific wrong path) | PASS |

## Duplicate check

`grep -c "artifacts/<name>.md" docs/cro/ARTIFACT-MANIFEST.md` per artifact:
exactly 1 occurrence each for all 7. No duplicate index entries.

## Fixes

None required. Zero broken artifact paths, zero wrong receipt references.
Only note: manifest line 84's provenance cites the glob `w650*/ledger-terminal*`
rather than exact filenames; the glob matches real on-disk files, so left
as-is under minimal-edit discipline.

## Commands / exits

- `test -f` on 7 artifact paths: 7/7 OK.
- `test -f` on 10 receipt paths (8 specific + w650 glob expansion + w525c absence check): all as tabled.
- `grep -n` on manifest for the 7 artifact names: lines 78–84, section
  "W850–W980 wave additions" (manifest line 74, lanes W970c + W970d).
- Duplicate grep count: 1 per artifact.

## Standing

ALIVE — all 7 index lines verified against on-disk reality; no manifest edit
was needed this lane. Falsifier: `test -f` any tabled path → missing, or
duplicate count > 1 for any artifact. No commit (lane contract); no build root.
