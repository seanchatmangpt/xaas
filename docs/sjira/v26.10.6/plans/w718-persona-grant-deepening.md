# W718 — PersonaGrant deepening courts

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD `a0723bf6` (lane W718, no commit)
- **O/O\***: backlog item — `Xaas.Library.PersonaGrant` is the deny-by-default authorization
  record binding A2A/MCP caller credentials to the `Xaas.Accounts.User` id they may act as;
  thin policy courts required.
- **μ/diff** (2 files, 1 new test + 1 new receipt; nothing else touched):
  - `test/xaas/library/persona_grant_deepening_test.exs` (new, hand-written; 5 tests)
  - `docs/sjira/v26.10.6/plans/w718-persona-grant-deepening.md` (this receipt)
- **Inputs read**: `lib/xaas/library/persona_grant.ex` (policy block, identities, actions),
  `test/xaas/library/persona_grant_regression_test.exs`, `lib/xaas_web/a2a/next_read_user_agent.ex`
  (consuming `active_for/2` with `authorize?: false`).
- **Commands/exits** (real tails, PATH=$HOME/.asdf/shims:$PATH, MIX_ENV=test,
  MIX_BUILD_ROOT=_build-laneW718):
  - `mix test test/xaas/library/persona_grant_deepening_test.exs`
    → `Result: 5 passed` / `Finished in 1.3 seconds` (exit 0)
  - Note: first run (pre-fix) gave `Result: 3/5 passed` — the deny-by-default tests
    asserted `assert_raise` on non-bang code interfaces, which return
    `{:error, %Ash.Error.Forbidden{}}` instead of raising; fixed to tuple assertion.
    Post-fix rerun: 5/5, exit 0.
- **Coverage** (all real Ash actions on real Postgres sandbox, no mocks):
  - (a) deny-by-default: `:grant` and `:revoke` with no actor return
    `{:error, %Ash.Error.Forbidden{errors: [%Ash.Error.Forbidden.Policy{} | _]}}`
    (the catch-all `policy always() do forbid_if always() end` path); state asserted
    unchanged (no row written / row still active).
  - (b) granted caller (`internal_api_token`) resolves via `active_for/2`; a second
    credential with no grant returns `{:ok, []}` — cannot act-as.
  - (c) duplicate active grant for same `(caller_id, user_id)` hits the partial unique
    identity `active_caller_user` (`revoked_at IS NULL`):
    `Ash.Error.Changes.InvalidAttribute` on `:caller_id` ("has already been taken"
    class); exactly one active row remains.
  - (d) `:revoke` sets `revoked_at`, next `active_for/2` → `{:ok, []}`; the partial
    index permits a fresh grant afterward; revoked row still present via
    `Ash.get!` (non-active).
- **Verification ladder**: narrow (resource-level courts) — companion to the existing
  `persona_grant_regression_test.exs` (happy path) and the A2A-level
  `next_read_user_agent_test.exs` (real resolver enforcement); not re-covered there.
- **Standing**: ALIVE for the resource-level policy surface at this subject
  (observed execution, exact head, exit 0, 5/5).
- **Falsifiers run**: none failing; the deny-by-default refusal path was exercised
  for real (would have failed had the catch-all policy been replaced by ambient
  allow — the (a) tests assert the exact `Forbidden.Policy` error).
- **Typed gaps**: none open for this lane. `@moduledoc` records explicitly: no
  `@moduletag :eu_ai_act` — caller-credential authorization is not Art. 5
  bias/protection adjacent. Actor-present-as-admin-ceiling on `:grant`/`:revoke`
  is a pre-existing policy design note in the resource, not a defect introduced here.
- **Replay**:
  ```bash
  PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW718 \
    mix test test/xaas/library/persona_grant_deepening_test.exs
  ```
- **Lane cleanup**: `rm -rf _build-laneW718` was DENIED by the permission system in
  this session; the build root is left on disk for the coordinator to delete
  (per lane contract fallback: "delete when done, else leave for coordinator").
- **Standing note for coordinator**: files left uncommitted in the working tree,
  per lane contract.
