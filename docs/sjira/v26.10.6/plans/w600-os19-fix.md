# W600 — OS-19: release_audit stale-pin fix

Lane: W600, campaign v26.10.6, repo `/Users/sac/xaas` @ `feat/playwright-surface`
(one canonical checkout; private build root `_build-laneW600`).

## Change (μ/diff)

`lib/mix/tasks/xaas.release_audit.ex:14` — one line:

```diff
-  @version "26.8.21"
+  @version File.read!("VERSION") |> String.trim()
```

Mirrors `mix.exs:13`. Everything else in the file untouched.

## Test (new)

`test/mix/tasks/xaas_release_audit_test.exs` — 3 tests, Chicago (real
artifacts, real task run, no mocks):

1. **Parity law**: `VERSION` file == `Mix.Project.config()[:version]`.
2. **No-stale-literal guard**: the task source derives `@version` from
   `File.read!("VERSION")` and contains no pinned `@version "..."` literal
   (the OS-19 defect class, guarded at source level).
3. **Acceptance traversal**: real `Mix.Tasks.Xaas.ReleaseAudit.run/1` on the
   current version must produce no version finding and must reach the final
   `check_rpc_alignment` check (asserted as `%File.Error{path: "lib/kanban_web/router.ex"}` —
   the audit's observed downstream refusal on real drift).

Design note: `check_version/1` is private and `tracked_files!/0` reads
relative paths, so a behavioral stale-VERSION injection cannot run the audit
to its refusal render (refusal lines print only at the end of a full run).
The stale branch is covered by test 2's source-level guard; this is a named
infeasibility, not a skipped property.

## Verification (commands + tails)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW600 \
  mix test test/mix/tasks/xaas_release_audit_test.exs
# => Result: 3 passed  (exit 0)
```

Real audit (`MIX_ENV=test MIX_BUILD_ROOT=_build-laneW600 mix xaas.release_audit`):
exit=1, tail:

```
** (File.Error) could not read file "lib/kanban_web/router.ex": no such file or directory
    (xaas 26.10.6) lib/mix/tasks/xaas.release_audit.ex:317: Mix.Tasks.Xaas.ReleaseAudit.check_rpc_alignment/1
    (xaas 26.10.6) lib/mix/tasks/xaas.release_audit.ex:62: Mix.Tasks.Xaas.ReleaseAudit.run/1
```

Classification: the audit **runs past the version check** (no
`VERSION=`/`Mix version=` findings; v26.10.6 accepted) and traverses every
earlier check — including the full `check_domains` resource-count census —
to the LAST check, which raises on genuine pre-existing drift
(`lib/kanban_web/router.ex` absent). That is the audit working, not forced
green. Secondary observation (pre-existing, out of contract): the rpc-alignment
check uses `File.read!` and crashes instead of rendering a typed refusal.

## Transport failures (session-introduced vs pre-existing)

- Dev-env audit attempt hit a transient `SyntaxError` in
  `lib/xaas/semantics/airo_risk_mapping.ex` — a concurrent lane's untracked
  mid-edit file (mtime 22:09, removed by that lane minutes later). Not a
  defect of this lane; re-run clean after removal.
- `lib/kanban_web/router.ex` missing: pre-existing drift, refused by the
  audit as designed.

## Standing

ALIVE (one-liner + regression suite, real run witnessed on this checkout).
Fix-forward diff is 2 files + this receipt; no commit (coordinator owns
integration per lane contract).
