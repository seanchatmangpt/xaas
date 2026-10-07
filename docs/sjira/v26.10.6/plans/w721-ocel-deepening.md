# W721 — Ocel Deepening (receipt)

- **Standing**: ALIVE (lane-local, exact subject below)
- **Subject**: repo `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `a0723bf6`
- **Lane**: W721, v26.10.6 campaign. No commit made (per dispatch); files left in working tree for coordinator integration.

## Delivered

New file `test/xaas/ocel_deepening_test.exs` (`Xaas.Ocel.DeepeningTest`, 8 tests), Chicago-style: real `Ecto.Adapters.SQL.Sandbox` checkout of `Xaas.Repo`, real Ash actions (`authorize?: false` per existing ocel test convention), assertions on real row state, zero mocks.

1. **(a) event→multi-object correlation** — one `Event :record` with 3 typed objects; read-back via `EventObject` join rows asserted as a set of `{event_id, object_id, qualifier}` (3 rows, no duplicates, set-equality asserted); two events sharing one object each hold exactly one join row; empty `object_relations` refused at admission and zero event rows written (fold-back read = `[]`).
2. **(b) append-only fold law** — 3 `ObjectStateDelta` rows fold (occurred_at order, per-attribute last-write-wins — test-local reference implementation of the documented convention) to `%{"status" => "shipped"}`; mutation gate: `Ash.Resource.Info.actions/1` has no `:update` action AND an attempted `for_update(:update)` is refused by Ash (rescued `:refused`), stored row unchanged (`new_value == "created"`); fold order-determinism: same 5-delta sequence inserted forward vs reverse into two objects folds to identical state (`%{"amount" => "999", "status" => "shipped"}`).
3. **(c) object-object graph** — a→b→c→a cycle inserted successfully (real contract has no DAG check, typed as observed); self-relation refused by `NotSelfReferential` validation with zero rows written.
4. **(d) determinism** — covered by (b)'s forward-vs-reverse insertion equality test.

## Command / exit

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW721 \
  mix test test/xaas/ocel_deepening_test.exs
# Result: 8 passed, 0 failures, 0 skipped (1.2s async); exit 0
```

First run was 6/8 (two exception-class mismatches: `Ash.Error.Invalid` is the concrete raise for both the empty-relations refusal and the missing-action refusal; also confirmed `for_update(:update)` on a resource without that action raises via `raise_no_action` rather than returning an error tuple — hence the try/rescue `:refused` form). Fixed forward; rerun green. Pre-existing warnings only (PromEx/Grafana nxdomain in sandboxed lane, no test impact).

## EU AI Act tag decision

NOT tagged `:eu_ai_act`. OCEL event/delta record-keeping is plausibly Art 12-adjacent in the abstract, but no in-file tie to the `Xaas.Semantics.EuAiActAdmission` surface exists — tagging would be fabricated grounding, and the tag excludes the file from default runs.

## Gaps / notes

- **TYPED GAP (convention-vs-code)**: the fold law is documented on `Xaas.Ocel.ObjectStateDelta`'s moduledoc but no fold function ships in `lib/` (checked `case_view.ex` — folds relation walk, not deltas). The test carries a reference implementation; if the fold is ever meant to be load-bearing, it should be externalized into `Xaas.Ocel` as a named function with these tests pointed at it (未学習 → 構造化).
- `:record`'s empty-relations refusal surfaces as a changeset validation error (`object_relations` argument), not a policy refusal — matches the `RelateEventToObjects` change moduledoc; recorded as observed contract.
- Lane build root `_build-laneW721` (356 MB, warm) left in place: lane-local `rm -rf` was permission-denied in this session — coordinator should delete it at integration per the fanout cleanup law.
