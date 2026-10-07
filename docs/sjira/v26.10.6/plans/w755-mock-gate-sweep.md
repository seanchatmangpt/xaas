# W755 — Mock Gate Sweep Receipt

Lane: W755, xaas v26.10.6 campaign. Repo `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `a0723bf6`.

## Gate run (authoritative)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW755 \
  mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
```

Output: `[]` — exit code 0. Full clean compile of all deps + xaas (928 files) under the
pinned asdf toolchain (elixir 1.20.2-otp-28) before the scan.

## 1. Allowed patterns observed

`scan_mock_usage` (lib/mix/tasks/xaas.verify_and_commit.ex:131) bans
`unittest.mock|Mock(|MagicMock|monkeypatch|import/use/alias Mox|Mox.|:meck|meck.` over
code lines only (skips `#` comments, `"""` heredocs, and its own source/test). No allowed-
pattern near-misses were hits; the following pattern-adjacent text in the tree is NOT
banned by construction:

- `patch(` — Phoenix ConnTest `patch/3` and Ash `patch(:approve)` (5 lib files:
  approval_sla_credit_apply.ex:90, approval_backup_retention_change.ex:64,
  approval_deployment_quarantine.ex:79, approval_dr_failover.ex:63,
  approval_legal_hold_release.ex:62; plus `patch(...)` HTTP calls in
  test/xaas/governance/multitenant_approval_deepening_test.exs:396).
- The word "mock(s)" in `#` comments and moduledocs across ~40 wave test files
  ("no mocks" declarations) — skipped by the gate's comment/heredoc filter.

## 2. Banned hits

**Zero.** No Mock/Mockery/Mox/meck/monkeypatch hits anywhere in `lib/` or `test/`
(wave files or pre-existing).

Cross-check: a byte-for-byte standalone replication of `scan_mock_usage` (same regex,
same comment/heredoc/self-file skipping, `/tmp/w755_scan.exs`, pinned elixir) also
returned `[]`.

## 3. Wave-scoped count

83 added/modified `.ex`/`.exs` files from current `git status` (untracked + modified,
lib+test), scanned with the raw banned regex INCLUDING comments and heredocs (stricter
than the gate): **0 hits**. The only textual matches in wave files are the word "mocks"
inside comments/docstrings and legitimate `patch(` calls — none of the banned patterns.

## Standing

ALIVE — gate executed on the exact subject (HEAD a0723bf6, working tree as of
2026-10-07), real compile, real scan, exit 0, `[]`.

Notes for coordinator:
- `_build-laneW755/` left in repo root; `rm -rf` was permission-denied in this lane.
  Per lane-lease law, delete at integration.
- Pre-existing build warnings only (AshA2A legacy-compat, PromEx/Grafana nxdomain,
  autofde not on PATH) — unrelated to the mock gate.

## Reproduce

```bash
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW755 \
  mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'  # expect []
```
