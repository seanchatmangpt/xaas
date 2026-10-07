# W946e — Strict-Compile Sweep (post-W946d)

Lane: W946e, v26.10.6 campaign, repo `/Users/sac/xaas`, branch `feat/playwright-surface` (uncommitted lane work).
Parent finding: `docs/sjira/v26.10.6/plans/w946-postcommit-gate-2.md`.

## Scope

Fix remaining REAL strict-compile HEAD blockers in `lib/` after W946d's
dataset_admission @doc fix. Documented exclusions (per dispatch):

- `dep: ash_affidavit` unused module attribute (`signing.ex:312
  @envelope_domain_tag`) — dep-side, not root-gated.
- `Xaas.Platform.RouteProjectsBackups.purge_expired` non-atomic warning —
  operator-row-coupled, skipped by order.

`lib/xaas/semantics/dataset_admission.ex` skipped (concurrent lane W946d).

## Result: ZERO new fixes required

Sweep finding: no remaining real `lib/` strict-compile blockers beyond the two
documented exclusions. Candidate list from dispatch (audit-export-token routes /
SPEC-16 conflict, w902 incident validations, capability_liveness_regressions
W978 syntax) — none materialized as strict-compile failures.

## Evidence

### Strict compile

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW946e \
    mix compile --force --warnings-as-errors
```

Full-force run completed; incremental strict rerun (real exit code):

```
MIX_EXIT=1
==> ash_affidavit
  warning: module attribute @envelope_domain_tag was set but never used
    lib/ash_affidavit/signing.ex:312
==> xaas
  warning: [Xaas.Platform.RouteProjectsBackups]
    actions -> purge_expired : cannot be done atomically
      (changes [Xaas.Platform.Validations.RouteProjectsBackupsRetainUntilPassed])
Compilation failed due to warnings while using the --warnings-as-errors option
```

The ONLY two findings are the two pre-declared exclusions. No `lib/xaas`
finding outside the excluded `route_projects_backups.ex` purge_expired
operator-row item. W944b distinct-route fix landed (no route-conflict
warnings); W978 syntax fix confirmed good.

### Mutation rationale

N/A — no fixes landed, so there is nothing to revert. The gate stands as-is:
reverting nothing changes nothing. Standing of the strict gate is carried by
W946d's dataset_admission fix plus the exclusions above.

### Test sanity

```
$ MIX_ENV=test MIX_BUILD_ROOT=_build-laneW946e mix test test/xaas/semantics/ test/xaas/governance/
Finished in 7.6 seconds (3.9s async, 3.6s sync)
Result: 365 passed (9 doctests, 356 tests), 1 skipped, 20 excluded
PIPE_EXIT=0
```

## Standing

PARTIAL_ALIVE — strict compile exits clean for `lib/` root subject except the
two declared non-root-gated / operator-coupled exclusions; semantics +
governance suites green on the exact working-tree subject (uncommitted, shared
with other W946 waves).

- Exclusion 1 (ash_affidavit dep attribute) — not root-gated, remains.
- Exclusion 2 (purge_expired non-atomic) — operator-row-coupled, remains;
  owned by the operator-row lane.

Cleanup: `_build-laneW946e` deletion was denied by the permission system in
this lane session — LEFT FOR COORDINATOR to delete at integration (lane-lease
law: it is a lease, not an asset).

Falsifier for this lane: any lib/ strict-compile warning other than the two
exclusions appearing on a committed HEAD after W946d lands.
