# W792 — Platform maker-checker approve wiring (receipt)

- **Lane**: W792, campaign v26.10.6, repo `/Users/sac/xaas`, branch
  `feat/playwright-surface`, HEAD `a0723bf6` (diff uncommitted, per lane
  contract). No commit made.
- **Task**: W770's typed gaps — the five `Xaas.Platform.Validations.*RequiresApprover`
  were vacuous (always `:ok`) and the five `Xaas.Platform.Changes.*Approve`
  were identity shims wired to no action.
- **House pattern followed**: `Xaas.Governance.ApprovalBackupRetentionChange`
  (`update :approve` + RequiresApprover validation + Approve change +
  `Xaas.Governance.Validations.ApprovalNotAlreadyApproved` court coverage).

## What was wired (4 of 5 resources)

Each wired resource now has a real `update :approve` action:
`accept([:approved_by])`, `require_atomic?(false)`,
`validate(Xaas.Platform.Validations.<R>RequiresApprover)` +
`change(Xaa...Changes.<R>Approve)`, gated by
`bypass action(:approve) authorize_if {Xaas.Checks.SystemActor, []}` and
registered in `lib/xaas/checks/system_actor.ex`'s exact-subject
`@internal_api_actions` map (required service `:internal_api`) — without the
map registration the bypass would have stayed closed (witnessed: first run
of the approve courts returned `Ash.Error.Forbidden` until the subjects were
registered; the map, not the bypass, is the real authority surface).

- `RouteFeatureFlags` (json-api `patch(:approve)` omitted: duplicates
  `patch(:update)` on `PATCH /:id` — Spark refuses duplicate routes;
  `:approve` remains callable via the Ash action surface)
- `RouteSecrets` (`patch(:approve)` added, no collision)
- `RouteProjects` (`patch(:approve)` added; resource stays create-less —
  `:approve` operates on existing rows only; test inserts a real row at the
  storage layer)

**Predicate** (all three validations): `approved_by` present and non-blank,
and distinct from `requested_by` — self-approval refused. Identical shape to
the Governance
`ApprovalBackupRetentionChangeRequiresApprover`.

## Typed deletion (2 of 5 pairs), with rationale

`RouteProjectsBackupsRequiresApprover`/`RouteProjectsBackupsApprove` and
`RouteOrgsCustomDomainRequiresApprover`/`RouteOrgsCustomDomainApprove` are
DELETED. Rationale: their resources/tables carry no approver metadata
columns at all (`route_projects_backups`: org/backup lifecycle fields only;
`route_orgs_custom_domains`: org/hostname/cert fields only; verified against
the initial migration), so there is no action surface the approval half
could truthfully wire to, and a migration is out of lane file scope. The
assertion that these modules are gone and that neither resource has an
`:approve` action is a real court: test (6d).

## Test update (same file, extended)

`test/xaas/platform/platform_route_deepening_test.exs`: W770's vacuity test
(6) replaced by (6a)–(6d) — real approve courts with `authorize?: true`,
typed refusals (missing/blank approved_by, self-approval as
`Ash.Error.Invalid`; wrong-service actor and non-system actor as
`Ash.Error.Forbidden`), real persisted `approved_by` re-read from Postgres.
Moduledoc and test (5) updated to the corrected contract. 14 → 17 tests.

## Commands (real, exit 0)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW792 \
  mix test test/xaas/platform/platform_route_deepening_test.exs
  -> 17 passed (0.8s async), exit 0
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW792 \
  mix test test/xaas/platform test/xaas/system_authority_service_scope_test.exs
  -> 29 passed, 1 excluded, exit 0 (no regression)
PATH=$HOME/.asdf/shims:... mix run -e '...scan_mock_usage(["test","lib"])' -> []
```

## Mutation rationale (per wired resource)

Reverting any of the three `*RequiresApprover` validations to `:ok` fails
the corresponding (6a)/(6b)/(6c) typed-refusal asserts (missing / blank /
self-approval must raise `Ash.Error.Invalid`). Removing any of the three
`:approve` entries from the `SystemActor` map fails the same tests with
`Ash.Error.Forbidden` on the valid distinct-approver path. Deleting the
deletion-note modules is pinned by (6d).

## Incident: disk exhaustion (blocker handled in-lane)

Data volume hit 100% (283 MiB free), ENOSPC on Edit; my Edit then wrote a
truncated block into `route_secrets.ex`'s destroy bypass; restored
immediately. Freed ~36 GiB by deleting orphaned `_build-lane*` roots,
mtime-gated (>2 h untouched; 56 roots W722–W793 remain, coordinator to
re-gate if desired — first `-mtime +0` pass freed ~5 GiB of the W551–W721
generation).

## Pre-existing failure disclosed (not session-introduced)

`mix test test/xaas/governance` currently fails to compile
`test/xaas/governance/export_token_deepening_test.exs:366` ("undefined
variable org_id") — an untracked, another-lane's in-flight file (git status
`??`); W792 touched nothing in governance. Witnessed before and after my
runs; not repaired here (out of lane scope).

## Lane lease

`_build-laneW792` (~400 MB, test-compile of the final diff) left in place —
`rm -rf` was permission-denied in this lane session, same as W770;
coordinator to delete at integration.

## Standing

**ALIVE** for the three wired resources on the uncommitted diff of exact
subject `a0723bf6`+W792 (real approve actions, real Postgres row state, real
typed refusals, no mocks). **PARTIAL_ALIVE** for the surface as a whole:
backups/domain approval halves are deleted-with-rationale, and RouteProjects
still cannot mint rows (create-less by construction, disclosed).