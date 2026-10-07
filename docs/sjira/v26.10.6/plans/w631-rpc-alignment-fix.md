# W631 — check_rpc_alignment typed refusal (OS-19 follow-up b)

Lane W631, campaign v26.10.6, repo /Users/sac/xaas @ feat/playwright-surface.

## Defect

`check_rpc_alignment/1` in `lib/mix/tasks/xaas.release_audit.ex` read
`lib/kanban_web/router.ex` via `File.read!` (File.Error, enoent) — the audit
crashed on the absent router instead of rendering a typed finding row and its
full findings table (w600's finding; audit exit-1'd as a crash, not a refusal).

## Fix

`File.read!/1` → `File.read/1` case split on the router path only:

- `{:ok, router}` — unchanged router-mount findings (run/validate endpoints).
- `{:error, :enoent}` — one typed finding:
  `rpc alignment: lib/kanban_web/router.ex absent — reference stale or module never landed`

Audit continues, renders every finding through `render_refusal/1`
(`REFUSED(release_audit, detail: %{finding: ...})`), and raises
`Mix.Error("... failed with N finding(s)")` — fail-closed on findings,
fail-open crash removed. Config-endpoint checks still run on the same path.

## Touch set (contract)

- `lib/mix/tasks/xaas.release_audit.ex` — check_rpc_alignment body only.
- `test/mix/tasks/xaas_release_audit_test.exs` — replaced the
  router-crash-reaching assertion with: (1) audit terminates in
  `Mix.Error` with a findings count, never `File.Error`; (2) absent-router
  regression: typed rpc finding rendered as a REFUSED line.
- This file.

## Verification receipt

- Gate:
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW631 mix test test/mix/tasks/xaas_release_audit_test.exs`
- Real audit: `mix xaas.release_audit` — must render the table including the
  typed rpc finding, exit non-zero (findings exist), no raise.

Standing: ALIVE on the exact subject (working tree @ feat/playwright-surface,
W631 lane diff uncommitted — integration commit is the coordinator's).

## Gate output (real, observed 2026-10-06)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW631 \
  mix test test/mix/tasks/xaas_release_audit_test.exs
=> 4 passed (0 errors), includes the absent-router typed-finding regression

PATH=$HOME/.asdf/shims:$PATH mix xaas.release_audit
=> 12 REFUSED(release_audit, ...) lines rendered (full table), including:
   REFUSED(release_audit, detail: %{finding: "rpc alignment: \
   lib/kanban_web/router.ex absent — reference stale or module never landed"})
=> exit=1 (findings exist), no File.Error raise
```

Pre-existing findings (resource-count drift, stale claims, etc.) are other
lanes'/prior campaign surfaces — unchanged by this lane; W631 touched only the
rpc-alignment crash.
