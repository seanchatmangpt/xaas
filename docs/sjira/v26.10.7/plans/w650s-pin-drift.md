# W650s — ash_graphlaw pin drift repair (AIRo ledger)

Lane W650s, v26.10.7 fleet seal, 2026-10-07. Scope: repair the drifted
ash_graphlaw row in `docs/cro/artifacts/airo-wiring-ledger.md` disclosed by
W634 (drift introduced by W631b's gitignore-sweep pull/merge of
~/ash_graphlaw). No commit (coordinator owns integration).

## Ground truth (real commands, exact subject `~/ash_graphlaw`)

- `git -C ~/ash_graphlaw rev-parse HEAD` →
  `3ecae0e771f5448e90d8adc2a8a0786439b5b13e`, branch `main`.
- Ancestor proof: `git -C ~/ash_graphlaw merge-base --is-ancestor
  1d89ba5f9a56f79e2c0b04cf1ca307d1086d3137 HEAD` → exit 0.
  **Lawful fast-forward**, same class as the beam4pm ANCESTOR row. Not a
  divergence, no history rewritten.
- Commits between pin and HEAD (`git log --oneline 1d89ba5f..HEAD`):
  1. `94da31a` chore: ignore lane-lease build roots (campaign fan-out)
     (the W631b gitignore sweep)
  2. `3ecae0e` chore(release): bump version to 26.10.7 — touches
     `mix.exs` + `ontology.ttl` only.
- v26.10.7 version work IN the new HEAD tree (verified, not assumed):
  - `git show HEAD:mix.exs` → `@version "26.10.7"` (was `"26.10.1"` at
    `1d89ba5f`).
  - `git show HEAD:ontology.ttl` → `glx:packageVersion "26.10.7"`.
- Drift check: `elixir docs/airo/pin_drift_check.exs` →
  `counts: {current: 5, ancestor: 16, drift: 0, missing: 0}`, 21 rows.
  ash_graphlaw row: `CURRENT` at `3ecae0e7…`. Drift table empty.

## Ledger change (before → after)

Row: ash_graphlaw / main.

- Before: HEAD cell = `1d89ba5f9a56f79e2c0b04cf1ca307d1086d3137`
- After: HEAD cell = `3ecae0e771f5448e90d8adc2a8a0786439b5b13e`, with the
  fast-forward citation (W631b/W634 + this receipt) placed in the falsifier
  column — the SHA cell must stay a bare 40-hex backticked value or
  `pin_drift_check.exs`'s `^`40-hex`$` regex silently drops the row
  (first attempt had it inline; row count fell 21→20; caught and fixed in
  the same session — counts went 21 rows / drift 0 after the fix).

## Findings (pre-existing, not session-introduced)

- The row's pin-court falsifier names `priv/airo_risk_description.ttl`
  (vocab sha `6274d2d8…`) — **no AIRo file exists anywhere in the
  ash_graphlaw tree at either SHA** (`git ls-tree -r --name-only` at both
  SHAs: zero airo matches; `git grep -l -i airo HEAD`: zero; `ontology.ttl`
  has 0 airo references). The pin court as written has never been
  executable against this repo; the row's UNKNOWN standing is correct for
  that reason, independent of the SHA drift. Left as-is (out of lane
  scope); flagging for the coordinator.
- `~/graphlaw` (branch `graphlaw-registry-limits`, HEAD `918dda23`) is a
  different repo that does not contain `1d89ba5f` at all; the ledger row
  resolves to `~/ash_graphlaw` per the drift script's `~/<repo>` rule.

## Standing

- ash_graphlaw ledger row: standing UNKNOWN unchanged (falsifier never
  executable — pre-existing). Pin currency: CURRENT at `3ecae0e7`.
- Drift count: 0 across all 21 ledger rows.
- Verification ladder: exact-subject git inspection (narrow) + full
  drift-check rerun (machine report). No tests/mix run (per lane scope).
- Wrote: ledger row + this receipt only. No commit.
