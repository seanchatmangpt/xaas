# W984bi — AIRo Pin-Drift Re-Witness (Rerun)

- Date: 2026-10-07
- Subject: xaas @ `b5d677b37bd57dd4821f159d798a19e2dfbe8863` (branch `feat/playwright-surface`, uncommitted tree as-found)
- Scope: re-witness only. No ledger edits, no code changes, no commit.

## Run 1 — pin_drift_check.exs

Command: `elixir docs/airo/pin_drift_check.exs` (2026-10-07T18:12:38.630988Z)

Counts: `{"missing": 0, "drift": 0, "current": 20, "ancestor": 1}`, rows_checked: 21, drift: [].

## Run 2 — pin_drift_check.exs

Command: `elixir docs/airo/pin_drift_check.exs` (2026-10-07T18:12:43.005264Z)

Counts: `{"missing": 0, "drift": 0, "current": 20, "ancestor": 1}`, drift: [].

Per-row deltas run1→run2: none. All 21 rows byte-identical between runs. The single
ANCESTOR row is `beam4pm` head `7312ffcd43f24a991b0536cdb61c139c070ae3e7` vs recorded
`560202484f5f61568e74fb0bfde13f6f6a67fdd2` (head is an ancestor of the recorded pin —
known state, matches w982h/w983k expectation). No new drift rows; no old→new SHA
transitions to report.

## Run 1 — pin court

Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984bi mix test test/xaas/airo/airo_pin_court_test.exs`

Real tail:

```
.....[pin-court] skipped (checkout absent): 0
.
Finished in 0.2 seconds (0.2s async, 0.00s sync)

Result: 6 passed
```

Exit 0. 6/6 passed. The receipted-drift-map court did not fail — because there is no
unreceipted drift to fail on (drift: 0 in both scan runs). Note: one test emits
`[pin-court] skipped (checkout absent): 0` — zero skips, all checkouts present.

## Run 2 — pin court

Same command. Real tail:

```
....[pin-court] skipped (checkout absent): 0
..
Finished in 0.4 seconds (0.4s async, 0.00s sync)

Result: 6 passed
```

Exit 0. 6/6 passed.

## Standing

ALIVE. Expectation from w982h/w983k reproduced exactly on the current tree, twice:
{current: 20, ancestor: 1, drift: 0, missing: 0} ×2; pin court 6/6 ×2.

## Environment notes / disclosures

- Fresh lane build root `_build-laneW984bi` was created for the court runs. **Cleanup
  incomplete**: `rm -rf /Users/sac/xaas/_build-laneW984bi` was denied by the permission
  system in this session. The directory remains on disk and needs manual deletion
  (~one full test compile).
- PromEx Grafana dashboard-upload warnings during test boot are pre-existing
  (nxdomain — no local Grafana); do not affect court results.
- No mix compile of the shared `_build` was performed; all mix work used the lane root.
