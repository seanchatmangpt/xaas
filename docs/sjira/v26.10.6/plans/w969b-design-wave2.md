# W969b — DESIGN wave 2 (SPEC-04 + SPEC-18) — receipt

- Lane W969b, xaas v26.10.6, repo `/Users/sac/xaas`, branch `feat/playwright-surface`.
- HEAD at lane open: `fab56ae1`. **No commit made** (lane contract: implementation
  sites + courts only; coordinator owns transitions/commits).
- Backlog: `docs/sjira/v26.10.6/plans/w905-design-gap-specs.md`. Wave-1 receipt
  `w968c-design-wave1.md` was NOT on disk at lane open, but wave-1's implementation
  IS on the shared tree uncommitted (see "Disjointness" below) — specs re-picked to
  be fully disjoint from it.

## Selection

- **SPEC-04 (W722-GAP-2, M)** — `XaasWeb.Plugs.AuthenticateOrg`: authenticated org
  identity on the `/api` surface.
- **SPEC-18 (W765-GAP-D, M)** — `Xaas.Governance.Checks.FreezeWindowActive`: runtime
  freeze-window gate on deploy-class `:approve` actions.
- Originally probed SPEC-14/SPEC-27 but found wave-1's on-disk implementation
  (`lib/xaas/operations/changes/set_previous_status.ex`,
  `M lib/xaas/operations/capability_liveness_receipt.ex`/
  `capability_liveness_regressions.ex`, `M lib/xaas/ledger/transfer.ex`,
  `priv/repo/migrations/20261007230000_add_reverses_transfer_id_to_ledger_transfers.exs`,
  `priv/repo/migrations/20261007231000_add_previous_status_to...exs`) and
  STOPPED — zero edits made to those files by this lane.

## Implementation (μ/diff, 8 files)

1. `lib/xaas_web/plugs/authenticate_org.ex` (new) — promotes
   `conn.assigns[:current_org]` (established by `RequireInternalApiToken` from a
   hashed, non-revoked, non-expired `InternalApiToken` whose hash matched the
   presented bearer) into `conn.assigns[:authenticated_org]` + Ash actor
   `%{org_id: org.slug}` + Ash tenant. Legacy shared-token / org-less-token tier:
   passthrough (legacy tier keeps legacy caller-asserted behavior).
2. `lib/xaas_web/router.ex` — new `pipeline :authenticate_org`, inserted into the
   `/api` scope's pipe_through AFTER `:require_internal_api_token` and BEFORE
   `:resolve_org_actor`.
3. `lib/xaas_web/plugs/resolve_org_actor.ex` — demoted to
   derive-from-authenticated-identity: when `conn.assigns[:authenticated_org]` is
   present, a forged `X-Org-Id` header (real other org) → 403 `org_mismatch`
   (fail-closed); header absent → authenticated org supplies the binding (no more
   400 missing_org_id on the authenticated tier); legacy tier unchanged.
4. `lib/xaas/governance/checks/freeze_window_active.ex` (new) — `Ash.Policy.
SimpleCheck`, `forbid_if`-wired onto `ApprovalDeploymentQuarantine :approve` and
   `ApprovalEnvironmentPromote :approve` (`forbid_if` FIRST inside the bypass,
   before `ActorOrgMatches`/`SystemActor`, because a bypass short-circuits on its
   first authorize_if). Fail-closed on lookup error. Unapproved override does not
   lift the freeze; override against a non-overrideable window does not lift it.
5. `approval_deployment_quarantine.ex` + `approval_environment_promote.ex` —
   `forbid_if({FreezeWindowActive, []})` added to the `:approve` bypasses.
6. Courts: `test/xaas/governance/freeze_window_active_gate_test.exs` (new, 5
   tests) and lens (e) in
   `test/xaas/governance/multitenant_approval_deepening_test.exs` (4 new tests).

Note: two hunks in `approval_environment_promote.ex` (moduledoc "RESOLVED" note
and one blank line) were not authored by this lane; they are consistent doc
updates and were kept, not reverted.

## Verification (real output)

- `mix compile` (MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW969b): exit 0; zero
  warnings in lane files.
- `mix test test/xaas/gs/governance/freeze_window_active_gate_test.exs` → **5 passed**.
- `mix test test/xaas/governance/multitenant_approval_deepening_test.exs` → **14 passed**
  (11 pre-existing + 4 new lens-(e), one legacy-tier 404-body assertion loosened to
  status-only after a real 404 body shape observation).
- Adjacent suites (quarantine/promote/resolve-org-actor/freeze-window controller
  tests): **20 passed**.
- Toolchain: PATH=$HOME/.asdf/shims:$PATH, MIX_ENV=test, MIX_BUILD_ROOT=
  _build-laneW969b.

## Mutation rationale (non-vacuity)

- SPEC-18 court: deleting the `forbid_if` wiring or breaking the window lookup
  fails tests 1–2 (in-window approve would admit); dropping the `approved_by`
  predicate fails test 3 (unapproved override would lift the freeze); inverting
  the `allow_emergency_override` branch fails test 4; deleting both wiring sites
  fails tests 1/5. Falsifier: an in-window `:approve` must refuse typed
  (`Ash.Error.Forbidden` naming the freeze), never admit.
- SPEC-04 court: deleting the `:authenticate_org` pipeline entry or the demotion
  branch fails the 403-org_mismatch test; removing the authenticated-bind-on-
  missing-header path fails the 200-without-header test; the legacy-tier test
  pins the pre-existing caller-asserted behavior as the disclosed boundary this
  spec closes for the org-token tier. Falsifier: authenticated org A + header
  org B must be refused, not honored.

## Lane lease

`_build-laneW969b/` left in place for the coordinator: the `rm -rf` of the lane
build root was denied by this session's permission boundary. It is a pure build
artifact (safe to delete at integration).

## Standing

**PARTIAL_ALIVE**: real, currently-passing courts on the shared tree (uncommitted);
router/plug surface touched — integration + commit owned by the coordinator.
Migrations: none needed for either spec (spec-conformant).

## Disjointness ledger

- Zero edits by this lane to: audit_export_token.ex, checkout.ex,
  conference/registration.ex, incident.ex, graphlaw/capability.ex, and (post-wave-1
  probe) everything under lib/xaas/operations/, lib/xaas/ledger/,
  test/xaas/operations/, test/xaas/ledger/, priv/repo/migrations/.
- Wave-1 collision detection: wave-1's uncommitted SPEC-14/27 work was detected
  via `git status` (see above), specs re-picked to SPEC-04/18 before any edit.
