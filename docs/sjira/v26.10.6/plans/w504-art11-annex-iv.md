# W504 — Art. 11 Annex-IV functorial technical documentation generator

Lane W504, 2026-10-06. Subject: /Users/sac/xaas @ `feat/playwright-surface` (canonical checkout,
lane build root `_build-laneW504`). Contract files:

- `lib/mix/tasks/xaas.eu_ai_act_annex_iv.ex` — `mix xaas.eu_ai_act_annex_iv --out <path>`
- `test/mix/tasks/xaas_eu_ai_act_annex_iv_test.exs`
- this receipt

## Design (Definition 4.1: D: Ont → Doc)

The task projects the REAL capability surface into an Annex-IV-shaped JSON document. It reads
at run time (never invents):

| Annex IV section | Real source (read at generation time) |
|---|---|
| (a) identity | `VERSION`; `priv/ash_surface/surface_contract.json` (`generatorIdentity` `ash_surface:v26.10.6`, `marketplaceIdentity` `ggen-marketplace:v26.10.6`, digests) |
| (b) capabilities | `priv/ash_surface/surface_contract.json` — 410 entrypoints over 60+ resources, grouped per resource, action-type frequencies |
| (c) human oversight | anchors in `lib/xaas_web/plugs/require_internal_api_token.ex`, `lib/xaas_web/router.ex`, `lib/xaas/actuation.ex`, `lib/xaas/castle.ex` (`REFUSED_CASTLE_AUTHORITY_NOT_ALLOWED`, `REFUSED_XAAS_PROJECTION_DRIFT`), `lib/xaas/witness/catalog.ex`, `config/config.exs` |
| (d) logging | `lib/xaas/telemetry/ocel_ndjson.ex`, castle checkpoint digest/evidence-path gates, `lib/xaas/witness/{audit_chain,certified_receipt}.ex`, `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json` |
| (e) accuracy/robustness | `docs/sjira/v26.10.6/_CLOSURE_PLAN.md` (62/62 refusal-token corpus), A2A v1 protocol/SSE courts, plug court, `docs/cro/artifacts/bias-awareness-measures-v26.10.6.md` |

Plus `coverage_map_rows`: Art. 12/14/15/50 rows parsed live from
`docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md` (clause + verdict per row).

**Loud drift**: every claim carries `sources[%{path, line}]`; the generator resolves the anchor
substring at generation time and `Mix.raise`s if the file is missing or the anchor moved —
stale citations cannot be emitted.

## Verification

- Court (Chicago: real files, real JSON, no mocks): 6/6 passed —
  sections present; identity == live `VERSION` + `surface_contract.json`; capabilities
  counts == live contract (410 entrypoints); every `sources[].path` exists with cited line
  present; two runs byte-identical; coverage rows projected from the real map.
- Lane-module compile: strict, zero warnings, via isolated `elixirc` (deps: Jason only).

## Blocker (typed, disclosed — pre-existing, NOT introduced by this lane)

Full-app gate `MIX_BUILD_ROOT=_build-laneW504 MIX_ENV=test mix compile` is
**BLOCKED(other_lane_untracked_wip)**: untracked foreign WIP file
`lib/xaas/actuation/quiescent_stop.ex` fails to compile
(`Ash.Query.filter/2` used without `require Ash.Query`, pin `^idempotency_key` misplaced —
line 91). Two attempts, identical failure. Outside this lane's write contract; not touched.
`mix test` full-suite and CLI-shaped `mix xaas.eu_ai_act_annex_iv` execution are blocked behind
the same file; lane verification ran via isolated ExUnit (real files, real output) instead.

## Standing

Lane modules: ALIVE (isolated execution, real artifacts at /tmp). Full-app gate:
BLOCKED as described. Falsifier for the "every source exists" claim: delete any cited file →
generation `Mix.raise`s (court asserts positive case; drift path exercised by construction).
