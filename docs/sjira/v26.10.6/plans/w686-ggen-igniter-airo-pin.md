# W686 — ggen_igniter AIRo wiring pin

Lane: W686 (xaas v26.10.6 campaign) · Date: 2026-10-07 · Status: DONE — ALIVE

## Subject

- Repo: `/Users/sac/ggen_igniter` (canonical checkout, no worktree)
- Branch: `feat/adr-0010-gate-convention`
- HEAD: `b78a73e9ae65c4435f06a81c3276147c17018f44`
- Tree: dirty from other lanes (pre-existing; none of my files). My diff: new file
  `test/airo_wiring_pin_w686_test.exs` only. No commit made (per dispatch).

## Per-claim verification (ledger row, airo-wiring-ledger.md:33)

| Ledger claim | Verified | Evidence |
|---|---|---|
| `priv/airo_risk_description.ttl` (10,296 B) | CONFIRMED | `wc -c` = 10296; sha256 `81ddec22d581411d47e2d72d3a8802671376e3efbeb1866cad1945ca1366e3cf` pinned in test |
| 4-test court exists | CONFIRMED | `test/airo_risk_description_test.exs` — exactly 4 `test` blocks (W618) |
| "every airo: term from fetched vocab" | CONFIRMED | 27 distinct `airo:` terms, all in AIRo 1.0 set, asserted programmatically |
| "cited paths asserted" | CONFIRMED | VIA-cited paths incl. `priv/ggen/ash-manufacture-pack/{ontology.ttl,gates,bin,verify}`, `scripts/forbid_generated_output_dir_once.py`, `lib/ggen_igniter/verify_mutation.ex` — all exist on disk |
| "4 passed" | CONFIRMED (re-run) | W618 suite re-run alongside W686: 8 tests, 0 failures |

## New pin test (W686)

`/Users/sac/ggen_igniter/test/airo_wiring_pin_w686_test.exs` — 4 tests, no mocks,
real file reads:

1. byte pin: exact sha256 + 10,296 B for the TTL
2. vocabulary pin: every `airo:` term ∈ AIRo 1.0 vocab (≥20 distinct terms)
3. W618 structural re-assertions (prefixes, AISystem, hasRisk, hasResidualRisk, dcterms:description)
4. all 15 cited repo paths exist on disk

## Run (real output)

```
export PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW686
mix test test/airo_wiring_pin_w686_test.exs test/airo_risk_description_test.exs
→ Finished in 0.09 seconds (0.09s async, 0.00s sync)
8 tests, 0 failures
```

Pre-existing unrelated failures: not observed in this run (only the two targeted
files were run). Full-suite run not performed (lane scope; dirty tree from other lanes).

## Before/after

- Before: W618 court only; ledger row asserted but unpinned to exact bytes.
- After: byte-level sha256 + size + vocabulary + path pin; TTL drift now fails CI in-repo.

## Standing

ALIVE — observed execution on exact subject (branch `feat/adr-0010-gate-convention`,
HEAD `b78a73e9`). Falsifier (replay): `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW686 mix test test/airo_wiring_pin_w686_test.exs` in `/Users/sac/ggen_igniter`.

## Cleanup

`_build-laneW686` deletion was denied by the permission system in this session — the
directory remains on disk for the coordinator to delete at integration (lane-lease law).
No other tree changes.
