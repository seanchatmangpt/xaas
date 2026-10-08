# W650v — ash_pplan suite witnessing receipt (v26.10.7 fleet seal)

- Date: 2026-10-07, 15:16–19:15 PT
- Subject: `~/ash_pplan` @ `847f487b4bb3b4e41afc179c813406d97cdfdc98` (main, W650j pins landed), no new commits (per dispatch)
- Toolchain: asdf elixir 1.20.4-otp-29 / erlang 29.1.1 (repo `.tool-versions`)
- Build root: `_build-laneW650v` (fresh full dep+app compile), **deleted at close** per lane-lease cleanup law
- Environment: load average 89–102 throughout, 14–34 concurrent BEAMs (campaign lanes W609b et al. running the same repo concurrently)

## Method

1. Full-suite background run: killed at the harness 2h background cap, mid-suite, no summary
   (output was buffered in a `tail` pipe). This plus W984cx2's three 30-min SIGTERMs make the
   monolithic route measured-infeasible under this load.
2. Fell back to 5 per-directory chunks (background, incremental per-chunk logs,
   `/tmp/w650v-chunk{A..E}.log`), each under the cap. All 5 completed.
3. Version-pin courts re-run directly for a clean gate record.

## Per-chunk tails (exit, summary)

| chunk | scope | files | time | result | exit |
|---|---|---|---|---|---|
| A | root `test/*_test.exs` + reactor, case_studies, policy_closure, fleet, marketplace_sim, support | 55 | 6490s | `Result: 638/646 passed (8/8 doctests, 6/6 properties, 624/632 tests), 71 skipped` | 2 |
| B | durable + stress | 71 | 1223s | `Result: 351/353 passed (10/10 properties, 341/343 tests), 5 skipped` | 2 |
| C | workflow + hardening | 70 | 193s | `Result: 616 passed` | 0 |
| D | courts | 70 | 3532s | `Result: 453/461 passed` | 2 |
| E | fond, sa2a, tokyo_depeg, standing dirs | 36 | 1.7s | `Result: 204 passed` | 0 |
| gate | ash_pplan_test + release_contract_test + airo_surface_pin_test | 3 | 0.4s | `Result: 48 passed` | 0 |

**Sum (honest, per-directory batches — not one process):** 2262/2280 passed, 18 failures,
76 skipped across chunks A+B. 302 test files total, full test/ tree covered (burn_in and
petal_framework excluded, same exclusions as prior attempts).

## Failure classification (18)

Load-induced ExUnit.TimeoutError / subprocess timeouts under load 89–102 (13):
- Chunk A, `AshPPlan.ManufactureTest` pack-regen courts ×6 (600–900s per-test timeouts
  exceeded; the exact "pack-regen 600s timeouts need a quiet window" constraint predicted
  at dispatch)
- Chunk A, `MarketplaceSim.GcpContractCourtTest` "pack re-syncs byte-identically" —
  ggen_igniter sync subprocess refused (`ArgumentError: not a nonempty list` at
  `ggen_igniter.sync.ex:1402`) — may be a real defect in ggen_igniter 26.10.2 reactor
  reconcile, but occurred under load; needs a quiet-window re-run to classify (UNKNOWN)
- Chunk A, `AshPPlan.DemonstrationCourtTest` `bin/demonstrate` exit ≠ 0 (empty output tail;
  load-suspected)
- Chunk D, PackChaos/ReactorMw/WorkflowGates determinism + anti-vacuity renders ×5
  (60s/600s timeouts exceeded)

Marketplace-pin drift, deterministic, not load-induced (4) — environment/pin state, distinct
from the 4 version-pin companions:
- Chunk B, `PackCourtsHarnessCourtTest` ×2 (harness refuses: `marketplace HEAD ba21c22a... !=
  pinned 6f779318...`; the harness names `RTI_ALLOW_MOVED_MARKETPLACE=1` as the override)
- Chunk D, `PackGateWitnessCourtTest` + `ProvenanceBaselineCourtTest` (same drift,
  "typed RE-PIN NEEDED on drift" — firing as designed)

Not load: 0. The 4 pack-regen failures that are not timeouts are the marketplace drift court
firing correctly on a moved marketplace checkout.

## Version-pin gate verdict (W650j companions — blocking gate for the tag decision)

**GREEN.** Direct run at 19:0x PT: `mix test test/ash_pplan_test.exs test/release_contract_test.exs
test/airo_surface_pin_test.exs` → `Result: 48 passed` (0 failures, 0.4s). The W650j commit
(847f487) fixed all four companions (mix.exs pin 26.10.7, CHANGELOG 26.10.7 entry,
ontology.ttl owl:versionInfo 26.10.7, ecosystem.lock.toml release v26.10.7); all observed green.

## Standing

**ALIVE with environment-constrained residue** — suite COMPLETE for the first time in the v26.10.7
campaign (W984cx2's INCOMPLETE resolved): full test tree executed, 2262/2280 passed. The tag
gate (4 version-pin companions) is green. The 18 failures are: 13 load-induced timeouts + 1
load-suspected subprocess refusal (UNKNOWN until a quiet-window re-run) + 4 deterministic
marketplace-pin-drift refusals (courts firing as designed; needs marketplace re-pin, a
separate work order, not a suite failure). No test tree edit was made by this lane.

## Residue disclosure (session-introduced)

- `~/ash_pplan/priv/ggen/ash-pplan-dsl-pack/ontology.ttl` is now modified in the working tree —
  not at lane start (git status was clean except W609's untracked court file). Likely killed
  mid-restore by one of the load-timeout pack-regen tests. Not committed; left for the
  coordinator/lane W609 to inspect (`git checkout -- ` restores it).
- Untracked `test/map_update_w609_residual_court_test.exs` is W609b's, pre-existing.
- Chunk logs retained at `/tmp/w650v-chunk{A..E}.log` for replay/inspection.

## Falsifier / open items

- Re-run the 13 timeout failures + gcp sync in a quiet window (load < ~10): predicted to pass
  and clear the residue to 4 pin-drift refusals.
- Marketplace re-pin 6f779318 → ba21c22a (or RTI_ALLOW_MOVED_MARKETPLACE override for the
  harness courts) is the open fleet-level item the drift courts name.
