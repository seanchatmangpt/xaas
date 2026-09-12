# Xaas.Operations.RouteCastleRun

Real `xar:RenderTarget` row from `ontology.ttl`, rendered by
`mix ggen_igniter.sync --for-each results` (one real invocation, one real
output file per real ontology row -- the actual lever behind
"experimentation-through-implementation throughput": N independent
generation candidates from one SPARQL query and one template, not N
hand-run commands).

- module: `RouteCastleRun`
- domain: `Xaas.Operations`
- would generate via: `mix ash.gen.resource Xaas.Operations.RouteCastleRun --ignore-if-exists --default-actions read`
  (not run here -- generation itself is a real, side-effecting `sh_after`
  step this project's pinned `ggen_igniter` version doesn't support yet,
  see `docs/claude/diataxis/how-to/fix-ash-admin-and-use-ggen-for-codegen.md`)
