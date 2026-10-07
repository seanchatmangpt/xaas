# W895 — Runbook lease-cleanup fold to W878 census

**Lane**: W895, v26.10.6 campaign, repo /Users/sac/xaas, branch
`feat/playwright-surface`.

## Task

Point the integration runbook's lease-cleanup sections at W878's landed census
(`plans/w878-lease-census.md`) as the authoritative cleanup input; add the
operator execution note; resolve census CHECK entries W856/W865 if receipts
landed.

## μ / diff

Handwritten docs-only edit to
`docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md` (3 edits, no code):

1. New dated section "Lease cleanup — AUTHORITATIVE INPUT (W895, 2026-10-07)"
   inserted before the legacy "Lane-lease inventory (coordinator, ~04:5x)"
   section, declaring the census (80 deletable / ~31.71 GB, byte-verified
   65-path rm list) authoritative and superseding the earlier inventories.
2. Step 1 of the W879 integration sequence annotated
   `[SUPERSEDED — W895, 2026-10-07]` with a pointer to the new section (prior
   text preserved as history).
3. Pre-condition table row "W878 lease census" updated IN_FLIGHT → LANDED.

No deletion, no build root, no commit (per lane contract).

## Receipt existence check (test -f, run by this lane)

- `plans/w856-dev-config-pin.md` — EXISTS
- `plans/w865-gap3-fix.md` — EXISTS

Both census CHECK entries resolve; their lane roots are DELETABLE alongside the
census's 65-path rm list. Census KEEP entries (W880, W888) remain held until
their receipts land.

## Verification

- `grep -n "w878-lease-census\|SUPERSEDED\|LANDED" _INTEGRATION_RUNBOOK.md`
  confirms all three edits on disk after write (Edit tool success + re-read of
  edited regions).

## Standing

ALIVE (docs fold executed on exact subject `feat/playwright-surface` @
a0723bf6; edits verified in the file). The census rm list itself remains
operator-executed — W895 executed no deletion.

## Falsifier

A runbook reader following only the legacy ~04:5x inventory or un-annotated
step 1 would act on stale inputs; the fold is falsified if any lease-inventory
section still presents non-census numbers as current without a superseded
marker.
