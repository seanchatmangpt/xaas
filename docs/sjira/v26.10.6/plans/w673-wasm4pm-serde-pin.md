# W673 — wasm4pm eu_gate serde surface pin

**Standing**: ALIVE (lane-scoped). **Subject**: xaas @ a0723bf6 (feat/playwright-surface), new file `test/xaas/wasm4pm_serde_surface_pin_test.exs`; sibling subject wasm4pm @ `32deb59f6e40cbf6812f2a9581e545c92b60d1ae` (working tree — note: `crates/eu_gate/` is **untracked** in wasm4pm, never committed upstream; pin reads the real files on disk).

## Defect class

W509→W652: `test/eu_ai_act/title_iv_v_test.exs` asserted crate **source literals** (`"ADMITTED"`, `"REFUSED_*"`); the wasm4pm serde `rename_all = "SCREAMING_SNAKE_CASE"` refactor removed the literals and broke the assertion. W652 repaired the consumer to attribute-level asserts. W673 adds a durable **contract pin** so the next serde move fails here, typed, naming the consumer.

## Pin list + provenance (which xaas assertion depends on which name)

| pinned surface (eu_gate source) | consuming xaas assertion |
|---|---|
| `Verdict`: `tag = "verdict"`, `rename_all = "SCREAMING_SNAKE_CASE"`, variants `Admitted`/`Refused` | title_iv_v binary-out asserts `{"verdict":"ADMITTED"}` and `REFUSED_REQUIRED_FIELD_MISSING` |
| `RefusalCode`: all 5 `REFUSED_*` codes (as_str/1 + serde enum) | title_iv_v refusal-vocabulary asserts; receipt `w509-wasi-gate.md` test-count pins |
| `Rule`: `tag = "type"`, `rename_all = "snake_case"`, payloads `field: String`, `values: Vec<Value>`, `min/max: f64`; `RuleSet.rules` | title_iv_v writes rules JSON `{"rules":[{"type":"required","field":"id"}]}` via `System.cmd/3` |
| `main.rs`: `evaluate_checked` entry + fail-closed stdout fallback `{"verdict":"REFUSED","code":"REFUSED_INFRASTRUCTURE_FAULT"}` | title_iv_v CLI contract (exit 0, stdout verdict); title_ii `@wasi_crate` path pin; title_iii Art. 55.1.d evidenced path |
| `rename_all = "SCREAMING_SNAKE_CASE"` lockstep | title_iv_v:~180 W652 attribute-level asserts (`~s(rename_all = ...)`, `pub enum Verdict`) |

Failures carry typed codes (`WASM4PM_SERDE_SURFACE_DRIFT`, `WASM4PM_REFUSAL_CODE_DRIFT`, `WASM4PM_RULES_CONTRACT_DRIFT`, `WASM4PM_CLI_CONTRACT_DRIFT`, `WASM4PM_EU_GATE_MISSING`) and name the consuming test file.

## Falsifier

`crates/eu_gate/src/lib.rs` renamed a field/variant → pin test fails with typed message.

## Receipt (real run)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW673 \
  mix test test/xaas/wasm4pm_serde_surface_pin_test.exs --include eu_ai_act
...
Result: 5 passed, 0 failed
```

(First run: 4/5 — the main.rs fallback literal needed a raw `~S` sigil; fixed forward, rerun green. Pre-existing, unrelated: `robust_margin.ex:102` compile warning, Grafana nxdomain warnings.)

`@moduletag :eu_ai_act` is load-bearing: the pinned surface IS the Art. 55.1.d cybersecurity-gate evidence (corpus 55.1.d EVIDENCED entry cites `/Users/sac/wasm4pm/crates/eu_gate` + `w509-wasi-gate.md`).

Chicago: real `File.read!/1` content asserts only, no mocks, no source-literal-vs-attribute confusion (attributes + wire strings both pinned, each cited to its consumer).

## Boundary

- No commit made; `git status` left as coordinator owns transitions.
- `rm -rf _build-laneW673` denied by permission system — **build dir left for coordinator** (`/Users/sac/xaas/_build-laneW673`).
- wasm4pm tree dirty (package.json churn) but `eu_gate` source files themselves untracked/clean.
