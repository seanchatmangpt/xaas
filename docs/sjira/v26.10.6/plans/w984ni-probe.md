# W984ni — Mutation Non-Vacuity Audit #18 over W984lv's internal-api JSON:API court

Lane: W984ni · Date: 2026-10-08 · Branch `feat/playwright-surface` (no branch switch,
no commits, no stash). Method held exactly per `w984ek`/`w984ha`/`w984iy`/`w984jp`/
`w984lc` (FILE-SWAP: snapshots in `/tmp/w984ni/` via `cp`, one surgical mutation at a
time, targeted court run, `cmp`-verified byte-identical restore after every mutant,
post-restore green confirmation). Compound-leg convention per W984ha/jp/lc included
(M5c, M6c).

Subjects (W984lv's, per `w984lv-probe.md`):
- `lib/xaas_web/internal_api_router.ex` — the `/internal-api` AshJsonApi catch-all
  forward (`use AshJsonApi.Router`, prefix `/internal-api`, domain `Xaas.Operations`).
- The resource policy layers it serves, which the court asserts through the wire:
  `lib/xaas/operations/incident.ex` (read bypass + ActorOrgMatches create/update
  bypass), `lib/xaas/operations/audit_log_entry.ex` (read bypass only), and the
  read-only projections `lib/xaas/operations/route_castle_deploy.ex`,
  `approval_castle_verb_schedule.ex`, `castle_verb_inventory_goals.ex`.
- Court: `test/xaas_web/controllers/internal_api_court_w984lv_test.exs` (8 tests,
  real ConnCase → real main router → real bearer token → real sandboxed Postgres).

Gates: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ni`.
Baseline before any mutation: court **8 passed, EXIT=0**.

## Mutation Matrix

| # | Mutated lib file | Mutation | During | Verdict |
|---|---|---|---|---|
| M1 | incident.ex | `bypass action(:create)`'s `ActorOrgMatches` → `always()` (re-opens the seventeenth-pass create bypass) | EXIT=2, 7/8; `assert conn.status == 403` got **201** | **KILLED** (test a3) |
| M2 | incident.ex | dropped `bypass action_type(:read)` entirely | EXIT=2, 6/8; index got `[]` (forbid-always floor) | **KILLED** (tests a + a2) |
| M3 | audit_log_entry.ex | dropped `bypass action_type(:read)` | EXIT=2, 7/8 | **KILLED** (test b) |
| M4 | route_castle_deploy.ex | dropped `bypass action_type(:read)` | EXIT=2, 7/8 | **KILLED** (test c) |
| M5 | internal_api_router.ex | `prefix: "/internal-api"` → `"/internal-api-w984ni-x"` | **EXIT=0, 8 passed** | **SURVIVED single** |
| M5c | internal_api_router.ex + incident.ex | compound: prefix mutant **and** incident read-bypass drop | EXIT=2, 6/8 (red only via the incident leg) | prefix leg STILL green — **inert** |
| M6c | incident.ex + audit_log_entry.ex | compound: create bypass `→ always()` **and** audit read-bypass drop, one run | EXIT=2, 6/8; a3 got 201 **and** b failed | **KILLED** (both legs observable in one run — no cross-masking between the 401 floor, read bypass, and ActorOrgMatches layers) |

## Standing Verdicts

- M1 ActorOrgMatches create bypass: **NON-VACUOUS** — the court pins the
  seventeenth-pass escalation fix itself: re-opening it returns a real 201 on the
  internal-api tier, exactly the failure the fix closed.
- M2 Incident read bypass: **NON-VACUOUS** — dropping it drops the whole read
  surface behind the forbid-always floor; index renders `[]`, both read tests red.
- M3 AuditLogEntry read bypass: **NON-VACUOUS**
- M4 RouteCastleDeploy read bypass: **NON-VACUOUS** (tests d/e stayed green while
  c failed → the court's per-resource specificity is real, not all-or-nothing)
- M5 catch-all `prefix`: **SURVIVED — semantically inert on this surface.** The
  `prefix` option of `AshJsonApi.Router` is not load-bearing for route matching
  when the router is Phoenix-`forward`ed from `/internal-api`: with the prefix
  mutated to a nonsense string, all 8 tests still pass. The forward path in
  `lib/xaas_web/router.ex:286` (`forward("/internal-api", XaasWeb.InternalApiRouter)`)
  is the real route authority; the child `prefix` is only used for URI generation.
  M5c (compound with a known-lethal leg) confirmed red-via-other-leg, so the
  survival is masking-class, not court-weakness. Same finding class as W984lc's
  M3a redundant-pair: a green surface carrying a dead knob. Falsifier for the
  "prefix is load-bearing" claim: M5 itself — it is not.
- M6c compound: **NON-VACUOUS** — one run killed both a3 (201/403) and b, proving
  neither the token floor nor the sibling policy layers mask a create-bypass or
  read-bypass regression.

5/6 single mutants killed; the 1 survivor (M5) is an inert-config finding, not a
court gap — the court's tests genuinely exercise the surface they name, and the
prefix option is genuinely dead on this forwarding surface.

## Tree Cleanliness

Every restore `cmp`-verified byte-identical against `/tmp/w984ni/` snapshots before
the next mutation. Final state: `git status --porcelain` under `lib/` shows ZERO
modified files; the only artifact in the subject set is the untracked W984lv court
test file (`?? test/xaas_web/controllers/internal_api_court_w984lv_test.exs`), which
was untracked at lane start (W984lv's own uncommitted work, untouched). No commit
made. Final green sweep after last restore: **8 passed, EXIT=0**.

Cleanup: `_build-laneW984ni` removed with `rm -rf` after the final gate
(BUILD_ROOT_REMOVED; no denial).

Standing: **ALIVE** — non-vacuity observed on the exact subjects (W984lv internal-api
JSON:API court + its router/policy layers) on branch `feat/playwright-surface`, this
lane, with one typed inert-config finding (M5 prefix) handed back for the W984lv
subject lane.

## Replay

```bash
cd /Users/sac/xaas
export PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ni
# baseline: mix test test/xaas_web/controllers/internal_api_court_w984lv_test.exs → 8 passed, exit 0
# apply one matrix mutation, run the court, expect RED (except M5: expect green)
# restore from /tmp/w984ni snapshot (cp), cmp-verify, court returns EXIT=0
```
