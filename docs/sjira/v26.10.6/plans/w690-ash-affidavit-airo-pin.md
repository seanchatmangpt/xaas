# W690 — ash_affidavit AIRo pin (ledger-consistent)

**Repo**: `/Users/sac/ash_affidavit` — branch `feat/signing-surface`, HEAD `8d90cc62716d12b12ec01253b3445131f8597acf`. Not committed (per lane contract). Build root `_build-laneW690` deleted after run.

**Ledger row (airo-wiring-ledger.md, w637)**: `ontology/airo_risk_description.ttl` (12,084 B), 4-test ExUnit court, path-exists assertions, AIRo-1.0 vocab per w600 pin, 4 passed.

## Per-claim verification

| Ledger claim | Observed on disk at 8d90cc62 | Verdict |
|---|---|---|
| TTL exists | `ontology/airo_risk_description.ttl` exists | CONSISTENT |
| 12,084 B | `wc -c` = 12084; byte_size pin in new test | CONSISTENT (exact) |
| 4-test court | `test/airo_risk_description_test.exs` — exactly 4 tests, all structural/real-file | CONSISTENT |
| Path-exists assertions | 13 cited paths in `@cited_paths`, existence asserted | CONSISTENT |
| AIRo 1.0 vocab (w600 pin) | all `airo:` terms within the known set | CONSISTENT |

Additional identity pins established this lane:

- **SHA-256 of TTL**: `71d4f706f5134fe5f572eb091e7fed00ba99539150911fba78f0ebb92ce79638` (now pinned in test).
- Every VIA-cited `lib/` path resolves to a **loadable module** (`Code.ensure_loaded/1`): EngineLoad, WasmConfig, **ABI** (not `Abi` — real module name discovered; `abi.ex` defines `AshAffidavit.ABI`), Ops, Signing, Signing.Keys, Refusal.
- Lane provenance in TTL header (`lane W637, AIRo wiring wave`, `w637:` namespace) pinned.

## Test file

`/Users/sac/ash_affidavit/test/airo_w690_pin_test.exs` (new, only file written in repo). 4 tests:
sha256+byte-size identity pin; VIA→loadable-module resolution; AIRo 1.0 vocab parity; drift tripwire (provenance header + subject + court delegation).

## Execution (real output)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW690 \
  mix test test/airo_w690_pin_test.exs
Excluding tags: [:pack_root, :ext_pack]
....
Finished in 0.03 seconds (0.03s async, 0.00s sync)
Result: 4 passed

$ mix test test/airo_risk_description_test.exs   # pre-existing w637 court
....
Result: 4 passed
```

First run failed 2/4: (1) `AshAffidavit.Abi` does not exist — real module is `AshAffidavit.ABI` (beam loader: `module name in object code is 'Elixir.AshAffidavit.ABI'`); (2) TTL contains no literal `ontology/airo_risk_description.ttl` string — VIA existence is delegated to the w637 court in prose, not the TTL body. Both fixed as pins, not assumptions.

Pre-existing unrelated failures: none observed in the two targeted runs; full suite not run (dirty tree from other lanes).

## Standing

**ALIVE** — ledger row w637/ash_affidavit verified CONSISTENT and hardened with identity pins (sha256 + byte + module-resolution) at exact HEAD `8d90cc62`. Uncommitted by contract; file left on disk for coordinator integration.
