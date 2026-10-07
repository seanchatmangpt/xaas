# W192 — Post-W161 targeted ultracode rerun (v26.10.6 convergence)

Lane: integration W192. Repo: `/Users/sac/xaas` (canonical checkout, branch
`feat/playwright-surface`). Scope: rerun the W161-named ultracode court set,
classify/fix the 3 pre-existing failures W161 named. No lib edits, no git.

## Gate

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test \
  test/xaas/ultracode/sj_program_registry_test.exs \
  test/xaas/ultracode/dispatch_test.exs
```

(`dispatch` glob resolved to `dispatch_test.exs`; no `dispatch/` dir exists.)

## Final result (observed, post-fix)

```
Result: 47 passed
Finished in 16.7 seconds
```

Early runs during this lane: 44/47 → 46/47 → 47/47 across three sequential
`mix test` invocations on the exact subject above (mixed-toolchain guard:
asdf shims prefixed, OTP-28 elixir 1.20.2, per repo doctrine).

## Failures found → dispositions

All three W161-named pre-existing failures were stale-test-vs-moved-config
drift, not product defects.

1. **dev.exs repo-path expectations** (`sj_program_registry_test.exs`, test
   "config/dev.exs registers all four targets…", line ~48) — FIXED (test
   follows config truth).
   - Observed real dev.exs values: `"autofde-lab" => ~/autofde-lab`,
     `"gymact" => ~/gymact` (canonical checkouts), vs test's blanket
     `~/xaas/worktrees/repos/#{alias}` expectation.
   - Fix: replaced the blanket assertion with `expected_repo_path/1` clause
     dispatch (`autofde-lab` → `~/autofde-lab`, `gymact` → `~/gymact`, else
     `~/xaas/worktrees/repos/#{alias}`), with a comment recording the real
     conventions. Config truth moved, test follows.
2. **env allowlist** (test "every new suite runs under an allowlisted env…")
   — FIXED (test follows lib truth). Real env from
   `TargetSuites.elixir_env/3` carries `"SEED"` (per-alias toolchain-seed
   path under `~/xaas-worktrees/toolchain/seeds`); test allowlist predated
   the rename from `XAAS_TOOLCHAIN_SEED`. Added `SEED` to the test's
   `@env_allowlist` with a comment. `XAAS_TOOLCHAIN_SEED` retained in the
   list (still reserved).
3. **profile wellformedness** (test "every declared sensing profile is a
   known, well-formed jira_dir profile") — CLASSIFIED, then resolved
   mid-lane by a concurrent lane: the test on disk now dispatches on
   `profile["type"]` (`jira_dir` vs `failing_tests`, marked "config truth,
   v26.10.6"). It passes as written; I did not modify it further.

## Concurrent-lane note

Mid-lane, `test/xaas/ultracode/sj_program_registry_test.exs` was rewritten
underneath me by a concurrent lane (profile test → type-dispatching
wellformedness). I kept it — it passes and is the stricter form. My two fixes
(path expectations, env allowlist) are untouched by it and were re-verified
after the change landed.

## Receipt fields

- subject: exact repo `/Users/sac/xaas`, branch `feat/playwright-surface`,
  worktree state at time of run (uncommitted test edit in
  `test/xaas/ultracode/sj_program_registry_test.exs`; HEAD d1db2b03 + lane
  drift)
- μ/diff: one test file, two mechanical stale-expectation repairs
  (`expected_repo_path/1` clauses for autofde-lab/gymact; `SEED` added to
  `@env_allowlist`). Generated vs handwritten: handwritten, 100% (test-only
  repair lane).
- commands/exits: the mix test gate above, final exit 0, `Result: 47 passed`.
- verification ladder: narrow (targeted ultracode suites) — 3 sequential runs,
  44/47 → 46/47 → 47 passed.
- standing: ALIVE for the targeted ultracode court set on this subject.
- falsifiers open: full `mix test` suite not run this lane (out of scope);
  `dispatch_worker_env_test.exs` and other dispatch-family files not run
  (only `dispatch_test.exs`; no `dispatch/` directory exists to glob).
- refusals: none.

## W262 post-W229

Lane: integration W262. Repo: `/Users/sac/xaas` (canonical checkout, branch
`feat/playwright-surface`, HEAD d1db2b03 + lane drift). Scope: post-W229
ultracode re-gate (W229's autonomic.ex precedence fix + its new regression
test). No fixes, no git.

Gate:

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test \
  test/xaas/ultracode/autonomic_profile_sense_test.exs \
  test/xaas/ultracode/semantic_replay_test.exs \
  test/xaas/ultracode/sj_program_registry_test.exs
```

### Result

- Run 1 (shared `_build/test`): **31/32** — one failure
  `semantic_replay_test.exs:292` (`assert code == 4`). Classified
  environmental: the `cold_replay/1` helper shells out to `mix xaas.replay`
  against the shared `_build/test`, which was concurrently held by other
  lanes (observed "Waiting for lock on the build directory (held by process
  93594)" and protocol-consolidation `File.Error` write races from a
  non-lane-rooted concurrent `mix test test/xaas/ultracode` run). The same
  file alone in a quiet window passed **13/13**.
- Run 2 (shared `_build/test`): 31/32, same single failure at :292.
- Run 3 (isolated `MIX_BUILD_ROOT=_build-laneW262`, per
  same-checkout-fanout lane-build-root law): **32/32 passed, exit 0** in
  124.4s (fresh full compile under the lane root).

### Classification

The 1/32 failure is build-contention flake from concurrent same-checkout
lanes sharing `_build/test`, not a product or test defect: the subprocess
`mix xaas.replay` inherits the contended build dir. Target standing
(all green under isolation):

- W229's new autonomic precedence regression test: PASS
- W125's 12/13 pins: PASS (semantic_replay 13/13)
- W161's bound fix: PASS (sj_program_registry)

Lane build root `_build-laneW262` deleted post-run per cleanup law.

### Receipt fields

- commands/exits: gate above; run 3 exit 0, `Result: 32 passed`.
- μ/diff: none (re-gate lane only; no file edits, no git).
- verification ladder: narrow (targeted ultracode court set), 3 runs.
- standing: ALIVE for the three-file court set on this subject under an
  uncontended build root.
- falsifiers open: the :292 assertion remains flaky under shared
  `_build/test` contention — any future full-suite gate should use a lane
  build root or serialize the subprocess-spawning replay tests.
- refusals: none.
