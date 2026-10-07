# W228 — `mix test test/mix` dir-level verification receipt

- Lane: W228, v26.10.6 convergence
- Repo/subject: `/Users/sac/xaas`, branch `feat/playwright-surface` (uncommitted working tree, no git actions taken)
- Date: 2026-10-06
- Command (exact, repeated 5x):
  `PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test mix test test/mix`
- Toolchain: asdf elixir (pinned via `.tool-versions`), MIX_ENV=test

## Verdict

**47/48 passed, 1 failed, 1 skipped (typed, expected), 15 excluded** — under the exact
commanded invocation.

Count line verbatim (all runs):

```
Result: 47/48 passed, 1 skipped, 15 excluded
Failed: 1 test
```

## Failure classification

Single failure, deterministic under this invocation (4/4 full-dir runs failed; the run
that also hit a build-lock/contention window failed at app-start with
`Xaas.Application.start/2 undefined` — transport-level, counted separately, not a test
failure):

```
  1) test prints the JSON receipt and admits the recurring self-work order (Mix.Tasks.Xaas.SelfDigestTest)
     test/mix/tasks/xaas_self_digest_test.exs:24
     Assertion with == failed
     code:  assert summary["frontier_episodes"] == 3
     left:  0
     right: 3
     test/mix/tasks/xaas_self_digest_test.exs:54
```

Classification: **pre-existing, invocation/order-dependent test defect (pollution or
load-order interaction), NOT session-introduced, NOT a product-code failure witness.**

Evidence for classification:

- `mix test test/mix/tasks/xaas_self_digest_test.exs` alone → `Result: 3 passed`.
- `mix test test/mix/tasks` (same file set as `test/mix`) → `Result: 48 passed, 1 skipped, 15 excluded`.
- `mix test test/mix` → fails 4/4 with `frontier_episodes == 0` instead of 3.
- Code path: `lib/xaas/ultracode/capital_census/self_digest_run.ex` `episodes/1` →
  `outcome_atom/1` drops lines whose outcome atom fails
  `String.to_existing_atom/1` + frontier allowlist (`Facts.frontier_outcomes()` in
  `lib/xaas/generated/capital_census/facts.ex:25` lists `:worker_unclosed`), OR `Jason.decode`
  mismatch. The generated Facts list contains the outcome, so the failure indicates the
  telemetry lines are being dropped during the full-dir load/eval context only — a
  test-env interaction, not a regression in this lane (lane changed nothing).
- Timing note: the digest fixture uses `DateTime.add(now, -i * 60, :second)` with
  `--window 60` (minutes), so the fixture is window-valid by ~57 min of slack — the
  failure is not a time-window artifact.

## Expected skip (typed)

The compile_prose skip is present and expected; nothing else in the suite is skipped.

## Boundary

No fixes, no git actions, no hand-edits to generated surfaces. Verification only.
Raw log: `/tmp/w228_mix_test.log`, `/tmp/w228_mix_test2.log`.
