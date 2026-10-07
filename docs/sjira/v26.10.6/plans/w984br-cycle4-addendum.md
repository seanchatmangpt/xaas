# W984br — CYCLE-4 addendum: graphql-removal arc + post-removal witnesses

- Lane: W984br, xaas v26.10.6, repo `/Users/sac/xaas`, branch
  `feat/playwright-surface`, HEAD at write time `b5d677b3` (local == origin
  after push wave 4). Docs-only; no commit; no mix commands.
- Method: every claim below read fresh from its on-disk receipt before
  citation; receipts cited-but-missing are flagged as drift, not papered over.

## (1) Operator directive "no GraphQL" → removal executed fix-forward

- **Directive**: in-session operator directive (2026-10-07), remove graphql
  code, fix forward — cited by `w984aq-graphql-docs-removal.md` and
  `w984ay-code-graphql-sweep.md`.
- **W984ao (code removal)**: **DRIFT — no receipt on disk**
  (`ls docs/sjira/v26.10.6/plans/w984ao*` → no matches; only
  `w984ao1-e2e-graphql-check.md` exists). Removal work is corroborated
  indirectly by `w984ax` (182 dirty files incl. W984ao in-flight edits),
  `w984x` disclosure 1 (court files staged `D`, router scope removed,
  `lib/xaas/graphql_schema.ex` staged `D`), and `w984az` (billing-tree
  graphql-removal in-flight attribution). Standing: **IN-FLIGHT —
  MISSING_RECEIPT(claimed-landed)**; owner lane must re-emit
  `w984ao-graphql-removal.md` (already forward-cited by w984aq).
- **W984ap (e2e)**: receipt `w984ap-e2e-removal.md` — deleted untracked
  `e2e/graphql-http.spec.cjs`; grep-zero across 27 remaining e2e files +
  playwright config (exit 1); internal-api spec contract verified unchanged
  by read. Standing ALIVE.
- **W984aq (docs)**: receipt `w984aq-graphql-docs-removal.md` — deleted the
  94-line `/api/graphql` section from
  `docs/claude/diataxis/reference/http-api-surface.md` (post-edit grep
  graphql|absinthe = 0), corrected the castle-bridge ERRC REDUCE row to
  "read-only on JSON:API", flipped 2 register rows OUT-OF-SCOPE.
  LANDED-UNCOMMITTED.
- **W984aw (register sweep)**: receipt `w984aw-graphql-rows.md` — swept all 51
  register rows for graphql-era citations; **0 additional flips**; per-row
  annotations on W729/W731/W750-G2/W765 (all load-bearing evidence confirmed
  graphql-independent); fresh awk tally 51 rows = 40 REPAIRED / 7 OPEN /
  2 TYPED-OPEN / 2 OUT-OF-SCOPE(removed-by-operator).
- **W984ay (straggler sweep)**: receipt `w984ay-code-graphql-sweep.md` —
  exhaustive second-pass grep (unrestricted file types) found **zero live
  graphql code surfaces**; classification table: 1 load-bearing straggler
  (`priv/packs/xaas_library_pack/templates/manufacture.ex.eex` — pack
  template still renders AshGraphql extensions + six `graphql do` blocks),
  mix.lock entries STRAGGLER(mechanical, self-resolves on `mix deps.get`),
  VKG `graphql/2` = legitimate non-surface (b), 5 stale SPEC-31 comment
  sites STRAGGLER(c)-lite, prose/removal-courts keep. Census BLOCKED
  (concurrent-lane-edit); standing PARTIAL_ALIVE.
- **W984bk (straggler removal)**: **DRIFT — no receipt on disk**
  (`ls plans/w984bk*` → no matches). Standing: **IN-FLIGHT —
  MISSING_RECEIPT**; whether the pack `.eex`/comment mix.lock stragglers have
  been removed is UNKNOWN on disk (the w984ay falsifier grep is unrun/unrun
  receipted).

## (2) Post/during-removal gates

- **W984am**: receipt `w984am-census-rewitness.md` — eu_ai_act gate 1352
  passed / 0 failed / 1 excluded, exit 0, fresh lane build root, at subject
  `5f7f70d9` = settled floor exactly. ALIVE.
- **W984ax**: receipt `w984ax-euaia-rewitness.md` — same gate, 1352/0/1
  excluded, exit 0, on the dirty mid-removal tree (182 dirty files with
  W984ao in-flight among them). Corpus graphql-independence confirmed
  (count, exclusions, runtime unchanged from w981x census at 6f235905).
  ALIVE.

## (3) Push waves 3+4

- **W984at (wave 3)**: `w984at-push3.md` — `6f235905..5f7f70d9`, 17 commits,
  ff, exit 0; post-push origin SHA == local == `5f7f70d9`. ALIVE.
- **W984bh (wave 4)**: `w984bh-push4.md` — `5f7f70d9..b5d677b3`, 1 commit
  (`b5d677b3` w984ba receipt docs commit), ff, exit 0; origin == local ==
  `b5d677b3`. ALIVE.

## (4) SPEC-07 complete 8/8

- `w983o-spec07-complete.md` — billing multitenancy second half landed by
  `ddb19522` (byte-identical 4/5 files; 5th differs only by foreign W984k
  delta), fresh-root compile --force --warnings-as-errors exit 0, court 5/5,
  billing dir 40 passed, multitenancy deepening 9 passed, post-HEAD-move
  re-witness at `1f2a2b23`. Register SPEC-07 row PARTIAL-REPAIRED →
  REPAIRED. Standing ALIVE at `1f2a2b23` (8/8 billing resources).

## (4b) Register tally evolution 32 → 40 REPAIRED, 2 OUT-OF-SCOPE

- Lineage (each flip receipted): W984ac-era 39 REPAIRED on disk → W984ae
  reconcile (w982g SPEC-34 regen_check + w984v CI leg; W849 backlog-2 flip
  applied; 40/9/2/0) → W984aq flipped 2 rows
  OUT-OF-SCOPE(removed-by-operator, 2026-10-07) (W802/W819 graphql-http-
  surface REPAIRED→OUT-OF-SCOPE; GAP(graphql-domain-coverage) OPEN→
  OUT-OF-SCOPE) → W984aw swept 51 rows, 0 further flips, fresh tally 40
  REPAIRED / 7 OPEN / 2 TYPED-OPEN / 2 OUT-OF-SCOPE.
- On-disk check this lane: 40 REPAIRED rows + 2 dated
  OUT-OF-SCOPE(removed-by-operator, 2026-10-07) rows in
  `w859-typed-gap-register.md` (grep-counted fresh: 40+2). The campaign
  narrative "32→40" is the cycle-to-date evolution claim from the dispatch;
  the receipted lineage above is what is on disk per-step.

## (5) SPEC-08 staged + BLOCKED(billing-tree-hot) ×2

- **W984az**: `w984az-w729-spec08.md` — BLOCKED(billing-tree-hot) on fresh
  evidence: 8 modified billing lib files + 1 billing court uncommitted;
  in-flight class attributed to graphql removal (correcting W984w's W975b
  attribution); full implementation plan staged. Also disclosed
  `w984u-billing-commits.md` missing at that lane's write time — now
  RESOLVED on disk (`w984u-billing-commits.md` present, read fresh this
  lane; git log shows its content landed as commits 32487e08 + d7beb066
  with receipt commit 4d59c680).
- **W984bd**: `w984bd-atomic-retrofit.md` — BLOCKED(billing-tree-hot) again
  (identical 9-file set unchanged across a 14-min recheck); added the
  per-site atomicizability classification of all 8 change modules:
  3 ATOMICIZABLE (PricingOverride, InvoiceReconciliationApprove,
  QuotaOverride — no-op stub change modules), 5 NON-ATOMICIZABLE(disclose)
  (after_action pre-state reads / read-or-create / nested Transfer), so the
  next lane's Step 1 is mechanical. Carries the disclosure-only falsifier
  warning: all five non-atomicizable sites use after_action (already
  in-transaction) — converting them per-site is a disclosure exercise, not a
  correctness repair; a court that would flip on disclosure-only conversion
  is a vacuity signal, not a win.

## (6) Mutation waves — zero vacuous guards

- **W981p**: `w981p-open-gap-mutation-hardening.md` — 3×KILL (OPEN_GAP-1/2,
  OPEN_GAP-3, OPEN_GAP-4), each minimal production mutation, court RED on
  exactly the guard legs, restores md5-verified.
- **W984x**: `w984x-mutation-wave2.md` — 4×KILL (W731 LimitGate depth gate,
  W750-G2 previous_status, W765 FreezeWindow promote gate, W802 graphql
  surface) — the W802 mutated leg witnessed (1/15) before the surface was
  removed mid-lane; restored leg BLOCKED, moot (row now OUT-OF-SCOPE).
- **W984au**: `w984au-mutation-wave3.md` — 4×KILL over 3 rows (Transfer
  :reverse sufficiency, OCEL determinism + destroy floor, SPEC-27
  double-reverse guard), baseline 25 passed → restored 25 passed, all
  restores md5-verified.
- Cumulative: **11 mutation legs, 11 KILL, 0 VACUOUS-GUARD.**

## (7) W984bm typed MISSING_RECEIPT flags (recorded, still open)

- `w984bm-receipts-verify.md` (PARTIAL_ALIVE): 4/6 verified present with
  matching content; **w984ai** and **w984al** flagged
  MISSING_RECEIPT(claimed-landed) — w984al additionally uncorroborated
  (zero disk references outside the coordinator log). Both remain missing on
  disk at this lane's check (`ls plans/w984ai* w984al*` → no matches) —
  **still open for owner-lane re-emit**; the w984al uncorroboration stands.
- Resolution updates this lane: w984u MISSING_RECEIPT (raised by w984az)
  resolved — receipt now on disk.

## Drift summary

| item | status |
|---|---|
| `w984ao-graphql-removal.md` (code removal receipt) | MISSING — load-bearing; forward-cited by w984aq and this addendum's arc claim |
| `w984bk` (straggler removal) | MISSING — straggler-removal standing UNKNOWN on disk |
| `w984ai` | MISSING (w984bm flag, uncorroborated owner re-emit pending) |
| `w984al` | MISSING (w984bm flag; claim itself uncorroborated) |
| `w984u-billing-commits.md` | was MISSING at w984az write time — RESOLVED, now on disk |

## Standing

- ALIVE: e2e removal (w984ap), docs removal + register flips (w984aq),
  register citation sweep 0-flip (w984aw), gates 1352/0 ×2 (w984am @5f7f70d9,
  w984ax mid-removal), push waves 3+4 (origin == local == b5d677b3),
  SPEC-07 8/8 (w983o), SPEC-08 staging + classification (w984az/w984bd),
  11/11 mutation kills (w981p/w984x/w984au), receipt-verify 4/6 (w984bm).
- PARTIAL_ALIVE: straggler sweep (w984ay, census BLOCKED; straggler removal
  receiptless).
- IN-FLIGHT / MISSING_RECEIPT: W984ao (code removal), W984bk (straggler
  removal). DRIFT: 2 load-bearing missing receipts in the removal arc;
  w984al uncorroborated.
- All standing on branch `feat/playwright-surface` @ `b5d677b3`
  (origin-verified), uncommitted docs tree.
