# W682 — ash_pplan AIRo pin (receipt)

- **Subject**: /Users/sac/ash_pplan, branch `fix/ggen-verify-header`,
  HEAD `7eeaaa16bd9f8e76170c90617bcceef7b852d410`. Not committed, no branch
  switch. Pre-existing dirty state: `M docs/demonstration.md`,
  `?? docs/sjira/v26.10.6/` (other lanes).
- **Task**: pin test for the ash_pplan AIRo surface per the AIRo wiring
  ledger claim (sibling of w675/w677/w678/w681).

## Per-claim verification

| claim | observation | verdict |
|---|---|---|
| Ledger covers ash_pplan | `grep -i pplan docs/cro/artifacts/airo-wiring-ledger.md` → exit 1, zero matches (both committed and working-tree versions) | **DRIFT: no ledger row exists for ash_pplan.** The ledger's coverage statement ("14 repos... all receipts landed") omits it |
| AIRo surface exists | `priv/airo_risk_description.ttl` (11,609 B, sha256 `5d28a105…31d3c`) + `test/airo_risk_description_test.exs` (W635 court), both **committed at HEAD 7eeaaa1** ("v26.10.6: OS-20 dual-safe Map.update + AIRo risk descriptions + wave fixes") | CONFIRMED — surface is real, committed, and self-consistent |
| Vocabulary pin | TTL header cites AIRo 1.0 sha256 `6274d2d8…d8469`, byte-identical to the ledger's cross-repo pin | CONFIRMED |
| W635 court | 4-test ExUnit court on disk, asserts structure + 18 VIA-cited paths | CONFIRMED on disk |
| W682 pin test | New file `test/airo_surface_pin_test.exs` — 6 tests: pinned sha256+byte size, vocab pin in header, court file exists, AISystem/Hazard(≥3)/RiskControl(≥5)/Risk structure, 18 cited paths on disk, 8 cited modules loadable via `Code.ensure_loaded/1` | EXECUTED, see below |

**Standing: PARTIAL_ALIVE.** Surface + court are real and pinned at the exact
HEAD; the ledger row is the missing edge (W635 authored the surface but its
lane receipt/ledger row never landed — coordinator should add an ash_pplan row
to docs/cro/artifacts/airo-wiring-ledger.md, e.g. `w635 | ash_pplan |
priv/airo_risk_description.ttl (11,609 B) | 4-test court + 6-test W682 pin |
4 + 6 passed | plans/w635-*.md / plans/w682-ash-pplan-airo-pin.md`).

## Executed verification (real output)

```
$ cd /Users/sac/ash_pplan
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW682 \
    mix test test/airo_surface_pin_test.exs
Compiling 264 files (.ex)          # ash_pplan, cold lane build root
Generated ash_pplan app
Running ExUnit with seed: 470896, max_cases: 32
......
Finished in 0.09 seconds (0.09s async, 0.00s sync)
Result: 6 passed                          # exit 0
```

The W635 court file was not re-run (it is committed and unchanged at this
HEAD; the pin test asserts its existence and content-shape). No other suites
run — W658e is running suites on this tree; only the new file was executed.

## Before/after

- Before: no ash_pplan ledger row; surface existed committed but unpinned by
  the pin-series convention.
- After: `test/airo_surface_pin_test.exs` (uncommitted, new) pins ttl sha256,
  byte size, vocab pin, AIRo structure, 18 cited paths, 8 loadable modules.
  6/6 passed, exit 0.

## Leases / carry-forwards

- `_build-laneW682` deletion was **denied by the permission system**; the
  lease remains at /Users/sac/ash_pplan/_build-laneW682 — coordinator deletes
  at integration per the cleanup law.
- Nothing committed in ash_pplan; coordinator owns the commit.
