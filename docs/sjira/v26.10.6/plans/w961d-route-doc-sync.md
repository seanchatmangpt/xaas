# W961d — http-api-surface doc sync for AuditExportToken :use/:revoke routes

Date: 2026-10-07. Lane W961d, xaas v26.10.6, branch `feat/playwright-surface`.
Doc-only lane; no lib/test changes, no commit (coordinator owns transitions).

## Change (1 file)

`docs/claude/diataxis/reference/http-api-surface.md` — two edits:

1. Mutation-verbs bullet (~L150-155): now reads
   `post(:issue)`/`patch(:use, route: "/:id/use")`/`patch(:revoke, route: "/:id/revoke")`
   on `Xaas.Governance.AuditExportToken` (SPEC-16 lane W935; collision court W944b,
   controller repoint W959).
2. Governance route table row `/audit_export_tokens` (~L213): rewritten to state
   the three-route surface (`post(:issue)`, `patch(:use, route: "/:id/use")`,
   `patch(:revoke, route: "/:id/revoke")`), the absence of a bare `patch(:update)`
   (bare PATCH `/:id` has no route — 404 `no_route_found` per W959's mutation run),
   the `used_at` single-stamp + `use_count` increment semantics of `:use`
   (refusals: `AuditExportTokenNotAlreadyUsed`, `AuditExportTokenExpiredTokenRefused`),
   the `AuditExportTokenActorOrgMatches` gate on both PATCH routes, and pointers to
   the W944b collision court + W959 repoint.

## Grounding (file:line, read at HEAD working tree)

- `lib/xaas/governance/audit_export_token.ex:54-61` — route block:
  `base("/audit_export_tokens")`, `get(:read)`, `index(:read)`, `post(:issue)`,
  `patch(:use, route: "/:id/use")`, `patch(:revoke, route: "/:id/revoke")`.
  No `patch(:update)` exists (verified by reading the whole routes block).
- `lib/xaas/governance/audit_export_token.ex:112-122` — `update :use`:
  `require_atomic?(false)`, validations
  `AuditExportTokenNoActiveFreezeWindow` / `AuditExportTokenExpiredTokenRefused` /
  `AuditExportTokenNotAlreadyUsed`, `set_attribute(:used_at, ...)`,
  `increment(:use_count, amount: 1)`.
- `lib/xaas/governance/audit_export_token.ex:38-40` — `bypass action(:use)` gated on
  `AuditExportTokenActorOrgMatches` (SPEC-16 lane W935).
- `lib/xaas/governance/audit_export_token.ex:90-96` — `update :revoke` stamps
  `revoked_at`, validates `AuditExportTokenNotAlreadyRevoked`.
- `test/xaas_web/audit_export_token_route_collision_court_test.exs:107-108,137-138,145,167`
  — W944b court asserts the exact routes `/audit_export_tokens/:id/use` and
  `/audit_export_tokens/:id/revoke`, distinct path list, and live
  use/revoke behavior through real HTTP.
- `docs/sjira/v26.10.6/plans/w944b-route-collision.md` — W944b verdict
  RESOLVED-AT-HEAD at `fab56ae1`; F2 finding (stale controller tests) fed W959.
- `docs/sjira/v26.10.6/plans/w959-controller-repoint.md` — W959 repointed 4 controller
  test PATCH paths to `/:id/revoke`; mutation run showed bare `/:id` → 404
  `no_route_found`, 10/10 green after repoint.

## Verification

- Source read directly (full resource file, 205 lines) — route block and actions
  quoted above are at the cited lines.
- Doc edits confirmed on disk by the Edit tool's success (exact old-string matches).
- No build/test run: doc-only lane, zero lib/test delta; the guarding runs are
  W944b's and W959's already-receipted runs.

## Standing

ALIVE (doc projection synced to committed SPEC-16 surface). Falsifier:
the doc's route row drifts from
`AshJsonApi.Resource.Info.routes(Xaas.Governance.AuditExportToken)` — not observed
at this subject.
