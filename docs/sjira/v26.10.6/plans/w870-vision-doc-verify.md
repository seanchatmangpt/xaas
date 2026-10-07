# W870 — Vision/ERRC doc verify + pointer refresh

- **Lane**: W870, v26.10.6 campaign
- **Subject**: `/Users/sac/xaas` @ `a0723bf6`, branch `feat/playwright-surface` (canonical checkout, no worktree, no commit)
- **Standing**: PARTIAL_ALIVE — pointers verified against real code on disk; the three wave receipts (W780/W818/W835) were written by their own lanes, not re-executed here (inspection≠execution; this lane's receipt is the doc refresh only)

## Doc selected (the ONE)

`docs/claude/diataxis/explanation/errc-innovation-grid.md` — the standing ERRC/FMEA index
("Blue Ocean ERRC grid … one evolving doc", 3302 lines, last pass 2026-08-21 twenty-third
pass). Chosen over the `docs/vision/vision-2030-*` cycle snapshots because the consolidation
wave materially changed ITS surface: its incident-guard item (twenty-third pass, lines
~872-885) describes exactly the guard wiring W818 extends, and it tracks the SLA-credit and
governance validation surfaces W835/W780 touch. The `docs/vision/` files are frozen per-cycle
snapshots (latest 2026-09-30-2355, ERRC over PR #108 scope) with zero overlap with
W780/W818/W835; none was materially changed by the wave.

## Verification performed (real greps, exact lines confirmed on disk)

- `lib/xaas/actuation.ex:613-614` — `Map.has_key?(authority, :__struct__)` →
  `{:error, :claim_shaped_authority_refused}`; provenance comment at :609. Confirms W780.
- `lib/xaas/operations/incident.ex:128,150` — `IncidentResolvedRequiresResolvedAt` wired on
  both `:create` and `:update`; `incident.ex:155` — `IncidentResolvedIsTerminal` on `:update`.
  Both validation modules exist under `lib/xaas/operations/validations/`. Confirms W818.
- `lib/xaas/billing/changes/approval_sla_credit_apply_approve.ex:119` and
  `approval_patch_sla_credit_apply_approve.ex:114` — `context: %{xaas_ledger:
  %{allow_overdraft: true}}` on the `:transfer` create. Confirms W835.
- All three receipts exist: `docs/sjira/v26.10.6/plans/w780-claim-authority-guard.md`,
  `w818-incident-guards.md`, `w835-sla-exemption.md`.

## Changes made (per-claim)

One edit, one file: inserted a dated pointer block
("## Pointer refresh — 2026-10-07 (v26.10.6 consolidation wave, lane W870)") after the
errc-innovation-grid.md header, before the twenty-third-pass section. The block:

- states the three repairs with exact file:line evidence and receipt paths (facts only);
- marks the W818 item as extending the grid's own twenty-third-pass incident-guard finding
  (both W793 gaps a/b closed);
- scopes itself: "refreshes pointers only" — no historical pass text rewritten.

No other file edited; no pointer blocks added to `docs/vision/` (see selection rationale above).

## Not executed here

No tests run, no compile — the guards' own courts (W780/W818/W835 lanes) own that evidence;
this lane's falsifier is documentable only: any cited file:line above not matching disk would
falsify the block. All matched at write time.
