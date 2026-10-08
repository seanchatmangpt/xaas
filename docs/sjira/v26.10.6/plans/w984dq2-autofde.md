# W984dq2 — AutofdePlanner connector depth court

Lane W984dq2, xaas v26.10.6 campaign, canonical checkout `/Users/sac/xaas`,
branch `feat/playwright-surface`. No commits (lane law). Wrote only:
`test/xaas/operations/autofde_planner_connector_depth_test.exs` + this receipt.

## Assignment resolution

W984dk census: 5 Operations modules UNKNOWN. W984cw4's receipt
(`w984cw4-ops-probe.md`) took `RefusalLedgerExport` (COURTED, 5-test depth
court) and explicitly left the `AutofdePlanner{CacheHotset,CacheStats,Match,
Catalog}` slice "for a later lane" → this lane's slice.

## Census (module surface)

Four sibling connector resources, 135–137 LOC each (542 LOC total), one shared
surface shape (differing only in tool name and `Match`'s `domain` argument):

- `lib/xaas/operations/autofde_planner_catalog.ex` — `:request_catalog` → `fabric__catalog`
- `lib/xaas/operations/autofde_planner_cache_stats.ex` — `:request_cache_stats` → `fabric__cache-stats`
- `lib/xaas/operations/autofde_planner_cache_hotset.ex` — `:request_cache_hotset` → `fabric__cache-hotset`
- `lib/xaas/operations/autofde_planner_match.ex` — `:request_match` → `fabric__match` (query → `arguments.domain`)

(`AutofdePlannerCandidate` is NOT in scope — it has a real dedicated court,
`autofde_planner_candidate_test.exs`, plus the cross-product integration test.)

Prior coverage: policy/authority mapping only, in
`test/xaas/system_authority_service_scope_test.exs` (lines 65–94: exact-subject
SystemActor mapping enumeration). Zero module-depth coverage of: persistence
invariants, wire dispatch, or the four typed failure classes.

### Excluded from court scope (not state-bearing invariants)

- `last_json_object/1` noise-extraction edge (stdout starting directly with
  `{\n` with no noise) — exercised via the noise-payload path in test 1; the
  no-noise branch is a string-prefix variant of the same predicate.
- `AutofdePlannerCandidate`'s `trajectory_sha256` solve path — Candidate's own
  court covers it; these four tools emit no digest (asserted nil in test 1).

## The court — 5 tests, real invariants, per-test mutation rationale

`test/xaas/operations/autofde_planner_connector_depth_test.exs`.
Chicago: every collaborator real — a real in-test `Bandit` HTTP listener
speaks cnv-deploy's real `/invoke` wire contract; `Req` does a real loopback
HTTP round-trip; real Ash creates into real Postgres (real migrations back
each table); real `Xaas.Checks.SystemActor` policy check. `async: false`
(global `Application.put_env` for `:cnv_deploy_base_url`, restored in
`on_exit`).

1. **Success persistence invariants ×4 resources** — real 200 envelope whose
   stdout carries frozenset/`{`-bearing log-noise before the trailing
   `indent=2` JSON payload: `cnv_response` is the decoded trailing payload
   (kills first-`{` mutants), `requested_at` set, `trajectory_sha256` stays
   nil (kills invented-digest mutants for non-solve tools).
2. **Per-resource wire dispatch** — captured real request bodies: exact tool
   per resource (`fabric__catalog` / `-cache-stats` / `-cache-hotset` /
   `-match`); `Match` sends `arguments == %{"domain" => "blocks"}`, the other
   three send `%{}` (kills wrong-tool and dropped-domain mutants).
3. **Nonzero exit_code typed failure** — `fabric__<tool> exited 2: domain not
   found…` surfaces as an Ash invalid error and no row is persisted (kills
   swallow-exit-code mutants).
4. **Three real failure classes, each typed, none persisted** — (a) non-200 →
   "returned status 500"; (b) 200 with malformed envelope → "unexpected
   cnv-deploy /invoke response shape"; (c) unreachable server → "request
   failed". Row count unchanged across all three.
5. **Deny-by-default floor** — foreign actor create → `%Ash.Error.Forbidden{}`;
   SystemActor bypass admits (test 1 exercises it end-to-end). Kills a mutant
   reverting the XAAS-2602 `SystemActor` predicate to bare `always()`.

## Verification (real commands, real output)

Pinned toolchain (`PATH=$HOME/.asdf/shims:$PATH`), `MIX_ENV=test`,
`MIX_BUILD_ROOT=_build-laneW984dq2`:

- Run 1 (fresh root, full rebuild ~25 min): 4/5 failed — lane bugs (plug
  respond-clause normalization, stale inline server in test 2, case-sensitive
  forbidden-message assert). Fixed in-place, same file.
- Run 2 (warm root): `4/5 passed, Failed: 1` → test 2 double-server bug
  (`start_cnv_server!` overwrote the capture server's env). Fixed.
- Run 3 (warm root): **`5 passed`** — `Result: 5 passed`, EXIT=0
  (/tmp/w984dq2-run3.log).

### Fresh-root gate (×2, final file) — PASSED

- Fresh root #1 (`MIX_BUILD_ROOT=_build-laneW984dq2-fresh1`, full dependency +
  app rebuild): `Result: 5 passed`, EXIT=0 (/tmp/w984dq2-fresh1.log, EXIT line
  5305).
- Fresh root #2 (`MIX_BUILD_ROOT=_build-laneW984dq2-fresh2`, full dependency +
  app rebuild): `Result: 5 passed`, EXIT=0 (/tmp/w984dq2-fresh2.log).

## Incidents

- `rm -rf` of the stale `_build-laneW984dq2` (pre-fix court) was denied by the
  permission system; fresh-root runs therefore use `-fresh1`/`-fresh2` build
  roots. Lane build roots left for coordinator cleanup per the task brief:
  `_build-laneW984dq2`, `_build-laneW984dq2-fresh1`,
  `_build-laneW984dq2-fresh2` (all three exist on disk; the first contains the
  pre-fix court build, so coordinator should delete, not reuse, it).

## Standing

- `AutofdePlannerCatalog`, `AutofdePlannerCacheStats`,
  `AutofdePlannerCacheHotset`, `AutofdePlannerMatch`: **PARTIAL_ALIVE →
  ALIVE-tested at module depth** (fresh-root ×2 gate passed, see above).
- Operations-family UNKNOWN census: 5 → 0 at module depth this slice
  (RefusalLedgerExport by W984cw4, these four by W984dq2).

## Falsifiers (what would kill this receipt)

- A mutant dropping `requested_at`, inventing `trajectory_sha256`, swapping
  any tool name, dropping Match's `domain`, admitting any of the four typed
  failure classes, or reverting `SystemActor`→`always()` passes the court.
- The fresh-root gate fails (order-dependent app-env or port contamination).
