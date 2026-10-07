# W813 — AshTypescript RPC surface deepening court

Date: 2026-10-07. Lane: W813, repo /Users/sac/xaas @ feat/playwright-surface
(HEAD a0723bf6), build root `_build-laneW813`.

## Change

New file `test/xaas_web/rpc_surface_deepening_test.exs` — 11 tests, Chicago
style (real router, real AshTypescript pipeline, real sandboxed Postgres,
zero mocks; mock gate returned `[]` for the file).

- (a) `rpc/run` happy path: real `list_marketplace_providers` read over a
  sandboxed `Xaas.Marketplace.Provider` row with a real actor
  (`conn.private[:ash][:actor] = %{org_id: ...}` — the exact channel
  `Ash.PlugHelpers.get_actor/1` reads; the controller deliberately does not
  mint its own authority path). Asserts the real envelope:
  `{"success": true, "data": [row...]}` with camelCase keys and no snake_case
  key in the returned row. Named-field probing confirmed the real boundary:
  non-public fields (e.g. `inserted_at` timestamps) are refused by the
  field processor with the stale-generated-client hint, so the court pins
  the public-field contract instead of a timestamp shape.
  Also pins the real nil-actor behavior: ActorOrgFilter is a FilterCheck, so
  a nil actor is NOT refused — the read is scoped to an empty set
  (success: true, provider row absent). Disclosed finding, asserted as-is.
  a2's name ("is org-filter-scoped, not refused") matches the real semantics.
- (b) `rpc/validate` with an unknown argument → real typed payload:
  `success: false`, non-empty `errors` list, each error carrying
  `type`/`message`/`path`.
- (c) unknown action → exact `type: "action_not_found"` envelope with
  `vars.actionName`; missing action → `type: "missing_required_parameter"`
  with `vars.parameter == "action"` (vars keys are camelCased by the output
  formatter — first guess `vars["action_name"]` was corrected from real
  output).
- (d) W723 auth floor on this route: missing bearer → 401 exact
  `{error: unauthorized, detail: missing or invalid Bearer token}`;
  wrong bearer → 401 exact; deleted `INTERNAL_API_TOKEN` → 503 exact
  fail-closed body (env restored in `after`).
- (e) W636 repoint regression: `lib/kanban_web/router.ex` absent,
  `lib/xaas_web/router.ex` carries `post("/rpc/run", AshTypescriptRpcController, :run)`
  and the `/rpc/validate` mount; the release-audit task source
  (`lib/mix/tasks/xaas.release_audit.ex`) references `lib/xaas_web/router.ex`
  and no stale kanban path.
- (f) determinism: two identical rpc/run requests → identical rows for the
  same provider id.

## Verification (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW813 mix test test/xaas_web/rpc_surface_deepening_test.exs`
  → final: `Result: 11 passed` (0.4s test time; ~9min first-run lane compile
  of 928 files).
- Mock gate: `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test/xaas_web/rpc_surface_deepening_test.exs"]))'`
  → `[]`.
- Iterations (disclosed, each corrected against real output, no
  hypothetical-pinning): 6/11 → 8/11 → 10/11 → 11/11. Corrections were:
  Provider has no primary create (explicit `create :create` is not primary in
  Ash 3 — `action: :create` required), `vars` keys camelCased, nil-actor read
  is empty-set-scoped not forbidden, requested-field processor rejects
  non-public fields.

## Standing

ALIVE on exact subject feat/playwright-surface @ a0723bf6 working tree
(lane build root, since deleted... note: `rm -rf _build-laneW813` was
permission-denied in this session; the directory is left for the
coordinator, per the lane contract's fallback).

## Typed gaps

- GAP(graphql-primary-create): `Xaas.Marketplace.Provider` has no primary
  create action; direct `Ash.create!/2` without `action:` fails. Informational
  only for this lane (test constructs with explicit `action: :create`).
- GAP(nil-actor-empty-set): `rpc/run` with a nil actor on
  `list_marketplace_providers` returns `success: true` with an empty set —
  scope-not-refuse semantics. If the surface contract wants an explicit
  typed refusal for actor-less internal-api callers, that is a product
  decision, not fixed here.
- GAP(actor-wiring): the RPC controller never sets an Ash actor from the
  internal-api token/org; only a client-side `conn.private[:ash]` actor (or a
  future plug) can authorize non-empty reads. Disclosed, unchanged upstream
  behavior.
- `rm -rf _build-laneW813` permission-denied for this lane; build root left
  on disk for coordinator cleanup (BLOCKED(filesystem-permission) on the
  cleanup step only).
