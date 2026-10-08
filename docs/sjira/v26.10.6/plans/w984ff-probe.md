# W984ff — w859-typed-gap-register.md re-verify receipt

Lane W984ff, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface`.
Docs-only lane: register refresh only, no lib/test edits, no commit, no
branch switch, no stash. Lane build root `_build-laneW984ff` created for the
one court re-witness run; deletion attempted at lane close — **DENIED by the
session permission system** (both attempts); root remains on disk as a lane
lease for coordinator deletion at integration (fanout cleanup law, same
denial class as W984ed/W984ee/W984eh).

## Method

1. Register + footer conventions read in full (w859-typed-gap-register.md,
   last verified footer w984aw: 40 REPAIRED / 7 OPEN / 2 TYPED-OPEN /
   2 OUT-OF-SCOPE).
2. Every OPEN row re-derived against the tree (grep/read; psql for W804).
3. w984*/w650* receipts grepped for NEW REPAIRED claims vs the register
   (w984a*–w984f*, w650h*, w650v*, w650w*): keyword sweep of OPEN-row
   surfaces; landing-receipt cross-check (w970b, w969f table, w984az,
   w984bd, w984eb).
4. 2 courts re-witnessed by real run (one blocked by box load — see below).

## Per-row verification table (all 7 then-OPEN rows + TYPED-OPEN)

| Row | Blocking condition re-derived | Evidence | Verdict |
|---|---|---|---|
| W729 atomic_update | `require_atomic?(false)` still present | grep: subscription.ex:113,127 (2 hits); w984az (SPEC-08 plan staged, BLOCKED billing-tree-hot) + w984bd (8-site atomicizability classification, 3 convert candidates) | **stays OPEN**, annotated in-row |
| W770 RouteProjectsBackups transition path | retention sweep absent? NO — landed | `destroy :purge_expired` at route_projects_backups.ex:132; w970b (SPEC-20, commit `b2758300`, 65 passed ×2); courts `retain_until_passed_w984dv_test.exs`, `purge_expired_atomicity_court_test.exs` on disk | **REPAIRED** (flip; honesty boundary in-row: `:update` still absent) |
| W784 TOFU | pinning/rotation absent in lib/ | grep tofu in lib/ → 0 hits | **stays OPEN** |
| W796-G3 hold-fulfillment Checkout mint | Checkout mint absent? NO — landed | hold_request.ex:113–168 `:fulfill` after_action mints real Checkout, code comment names W970b/W796-G3; w970b row 3 (commit `b2758300`, mutation 11/12 exact-court RED) | **REPAIRED** (flip) |
| W799 reversal-action-absent | no :reverse in ledger? NO — landed | transfer.ex:55–66 `create :reverse`, :84–87 `reverses_transfer_id`, :102–107 `identity(:unique_reversal)`; W968c SPEC-27 commit `352cc34c` per w969f table; court reversal_deepening_test.exs re-witness | **REPAIRED** (flip) |
| W804 migrate bookkeeping | versions still unrecorded? NO | psql xaas_dev: `select version from schema_migrations where version in ('20261007120000','20261007210000','20261007220000')` → 3 rows returned | **REPAIRED** (flip) |
| W902 sandbox-escape contamination | environmental class, no repairing receipt | no w984*/w650* receipt claims it closed | **stays OPEN** |
| W811 test-scope boundary | scope disclosure, not a defect | unchanged | TYPED-OPEN (no change) |
| 49.3 EU-database registration | external Commission registry, no deployer endpoint | unchanged | TYPED-OPEN (no change) |

## W984eb FRIA check (task-directed)

w984eb-probe.md flipped the oversight-governance FRIA right-to-remedy entry
(`:access_to_effective_remedy_authority_channel`) `:OPEN_GAP` → `:EVIDENCED`.
That surface is NOT a register row (grep of w859-typed-gap-register.md for
remedy/FRIA → 0 hits) — no register change; w984eb cited from the addendum
as checked-not-a-row.

## Court re-witnesses (real runs, pinned toolchain
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ff`)

- `mix test test/xaas/ledger/reversal_deepening_test.exs` → **`Result:
  9 passed`, exit 0** (real run, fresh `_build-laneW984ff` root, pinned
  toolchain; box heavily loaded — full compile from scratch took ~15 min
  wall clock). W799/SPEC-27 `:reverse` court re-witnessed GREEN at this
  tree.
- Combined run
  `mix test test/xaas/ledger/reversal_deepening_test.exs test/xaas/library/hold_request_test.exs`
  attempted first: killed at 240s by this lane's own `timeout` mid-compile
  (noproc crash) under heavy concurrent-lane box load — no test verdict;
  re-run narrowed to the reversal file only.

## Standing

- Register refreshed; 4 flips (W770, W796-G3, W799, W804), 1 annotation
  (W729 atomic_update), 0 regressions found among the 40 previously
  REPAIRED rows (spot re-derivation of 3: W674-GAP-2, W824, W849 backlog-2
  surfaces still present on tree by grep).
- Fresh tally grep-verified on disk: **51 rows = 44 REPAIRED / 3 OPEN /
  2 TYPED-OPEN / 2 OUT-OF-SCOPE (removed-by-operator)**
  (`grep -c '| REPAIRED |'` = 44, `'| OPEN |'` = 3, `'| TYPED-OPEN |'` = 2,
  `'| OUT-OF-SCOPE'` = 2).
- NO COMMIT (lane contract). Receipt staged in working tree for
  coordinator integration.
