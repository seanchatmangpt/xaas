# W618 — ggen_igniter AIRo risk description

Lane W618, AIRo wiring wave. Subject repo: `/Users/sac/ggen_igniter` (canonical checkout,
nothing committed — lane writes only its contract files).

## Files (lane-owned)

- `/Users/sac/ggen_igniter/priv/airo_risk_description.ttl` — new
- `/Users/sac/ggen_igniter/test/airo_risk_description_test.exs` — new (structural court)

## AIRo reference

`https://raw.githubusercontent.com/DelaramGlp/airo/main/airo.ttl` (AIRo 1.0, fetched
2026-10-06; 974 lines; terms verified against the fetched file, not memory).

## Mapping

| AIRo term | Subject |
|---|---|
| `airo:AISystem` | `w618:AshManufactureIgniter` — the Ash-manufacture igniter (pack + gates + suite as `airo:AIComponent`s) |
| `airo:Hazard` x3 | RS-1 generated-code shadowing (W230/W531-era fixtureOnly receipts; guard `scripts/forbid_generated_output_dir_once.py`); RS-2 consumer-installer emission (OS-13/W355; e2e installer test); RS-3 hex-pin staleness (OS-4; drift gate) |
| `airo:Risk` / `Consequence` / `Impact` | wrong-projection risk -> three consequences -> consumer-correctness impact on the consumer-repo developer stakeholder |
| `airo:Likelihood`/`Severity` | honest qualitative Medium/Medium |
| `airo:RiskControl` x5 | pack `gates/` (13 staged .rq gates 010..092), pack `bin/` gates (citation_check/drift_check/evidence_check/conformance/qualify/receipt), `verify/` contracts (cardinality.json + unbound.rq, mutation-tested by `lib/ggen_igniter/verify_mutation.ex`), ExUnit suite (306 `*_test.exs` files, counted on disk), anchor-repoint verification via citation_check.py |

All cited paths asserted to exist on disk by the test (`@cited_paths`).

## Check run (real output)

```
$ cd /Users/sac/ggen_igniter && PATH=$HOME/.asdf/shims:$PATH mix test test/airo_risk_description_test.exs
Finished in 0.05 seconds (0.05s async, 0.00s sync)
4 tests, 0 failures
```

Court asserts: file exists/non-empty, prefixes declared, no typo-prefixed predicates,
every `airo:` term drawn from the fetched AIRo 1.0 vocabulary, >=3 Hazards and >=4
RiskControls present, and every VIA-cited repo path exists.

Standing: ALIVE (test executed on the exact working-tree subject in
`/Users/sac/ggen_igniter`; nothing committed per lane contract).
