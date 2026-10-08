# W984la — unclaimed-family probe: /dev-scope controller surface

Lane W984la on `feat/playwright-surface` at /Users/sac/xaas. No commit, no branch switch.

## Subject

`lib/xaas_web/controllers/` contains no `*dev*` file. The /dev scope
(router.ex:339-379, inside the `Application.compile_env(:xaas, :dev_routes)`
block W984hq typed) mounts framework handlers (LiveDashboard, Swoosh
MailboxPreview, AshAdmin) plus two first-party LiveView handlers:

- `XaasWeb.AutofdeLab.StatusLive` — `/dev/dashboards/autofde-lab`
  (lib/xaas_web/live/autofde_lab/status_live.ex)
- `XaasWeb.System.CommandCenterLive` — `/system` (same dev_routes gate)
  (lib/xaas_web/live/system/command_center_live.ex) +
  `XaasWeb.System.CommandCenterAdapter`

The handlers ARE HTTP-exercisable in test: test config sets
`dev_routes: true`, so the guarded block is mounted (witnessed by the
W774 court, test/xaas_web/dev_routes_court_test.exs). No compile-guard
exclusion applies to the court.

## Census + dispositions

Pre-existing coverage: `test/xaas_web/dev_routes_court_test.exs` (all
five mounts via real HTTP/LiveView + compile-guard source pins),
`test/xaas/chicago/surface/command_center_live_test.exs` (mount, refresh,
digest, transport, refused sections),
`test/xaas/chicago/surface/command_center_adapter_test.exs` (9 tests incl.
zero-mutation grep gate), `test/xaas_web/live/autofde_lab/status_live_test.exs`.

Genuinely unexercised branches found (grep across test/ for direct calls:
zero hits):

| Branch | Disposition |
|---|---|
| `CommandCenterLive.standing_chip_classes/1` — ALIVE / PARTIAL_ALIVE / REFUSED_* / catch-all arms | UNCOVERED → covered this lane, direct real calls |
| `CommandCenterLive.state_chip_classes/1` — running / completed / failed,missed,abandoned / catch-all arms | UNCOVERED → covered this lane, direct real calls |
| `StatusLive.delivery_status_class/1` `:failed` / `:pending` arms | UNCOVERED (existing test seeds only :delivered) → covered this lane via real `/dev/dashboards/autofde-lab` mount with seeded real WebhookDelivery rows |
| `StatusLive.delivery_status_class/1` catch-all `_` | THIN/COVERED(config) — unreachable by dispatch: `Xaas.Platform.Types.WebhookDeliveryStatus` is `Ash.Type.Enum values: [:pending, :delivered, :failed]` |
| `StatusLive.verdict_class/1` (all three clauses) | THIN — reachable only when sibling repo `autofde-lab/docs/STATUS.md` exists at the parser's default path; not present/deterministic in this checkout, not courted |
| adapter private helpers (`f2/3`, `to_list/1`, `layers_from/1` error arms, etc.) | COVERED indirectly via the 9 adapter-court tests over real snapshot folds |

## Court

One file: `test/xaas_web/controllers/dev_court_w984la_test.exs` — 4 tests,
Chicago (direct real calls to pure functions; real mount + real seeded Ash
rows for the LiveView; zero mocks).

Gate: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984la mix test test/xaas_web/controllers/dev_court_w984la_test.exs`
→ `Result: 4 passed`, exit 0 (fresh lane build root, cold compile).

Mock gate over the new file: zero banned-pattern hits (`patch(` not present).

## Cleanup

Lane build root `_build-laneW984la` removed post-gate.
