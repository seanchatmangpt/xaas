# W984ls Probe Receipt — Platform Route Validations Court

Lane: W984ls on /Users/sac/xaas, branch feat/playwright-surface (no branch
switch, no commit, no stash). Date: 2026-10-08.

Task: burn the new-top uncovered batch from W984lq's eighth census
(/tmp/w984it_map.txt was overwritten by W984lq, and no w984lq-probe.md
exists on disk, so the batch was re-derived from the dispatch order's
top-10 text): the 5 Platform Route validations.

## Subject

New court: `test/xaas/platform/route_validations_court_w984ls_test.exs`
(5 tests, parametrized + boundary, W984dr2b idiom: exercised through LIVE
actions, one wiring non-vacuity assert per module, sandboxed Postgres,
zero mocks, unique-per-run ids). These are the VALIDATIONS — distinct
from W984dv's RouteProjectsBackupsRetainUntilPassed and W984fm's
RouteFeatureFlagsApprove / RouteProjectsApprove CHANGES.

## Per-module dispositions

- `Xaas.Platform.Validations.RouteFeatureFlagsRequiresApprover` —
  COURTED, all 3 cond branches: missing/nil, blank "", self-approval,
  distinct-approver happy path. Through the live `:approve` action on a
  real `RouteFeatureFlags` row (real create, 3 typed refusals, real
  persisted approver); wiring non-vacuity assert that the module is in
  `:approve.changes`.

- `Xaas.Platform.Validations.RouteProjectsRequiresApprover` — COURTED,
  same 3 branches, through the live `:approve` action on a real
  `RouteProjects` row; wiring assert on `:approve.changes`.

- `Xaas.Platform.Validations.RouteOrgsCustomDomainValidHostname` —
  COURTED on the binary branch: valid multi-label hostname persists
  (status "pending"); single-label (`localhost`), leading-hyphen
  (`-console.customer.com`), and empty-middle-label (`a..b`) refused
  with the typed "is not a valid DNS hostname" message. The non-binary
  (nil) branch is typed UNREACHABLE-VIA-ACTION: `hostname` is
  `allow_nil?(false)` `:string`, so Ash's own required/type errors fire
  before the validation sees nil. Wiring assert on `:create`.

- `Xaas.Platform.Validations.RouteOrgsCustomDomainActiveRequiresCertificateSecret` —
  COURTED, all branches: `status: "active"` with nil secret refused,
  with blank "" secret refused, with a real secret name persists
  (status/secret state asserted on disk), and `status: "failed"` without
  a secret remains lawful (non-active transition not over-refused).
  Wiring assert on `:update`.

- `Xaas.Platform.Validations.RouteProjectsBackupsValidProjectName` —
  COURTED on the binary branch: blank "" and whitespace-only ("   ")
  refused via the real trim branch; valid name persists (`status:
  :pending` asserted). Nil branch typed UNREACHABLE-VIA-ACTION:
  `project_name` is `allow_nil?(false)` `:string`. Wiring assert on
  `:create`, payload carries real `taken_at`/`retain_until` utc
  datetimes.

## Gates (real output)

- `mix test test/xaas/platform/route_validations_court_w984ls_test.exs`
  under `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
  MIX_BUILD_ROOT=_build-laneW984ls`: **exit 0, 5 passed** (cold lane
  build root, full deps compile; compile warnings present are
  pre-existing in ash_affidavit / approval_causal_anatomy /
  airo.compile_shacl — zero from the court).
- Mock gate `scan_mock_usage(["test","lib"])`: **[]**.
- No commit (lane law); branch unchanged (feat/playwright-surface).
