# W984na — follow-on court for the 6 UNKNOWN JSON:API paths from W984lv

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` (lane W984na start;
  shared canonical checkout, no branch switch, no commit).
- **Mode**: follow-on court, 1 new test file. NO commit.
- **Closes the UNKNOWN standing** W984lv's receipt left on
  `RouteCastleRun`, `RouteCastleSchedule`, `RouteCastleSunset`,
  `CastleVerbInventoryComponents`, `CastleVerbFortune5Requirements`,
  `ApprovalK8sFaultRemediateSuggest`.

## Court

`test/xaas_web/controllers/internal_api_followon_court_w984na_test.exs` —
9 tests, W984lv idiom exactly: real ConnCase through the main router,
real bearer token, real sandboxed Postgres rows, zero mocks, mutation
rationale per test. Test descriptions kept under the Erlang atom limit
(first compile attempt hit SystemLimitError on list_to_atom — names
shortened; disclosed).

## Per-resource dispositions (all ALIVE on this subject)

| Resource | Routes courted | Tests |
|---|---|---|
| `Xaas.Operations.RouteCastleRun` | GET index + GET read + unknown-id 404 | a |
| `Xaas.Operations.RouteCastleSchedule` | GET index + GET read + 404 | b |
| `Xaas.Operations.RouteCastleSunset` | GET index + GET read + 404 | c |
| `Xaas.Operations.CastleVerbInventoryComponents` | GET index + GET read + 404 | d |
| `Xaas.Operations.CastleVerbFortune5Requirements` | GET index + GET read + 404 | e |
| `Xaas.Operations.ApprovalK8sFaultRemediateSuggest` | GET index + GET read + 404 (f); POST create (g); PATCH approve self-approval refusal (h); 401 floor incl. write route (i) | f–i |

Fixture idiom: read-only projections get real Postgres rows via
`Repo.insert!(struct!(schema, ...))` (no Ash create action exists);
`ApprovalK8sFaultRemediateSuggest` rows via the real `Ash.create!`
internal write path.

## Disclosed deviation from W984lv's fail-closed-403-create pattern

The `/internal-api` forward scope pipes `:set_internal_api_system_actor`
(`lib/xaas_web/router.ex`), and `approval_k8s_fault_remediate_suggest` is
in that plug's path-segment set with `bypass action(:create) do
authorize_if(Xaas.Checks.SystemActor)` — so a valid-token POST on this
tier is genuinely ADMITTED (201 + real persisted row, test g), not 403.
The fail-closed surface was courted where it actually lives:

- test h: PATCH approve with `approved_by == requested_by` → 400
  (fail-closed, matching the existing `/api` sibling court
  `approval_k8s_fault_remediate_suggest_controller_test.exs`, which also
  asserts 400 — an initial 422 expectation was corrected against the real
  wire contract) and the self-approval does not persist.
- test i: 401 token floor on all 6 reads AND the POST create route.

No 403-create test exists because no 403-create behavior exists on this
resource/tier.

## Gates (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984na \
  mix test test/xaas_web/controllers/internal_api_followon_court_w984na_test.exs
→ Result: 9 passed, exit 0

W984lv court regression:
  mix test test/xaas_web/controllers/internal_api_court_w984lv_test.exs
→ Result: 8 passed, exit 0

mock gate (scan_mock_usage on the new file) → []
```

## Receipt fields

- identity: lane W984na, file receipt `docs/sjira/v26.10.6/plans/w984na-probe.md`
- μ/diff: 1 new handwritten test file
  (`test/xaas_web/controllers/internal_api_followon_court_w984na_test.exs`),
  1 new receipt. No lib/ changes. No commit.
- commands/exits: court 9/9 exit 0; W984lv 8/8 exit 0; mock gate `[]`
- verification ladder: narrow (two single-file court runs) — full suite left
  to integration
- standing: ALIVE for all 6 previously-UNKNOWN JSON:API route families on
  this exact subject (index/read/404 for the 5 read-only projections;
  index/read/404/create/approve-refusal/401-floor for the k8s suggest)
- falsifiers (all held): (1) a dropped catch-all route or broken id scoping
  → 404/missing row would fail a–f; (2) removing the token floor → test i
  fails; (3) removing the RequiresApprover validation or re-admitting
  self-approval → test h fails (row persists); (4) breaking the
  XAAS-2602 SystemActor carve-out or pipeline order → test g fails
- cleanup: lane build root `_build-laneW984na` deleted after final gate
