# W873 — release_audit typed-absent (ENOENT) regression court

Lane: W873 · repo `/Users/sac/xaas` · branch `feat/playwright-surface` · HEAD `a0723bf6` · 2026-10-07

## Task

Add an ExUnit regression court for the W845/W872 hardening: every absent-file
path in `Mix.Tasks.Xaas.ReleaseAudit` must yield a typed finding / loud typed
refusal, never a `File.Error` crash.

## Subject

`test/xaas/release_audit_enoent_court_test.exs` (new, 4 tests, Chicago-style:
real `run/0` executions, real git fixture, zero mocks). No task file edits;
W872 concurrent-edit conflict did not occur (compile clean first try).

## Court design

The post-W845/W872 check functions are all `defp` with no fixture-path seam,
so — per the existing OS-19 test file's convention (`test/mix/tasks/
xaas_release_audit_test.exs`) — properties are observed behaviorally through
real `run/0` executions with controlled cwd; no tracked file is mutated:

1. **(c) required-input refusal (behavioral)**: `File.cd!` into an untracked
   probe dir (`_build-laneW873/enoent_probe`, `git ls-files` → empty) so
   `VERSION` reads `:enoent` → asserts the loud `Mix.Error` whose message
   carries `required release-audit input VERSION unreadable: :enoent` and the
   `REFUSED(release_audit,` prefix; never a `File.Error`.
2. **Required-input gating (source-shape)**: in function bodies, only
   `required_input!/1` may read `.tool-versions`/`Dockerfile`; the module-top
   `@version File.read!("VERSION")` is the OS-19-mandated derive-from read and
   is explicitly out of scope.
3. **(a/b) typed-absent scans (behavioral)**: a real temp git repo whose index
   tracks `absent.json`/`absent.md` deleted from the worktree (tracked-but-
   absent state) plus real copies of VERSION/.tool-versions/Dockerfile so the
   run traverses `required_input!` into `check_text_integrity`/`check_json`/
   `check_markdown_links`/`check_stale_claims`. Asserts the five typed
   `:enoent` findings render as `REFUSED(release_audit, ...)` lines and the
   audit terminates in the findings-count `Mix.Error`, never a `File.Error`.
4. **(d) determinism ×2**: the probe run twice emits an identical (nonempty)
   refusal-line set.

Fixture state is asserted (`git ls-files` lists the absent files; `File.exists?`
refutes them) before the run; cwd restored and fixtures removed in `on_exit`.

## Real command tails

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW873 \
  mix test test/xaas/release_audit_enoent_court_test.exs
Result: 4 passed

$ ... mix test test/xaas/release_audit_enoent_court_test.exs test/mix/tasks/xaas_release_audit_test.exs
Result: 8 passed

$ ... mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
[]
```

Witnessed `REFUSED` lines include (from the fixture run's stderr):
`tracked JSON file absent in worktree: absent.json`, `tracked markdown file
absent in worktree: absent.md`, `stale-claim scan: tracked file absent in
worktree: absent.{json,md}`, `cannot read tracked text file absent.json:
:enoent`, plus the downstream typed-absent arms (PRD/architecture/config/
router) — confirming the entire chain is crash-free.

Two real iteration cycles before ALIVE: (1) refusal-line matching had to be
substring-based (findings render inside `REFUSED(...)` wrappers); (2) the
source-shape scan needed a non-regex split on `def run`.

## Standing

**ALIVE** — exact subject (`test/xaas/release_audit_enoent_court_test.exs` on
`a0723bf6` working tree) observed passing 4/4, jointly 8/8 with the pre-existing
audit suite; mock gate clean; determinism witnessed ×2.

## Typed gaps / dispositions

- **NOT_COVERED(enoent-on-error-other-than-enoent)**: the `{:error, reason}`
  arms other than `:enoent` (e.g. `check_text_integrity`'s generic arm) are
  exercised only via `:enoent`; permission-denied variants unprobed.
- **NOT_COVERED(shell-check arm)**: `check_shell/2` has no typed-absent arm
  (relies on `System.cmd` exit status); out of this court's contract.
- **FIXTURE_ONLY(finding superset)**: the fixture run also emits downstream
  findings (domains drift, PRD absent) because the fixture tree is minimal;
  the court asserts the enoent subset, not the full refusal set.
- **SESSION_ARTIFACT(_build-laneW873 left in place)**: post-run `rm -rf` of
  the lane build root was denied by the permission system; left for the
  coordinator per the dispatch's fallback ("else leave for coordinator").
  No tracked file mutated; nothing committed (per dispatch).
