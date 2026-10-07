# W805 — JSON:API Composed-Surface Court (InternalApiRouter + ApiRouter)

- **Lane**: W805, xaas v26.10.6 campaign
- **Repo**: /Users/sac/xaas (canonical checkout, branch `feat/playwright-surface`, HEAD a0723bf6)
- **Status**: ALIVE (7/7 real test executions, real HTTP, real sandboxed Postgres)
- **Date**: 2026-10-07

## Task

The two generated AshJsonApi routers (`lib/xaas_web/internal_api_router.ex`
(prefix `/internal-api`, domain `Xaas.Operations`) and `lib/xaas_web/api_router.ex`
(prefix `/api`, 7 domains)) were undocketed as a composed surface. Dock them with
one Chicago-style court file, cross-checking the W733/W739/W743 patterns over the
real generated surface. Routers read, not edited (generated surface — do not
hand-edit).

## What was built

New file (the only file written):
`test/xaas_web/json_api_surface_court_test.exs`
(module `XaasWeb.JsonApiSurfaceCourtTest`, 7 tests)

Coverage mapped to the brief:

| Brief | Court | Probe |
|---|---|---|
| (a) one representative READ per router | 2 tests | Real ingest via `CapabilityLivenessReceipt` `:ingest` (authorize?: false) + real `GET /internal-api/capability_liveness_receipts?filter[capability]=…` and `GET /api/capable...` returns real json-api doc: `data[0].type == "capability_liveness_receipts"`, real `id`, real attributes (`capability`/`status`/`subject`), `is_map(body["links"])` asserted on both routers |
| (b) W743 cross-check: non-special /api resource without X-Org-Id | 1 test | `GET /api/capability_liveness_receipts` with the bearer token and NO `X-Org-Id` header → real 200; resource segment not in `ResolveOrgActor`'s `@tenant_scoped_path_segments` — the documented pass-through, asserted over real HTTP |
| (c) W733 org-forgery refusal, over real HTTP | 1 test | Two real `Org` rows A/B; `POST /api/marketplace_providers` with real `X-Org-Id: org-A-slug` but body attribute `org_id == org B's slug` → real 403 from `Xaas.Marketplace.Checks.ActorOrgMatches`; also asserts nothing persisted (`Ash.read!` filter `name == "Impostor"` == `[]`) |
| (d) W739 floor-first ordering | 1 test | Unauthenticated `GET /internal-api/capability_liveness_receipts` with `Accept: application/vnd.api+json` → real 401, `refute 406` |
| (e) determinism ×2 | 2 tests | (a)-/api read and the (d) floor probe each replayed twice within one test; identical status AND byte-identical `resp_body` asserted |

Note on the (c) probe: `org_id` is a loose string attribute (deliberately no
`belongs_to :org` — see `Xaas.Marketplace.Checks.ActorOrgMatches` moduledoc),
so the forgery is a body attribute forgery, not a relationship forgery. Same
refusal class as W733's pattern.

## Real commands + tails (final green run, run 4)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW805 \
  INTERNAL_API_TOKEN=w805-lane-token mix test test/xaas_web/json_api_surface_court_test.exs

Running ExUnit with seed: 417147, max_cases: 32
Excluding tags: [:stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api, :external, :external_llm, :subprocess, :property, :castle_kernel, :eu_ai_act]

.......
Finished in 0.9 seconds (0.00s async, 0.9s sync)

Result: 7 passed
```

Earlier runs (honest ladder):
1. Run 1: never reached tests — fresh lane build root full compile hit a
   type-check error in `lib/xaas/operations/validations/incident_resolved_is_terminal.ex`
   (`Ash.Changeset.OriginalDataNotLoaded` struct undefined). That file was
   **deleted from the working tree by another concurrent lane mid-compile**
   (it no longer exists on disk; only `incident_resolved_requires_resolved_at.ex`
   remains). Pre-existing/other-lane failure, not session-introduced by W805.
   Deps + 929-file xaas compile then completed on retry.
2. Run 2: compile error in MY file — `Ash.Query.filter(name == "Impostor")`
   without `require Ash.Query` (undefined variable `name`). Fixed: added
   `require Ash.Query`.
3. Run 3: 6/7 — same macro-vs-function issue surfaced at runtime
   (`Ash.Query.filter/2` undefined as a function under a stale .beam of the
   test module). Fixed: kept `require Ash.Query`, restored expression syntax
   (keyword form hits the non-macro `filter/2`).
4. Run 4 (final): 7/7 passed, 0 warnings attributable to the new file.
   Full log: /tmp/w805_run4.log

## Standing

| Item | Standing |
|---|---|
| New court file (7 tests, Chicago-style, zero mocks) | ALIVE (run 4, seed 417147, 0.9s) |
| `/internal-api` read surface (json-api doc shape) | ALIVE (witnessed) |
| `/api` read surface (json-api doc shape, same resource on both routers) | ALIVE (witnessed) |
| W743 pass-through (non-special /api resource without X-Org-Id → 200) | ALIVE (witnessed) |
| W733 org-forgery refusal over real HTTP (Provider :create) | ALIVE (witnessed, 403 + no persistence) |
| W739 floor-first on /internal-api (401 not 406, vnd.api+json) | ALIVE (witnessed) |
| Determinism (read + floor probes, ×2 byte-identical) | ALIVE (witnessed) |
| `_build-laneW805` build root | BLOCKED-CLEANUP: `rm -rf` denied by the permission system; `_build-laneW805` (~400 MB) left in place for coordinator deletion at integration (fanout lane-lease law: coordinator deletes lane build roots). |

## Typed gaps

- `Ash.Query.filter` macro-vs-function trap: the keyword-list form calls the
  non-macro `filter/2` function which is undefined-or-private in ash 3.34.4;
  the court pins the expression form behind `require Ash.Query` — recorded so
  the next court author doesn't burn the same two runs.
- Run-1 failure subject was transient tree state (another lane's mid-flight
  deletion of `incident_resolved_is_terminal.ex`); that file is now gone from
  the tree, so the run-1 BLOCKED cannot be replayed — UNKNOWN whether the
  type-check failure reproduces on the tree as it now stands.
- Routers were read, not modified (generated surface). A route-inventory
  diff court (every declared json-api route vs a docked enumeration) remains
  UNSUPPORTED(out-of-scope) here — not attempted.
- INTERNAL_API_TOKEN for the lane was supplied as a per-run env value
  (`w805-lane-token`), matching the existing `internal_api_router_test.exs`
  pattern (`System.fetch_env!`).
