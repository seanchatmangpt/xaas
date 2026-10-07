# W984db — A2A family probe (coverage burn-down)

Lane W984db, xaas v26.10.6 campaign. Date: 2026-10-07.
Subject: branch `feat/playwright-surface`, working tree as of this run (shared
canonical checkout, uncommitted lane edits present — `Xaas.Semantics.GraphlawWasm`
was mid-edit by its owning lane during the first two run attempts; waited out the
compile-freeze SLA, no cross-lane edit applied).

## A2A family census (lib/xaas/a2a/, W984cj map method)

| Module | LOC | Prior coverage | Post-W984db |
|---|---|---|---|
| `Xaas.A2a.Agent` (lib/xaas/a2a/agent.ex) | 93 | COVERED — `test/xaas/a2a/agent_identity_policy_depth_test.exs` (W984ak) | COVERED |
| `Xaas.A2a.Catalog` (lib/xaas/a2a/catalog.ex) | 205 | PARTIAL — `test/xaas/a2a/catalog_test.exs` (ingest happy paths, idempotent re-ingest, search_by_skill, tasks_for_agent, typed error on malformed JSON/map) | **COVERED (deep)** — direct court added |
| `Xaas.A2a.Task` (lib/xaas/a2a/task.ex) | 62 | COVERED — `test/xaas/a2a_resources_deepening_test.exs` (W751/W772: membership, forward-edge matrix, terminal-absorbing, unique identity, no-FK acceptance) | COVERED |
| `Xaas.A2a.Validations.ForwardOnlyTransition` (lib/xaas/a2a/validations/forward_only_transition.ex) | 72 | COVERED — same W751 court, parametrized over `forward_edges/0` | COVER |

All four family members have direct courts. No DEAD/UNSUPPORTED/THIN disposition is
warranted for any family member: none is dead, none is thin (Catalog was the only
PARTIAL, now deepened).

## Court: `test/xaas/a2a/catalog_ingest_depth_test.exs` (new, 5 tests)

Target: `Xaas.A2a.Catalog` ingest/read edges unpinned by the prior courts.

1. **Dual key shape** — the same card in wire camelCase (`supportedInterfaces`)
   and struct snake_case (`supported_interfaces`) projects identically, with
   `protocol_binding`/`protocol_version` normalized onto wire keys; cross-shape
   re-ingest is idempotent. Mutation target: `card_key/2` camelize fallback.
2. **URL fallback** — card with no top-level `url` but `supportedInterfaces[0].url`
   (the v1 spec L1008 shape) ingests with the interface URL; a card with no URL
   anywhere is refused typed (`invalid_card`, `detail: {:bad_field_types, name}`)
   and lands no row. Mutation target: `card_url/1` `Enum.find_value` fallback.
3. **Non-list normalization** — `skills`/`supportedInterfaces` of the wrong type
   project as `[]`, never raise. Mutation target: `normalize_list/1` identity arm.
4. **Upsert UPDATE path** — re-ingest with changed description/version/skills
   mutates the existing row (count stays 1, fields move, `updated_at` advances).
   Mutation target: `upsert_agent!/1` always-create path.
5. **Read-surface contracts** — `get_agent!` raises `Ash.Error.Invalid` (wrapping
   NotFound) on absent; `list_agents/0` sorts by name; `Catalog.Error.message/1`
   formats both reasons. Mutation targets: sort(:name), raise-on-absent.

Chicago: real ETS-backed Ash actions, real rows asserted, no mocks.

## Verification (real runs)

- Run 1 (existing lane root): `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984db mix test
  test/xaas/a2a/catalog_ingest_depth_test.exs` → **5 passed, 0 failures**
  (/tmp/w984db_run1.log). Two earlier failures were test-side (wrong exception
  class — Ash surfaces get-miss as `Invalid{NotFound}`; wrong `detail` name in the
  expected pattern) — fixed, not code defects.
- Run 2 (fresh root): deleted `_build-laneW984db`, full cold recompile + run →
  **5 passed** (/tmp/w984db_run2.log). The cold compile exceeded the harness's
  30-minute background limit once and was killed mid-compile; the run was
  resumed on the SAME fresh root (incremental compile completion) and went
  green with exit 0.
- Pre-existing, unrelated: compile errors in `lib/xaas/semantics/graphlaw_wasm.ex`
  observed at 14:07 were the owning lane's mid-edit state (mtime == now); clean by
  14:22 without intervention from this lane. Session-introduced: none.

## Transport failures

- Cold-compile runs exceed the 600s foreground limit; ran in background. One run
  failed to compile due to the concurrent lane's in-flight `graphlaw_wasm.ex`
  edit (compile-freeze, resolved by waiting — the owner landed a compiling
  version). No permission denials this lane. **Corrections:** (1) final cleanup
  `rm -rf _build-laneW984db` was DENIED by the session permission system —
  **`/Users/sac/xaas/_build-laneW984db` (426M) remains on disk**; coordinator:
  delete at integration per the fanout cleanup law (same as W984cj's leftover).

## Standing

- Court: **ALIVE** — 5/5 real Ash/ETS executions on the exact working-tree subject,
  twice (second run from a cold build root).
- Disposition: family **fully covered**; W984db adds the depth court on the one
  PARTIAL member (`Catalog`). A2A family exits the burn-down backlog.
