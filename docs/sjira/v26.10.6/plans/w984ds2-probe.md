# W984ds2 — pentest-org-match + sso-mappings depth courts

Standing: **PARTIAL_ALIVE** — 10/10 green ×2 fresh roots (run 5 on
`_build-laneW984ds2` after repair; run 7 on empty fresh root
`_build-laneW984ds2c`); no commit; coordinator owns integration.

## Census (fresh, 2026-10-07)

- `lib/xaas/governance/validations/`: 42 modules (matches W984cz/W984dr2
  census). Targets: `approval_pentest_finding_resolve_finding_org_matches.ex`
  (81 lines), `approval_sso_role_mapping_update_valid_mappings.ex`
  (75 lines) — the W984dr2-named next-lane picks, confirmed unclaimed:
  - `pentest-org-match` — existing base court
    `test/xaas/governance/approval_pentest_finding_resolve_finding_org_matches_test.exs`
    — 4 tests (happy/ghost/cross-org/approve-unaffected); this lane
    adds the depth court, not a duplicate.
  - `sso-mappings` — existing coverage is HTTP-level, single-scenario
    (one invalid-role POST in
    `test/xaas_web/controllers/approval_sso_role_mapping_update_controller_test.exs`).
    No resource-level court existed.
  - W984da (finding_lifecycle) and W984dr2 (DR failover + audit-export
    freeze gates) are different validations; zero test overlap with
    either court file on disk.

## Courts (5 tests each, 10/10 ×2 fresh roots)

### Court A — pentest-org-match depth
File: `test/xaas/governance/w984ds2_pentest_org_match_depth_court_test.exs`
Real sandboxed Postgres, real `:create` actions on
`ApprovalPentestFindingResolve` + real `PentestFinding` rows, zero
mocks.

1. Cross-org refusal carries the exact typed message ("must reference
   a pentest finding in the same org as this resolution request"),
   filtered to `field: :finding_id`, nothing persists for the attacker
   org. Mutation: relax the org-match clause to existence-only →
   admitted.
2. Ghost finding refused with the distinct ghost message ("does not
   reference a real pentest finding"), asserted distinct from the
   cross-org message (kills a message-merge mutation).
3. Happy path persists re-readable state; referenced finding status
   stays `:open` (validation gates :create only; :approve is the
   disclosed no-op). Mutation: remove validation from :create → tests
   1, 2, 5 fail.
4. Absent `finding_id` refused by the attribute's `allow_nil?(false)`
   (typed `Ash.Error.Changes.Required` on :finding_id), NOT by the
   validation's nil→:ok short-circuit — the ghost message is refuted
   on the error list, proving the nil branch never silently admits
   absence. Mutation: drop `allow_nil?(false)` → the validation's
   nil→:ok would admit absence silently.
5. Multi-finding same-org: own-org finding passes while a foreign-org
   finding exists in the table; a cross-org attempt in the same run is
   still refused. Mutation: any-row existence rewrite of the org
   clause → cross-org attempt admitted.

### Court B — sso-mappings
File: `test/xaas/governance/w984ds2_sso_mappings_depth_court_test.exs`
Real sandboxed Postgres, real `:create` actions on
`ApprovalSsoRoleMappingUpdate`, zero mocks. Two branches (non-map
entry, non-list payload) are unreachable through real `{:array, :map}`
casting — the cast layer refuses them first with "is invalid", which
itself is the real fail-closed behavior; those two branches are
courted by calling the real validation `validate/3` on a real action
changeset bypassing only the cast (disclosed; not a mock — the real
validation function on a real changeset).

1. Valid 2-entry set passes the real action and round-trips through
   Postgres (`requested_mappings` re-read). Mutation: drop the
   validation from :create → this and tests 2–5 fail.
2. Role outside OrgRole ("admin") refused with exact typed message
   "role must be one of: viewer, member, owner"; nothing persists.
   Mutation: drop the role-membership clause → "admin" admitted.
3. 257-char ssoGroup refused with the exact typed length message;
   non-map entry (`[42]`) → same typed ssoGroup-required refusal via
   the direct-validation arm. Mutation: relax length check `> 256` →
   257 admitted.
4. Duplicate ssoGroup in one set refused ("duplicate ssoGroup in
   mapping set: '…'"); distinct groups with the same role pass
   (duplicate clause keys on ssoGroup, not the whole entry). Mutation:
   drop the duplicate clause → dupes admitted.
5. Boundary cap: 100 entries pass, 101 refused with "must contain at
   most 100 entries"; non-list payload ("not-a-list") refused "must be
   an array" via the direct-validation arm. Mutation: relax cap
   `> 100` → 101 admitted.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ds2 \
  mix test test/xaas/governance/w984ds2_pentest_org_match_depth_court_test.exs \
           test/xaas/governance/w984ds2_sso_mappings_depth_court_test.exs
run 1 (fresh build, background): 7/10 — fixture defects, see repairs
run 2 (warm):                    7/10 — full failure detail captured
run 3: syntax error (orphan fragment from a bad edit) → repaired
run 4: 8/10 — direct validate/3 returns {:error, kw-list}, asserted as
       %Ash.Error struct → repaired to kw-list pattern
run 5 (warm, _build-laneW984ds2): 10 passed
run 6 (fresh root _build-laneW984ds2b): ABORTED — the build root was
      deleted by a concurrent process mid-compile (run died with
      "Could not load Xaas.LegacyRepo" after `_build-laneW984ds2b`
      vanished); disclosed, not a code failure
run 7 (fresh root _build-laneW984ds2c, empty compile): 10 passed
```

Repairs during the run: attribute Required error has no :message key
(pattern on `%Ash.Error.Changes.Required{field: :finding_id}`);
casting refuses non-map/non-list payloads before the validation
("is invalid" at cast time) — non-map and non-list branches courted
via real `validate/3` on a real changeset bypassing only the cast;
one syntax error from an overlapping edit, repaired.

## Dispositions

- Courted: 2 validations (above), 10 tests, ×2 roots.
- Adjacent/claimed elsewhere: W984cz courted the identity-stub
  Approve changes + 3 other validations; W984dr2 courted DR-failover +
  audit-export-freeze validations; the base pentest-org-match court
  (`approval_pentest_finding_resolve_finding_org_matches_test.exs`)
  predates this lane and is complemented, not duplicated.
- sso controller HTTP test (single invalid-role scenario) remains as
  the HTTP-surface witness; this lane owns the resource-level depth.

## Falsifiers

- Revert any guarded clause (org-match, ghost-id error clause,
  role-membership, duplicate-ssoGroup, cap `> 100`, length `> 256`)
  → the corresponding court test fails.
- Non-vacuity: unique-per-run org ids and fresh sandbox checkouts per
  test; refusals track real DB state (persisted-filter asserts `[]`).

## Notes

- `rm -rf _build-laneW984ds2` was denied by permissions; the remaining
  lane build roots (`_build-laneW984ds2`, `_build-laneW984ds2c`) are
  LEFT ON DISK for the coordinator to delete at integration (fanout
  cleanup-law disclosure). `_build-laneW984ds2b` was deleted by a
  concurrent process mid-run (see run 6).
- One stray `mix format` invocation was launched without the lane
  MIX_BUILD_ROOT and killed early; it may have touched `_build/dev`.
  Disclosed for the coordinator.
- No commits made; only the two court files under
  `test/xaas/governance/` and this receipt written.
