# W984bq — Platform depth court receipt (v26.10.6)

Lane: W984bq · repo `/Users/sac/xaas` @ `feat/playwright-surface` (worktree state at
session start; no commit made, per lane contract).

## Coverage-gap evidence (fresh read of `lib/xaas/platform/`)

Covered slices excluded per task:

- RouteProjectsBackups purge/retention — W970b/W981d
  (`test/xaas/platform/purge_expired_atomicity_court_test.exs`, deepening test 4c)
- RouteProjects :create/:approve — SPEC-21/W969 (deepening test 5, 6c,
  `route_projects_create_court_test.exs`)
- route-castle W984f-era; W984aa's castle-verb file
- RouteFeatureFlags / RouteSecrets / RouteOrgsCustomDomain basic lifecycles and
  maker-checker approvals — W770/W792 (`platform_route_deepening_test.exs` 1a–3c,
  6a–6d, 7, 9a–9b); webhook dispatch/HMAC/retry —
  `webhook_deepening_test.exs`, `deliver_webhook_test.exs`,
  `webhook_delivery_stress_test.exs`

Uncourted remainder found (fresh source read):

1. `Xaas.Platform.Webhook` resource lifecycle: no test courts its deny-by-default
   floor (no bypass at all — every verb refused for EVERY actor incl.
   `:internal_api`), and no test proves the AshCloak at-rest contract
   (`platform_webhooks.encrypted_secret` populated, plaintext absent from the raw
   Postgres row and from `inspect`, re-read decrypts).
2. `Xaas.Platform.WebhookDelivery` policy boundary: `:create`/`:record_attempt`
   are covered by no bypass → refused for every actor; only
   `:retry_failed_deliveries` (`:oban_scheduler`) and `:deliver`
   (`:webhook_dispatcher`) are admitted. Uncourted.
3. `:retry_failed_deliveries` filter boundary (`status == :failed and
   attempt_count < 5`): below-ceiling re-dispatch + at-ceiling exclusion, never
   courted end-to-end through the real delegation + real HTTP.
4. `RouteOrgsCustomDomain` "failed" half of the cert-status contract and the
   refusal of system-authority actors on `:update` (only the org-matching actor
   is admitted) — uncourted.
5. Typed gap: the `hostname` unique constraint platform-console parity relies on
   ("left to a real database unique index" per the resource comment) does NOT
   exist in any migration — `route_orgs_custom_domains` has no unique index on
   hostname. Recorded as a gap, not courted (cannot court a nonexistent invariant
   without landing a migration, out of lane scope).

## Court file

`test/xaas/platform/platform_depth_w984bq_test.exs` — 5 tests, Chicago-style
(real sandboxed Postgres, real policies `authorize?: true`, raw SQL row reads,
real closed-port HTTP for the retry path; zero mocks — mock gate `[]`).

1. **(1) Webhook deny-by-default, no bypass**: `:create` refused (`Ash.Error
   .Forbidden`) for `:internal_api`, `:oban_scheduler`, and a plain org actor;
   zero rows persisted.
2. **(2) Webhook AshCloak at-rest**: `authorize?: false` create; raw
   `SELECT encrypted_secret` populated and not containing plaintext;
   `row_to_json` raw-row inspect lacks plaintext; `inspect(hook)` redacts
   (`sensitive?`); Ash re-read decrypts to the original secret.
3. **(3) WebhookDelivery policy boundary**: `:create` and `:record_attempt`
   refused for `:internal_api` and `:oban_scheduler` (real webhook row needed —
   the `belongs_to` FK check fires before policy, first run caught this);
   `:retry_failed_deliveries` runs as `:oban_scheduler` with 0 candidates
   → `%{candidates: 0, updated: 0, errored: 0}`.
4. **(4) Retry filter boundary, real HTTP**: below-ceiling `:failed` row
   (attempt_count 4) is re-dispatched over real HTTP to a dead port → stays
   `:failed`, `attempt_count == 5`; at-ceiling row (attempt_count 5) excluded,
   `last_attempted_at` untouched. Result `%{candidates: 1, updated: 1, errored: 0}`.
5. **(5) Custom-domain failed-cert contract**: "active" without
   `certificate_secret_name` is a typed `Ash.Error.Invalid` (validation fires
   before policy); system-authority actors refused (`Forbidden`) on `:update`
   with "failed" (policy is the denial, validation passes); matching-org actor
   transitions to `"failed"` with `certificate_reason`/`certificate_message`,
   persisted row state asserted.

## Commands / exits (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984bq mix compile`
  → exit 0 (`Generated xaas app`), fresh lane build root, ~19 min full dep build.
- `mix test test/xaas/platform/platform_depth_w984bq_test.exs` → run 1: 3/5
  (FK-before-policy and validation-before-policy orderings — fixed by using a
  real webhook row and by asserting the typed Invalid boundary first);
  run 2: **5 passed, 0 failures**; run 3 (`--seed 777`): **5 passed, 0 failures**.
- Mock gate: `scan_mock_usage(["test/xaas/platform/platform_depth_w984bq_test.exs"])`
  → `[]`.

## Standing

- Test file: **ALIVE** — 5/5 on two seeds against the current worktree subject.
- `hostname` unique index on `route_orgs_custom_domains`: **BLOCKED
  (out-of-lane-scope migration)** — recorded as coverage gap.
- Lane build root `_build-laneW984bq` (~426 MB): **left for coordinator**
  (rm denied by permission system; per lane contract this is the disclosed
  fallback).
