# W984cv — SparqlBridge depth court receipt

Lane: W984cv, xaas v26.10.6 campaign, branch `feat/playwright-surface` (HEAD at
lane start: cf228da6).
Scope held: one test file under `test/xaas/` + this receipt. No `lib/` edits, no
commits. Lane build root `_build-laneW984cv` deleted at integration.

## Module surface analysis

`lib/xaas/sparql_bridge.ex` — `Xaas.SparqlBridge` (lives at `lib/xaas/`, not in
`lib/xaas/bridges/`; the prompt's `pplan.ex` hint was sibling-pattern only).
7 public functions:

- `to_turtle/0` — `Ash.read` on all five resources
  (AutofdePlannerCandidate / Catalog / Match / CacheHotset / CacheStats), joins
  one individual per row into a single Turtle document with `aacm:` + `xsd:`
  prefixes.
- `to_turtle/1` (candidate rows list) — candidate-only document, same header.
- `catalog_to_turtle/0`, `match_to_turtle/0`, `cache_hotset_to_turtle/0`,
  `cache_stats_to_turtle/0` — per-class documents via `turtle_document/1`.
- `write_turtle/1` — file sink, default `priv/autofde_monitor.ttl`.

MAPE-K Monitor seam: `mix xaas.close_coverage_gap` (lib/mix/tasks/
xaas.close_coverage_gap.ex) — Monitor = `to_turtle/0` → tmp .ttl → python3+rdflib
SPARQL COUNT-by-class subprocess → least-exercised class → Ash create actuated
under `Xaas.SystemAuthority.new(:autofde_coverage_monitor)` → re-project for
before/after counts. The court exercises the Monitor's projection→file→parse path
end-to-end; the python3/rdflib subprocess leg is out of lane scope (that court
belongs to the mix-task lane).

## Tests landed

`test/xaas/sparql_bridge_court_test.exs` — 5 tests, Chicago style, async: false,
real Postgres rows via `Ecto.Adapters.SQL.Sandbox` (direct `Repo.insert!` of real
structs — the resources' only create actions call the cnv-deploy HTTP surface, so
direct row insertion is the real-substrate route, not a mock):

1. Well-formed projection across all five classes: emitted document parses with
   the repo's real RDF.ex Turtle parser; one typed subject per class; candidate
   carries `aacm:query` / `trajectorySha256` / `solver` / `domain` / `requestedAt`
   copied verbatim (solver/domain extracted from a noisy-stdout `cnv_response`
   via the real last-JSON-object rule).
2. Determinism: two independent projections (`to_turtle/0` ×2 fresh roots) are
   byte-identical.
3. Empty tables: still valid Turtle, zero triples, both prefix declarations
   present — the Monitor can report an empty K graph without crashing.
4. Malformed `cnv_response` (noise-without-JSON-tail stdout, and nil response):
   typed degradation — solver/domain triples omitted, query triple preserved,
   document still parses; 2 typed candidates, 0 solver/domain triples, no crash.
5. Round-trip through `write_turtle/1` to a real tmp file, parsed back with
   RDF.ex: one typed subject per real row, correct per-class counts. This is the
   exact Monitor seam (projection → disk → parser).

Mutation rationale per test (what each kills): (1) kills subject-class misbinding
and column-to-predicate drift; (2) kills hidden nondeterminism (map iteration,
timestamps injected at render time); (3) kills a header/body join crash or prefix
loss on empty state; (4) kills an `extract_solver_and_domain` regression to
FunctionClauseError on malformed payloads, and predicate-noise regressions; (5)
kills a `write_turtle` path/encoding regression and subject-IRI drift
(`Class_#{id}` naming).

## Standing: ALIVE (lane-scoped)

Verification ladder — real commands, real output:

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984cv
  mix test test/xaas/sparql_bridge SparqlBridgeCourtTest...` (exact invocation:
  `mix test test/xaas/sparql_bridge_court_test.exs`) → `5 passed` (run 1, after
  two repair iterations: ecto datetime precision, RDF 3.0 API surface —
  `RDF.Statistics` absent, `RDF.Description.first/3` clause set).
- ×2 fresh-root determinism re-run → `5 passed` again (0.4s).
- Mock gate: `scan_mock_usage(["test/xaas/sparql_bridge_court_test.exs"])` → `[]`.

Transport failures disclosed: first full-lane compile took >10 min under heavy
concurrent lane-build contention (multiple `mix compile --force` beams observed);
compile only, no test-state corruption (pinned asdf toolchain used throughout).

Falsifier for this court: reverting any single bridge render clause (e.g.
`render_individual/2` nil-filter, `turtle_maybe_datetime/1`) must fail at least
one of the 5 tests.

Not done (out of lane scope): python3/rdflib subprocess leg of
`mix xaas.close_coverage_gap`; `to_turtle(nil)` untyped-seam hazard noted
(FunctionClauseError by contract) but not changed — no `lib/` edits allowed.
