# W984cy — r2rml/VKG surface probe receipt

Lane: W984cy · repo `/Users/sac/xaas` · branch `feat/playwright-surface` · head at probe `cf228da6` · 2026-10-07 · no commit (per dispatch)

## Task

Probe the r2rml/VKG surface flagged in W610 pack work and W984bj's `vkg.ex graphql/2`
note: is `Xaas.Semantics.VKG.graphql/2` courted? If genuinely uncourted, write 4-5
Chicago tests; if covered/unsuitable, typed disposition. Also check ash_r2rml pack
consumer contract (live references in priv/ + lib/).

## Module surface analysis

`lib/xaas/semantics/vkg.ex` — `Xaas.Semantics.VKG` is the XaaS consumer facade over
AshR2RML's VKG runtime (`alias AshR2RML.VKG, as: Runtime`,
`AshR2RML.VKG.Consumer.{Engineering, GraphQL}`). Surface:

- `observe/2` — admit + execute one bounded read-only VKG query → `Witness`
- `observe_all/1` — one bounded query across all admitted catalog sources
- `engineering/1` — witness → engineering read-model snapshot
- `graphql/2` — witness → read-only GraphQL connection via
  `AshR2RML.VKG.Consumer.GraphQL.connection/2`
- `catalog/1` / `catalog_snapshot/1` — canonical catalog + inspection snapshot
- `encode_witness!/1`, `verify/1` — canonical serializer + replay boundary check

The moduledoc declares the invariant set: never mutates a source, never grants
authority (`authority == :NONE`), never reconstructs AshR2RML semantics locally.

**graphql/2**: a pure projection — takes an observed `Witness`, delegates to the
canonical AshR2RML GraphQL consumer, returns a connection map
(`authority`/`receiptId`/`edges` with `node`/`provenance`/`cursor`). No write path
exists anywhere in the module: all runtime calls are `Runtime.query/2` and
`Runtime.catalog/1`; there is no mutation entry point to project.

## Standing determination: COVERED (not uncourted)

`graphql/2` has a real Chicago court:
`test/xaas/semantics/vkg/integration_test.exs`, test
"GraphQL projection preserves provenance and remains read-only" (lines 55-84):

- Real observation through `VKG.observe/2` with the real test engine
  (`Xaas.Test.VKGObservationEngine`) — no mocks (Chicago-compliant).
- Asserts output shape: `authority == "NONE"`, `receiptId == witness.receipt_id`,
  edges carry `node`/`provenance`/`cursor`, provenance `contract_id`, 64-char
  `source_sha256`.
- Read-only property asserted via `authority == "NONE"` and provenance binding.

Surrounding VKG/R2RML courts found:

- `test/xaas/semantics/vkg/integration_test.exs` — catalog consumption, full
  observe→witness→engineering closure, unknown-source refusal.
- `test/xaas/semantics/vkg/query_test.exs`, `vkg/workspace_test.exs`,
  `vkg/replay_test.exs` — sub-boundary courts.
- `test/xaas/semantics/vkg_refusal_negative_test.exs`,
  `vkg_registry_nonempty_contract_test.exs`.
- `test/xaas/semantics/ash_r2rml_test.exs` + `r2rml_refusal_test.exs` — the
  `Xaas.Semantics.R2RML` mapping/SPARQL facade and its typed refusals.

## Census receipt (real run)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984cy \
  mix test test/xaas/semantics/vkg/integration_test.exs \
           test/xaas/semantics/ash_r2rml_test.exs \
           test/xaas/semantics/r2rml_refusal_test.exs \
           test/xaas/semantics/vkg_refusal_negative_test.exs
→ Result: 9 passed, 0 failures, exit 0  (fresh lane build root, full compile)
```

Falsifier considered: had `graphql/2` been absent from every test file, new courts
would have been written. It is exercised with a real engine; no new tests were
needed, so none were added (novelty minimal).

## Pack consumer contract

ash_r2rml is consumed live, not as a priv/packs template pack:

- `mix.exs:120-124` — git dep pinned `ref: 0d5320f6c5e9a43bb3e8dcb0f30d301b1ebb64d7`, override.
- `lib/xaas/semantics/r2rml.ex` — `Xaas.Semantics.R2RML` facade (mapping compile,
  Turtle render, SPARQL explore/observe) delegating to `AshR2RML.*`.
- `lib/xaas/resource.ex:38-63` — `r2rml_mapping/0`, `r2rml_mapping!/0`,
  `r2rml_mapping_hash/0` extension on every Xaas resource.
- `lib/xaas/castle.ex:107-123` + `lib/xaas/generated/castle_bridge_contract.ex:8` —
  `ash_r2rml_sha` "067954ad406fd637fd47646bdb10c4580809c79d" identity pin.
- `lib/xaas_web/plugs/ontop_proxy_plug.ex` + `lib/xaas_web/router.ex:260` — live
  Ontop VKG HTTP surface (prototype per
  `docs/claude/diataxis/explanation/r2rml-ontop-prototype.md`).
- `priv/ontop/xaas-mapping.ttl` / `xaas-mapping.generated.ttl` — R2RML mapping
  artifacts (one generated).
- No `r2rml` entry in `priv/packs/` — pack-name-based selection does not apply;
  the git dep + facade IS the consumer contract.

## Disposition

`PARTIAL_ALIVE → ALIVE for the graphql/2 question`: the surface flagged in W984bj
is covered by a real Chicago court and the whole VKG/R2RML boundary passes its
census (9/9, exit 0). No new tests warranted. Standing: COVERED / census ALIVE at
`cf228da6` + ash_r2rml `0d5320f6`.

## Transport failure

Lane build root `_build-laneW984cy` deletion was refused by the permission system
(`rm -rf` denied); the directory remains on disk as an orphaned lane lease. Cleanup
required by coordinator or via a permitted deletion path (osx-clnr plan/execute).
