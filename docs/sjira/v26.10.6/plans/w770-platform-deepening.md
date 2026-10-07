# W770 — Platform route-resource deepening (receipt)

- **Lane**: W770, campaign v26.10.6, repo `/Users/sac/xaas`, branch
  `feat/playwright-surface`, HEAD `a0723bf6`.
- **Backlog item**: the `Xaas.Platform` route/approval resources beyond the
  webhook pair were undocketed. Read `lib/xaas/platform.ex` in full: five
  route resources exist beyond Webhook/WebhookDelivery —
  `RouteFeatureFlags`, `RouteSecrets`, `RouteOrgsCustomDomain`,
  `RouteProjectsBackups`, `RouteProjects`.
- **Deliverable**: `test/xaas/platform/platform_route_deepening_test.exs`
  (14 tests, all passing). No production code touched; no commit (per lane
  contract).

## Commands (real, exits 0)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW770 \
  mix test test/xaas/platform/platform_route_deepening_test.exs
  -> "14 passed" (0.7s async), exit 0
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW770 \
  mix test test/xaas/platform test/xaas/system_authority_service_scope_test.exs
  -> "26 passed, 1 excluded", exit 0 (existing platform + authority suite:
     12 pre-existing tests, no regression)
```

## Standing

**PARTIAL_ALIVE** (deepening coverage on exact subject `a0723bf6`; the
route resources' policy gates, validations, and no-op approve shims are
real, witnessed code paths; the maker-checker approval half is witnessed
ABSENT, see gaps).

## What the court now pins (all with `authorize?: true`, real Postgres rows)

1. **RouteFeatureFlags / RouteSecrets** — mutations are gated by
   `Xaas.Checks.SystemActor` exact-subject mapping to `:internal_api`:
   a non-system actor AND a wrong-service system authority
   (`:oban_scheduler`) are both refused (`Ash.Error.Forbidden`); the
   internal-api lifecycle (create/update/destroy) succeeds and real row
   state moves on disk (re-read after update/destroy).
2. **RouteOrgsCustomDomain** — `ActorOrgMatches` real cross-org refusals on
   `:create` and `:update` (no row on refused create); RFC 1123 hostname
   rule (single label, underscore label → typed `Ash.Error.Invalid`,
   nothing persisted); active-requires-certificate-secret rule refuses
   `status: "active"` without `certificate_secret_name` and leaves the
   row `pending`; valid activation transitions for the matching org.
3. **RouteProjectsBackups** — org-matched create only; blank
   `project_name` refused; cross-org create refused (count unchanged).
4. **Determinism** — identical create inputs yield independent rows with
   identical field state (flags and backups).
5. **Reads** — `bypass action_type(:read)` is open to any/no actor across
   all five resources (real authorized reads with `actor: nil`).

## Honest typed gaps (asserted in the file, not assumed)

- **Vacuous approvals**: the five `Validations.*RequiresApprover` modules
  return `:ok` unconditionally (executed directly with `approved_by` nil)
  and the five `Changes.*Approve` modules are identity pass-throughs,
  wired to no action anywhere — the maker-checker "approve" half named by
  this surface does not exist in executable form.
- **No transition path**: `RouteProjectsBackups` has no `:update`/`:destroy`
  action — a backup row starts `:pending` and nothing in the domain can
  transition or prune it (no retention sweep; update attempt raises
  `ArgumentError: No such update action`, the real typed surface — Ash
  raises `ArgumentError`, not `NoSuchAction`, for a nonexistent action
  name).
- **RouteProjects is dead-write**: only `:read` exists; `approved_by`/
  `requested_by` approval metadata can never be produced through this
  resource; a create attempt raises `ArgumentError` (same typed surface).
- Typed-gap pattern follows W715 (enforced-vs-owed disclosed in the test
  moduledoc and asserted as executable facts).

## Notes

- Grep gate: no `patch(`/`Mock` usage — real Ash actions against real
  sandboxed Postgres, Chicago-style.
- Webhook pair NOT re-courted here (W725's `WebhookDeepeningTest` owns it:
  signature/HMAC, secret-rotation-by-next-delivery, delivery
  terminal-ceiling — already covered there).
- `_build-laneW770` left in place for the coordinator (lane-lease
  delegation: `rm -rf` was permission-denied in this lane session; the
  directory contains only the test compile of the unmodified tree).
