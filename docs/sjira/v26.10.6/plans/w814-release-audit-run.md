# W814 — Full Real Run: `mix xaas.release_audit` + mock-grep verify gate

Lane W814, findings-only, no fixes. Subject: `/Users/sac/xaas` branch
`feat/playwright-surface`, HEAD `a0723bf6` (shared checkout, concurrent lanes
active — 251 untracked files, live file churn during the run). Build:
`MIX_ENV=test MIX_BUILD_ROOT=_build-laneW814`, elixir 1.20.2-otp-28 via asdf.

## 1. `mix xaas.release_audit` — BLOCKED (environment), typed findings attached

### Run history (all real, full output in lane logs)

1. **Run 1** (fresh lane build): compile of `lib/xaas/operations/validations/incident_resolved_is_terminal.ex`
   failed type checking — `%Ash.Changeset.OriginalDataNotLoaded{}` does not
   exist in ash 3.34.4 (verified: zero matches in `deps/ash/lib`). The file was
   a concurrent lane's in-flight edit, absent from the final working tree.
   Classification: **(c) environment** — concurrent-lane churn, not a task bug.
2. `mix compile --force` (same lane env): **EXIT=0**, clean full recompile of
   929 files — pre-existing vs session-introduced: this failure did not survive
   the tree settling; no reproducible compile defect remains.
3. **Runs 2–5** (post-clean-compile, ×3 retries): deterministic crash —
   ```
   ** (File.Error) could not read file "lib/xaas/platform/changes/route_orgs_custom_domain_approve.ex": no such file or directory
       lib/mix/tasks/xaas.release_audit.ex:291: anonymous fn/2 in ...check_stale_claims/2
   ```
   Cause: 4 tracked files deleted in the working tree by concurrent lanes
   (`git ls-files -d | wc -l` = 4), while `git ls-files` still lists them.
   The audit's `File.read!` at xaas.release_audit.ex:291 (and identically at
   :156, :187, :256, :263, :287 — every check that reads tracked files) does
   not tolerate a tracked-but-deleted-in-worktree file.

### Per-finding classification

| # | Finding | Class |
|---|---------|-------|
| F1 | `check_stale_claims` (xaas.release_audit.ex:291, `File.read!`) crashes with `File.Error` on any tracked file deleted in the working tree, instead of emitting a typed finding — contradicts the task's own moduledoc "fails closed... does not crash" contract (the rpc check at :344 explicitly handles `:enoent`, the file-list checks do not). Same exposure at :156/:187/:256/:263/:287. Reproduces 100% (3/3 retries) whenever the worktree has `git ls-files -d` non-empty. | **(b) task bug** — coordinator owns lib/ |
| F2 | `incident_resolved_is_terminal.ex` referenced struct `Ash.Changeset.OriginalDataNotLoaded`, undefined in ash 3.34.4 — transient concurrent-lane artifact, gone from final tree; `mix compile --force` EXIT=0 after settle. | (c) environment |
| F3 | PromEx/Grafana `nxdomain` upload warnings on app start in the sandbox (no network). Harmless to the audit; noted so the noise is not misread as findings. | (c) environment |

**No audit-level stale-citation or contract findings were reachable**: the task
crashes in the file-scan phase before emitting its typed refusal list, so the
standing of the release contract itself is UNKNOWN this wave, not REFUSED and
not ALIVE.

## 2. Mock-grep verify gate — PASS

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW814 \
  mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
[]
EXIT=0
```

Covers the ~15 test files landed since W755's last run: zero mock usage in
`test/` and `lib/`. This half of the gate is ALIVE on subject a0723bf6 + the
current working tree.

## 3. Standing

- Mock-gate half: **ALIVE** (real run, exit 0, `[]`).
- Release-audit half: **BLOCKED(environment)** — deterministic crash on the
  shared-checkout file churn; **UNKNOWN** on the release contract itself, with
  typed finding F1 (task robustness bug) for the coordinator. Falsifier for
  clearing the block: a run on a settled tree (or after F1 is fixed) that
  prints `XAAS_RELEASE_AUDIT ALIVE ...` or a typed-refusal list, exit 0/1
  respectively.
- Build root `_build-laneW814` left in place for the coordinator (deletion
  denied in this lane's permission scope); it holds a clean, current compile
  state and can be deleted at integration.

## Commands / exits

- `mix compile --force` → EXIT=0 (929 files)
- `mix xaas.release_audit` → EXIT=1 (File.Error crash, 3/3 reproducible)
- `mix run -e 'IO.inspect(...scan_mock_usage(["test","lib"]))'` → EXIT=0, `[]`
