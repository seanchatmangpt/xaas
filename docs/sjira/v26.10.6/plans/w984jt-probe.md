# W984jt — unclaimed-family probe: a2a catalog/agent seam

Lane receipt (NO commit; coordinator owns transitions). Branch `feat/playwright-surface`,
shared canonical checkout `/Users/sac/xaas`.

## Census — `lib/xaas/a2a/*.ex` minus `tofu.ex`

| module | lines | existing coverage | disposition |
|---|---|---|---|
| `lib/xaas/a2a/catalog.ex` | 205 | `catalog_test.exs` (W699: real ash_a2a card ingest, path/JSON/map forms, idempotent upsert, search, tasks cross-ref), `catalog_ingest_depth_test.exs` (W984db: camelCase/snake_case dual shape, interface-url fallback, non-list normalization, upsert-update mutation, sort/raise/Error.message) | covered + indirectly covered via tofu_test; residual branches newly courted by W984jt |
| `lib/xaas/a2a/agent.ex` | 93 | `agent_identity_policy_depth_test.exs` (W984ak: unique_name, deny-floor create/destroy refusals, update accept-list, defaults/optional version), deepening c2 attribute surface | covered; read-bypass OPEN half + allow_nil? floors were unpinned → courted |
| `lib/xaas/a2a/task.ex` | 62 | `a2a_resources_deepening_test.exs` (W751/W772: status one_of, forward-only machine incl. all edges + terminal absorbing + self-transitions, unique_task_id, dangling FK semantics, determinism) | covered; explicit-nil required-attr refusals were unpinned → courted |
| `lib/xaas/a2a/validations/forward_only_transition.ex` | 72 | deepening a3/a3b/a3c (every allow-list edge + refusals + `forward_edges/0` enumeration) | covered |

Tofu excluded per lane contract (`tofu_test.exs` 6/6 green after the probe, exercising
Catalog.ingest indirectly).

## Newly courted branches — `test/xaas/a2a/catalog_agent_court_w984jt_test.exs`

1. `search_by_skill/1` nil skill fields + non-binary tag entries (`tag_matches?/2`
   non-binary clause), and the `is_binary(term)` guard (FunctionClauseError).
2. `Catalog.ingest/1` non-map/non-binary catch-all → typed `invalid_card`, no exception.
3. Agent policy floor's OPEN half: `authorize?: true` read admitted through the read
   bypass (W984ak pinned only the refusing half).
4. Task required attrs: explicitly-nil `agent_id`/`task_id`/`context_id` refused typed;
   ABSENT required attrs refused typed; no row lands.

Finding recorded while courting: an earlier draft iteration observed an absent-attribute
Task create returning `{:ok, row}`; pinned as a typed refusal in the final court (the
deterministic single-case form passes — the earlier observation was an id-stable artifact
of the loop's prior-iteration row, not a resource gap; distinct task_ids per case removed
the ambiguity).

5. Agent `allow_nil?` floor: nil `url`/`description` refused typed at create.

Mutation rationale per test in the file's moduledoc.

## Gates (real runs)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984jt mix test test/xaas/a2a/catalog_agent_court_w984jt_test.exs` → `6 passed`, exit 0
- `... mix test test/xaas/a2a/tofu_test.exs` → `6 passed` (stays green), exit 0
- `... mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'` → `[]`

(Note: a type warning is emitted by dialyzer-lite for the deliberate
`search_by_skill(42)` FunctionClauseError court — intentional, pins the guard.)

## Hygiene

One type warning in the new file (deliberate guard court); zero warnings in `lib/`.
Lane build root `_build-laneW984jt` deleted after gates (see final report for rm status).
Standing: ALIVE for the courted branches; no mocks, real Ash/ETS state throughout.
