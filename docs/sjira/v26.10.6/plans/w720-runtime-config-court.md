# W720 — ash_a2a runtime-config court

- **Subject**: /Users/sac/xaas @ feat/playwright-surface, HEAD `a0723bf6`
- **Lane**: W720 (single-lane; no git commands run; no commit)
- **Standing**: ALIVE (real run on the exact subject, exit 0)
- **Repo posture note**: `rm -rf _build-laneW720` was permission-denied; the
  lane build-root lease is left on disk for the coordinator (fanout cleanup
  law). Everything else is per contract.

## Files written

- `test/xaas/ash_a2a_runtime_config_court_test.exs` (new, only code artifact)
- `docs/sjira/v26.10.6/plans/w720-runtime-config-court.md` (this receipt)

## Technique (documented in the test moduledoc)

`config/runtime.exs` is not loaded in the test env, so the court reads the
real file with `Config.Reader.read!/2` (the stdlib reader `mix` itself uses)
under stubbed env vars, once per `env:`, and asserts on the returned config
structure. No mocks; the dep refusal path is exercised by calling the real
`AshA2A.CapabilityRelease.binding/2` / `filter_skills/2`.

## Assertions

- (a) prod block sets `capability_release_mode: :strict` (reader-eval, env: :prod)
- (a') prod block pairs strict mode with the durable half: EKV receipt store,
  DurableFile claim store, EKV authority broker, kill-switch class, outbox dir/key
- (b) strict mode without a closure refuses `:capability_release_closure_missing`
  via real dep call, and source pins:
  `capability_release_closure_missing` in `deps/ash_a2a/lib/ash_a2a/capability_release.ex`;
  `chicago_b11_wire_agent` in `deps/ash_a2a/lib/ash_a2a/chicago/bench/b11_wire.ex`
  (the W701-observed refusing surface);
  `capability_release_closure_missing: :refused_provenance` in
  `deps/ash_a2a/lib/ash_a2a/semantic/refusal.ex`
- (c) runtime.exs test-env block deliberately does NOT configure :ash_a2a
  (W701 fresh-root finding: compile-time :strict fails the dep's own compile)
- (d) kill_switch_class: prod `:xaas_a2a` vs test `:xaas_a2a_test` — differing
  by design (test-scoped kill switch), equal presence; pinned both ways with
  an honest in-test comment.

## Commands / exits

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW720 \
    mix test test/xaas/ash_a2a_runtime_config_court_test.exs
Excluding tags: [:stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api, :external, :external_llm, :subprocess, :property, :castle_kernel, :eu_ai_act]
........
Finished in 0.1 seconds (0.00s async, 0.1s sync)
Result: 8 passed
[exited with code 0]
```

## Falsifier status

- Ran: 8/8 passed on the exact subject (exit 0).
- Mutation lens: flipping runtime.exs prod to non-strict, deleting the dep's
  refusal tuple, or adding a test-env strict block would each fail the court
  (reader eval is source-bound).
- Revert lens: reverting this lane's diff removes only the new test file —
  no acceptance criterion depends on its absence.
