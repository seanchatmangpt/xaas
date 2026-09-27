# Qualification — ultracode-self-digest-pack

Acceptance = the generated Chicago court, run on REAL Postgres against the
REAL generated resources:

```
MIX_BUILD_ROOT=_build-int MIX_ENV=test mix ecto.migrate --quiet
MIX_BUILD_ROOT=_build-int MIX_ENV=test mix test \
  test/xaas/ultracode/capital_census/self_digest_chicago_test.exs
# observed 2026-09-27: 7 passed, 0 failed
```

## Falsifier corpus (each is witnessed by a named test)

| # | falsifier | witness |
|---|---|---|
| 1 | 3 same-topology episodes MUST cluster, classify (`{:hypothesis, :runtime, :otp_ash_reactor}`), and admit a REAL WorkOrder through the full chain Episode → ExperienceCluster → Gap → WorkOrder | `3 same-topology episodes cluster, classify and admit a real WorkOrder` |
| 2 | differing topology MUST NOT cluster — {2 same, 1 different} gives count=2, `recurring? == false`, refusal `:below_threshold` | `differing topology MUST NOT cluster` |
| 3 | 2 episodes MUST NOT create recurrence at the ontology threshold (3) | `2 episodes MUST NOT create recurrence` |
| 4 | a residual shape the ontology does not classify MUST refuse `{:unknown, nil, nil}` — unknown never guesses | `unknown residual shape refuses classification` |
| 5 | missing falsifier or missing/empty provenance receipt MUST refuse self-work orders | `missing falsifier or provenance receipt refuses` |
| 6 | an unclassified class name MUST be refused by the GENERATED enum type (`Ash.Error.Invalid` naming the bad atom) | `unclassified class names are refused` |

## Anti-vacuity

* Threshold mutation: setting threshold 2 in the ontology would flip test 3
  (the {1,2},{3} negative) — the corpus dies if the law is weakened.
* Regeneration court: re-run
  `mix xaas.ash.gen --ontology priv/ggen/ultracode-self-digest-pack/ontology.ttl --yes`
  and the facts `ggen_igniter.sync` line from the pack README, then
  `git diff --exit-code` — byte-identity or the court fails. Hand-edits to
  generated files are caught by this court, not by review.

## Standing (2026-09-27, this pack's authoring increment)

* `ontology.ttl` — real, loads via `GgenIgniter.Ontology.load!` (oxigraph).
* 7 `queries/*.rq` — all run for real during manufacture (20 rows total
  rendered into `Facts`; the bridge consumed enums/attributes/relationships rows).
* Bridge + render — ALIVE: 6 enums + 5 Ash resources + domain registration
  manufactured by Ash's own `ash.gen.enum` / `ash.gen.resource` / `ash.extend`
  generators; `Facts` rendered by `ggen_igniter.sync` through the real
  ReconcileReactor (wrote + verified).
* Chicago court — ALIVE: 7/7 on real Postgres (`xaas_test`), 107/107 with the
  census + wave-loop regression suites.
* Regeneration court — ALIVE: post-commit re-render produced zero diff.

## Known residuals (honest, typed)

* The verify gate of `ggen_igniter.sync` runs `mix compile --warnings-as-errors`;
  xaas fails it today because hex `ex4pm 26.9.9` warns from its `mix.exs` on
  every Mix start (`Application.get_env/2 discouraged`). The Facts render
  succeeded ONLY after patching the checked-out `deps/ex4pm/mix.exs` locally
  (transient, `Application.compile_env`). Upstream fix + hex publish of
  ex4pm 26.9.10 is the permanent guard (operator-gated publish).
* `ash.codegen` also swept an unrelated pending codegen
  (`billing_revenue_recognitions`) into the migration; that block was stripped
  per `xaas.safe_generate_migrations` doctrine and the snapshot removed — the
  billing resource's owner must regenerate.
* `mix ash.codegen` needs `config :ash_typescript, manifest: Xaas.AshTypescriptManifest`
  (ash_typescript 0.18 drift); the manifest module is ledgered handwritten glue.
