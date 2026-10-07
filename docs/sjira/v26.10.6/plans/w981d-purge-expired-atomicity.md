# W981d — purge_expired atomicity (strict-sweep Exclusion 2 removal)

Lane W981d, v26.10.6 campaign, repo `/Users/sac/xaas`, branch
`feat/playwright-surface` (uncommitted lane work, NOT committed per dispatch).
Parent finding: `docs/sjira/v26.10.6/plans/w946e-strict-sweep.md` (Exclusion 2).

## Scope / files touched

Write scope honored: `lib/xaas/platform/` + `test/xaas/platform/` + this
receipt only.

- `lib/xaas/platform/validations/route_projects_backups_retain_until_passed.ex`
  — added `atomic/3` (Ash expr: refuse when `retain_until` absent
  (fail-closed) or `> now()`), so the validation no longer forces
  `:purge_expired` to be non-atomic. Non-atomic `validate/3` retained for
  the per-row changeset path.
- `lib/xaas/platform/route_projects_backups.ex`
  - `destroy :purge_expired` gained explicit `require_atomic?(true)` and a
    set-based description.
  - `:purge_expired` policy bypass switched from the SimpleCheck
    `ActorOrgMatches` (whose `requires_original_data? -> true` cannot be
    converted to a filter check, blocking atomic bulk) to an equivalent
    expr check `authorize_if(expr(org_id == ^actor(:org_id)))` — same
    fail-closed org-match semantics, filter-check-convertible. `:create`
    still uses `ActorOrgMatches` unchanged.
- `test/xaas/platform/purge_expired_atomicity_court_test.exs` (NEW court)

## Before / after

BEFORE (W946e real tail):
```
warning: [Xaas.Platform.RouteProjectsBackups]
  actions -> purge_expired : cannot be done atomically
    (changes [Xaas.Platform.Validations.RouteProjectsBackupsRetainUntilPassed])
```
Purge was operator-row-coupled: caller read a row, then per-row
`for_destroy`.

AFTER: `Ash.bulk_destroy!(Query |> filter(org_id, retain_until <= now),
:purge_expired, %{}, strategy: [:atomic])` — a single set-based DELETE
backed by a server-side atomic validation. No per-row operator read.

## Court (Chicago — state assertions, not call counts)

`test/xaas/platform/purge_expired_atomicity_court_test.exs`, 4 cases:
1. Bulk purge of 2 expired rows: `bulk.status == :success` with strategy
   pinned `[:atomic]` (success itself proves atomic capability); expired
   rows really gone from disk; non-expired row fully intact; cross-org row
   untouched.
2. No-match bulk purge: success, zero rows affected, survivors intact.
3. Per-row path still refuses a not-yet-expired row (typed
   `Ash.Error.Invalid`, row survives) — atomic validation preserves the
   fail-closed rule.
4. Cross-org bulk attempt: typed refusal (`status == :error`, exactly
   `[%Ash.Error.Forbidden{}]`), victim row survives. Behavior determined
   empirically (two prior assertions corrected against real output, not
   assumed).

## Commands and real tails

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW981d \
    mix test test/xaas/platform/purge_expired_atomicity_court_test.exs \
             test/xaas/platform/platform_route_deepening_test.exs
Result: 24 passed
```

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW981d \
    mix compile --force --warnings-as-errors   # exit 0
    sole warning: ash_affidavit lib/ash_affidavit/signing.ex:312
    @envelope_domain_tag (dep-side, pre-declared Exclusion 1)
    zero purge_expired / route_projects_backups findings
```
Full log: `/tmp/w981d_strict.log`.

Notes on the shared tree: two earlier full-force attempts hit other lanes'
in-flight edits (`lib/xaas/bridges/graphlaw.ex` TokenMissingError;
`lib/xaas/security/finding.ex`; `lib/xaas/generated/regen_check.ex`;
a Conference `unique_attendee_session` pre_check_with DslError) — all
transient, resolved by their owners while this lane waited; the final run
above is clean. Not session-introduced by W981d.

## Standing

ALIVE for the lane subject (uncommitted working-tree diff):
`purge_expired` is a single atomic set-based bulk destroy, strict Exclusion 2
is removed — full-force strict compile now carries only the dep-side
ash_affidavit exclusion. 24/24 platform tests green on the exact subject.

- W946e falsifier update: any lib/ strict-compile warning other than
  Exclusion 1 (ash_affidavit dep) on a committed HEAD now falsifies the
  strict gate.
- Cleanup: `_build-laneW981d` deletion DENIED by the permission system in
  this lane session (same as W946e) — LEFT FOR COORDINATOR to delete at
  integration (lane-lease law).
- NOT committed; coordinator owns the integration commit.
