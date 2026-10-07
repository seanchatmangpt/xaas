# W984w — W824 witness+flip (SPEC-32 ALREADY-LANDED), register 9 OPEN remainder disposed

- Lane W984w, xaas v26.10.6, repo `/Users/sac/xaas`, branch `feat/playwright-surface`
  (dirty campaign tree; no commit — coordinator owns commits).
- Only writes: `w859-typed-gap-register.md` (1 row flip + tally reconciliation)
  + this receipt.

## Row picked and why

Picked **W824 (SPEC-32)** per the lane's preference order: witness+flip is the
cheapest lawful move given (a) w982g already typed SPEC-32 ALREADY-LANDED at
HEAD (`lib/xaas_web/controllers/execution_fabric_controller.ex`
`format_actuation/2` additive quiescent envelope, commit `9f1247c1`), and (b)
the two alternatives were typed out:

- **W729 / SPEC-08 (atomic_update retrofit)**: TYPED-BLOCKED this lane. The
  spec's surface is `lib/xaas/billing/changes/*` + billing money-movers
  (`approval_{pricing,quota}_*.ex`, `approval_invoice_reconciliation_approve.ex`),
  and the billing tree is HOT — uncommitted in-flight diffs are on tree (visible
  in `git status`: `lib/xaas/billing/approval_*` modified, part of the
  W983p-family multitenancy diff per w982g's "LANE-HOT" note). Retrofitting
  money-movers under another lane's uncommitted diff violates the fan-out
  one-writer law.
- **W819 graphql-domain-coverage**: no W984l receipt exists on disk
  (`ls docs/sjira/v26.10.6/plans | grep w984l` → no match), so its 12/19 →
  closure evidence is not yet witnessed; row stays OPEN pending that lane's
  receipt. Not flippable from a rumor.

## What was witnessed (W824 / SPEC-32)

Surface re-verified on tree at lane open:

- `lib/xaas_web/controllers/execution_fabric_controller.ex:742-766` —
  `format_actuation/2` projects the kernel envelope additively:
  `{status, replay, intent_id, receipt_id}` plus, when
  `quiescent_intent?/1` matches (`actuate_status` → `"suspended"`),
  `Map.put(:target, "quiescent")` and
  `Map.put(:already_stopped, envelope.status == :replayed)`. Non-quiescent
  responses never change shape. Exactly the SPEC-32 contract.
- Both files are COMMITTED and clean in `git status` (last-touch commit
  `9f1247c1` "fix(ops): lease clock seam + fabric quiescent envelope
  (W840/W824/W844) + actuation idempotency deepening (W747/W704)").
- Court: `test/xaas_fabric_tie_test.exs` is cited as
  `test/xaas_web/quiescent_fabric_tie_test.exs` (22 KB on disk).

### Witness run (fresh pinned-toolchain lane root)

```
export PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984w
mix compile        # exit 0 (fresh cold build: deps + app)
mix test test/xaas_web/quiescent_fabric_tie_test.exs   # ×3
```

Results: `Result: 9 passed` on all three consecutive runs (×2 green required,
×3 witnessed). No compile error; the one-time `graphql_schema.ex` compile
complaint seen on the first `mix test` invocation did not reproduce on any of
the three court runs (fresh-root partial-recompile artifact; the test task
recompiled and compiled clean).

## Dispositions of the remaining OPEN rows (typed, no repair this lane)

| row | disposition |
|---|---|
| W729 SPEC-08 atomic_update | TYPED-BLOCKED(billing-tree-hot: uncommitted in-flight money-mover diffs on tree; one-writer law) — implementable after integration commits land |
| W819 graphql-domain-coverage | stays OPEN — W984l has no receipt on disk yet; flip waits for witnessed closure evidence |
| W902 shared xaas_test contamination | environmental — coordinator hygiene pass / per-lane test DBs; not lane-safe |
| W804 dev DB migration stamp | operator action on xaas_dev; not lane-safe |
| W784 TOFU trust chain | UNSUPPORTED — campaign backlog; no landing named by any receipt |

## Register tally after this lane (grep on disk)

- 9 OPEN / 40 REPAIRED / 2 TYPED-OPEN across 51 table rows (verified by grep
  after the flip; previously 10/39/2).
- OPEN remainder: W729 (unblocked after billing integration), W819, W902, W804,
  W784 + design-class rows recorded in the register body.

## Standing

- ALIVE for the witness: surface grep on disk + court green ×3, commands and
  results quoted above. Register + receipt edits uncommitted on tree.
- Falsifier: `git show 9f1247c1 --stat | grep execution_fabric_controller` and
  re-run `MIX_ENV=test MIX_BUILD_ROOT=<fresh> mix test
  test/xaas_web/quiescent_fabric_tie_test.exs` — any RED, or absence of
  `format_actuation/2`'s quiescent branch at
  `lib/xaas_web/controllers/execution_fabric_controller.ex:742-766`,
  invalidates the flip.

## Lane hygiene

`_build-laneW984w` left on disk for the coordinator (fresh cold root,
~1+ GB; deletion may be permission-denied per W983p precedent). No lib/test
files touched. No commit.
