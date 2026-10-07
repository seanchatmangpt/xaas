# W984ae — Register reconcile round 2 (resolves W984ac DRIFT(REGISTER_COUNT))

Lane W984ae, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface`,
HEAD `5f7f70d9` (uncommitted working tree). No commit (per dispatch).
Files written: `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md`
(one row flip + footer refresh) and this receipt. CYCLE-LOG CYCLE-4 correction
appended to `docs/cro/CYCLE-LOG.md`.

## Method

Fresh row-level awk enumeration of every table row in
`w859-typed-gap-register.md` (field 5 = status; separator row excluded).
Each REPAIRED row's status-receipt citation was read from the row itself;
the two receipts whose claims were in question (w982t/w983d, w984v) were
re-read from disk before concluding. No number was trusted from either
prior tally; both were re-derived.

## True arithmetic (recounted from receipts)

Baseline at W982q: 32 REPAIRED. Claimed flips since:

| Receipt | Rows claimed | Rows |
|---|---|###|
| w982t / w983d row 1 | 1 (W722 gap-2 — claimed by w982t, applied by w983d; ONE row, two receipts) | W722 gap-2 → 33 |
| w983d row 2 | 1 (W793 NO_CROSS_REFERENCE, commit `b2758300`) | → 34 |
| w983p | 4 (W731 limits, W750-G2, W765 GAP-D, W802/W819 mounted) | → 38 |
| w983o | 1 (W729 multitenancy, SPEC-07, commit `ddb19522`) | → 39 |
| w984v | 1 (W849 backlog-2, CI leg) | → 40 claimed |

W984ac's "41?" came from counting w982t's claim and w983d's row 1 as two
flips — they are the same row. True claim total: 40.

## Root cause of 39 vs 40

W984v flipped W849 backlog-2 **only in the per-row verdict table of
`w983p-register-flips.md`**, never in `w859-typed-gap-register.md` itself —
7 of the 8 claimed flips had been applied to the register, so disk read
39 REPAIRED / 10 OPEN. W793/W983d's row was NOT double-counted with W793's
4-gap row (distinct rows); the double-count was W722 gap-2.

## Flip applied (evidence verified before flipping)

**W849 backlog-2 OPEN → REPAIRED** citing w849 (disclosure) + w982g
(SPEC-34: `lib/xaas/generated/regen_check.ex` + `mix xaas.generated.regen_check`
+ court) + w984v (CI leg at `.github/workflows/ci_cd.yaml:107-115`).
Verified on tree before the edit: step present in `ci_cd.yaml` (sed
105-118), task file exists (`lib/mix/tasks/xaas.generated.regen_check.ex`),
w982g receipt on disk (`docs/sjira/v26.10.6/plans/w982g-lspec-wave.md`).
Falsifier:
remove/rename the CI step at ci_cd.yaml:112-115 → flip invalid.

## Full 51-row tally (post-flip, awk-verified)

40 REPAIRED / 9 OPEN / 2 TYPED-OPEN.

1. REPAIRED W665 kernel gap — w897 row 1 (flip W968b)
2. REPAIRED W674-GAP-1 — w902 + w928 + w945b
3. REPAIRED W674-GAP-2 — w900 + w928
4. REPAIRED W722 gaps 1-2 (gap-1 state guard) — W740, witnessed w945c
5. REPAIRED W722 gap-2 — 5a853130, w982t witness, flip w983d
6. REPAIRED W729 lifecycle-state-machine — w897 row 5 (flip W968b)
7. REPAIRED W729 db-approve-idempotency — w897 drift note (flip W968b)
8. REPAIRED W729 multitenancy — W970a/W975b, ddb19522, flip W983o
9. OPEN W729 atomic_update — w729
10. REPAIRED W731 capability-class — w912 SPEC-09 (flip W971)
11. REPAIRED W731 limits-not-enforced — w976/w981k (flip W983p)
12. REPAIRED W731 registry-path-hardcoded — w897 row 11 (flip W968b)
13. REPAIRED W745 rescue-arm — w945c c.5
14. REPAIRED W750-G1 — W768, witnessed w945c
15. REPAIRED W750-G2 — w968c SPEC-14, fd471722 (flip W983p)
16. REPAIRED W763-G1 — w780
17. REPAIRED W765 GAP-A — w900
18. REPAIRED W765 GAP-B — w935/w940b fab56ae1
19. REPAIRED W765 GAP-C — w935/w940b fab56ae1
20. REPAIRED W765 GAP-D — w969b/w969c, 5a853130 (flip W983p)
21. REPAIRED W770 vacuous approvals — W792/w900
22. OPEN W770 RouteProjectsBackups transition path — w770
23. REPAIRED W770 RouteProjects dead-write — w792 (flip W971)
24. OPEN W784 TOFU — w784 (deferred)
25. REPAIRED W793 4-gap row — w818 + w902
26. REPAIRED W793 NO_CROSS_REFERENCE — b2758300 (flip W983d)
27. REPAIRED W796-G1 — w902
28. REPAIRED W796-G2 — w809
29. OPEN W796-G3 — w796
30. OPEN W799 reversal-action-absent — w799
31. REPAIRED W799 credit-path-unfundable — w945b row 28
32. OPEN W804 operator action — w804 (hazardous migrate bookkeeping)
33. REPAIRED W802/W819 graphql-mounted — w975b SPEC-30 (flip W983p)
34. OPEN graphql-domain-coverage — w819
35. OPEN W824 wire coupling — w824
36. REPAIRED W849 backlog-1 — w852 + w902
37. REPAIRED W849 backlog-2 — w982g + w984v (flip W984v, applied W984ae)
38. REPAIRED W849 backlog-3 — w945b row 35
39. TYPED-OPEN W811 test-scope — w811
40-42. REPAIRED W650c OPEN_GAP-1/2 (w676), -3 (w865), -4 (w659d)
43. TYPED-OPEN 49.3 EU-AI-Act corpus — w815 + w983n
44. REPAIRED W880 bare-fun typedoc — w907
45. REPAIRED W836 health no-timeout — w860
46. REPAIRED W893 CancelDoesNotReleaseSlot — w925
47. REPAIRED W893 NoServerActionForCancel — w947 (flip W968b)
48. REPAIRED W866 dead-branch — deleted on tree (flip W971)
49. OPEN W902 sandbox-escape contamination — w902 (environmental)
50. REPAIRED W838-G1 — w909 + w918b
51. REPAIRED W969e re-register identity scope — w981s

## Standing

ALIVE: register row-level tally (40/9/2 awk-verified post-flip), footer
refreshed, W849-2 flip + on-tree evidence (ci_cd.yaml step, regen_check task,
w982g receipt), CYCLE-LOG CYCLE-4 correction appended. RESOLVED:
W984ac's DRIFT(REGISTER_COUNT) and STALE(REGISTER_FOOTER). NOT done (per
dispatch scope): no mix commands, no commit. Residual: working tree carries
the register/flip edits uncommitted; exact-head CI execution of the W849-2
CI step itself is owned by the next push/PR run of `CI/CD Elixir` (same
boundary w984v recorded).
