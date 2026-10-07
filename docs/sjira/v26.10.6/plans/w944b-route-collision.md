# W944b — Route-collision court for `AuditExportToken` :use/:revoke (v26.10.6)

**Verdict: RESOLVED-AT-HEAD.** W940b's distinct subpaths
(`patch(:use, route: "/:id/use")`, `patch(:revoke, route: "/:id/revoke")`) are
committed at HEAD `fab56ae1` and verified live. **No committed regression.**
One pre-existing defect found (below, F2 — stale controller tests), out of
lane write-scope, for the coordinator.

## Subject

- Repo `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `fab56ae1`
  (working tree carries other lanes' uncommitted changes; none in
  `lib/xaas/governance/audit_export_token.ex` — file clean vs HEAD).
- Lane W944b, build root `_build-laneW944b` (deleted after run).

## (a) Real compile

```
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW944b mix compile --warnings-as-errors
→ EXIT:1 — "Compilation failed due to warnings" — PRE-EXISTING, committed:
  lib/xaas/semantics/dataset_admission.ex:137 — "@doc redefined, previously
  set at line 132" (last touched by committed 297da2f1; not a W944b file).
```

Without `--warnings-as-errors` the app compiles (934 files, xaas app
compiled and test tree compiled+ran cleanly under this build root).

## (b) Route introspection (real)

`AshJsonApi.Resource.Info.routes(Xaas.Governance.AuditExportToken)`:

```
method :patch  route "/audit_export_tokens/:id/use"    action :use
method :patch  route "/audit_export_tokens/:id/revoke" action :revoke
```

Exactly one PATCH route per action, zero duplicate (method, path) pairs.
Note: `XaasWeb.ApiRouter` (AshJsonApi.Router) compiles a single catch-all
`match` and dispatches at runtime, so `__routes__/0` introspection of the
Phoenix router is undefined there — the runtime match table IS the resource
route table over `ApiRouter.domains()`, which the court introspects.

## (c) The court (new file)

`test/xaas_web/audit_export_token_route_collision_court_test.exs` — 3 layers:

1. Resource route table: exactly one PATCH route per action; zero duplicate
   (method, path) pairs; :use → `/:id/use`, :revoke → `/:id/revoke`.
2. Runtime match table over `ApiRouter.domains()`: mount non-empty, zero
   duplicate (verb, path) pairs, PATCH surface pinned to exactly
   `["/api/audit_export_tokens/:id/revoke", "/api/audit_export_tokens/:id/use"]`.
3. Real HTTP probes (full pipeline: internal-api bearer token floor, org
   actor resolution): `PATCH /api/audit_export_tokens/:id/use` → 200,
   `used_at` stamped, `use_count == 1` (persisted assert);
   `PATCH .../:id/revoke` → 200, `revoked_at` stamped (persisted assert).

```
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW944b mix test \
  test/xaas_web/audit_export_token_route_collision_court_test.exs
→ "Result: 4 passed" EXIT:0
```

## (d) Real HTTP probe — confirmed in layer 3 above (real ConnCase requests).

## Finding F2 (pre-existing, out of lane scope): stale controller tests

`test/xaas_web/controllers/audit_export_token_controller_test.exs` still
PATCHes the bare `/:id` path (the pre-W940b shadowed surface). At HEAD:

```
mix test test/xaas_web/controllers/audit_export_token_controller_test.exs
→ Result: 7/10 passed, Failed: 3 — all three :revoke tests now get real
  404 no_route_found (W940b moved :revoke to /:id/revoke):
  - :187 "revokes a real token from the matching org"  → expected 200, got 404
  - :212 "rejects revoking a token whose org_id does NOT match" → expected 403, got 404
  - :240 "rejects revoking an already-revoked token" → expected 400, got 404
```

Not a route collision — the W940b fix shipped without updating the
pre-existing court's request paths. Repair is a 3-line repoint to
`/:id/revoke` in that file; left to the coordinator/owning lane (outside
W944b's write scope).

## Receipt fields

- **μ/diff**: 1 new file `test/xaas_web/audit_export_token_route_collision_court_test.exs`
  (handwritten, ~185 lines) + this receipt. No lib changes.
- **Commands/exits**: compile `--warnings-as-errors` EXIT:1 (pre-existing
  warning, F0 above); court test EXIT:0 (4/4); controller test EXIT:2 (3
  pre-existing failures, F2).
- **Verification ladder**: narrow (route table) → unit (runtime match
  table) → integration (real HTTP through token+org pipeline).
- **Standing**: court test ALIVE on exact subject HEAD `fab56ae1` +
  working-tree test tree; verdict RESOLVED-AT-HEAD.
- **Falsifiers**: F0 compile warning (pre-existing, committed);
  F2 stale :revoke paths in pre-existing controller court (pre-existing).
- **Replay**: commands in sections (a)/(c)/(d) above with
  `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`,
  `MIX_BUILD_ROOT=_build-laneW944b` (lane root deleted after run — rebuild
  with the same env to replay).
