# W984cf — Lane Receipt: Oversight Depth Court

- **Subject**: branch `feat/playwright-surface`, working tree (uncommitted, per lane law — coordinator commits)
- **Scope**: 5-test depth court on the human-oversight surface, MINUS covered slices
- **Standing**: ALIVE (5/5 passing, 3 seeds)
- **Files written** (tests + receipt only, nothing else touched):
  - `test/xaas/oversight/w984cf_oversight_depth_test.exs` (new, 5 tests)
  - this receipt

## Coverage analysis (fresh re-read, 2026-10-07)

Read fresh: `lib/xaas/semantics/oversight_governance.ex` (353 L),
`lib/xaas/semantics/authority_channel.ex` (310 L),
`lib/xaas/actuation/quiescent_stop.ex`.

Covered slices (not re-courted):
- 26.2 assignment + sig-callback chain — `test/xaas/deepening/art_26_2_human_oversight_assignment_test.exs` (W984be)
- 26.6 retention rows — `test/xaas/deepening/art_26_6_retention_durable_row_test.exs` (W981t)
- AuthorityChannel registry/with_endpoint/transmit happy paths + refusals + determinism — `test/xaas/semantics/authority_channel_test.exs`, plus `test/xaas/semantics/authority_channel_incident_witness_test.exs`
- OversightGovernance typed structures + per-list cited-path existence — `test/xaas/semantics/oversight_governance_test.exs`

Uncourted remainder courted here:
1. **Authority-shape fail-closed legs** of `QuiescentStop.authority_admitted?/1`: missing
   `kind` with a real `source` (W984be courts only the mirror missing-source leg), atom
   `kind`, non-map authority. Mutates the `is_binary(kind)` conjunct and the map clause.
2. **Same-key concurrent stop race**: winner holds the only `stopped_at` receipt, exactly
   one intent row binds the contended key, state quiescent. Mutates the intent-ledger
   idempotency path.
3. **Fresh-key concurrent stop race + rotation**: subject reaches quiescent with ≥1
   receipt; a third fresh authority post-attractor refuses
   `:REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT` with no new intent row. Mutates the monotone
   `stopped?` attractor check (sequential form).
4. **AuthorityChannel path degradation** (`verify_paths/1` — the module's only uncourted
   seam): an operator channel citing a missing path degrades to typed `:OPEN` with a basis
   naming the drift; intact sibling keeps `:EVIDENCED`; degraded channel still transmits
   `:RECORDED` via a real `IncidentReport.build` over a real witnessed receipt. Mutates
   `verify_paths/1`.
5. **OversightGovernance list drift**: `retention_policy/0.source ⊆ cited_paths/0` — the
   two constant lists can drift independently; cross-court fails on divergence.

## Commands + exits (real, run under `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984cf`)

```
mix test test/xaas/oversight/w984cf_oversight_depth_test.exs            → 5 passed
mix test ... --seed 77234                                               → 5 passed
mix test ... --seed 991                                                 → 5 passed
```

5/5, three seeds. All Postgres legs over real sandboxed Postgres via `Xaas.DataCase`,
real Ash actions, real quiescent-stop actuations, real channel registry over the real
tree. No mocks (Chicago discipline).

## Findings (real, observed during court construction — not fixed by this lane)

1. **W984cf-1 (unhandled replay envelope in `QuiescentStop.do_stop/2`,
   `lib/xaas/actuation/quiescent_stop.ex:53-65`)**: under a same-key concurrent stop
   race, the loser passes the pre-DO `find_intent` window and reaches the kernel, which
   returns `{:ok, %{status: :replayed, ..., replay?: true}}`. `do_stop/2` has no matching
   clause (`:succeeded` / `:refused` / `:failed` only) → the loser raises
   `CaseClauseError` instead of replaying `{:ok, %{already_stopped: true}}`. The durable
   ledger stays exactly-once (one intent row) and state stays quiescent — no corruption —
   but the caller-facing contract is a crash, not the typed replay. Sequenced callers are
   unaffected (pre-existing `already_stopped` replay is correct).
2. **W984cf-2 (TOCTOU in the monotone attractor, `quiescent_stop.ex:66-73`)**: two
   concurrent fresh-key stops on a fresh subject can BOTH win the stop DO (both pass
   `stopped?/2` before either commits) and both receive `{:ok, %{stopped_at, ...}}`
   receipts — observed directly. The attractor holds sequentially (post-attractor fresh
   key refuses typed, courted) but is not race-safe. No corruption: the subject is
   idempotently quiescent either way; the `already_stopped`-losing side effect is a second
   receipt row.

Both findings are concurrency-window contract gaps, disclosed to the coordinator;
no `lib/` edits made (lane writes tests only).

## Transport failures / notes

- One transient compile failure from a foreign in-flight lane edit
  (`lib/xaas/operations/approval_causal_anatomy.ex` with a literal `...`); resolved
  itself when that lane fixed its file — not this lane's subject.
- `rm -rf _build-laneW984cf` was denied by the permission system; the lane build root
  (~430 MB) is left on disk for the coordinator per the fanout cleanup law (deletion is
  the coordinator's integration step).

## Standing

ALIVE — 5/5 green, ×3 seeds, on the exact working tree; tests-only diff, uncommitted.
