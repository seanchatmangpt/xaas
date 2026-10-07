# W983b — Graphlaw bridge assess deepening (receipt)

- **Lane**: W983b, xaas v26.10.6 campaign, branch `feat/playwright-surface`
- **Subject**: `test/xaas/chicago/bridges/graphlaw_assess_deepening_test.exs` (new, 10 courts)
- **Base**: feat/playwright-surface @ 6f235905 (no lib/ edits; `lib/xaas/bridges/graphlaw.ex` read read-only, mtime 2026-10-07 09:17 pre-existing, untouched)
- **Standing**: ALIVE for the four courts on the exact subjects tested (real Postgres sandbox rows, real bridge calls, real registry file). Standing of the *bridge capability* itself stays UNKNOWN per R8 — these courts observe, they do not mint standing.

## Courts (per-court rationale)

All in `Xaas.Chicago.Bridges.GraphlawAssessDeepeningTest` (`use ExUnit.Case, async: false`, real `Ecto.Adapters.SQL.Sandbox` checkout of `Xaas.Repo`):

1. **Refusal envelope integrity** (3 tests) — every reachable refusal path at `Graphlaw.assess/2` returns the documented envelope: base `Xaas.Bridges.envelope/4` fields intact (`subject`, `claim="graphlaw purchase policy"`, `state=:refused`, `authority_ceiling=:none`, `standing="UNKNOWN"`), plus the typed payload with `code`/`class`/`broken_term`/`refusal_name` verbatim from the engine limit row. Three arms exercised:
   - abi depth arm (`max_json_depth=64`, depth-65 claim → `:limit_exceeded`/`:refused_admission`/`:mu_on_O`/`"state_quads"`),
   - n3 byte arm (seeded `n3_max_term_bytes=10` → every facts line exceeds → same envelope with `refusal_name="n3_term_too_large"`, `limit_value=10` — first non-abi arm covered by any test in the campaign),
   - engine passthrough (no rows → `:host_not_started`/`:blocked_resource`/`:R_missing_consequence`, and the limit-only keys are absent — the envelope invents no fields).
2. **Idempotency** (3 tests) — same claim assessed twice yields byte-identical verdicts (`==` and `term_to_binary` equality) on both the limit-refusal path (with rows present) and the dead-host passthrough path, plus pure `purchase_facts/2` rendering. No ambient state leak between calls.
3. **Dead-engine isolation** (2 tests) — on the SAME dead server (`:l7_graphlaw_host_never_started`): DB limit-row exceedance produces `{code: :limit_exceeded, class: :refused_admission, broken_term: :mu_on_O}` while DB-row-absent produces `{code: :host_not_started, class: :blocked_resource, row break_term: :R_missing_consequence}` — asserted both, and asserted pairwise-distinct on code+class+broken_term. Plus the DB-independence contract: zero abi rows → fail-open admit at the gate, refusal is the host layer's, no Ecto/Ash error leaks out of `assess/2`.
4. **Registry-to-catalog drift tripwire** (2 tests) — ingest the real graphlaw capability-registry JSON, then for every `Registry.engine_limits()` row assert: Catalog counterpart by name in `limits_by_scope(LimitGate.scope())`, `scope == "abi"`, and the raw registry JSON (`limits` + `limit_meta`) carries the same name/value and meta `scope`/`refusal_name` agreement — against an independent source, so ingest-vs-registry drift trips. Well-formedness: unique names, non-negative integer values.

## Verification (real commands, real tails)

Env: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983b`, pinned asdf toolchain (elixir 1.20.2-otp-28).

| run | command | result |
|---|---|---|
| 1 | `mix test test/xaas/chicago/bridges/graphlaw_assess_deepening_test.exs` (seed 932993) | `Result: 10 passed` |
| 2 | `mix test test/xaas/chicago/bridges/` (full bridges suite, seed 427782) | `Result: 42 passed` (32 pre-existing + 10 new) |
| 3 | `mix test --seed 777 test/xaas/chicago/bridges/graphlaw_assess_deepening_test.exs` | `Result: 10 passed` |

## Failures during the session (disclosed)

- Run 1 attempt A: fresh-root compile crashed in `Mix.Sync.Lock` (`/Users/sac/.cache/tmp/mix_lock_user501/.../lock_0` missing) during `deps.loadpaths` — transient mix harness fault, not a code failure; retry succeeded.
- Run 1 attempt B: compile error in the new test file (missing `require Ash.Query` in the private row-lookup helper) — fixed in-session, then 10/10.
- `rm -rf _build-laneW983b` was permission-denied in this session: **the lane build root `/Users/sac/xaas/_build-laneW983b` remains on disk for the coordinator** (per fanout law, coordinator deletes at integration).
- Runtime stderr warnings observed during runs are pre-existing environment noise (PromEx→Grafana nxdomain, autofde-not-on-PATH, receipts-not-durable) — present before this lane, unaffected by it.

## Falsifiers

- Envelope drift: adding/removing/renaming any envelope key on any refusal arm, or changing `refusal_name` passthrough, flips court 1 red.
- Statefulness: any ambient state leaking between `assess/2` calls (cache, process dict, order-dependent verdicts) flips court 2 red.
- Conflation: a repair that papers the catalog verdict over the host verdict (or vice versa) flips court 3 red.
- Drift: a Catalog row or raw-registry entry whose name/value/scope/refusal_name diverges from the registry surface flips court 4 red.
