# W984j — Manifest v3 staging extension 2 (manifest update receipt)

Date 2026-10-07. Repo `/Users/sac/xaas`, branch `feat/playwright-surface`,
HEAD `1f2a2b23`. Lane W984j. No commits, no git write ops; wrote
`_COMMIT_MANIFEST_W850.md` (v3 extension 2) + this receipt only. No mix commands.

## Method

Fresh enumeration, not briefing-trusted: `git log --format='%h %ad %s' --date=short
84a5ef51~1..HEAD` (13 commits since base); `git show --stat` per new commit;
`git rev-parse origin/feat/playwright-surface` and `git rev-list origin/..HEAD`
for push state; owner receipts read on disk (w982b-integration-commits.md,
w982k-spec07-integration.md, w983i-migration-integration.md). Owner-receipt
existence checks via `ls docs/sjira/v26.10.6/plans/`.

## Enumerated table (real git log; briefing list confirmed with 2 corrections)

13 commits since 84a5ef51 (base already recorded). Oldest→newest; the first 4
were staged in extension 1 (W981u) and are not restaged.

| # | SHA | subject (truncated) | ext |
|---|---|---|---|
| 1 | fc14f10b | fix(platform): RouteProjects :create in SystemActor map (w969c completion) | ext2 #1 |
| 2 | 39c405fc | fix(billing): SPEC-07 W970a half, attribute-strategy multitenancy (w982k) | ext2 #2 |
| 3 | bf9f5cb9 | test(billing): SPEC-07 court + tier controller fixture (w982k) | ext2 #3 |
| 4 | 691e0a93 | feat(graphql): SPEC-30 GraphQL-over-HTTP mount (w975b via w982b) | ext2 #4 |
| 5 | ddb19522 | fix(billing): land W970a SPEC-07 (fix-forward of 691e0a93 sweep) | ext2 #5 |
| 6 | 39e9d77f | feat(graphql): SPEC-31 domain wiring (w973c via w982b) | ext2 #6 |
| 7 | f9c4f090 | feat(graphlaw): W976 LimitGate (via w982b) | ext2 #7 |
| 8 | 49a719ab | docs(sjira): w982b integration commits receipt | ext2 #8 |
| 9 | 1f2a2b23 | feat(migrations): migration corpus (w983i integration) — HEAD | ext2 #9 |
| — | 68a5c9f9 | ash_surface regen 418 entrypoints | already ext1 |
| — | 4546f96a | w981 enoent court NO-OP + w896b plan | already ext1 |
| — | 6f235905 | semantics @doc dedup (w946d via w981h) | already ext1 |
| — | 84a5ef51 | castle-bridge pin advance | already-recorded base |

Briefing corrections found during verification:
1. Briefing implied all of 4546f96a/6f235905/68a5c9f9 etc. were unpushed;
   actually the push has advanced — origin = **6f235905**, so only
   39c405fc..1f2a2b23 (8 commits) are unpushed. fc14f10b and earlier are pushed.
2. Briefing did not name fc14f10b; real log shows it between 84a5ef51 and 68a5c9f9.

## Group mapping summary (ext2 rows)

- CG-02 (billing/migrations): 39c405fc, bf9f5cb9, ddb19522, 1f2a2b23
- CG-11-adjacent (web/GraphQL surface): 691e0a93, 39e9d77f
- CG-14 (sjira plans receipt blanket): 49a719ab
- CG-12-adjacent (platform/checks lib): fc14f10b
- NEW-GROUP → CG-18 (graphlaw bridge enforcement): f9c4f090
  (68a5c9f9 was NEW-GROUP → CG-17 in ext1.)

## Gates attested (from on-disk receipts)

- w982k (39c405fc/bf9f5cb9): fresh-lane strict compile EXIT=0 (942 files);
  mix test 57 passed 0 failures; court re-witnessed 5/5 post-integration.
- w982b (691e0a93/ddb19522/39e9d77f/f9c4f090): SPEC-30/31 + W976 + W970a ALIVE,
  courts passed at HEAD; full-tree strict compile EXIT=0 (disclosed dep-only
  ash_affidavit warning, non-fatal); full billing court run excluded to owner
  lane (disclosed).
- w983i (1f2a2b23): fresh-lane strict compile EXIT=0 (212 lib artifacts);
  migration/replay/consistency courts 9 passed; migration version uniqueness
  verified.
- fc14f10b: no dedicated receipt; commit-only attestation, compile-neutral
  (+3 lines).

## Delta summary

- 9 new commits staged (ext1's 3 + 9 = 12 committed since 84a5ef51 base, plus
  base itself = 13 in log range).
- Ext-1 pending-integration rows resolved by these commits: W976 LimitGate
  (f9c4f090), W975b SPEC-30 (691e0a93), 2 of 3 migration guards (1f2a2b23) +
  org_id migration (ddb19522).
- Pending-integration table updated: SPEC-07 second half IN FLIGHT (W983o, no
  receipt on disk); conference/identity corpus IN FLIGHT (W983j/W984c, no
  receipts on disk; conference registration.ex [M] + enrollment court [M] in
  tree); docs/receipts corpus STILL PENDING (W983m in flight; docs/airo/ [??],
  airo-wiring-ledger.md [M], diataxis refs [M] still uncommitted).
- W982b shared-index incident (691e0a93 swept a staged SPEC-07 rollback;
  fixed forward in ddb19522; subsequent commits explicit-pathspec) recorded as
  a manifest process note citing the standing rules (xaas-concurrent-sessions /
  no-stash-baselining-xaas).
- Push state: origin advanced a0723bf6 → 6f235905 since ext1; push in-flight
  per W984d (no w984d receipt on disk at read time); 8 commits unpushed.

## Standing

- Manifest v3 ext 2: **ALIVE as staging**.
- Commit execution / push: UNKNOWN / IN FLIGHT — coordinator-owned.
- Falsifier: any row re-enumerable by `git log 84a5ef51~1..HEAD` disagreeing
  with the table above.
