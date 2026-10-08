# W984le — unclaimed-family probe: priv/packs/xaas_library_pack query surfaces

Lane: W984le · Branch: feat/playwright-surface · NO commit (lane receipt only)
Date: 2026-10-08 · Subject: canonical checkout /Users/sac/xaas @ 86c69061 + lane diff (one new test file)

## Scope

Uncourted surfaces of `priv/packs/xaas_library_pack/` beyond
`templates/manufacture.ex.eex` (already witnessed by W984ju):
`queries/*.rq` (14), `gates/*.rq` (14), `ontology.ttl`.

## Consumer analysis (grep over lib/ + test/, real refs only)

| surface | consumer | disposition |
|---|---|---|
| `gates/*.rq` (all 14) | `GgenIgniter.Pack.discover_queries/1` (`deps/ggen_igniter/lib/ggen_igniter/pack.ex:493`) reads `<pack_dir>/gates/*.rq` as the default `--query` source of `mix ggen_igniter.sync --pack-dir priv/packs/xaas_library_pack` (the regen path pinned in `lib/xaas/generated/regen_check.ex:103`) | LIVE — exercised by the real manufacturing pipeline |
| `queries/001-013.rq` | none. `regen_check.ex` points explicit `--query` flags only at OTHER packs' `queries/` dirs; the library pack regen command is bare `--pack-dir`, which reads gates/ only | INERT duplicate — byte-identical copies of the live gates/ 001-013, no consumer. Typed disposition: stale duplicate directory; content verified live-identical, no lib/ change warranted |
| `queries/014_ranker_factor_weights.rq` | no direct consumer; its SELECT shape is mirrored at runtime by `Xaas.Library.Config.ontology_weights/0` (`lib/xaas/library/config.ex` regex parser over the same ontology.ttl) | LIVE (by-mirror) — courted directly |
| `gates/014_ranker_factor_weights.rq` | same gates/ discovery path; deliberately diverges from queries/014 (NOT EXISTS complement gate, commented gate contract) | LIVE — courted, with mutation testing. **Finding below.** |
| `ontology.ttl` | `Xaas.Library.Config.ontology_weights/0` (runtime read), ggen_igniter sync | LIVE |

## Court

`test/xaas/generation/pack_queries_court_w984le_test.exs` — 8 tests, all green.

Chicago-school: real Turtle parse (`RDF.Turtle.read_file!/1`) of the real
ontology.ttl, real SPARQL execution through `GgenIgniter.Query.run/2` (the exact
engine ggen_igniter uses at manufacturing time) and
`GgenIgniter.Query.Oxigraph.run/2`, real discovery via
`GgenIgniter.Pack.discover_queries/1`, real runtime consumer
`Xaas.Library.Config.ontology_weights/0`. Zero mocks; mock gate returned `[]`.

Coverage: discovery count/stems (14); domain rows 001/012 incl. FILTER
(adminShow=true); class grounding 002-004 (one row each through real
rdfs:subClassOf chains to bibo/schema/prov); resource mappings 005-007 (real
column strings isbn/author/genres/grade_level/available_copies etc.);
codegen pipeline 008-010 (6 base + 5 core = 11 targets, real mixTask strings);
inventory 011 (5 resources), relational integrity 013 (Checkout/Curation/Book
join on book_id); 014 tripartite agreement (runtime regex parser == 6 weights ==
SELECT rows == empty complement gate); byte-parity drift guard queries/ vs
gates/ for 001-013, documented divergence for 014.

## Mutation testing (C05) + engine finding

Real in-memory graph surgery (delete the `xl:weight` triple of
`xl:Factor_Collab`, keep type/identifier): queries/014 SELECT drops 6→5 rows
under both engines — non-vacuous. The gates/014 complement gate FIRES
(`Factor_Collab` row) under oxigraph.

**W984le finding (typed)**: under ggen_igniter's DEFAULT `--engine sparql`,
the same gate returns `[]` on the mutated graph — `FILTER ( NOT EXISTS {..}
|| NOT EXISTS {..} )` silently evaluates false. gates/014 is therefore a
FALSE-NEGATIVE GATE under the default engine: it can never fail, so as a gate
it carries zero bits unless the regen command pins `--engine oxigraph`. Same
limitation class as the ORDER BY defect already disclosed in
`GgenIgniter.Query`'s moduledoc. A regression trip-wire assertion is
committed in test 7: if the sparql lib gains `||`-joined NOT EXISTS, that
assertion fails and flags the limitation as fixed. Owner decision (not made
by this lane): either pin `--engine oxigraph` for library-pack sync or
rewrite gates/014 to a shape the default engine honors.

## Gates (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984le \
  mix test test/xaas/generation/pack_queries_court_w984le_test.exs
→ Result: 8 passed, 0 failed, exit 0

mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
→ []
```

## Dispositions ledger

- gates/001-013: LIVE (real consumer path), executed + asserted — fully covered.
- gates/014: LIVE logic, SPEC-CONFORMANT only under oxigraph; typed finding above.
- queries/001-013: INERT (stale byte-identical duplicates, no consumer). No change.
- queries/014: LIVE by runtime mirror (Config.ontology_weights/0), executed + asserted.
- templates/manufacture.ex.eex: covered by prior W984ju court (out of scope).

No lib/ changes. One file added:
`test/xaas/generation/pack_queries_court_w984le_test.exs`. No commit.

## Lane cleanup

`rm -rf _build-laneW984le` executed, exit 0, directory confirmed absent.
