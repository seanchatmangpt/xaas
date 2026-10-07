# W984ct2 — stale-redacted-struct update-chain hazard court (lane receipt)

Lane: W984ct2, xaas v26.10.6, branch `feat/playwright-surface` (shared canonical
checkout). Date: 2026-10-07.

Subject: `test/xaas/accounts/stale_struct_update_chain_test.exs` (new, 5 tests,
uncommitted). Accounts-only, per lane contract; `quiescent_stop.ex` is W984ct's.

## Origin

W984bw coordinator finding #1
(`docs/sjira/v26.10.6/plans/w984bw-accounts-depth.md`): "a stale in-memory
struct after any authorized update (Ash re-loads via the read policy, so
returned structs carry `Ash.ForbiddenField`) makes the next status mutation a
ZERO-CHANGE no-op update — which Ash runs WITHOUT re-running validations."

## What the court found (real-reproduced, not inferred)

The claim decomposes into THREE distinct empirically-confirmed behaviors:

- **Redaction confirmed**: every authorized update return (org-token actor,
  authorized via `Xaas.Accounts.Checks.ActorOrgSelfFilter`'s FilterCheck) has
  ALL attribute fields re-loaded through `Org`'s `:read` policy — every
  attribute, including fields the request itself just wrote, comes back as
  `%Ash.ForbiddenField{}`.
- **REFUTED sub-claim**: "skips validations entirely" is FALSE for the
  redacted-struct chain. Suspend-without-reason off a redacted struct still
  runs `Xaas.Accounts.Validations.OrgSuspendedRequiresSuspensionReason`, whose
  `blank?(%Ash.ForbiddenField{})` clause fails closed (test 2 of the court).
- **Third failure mode found**: a chained legitimate mutation (rename) of a
  suspended org off its redacted update return fails at AUTHORIZATION, before
  any validation: `ActorOrgSelfFilter` builds its filter off the record's own
  `slug` — ForbiddenField on the redacted struct — producing
  `Ash.Error.Query.InvalidFilterValue` (test 3). This means
  `ActorBelongsToOrg`'s org-token clause reading `changeset.data.slug` (the
  mechanism both prior validations' moduledocs disclose as the reason
  `:update` must stay atomic-ineligible) is itself broken by any chained
  redacted struct. Product-fix candidate, report-only per lane contract.

The REAL "skip" is a different mechanism, also pinned: a changeset off a STALE
(not redacted — stale, pre-update values) struct makes the intended mutation a
ZERO-CHANGE no-op: Ash records no changes, skips the UPDATE, and still returns
`{:ok, _}` — the mutation is silently lost (test 4: reactivation off a stale
active-valued struct returns ok while the DB stays `:suspended`; the control
re-fetch lands it).

## Court

`test/xaas/accounts/stale_struct_update_chain_test.exs` — 5 Chicago tests
(real Postgres sandbox, real Ash actions, real policies; `authorize?: false`
only for seeding/read-back per the accounts-test convention):

1. Redaction shape: authorized update return is ForbiddenField across
   `:name`, `:status`, `:suspension_reason` (including the just-written
   `:name`).
2. Fail-closed, NOT bypassed: suspend-without-reason off the redacted struct
   is rejected with "suspension_reason is required"; DB unchanged.
3. Spurious rejection: chained rename of a suspended org off its redacted
   update return → `InvalidFilterValue` with `value: %Ash.ForbiddenField{
   field: :slug}` from the FilterCheck; DB unchanged.
4. Silent lost mutation: reactivation off a STALE pre-update struct returns
   `{:ok, _}` as a zero-change no-op while the DB stays `:suspended`;
   CONTROL: same mutation off a fresh `Ash.get!` lands (`:active`).
5. CONTROL: suspend-without-reason off a fresh `Ash.get!` is rejected
   (validation alive) — the defensive idiom is the passing control.

Defensive idiom (documented + control-tested): fresh `Ash.get!/2` before
EVERY changeset; never chain off an update's return value.

## Execution receipt

Toolchain: asdf elixir 1.20.2-otp-28 / erlang 28.5.0.2, `MIX_ENV=test`,
`MIX_BUILD_ROOT=_build-laneW984ct2`.

```
mix test test/xaas/accounts/stale_struct_update_chain_test.exs
  -> Result: 5 passed            (run 1)
mix test test/xaas/accounts/
  -> Result: 39 passed           (run 1; 34 prior + 5 new)
mix test test/xaas/accounts/     (fresh run 2)
  -> Result: 39 passed
mix test test/xaas/accounts/stale_struct_update_chain_test.exs (fresh run 2)
  -> Result: 5 passed
# mutation M1 (non-vacuity): delete blank?(%Ash.ForbiddenField{}) clause
#   from OrgSuspendedRequiresSuspensionReason -> 4/5 passed, 1 FAIL (test 2).
#   KILLED. File restored byte-identical (git diff --quiet exit 0).
mix test ... # post-restore confirm
  -> Result: 5 passed
```

## Blast radius (lib/ update-chain enumeration, grep + read of every hit)

Pattern sought: a SECOND changeset built from a PRIOR authorized update's
return value (or an authorized read whose struct then feeds a mutation).

Worst real production candidates found (no live hazard-court run — report-only,
product decision; the court above pins the mechanism at the accounts layer):

| site | shape | verdict |
|---|---|---|
| `lib/xaas/actuation.ex` `execute_action/8` (~:806) | authorized `Ash.get` (actor, authorize? passthrough) → `Ash.update(record, ...)` off that read | READ-variant of the mechanism: changeset built off an actor-authorized read of Org-shaped resources could redact; single-hop, return not re-chained. Closest real analog. |
| `lib/xaas/actuation/quiescent_stop.ex` (~:135, :250) | `Ash.update(claim, %{status: ...}, authorize?: false)` chains | W984ct's lane; `authorize?: false` chains → no redaction (structs fully loaded); stale-struct no-op variant possible but state-machine-guarded (`when status in [:failed, :refused]`). Out of lane scope; NOT courted. |
| `lib/xaas/library/hold_request.ex` `:expire_stale` (~:265) | authorized read (`actor: system_actor`) → per-row `for_update` + `Ash.update!(actor: ...)` off each read | If HoldRequest's read policies were a FilterCheck this would redact; `Xaas.Checks.SystemActor` is a SimpleCheck → structs fully loaded. No redaction path today; latent if policies change. |
| `lib/xaas/platform/webhook_delivery.ex` `:retry_failed_deliveries` (~:151) | `authorize?: false` read → per-row `for_update` + `Ash.update(actor: delivery_actor)` | Read is un-authorized → structs fully loaded; update returns not re-chained. Safe today. |
| `lib/xaas/ultracode/closure_controller.ex` `close`/`suspend` | `read_unscoped authorize?: false` → `for_update(..., authorize?: false)` + `Ash.update(actor:)` | Un-authorized read, no chain off update return. Safe today. |

**Conclusion**: NO live production site chains a second changeset off an
authorized update's return value in `lib/` today. The hazard is real at the
mechanism level (pinned on Org) and the closest analog is `execute_action/8`'s
authorized-read→update hop plus the `ActorOrgSelfFilter`-reads-`data.slug`
authorization breakage (court test 3), which affects ANY future chained call
against `Org` — including every controller that might reuse an update return.

## Standing

- Court: ALIVE (5/5 green ×2 fresh runs + post-mutation-restore confirm;
  mutation M1 killed).
- Refuted sub-claim disclosed (validations are NOT skipped on redacted-struct
  chains; they fail closed; the real skip is the stale-struct zero-change
  no-op that silently drops the mutation).
- `rm` of `_build-laneW984ct2` DENIED by permission system — build root left
  in place for the coordinator (same precedent as W984bw/W984aj).
- Not committed, per lane contract. Files touched:
  - `test/xaas/accounts/stale_struct_update_chain_test.exs` (new)
  - `docs/sjira/v26.10.6/plans/w984ct2-stale-struct.md` (this receipt)
