# Explanation: Public Ontology + Reactor Control Plane

XaaS now separates semantic identity from consequential authority.

`Xaas.Semantics.Registry` answers **what an Ash resource projects to** in public semantic terms. It maps resources, attributes, and relationships onto published vocabularies and computes a deterministic projection hash. That projection is reversible metadata: it preserves the Ash names needed for exact replay while refusing application-private semantic standing.

`Xaas.Actuation` answers **how an admitted consequence is performed**. Consequential state does not inherit authority merely because a semantic graph describes it. The control plane therefore separates projection, admission, intent, execution, receipt, and replay.

```text
Ash resource
  -> public-ontology projection
  -> admission
  -> durable intent + prepared receipt
  -> synchronous Ash.Reactor DO
  -> sealed receipt
  -> replay
```

## Why Reactor is the DO boundary

Provider lifecycle state is a useful concrete example. Provider descriptive metadata may use ordinary Ash create/update actions, but lifecycle status is consequential. The public update action cannot accept status, and the internal `:actuate_status` action requires Reactor-manufactured context.

This creates two distinct properties:

1. **No ambient actuation** — possessing a resource module or disabling policy authorization does not manufacture the context required for consequential mutation.
2. **No unreceipted commit** — Reactor executes synchronously inside the Ash data-layer transaction that also contains the intent/receipt resources. Failure or halt rolls back the transaction.

## Why receipts bind the ontology projection

The actuation receipt stores the semantic projection hash. That means the evidence for a consequence is bound not just to an action name and input but also to the semantic model used to admit that resource at the time of execution.

This preserves a correspondence between the public semantic projection and the executable Ash operation without giving the projection itself execution authority.

## Idempotency as a consequence identity

The required idempotency key is not merely a retry convenience. It names an admitted consequence. Repeating the same consequence with the same key resolves to replay; attempting to reuse the key for a different consequence is refused.

That prevents a successful prior authorization/receipt identity from being silently repurposed for a different mutation.

## Boundaries

- Public ontology identity is not authorization.
- Ontop/R2RML/read projections are not DO paths.
- Generated client/API surfaces do not make internal actions public.
- `authorize?: false` is not Reactor authority.
- Sensitive ledger/auth resources remain separate exposure decisions.

## Evidence model

The repository's Chicago-style actuation test uses real Ash resources, real Reactor, and sandboxed Postgres to falsify direct bypass, receipt omission, replay duplication, and idempotency conflicts. These executable falsifiers outrank prose descriptions of intended architecture.

## Verified 2026-10-07 (W984hz truth-pass)

Checked against the working tree at `feat/playwright-surface` (docs-only lane; no code changes). Corrections and confirmations, all read from source this session:

- **Receipt resource name.** The ledger resources are `Xaas.Operations.ActuationIntent` and `Xaas.Operations.ActuationReceipt` (`lib/xaas/operations/`), aliased in `lib/xaas/actuation.ex:23`. There is no `Xaas.Actuation.Receipt` module (`grep` for `defmodule Xaas.Actuation.Receipt` returns nothing). Readers citing "the receipt" should cite `Xaas.Operations.ActuationReceipt`.
- **`Xaas.Actuation.run/4` contract** (`lib/xaas/actuation.ex:26`): `resource` and `action` must be atoms, `input` a map, and `opts` must carry a nonempty binary `:idempotency_key` or the call fails with `{:error, :idempotency_key_required}` (`inputs/4`, `lib/xaas/actuation.ex:161-179`). `:authority` defaults to `%{}`; `:authorize?` defaults `true`. The whole DO runs inside `Ash.DataLayer.transaction/4` over `[resource, ActuationIntent, ActuationReceipt]` with `Reactor.run(Xaas.Actuation.Reactor, ..., async?: false)` inside it, so a Reactor error/halt rolls back intent, receipt, and mutation together (`run_reactor_or_rollback/2`, `lib/xaas/actuation.ex:193-210`).
- **SpgGate seam.** Landed by commit `f0321df2` ("test(actuation): W650h22 — land W984dq6 SpgGate integration (F2 guard + single-funnel seam + courts)"), see `docs/sjira/v26.10.6/plans/w650h22-commit.md`. `Xaas.Actuation.SpgGate.admit/1` (`lib/xaas/actuation/spg_gate.ex`) requires nonempty `[:graph_id, :graph_version, :node_id, :edge_id]` keys and `state` in `:admitted`/`"ADMITTED"`; fail-closed otherwise. Its ONLY caller is `admit_spg/1` (`lib/xaas/actuation.ex:642`), invoked in `do_admit/2` at `lib/xaas/actuation.ex:345`, ordered AFTER `admit_authority/2` so an authority-refused call never observes the gate. Opt-in via the atom `:spg` key in the authority map; absent key = no-op; a string `"spg"` key is ignored (fail-closed-by-absence). Gate refusal surfaces to `run/4` callers as the bare tuple `{:spg_gate_refused, reason}` via the W984dq5 unwrapping in `unwrap_reactor_error/1` (`lib/xaas/actuation.ex:245-258`). Opening the gate grants no authority — the gate's own moduledoc states this.
- **Reactor step structure** (`Xaas.Actuation.Reactor`, `lib/xaas/actuation.ex:263-320`): three async?-false steps — `:admit` (`Xaas.Actuation.Kernel.admit/2`) → `:do` (`Kernel.actuate/2`, with `undo: Kernel.undo_actuate/3` forwarding a cancellation OCEL event when a later step fails) → `:receipt` (`Kernel.seal/2`), returning the sealed envelope. A replayed admission short-circuits `:do` to `{:replayed, result}` and `:receipt` to a `status: :replayed` envelope without new DO.
- **Receipt writing.** `Kernel.seal/2` updates the prepared `ActuationReceipt` via action `:seal` (status `:succeeded`/`:failed`/`:refused`, result snapshot + result hash + `completed_at`) and transitions the `ActuationIntent` via `:transition`. A typed `Xaas.Actuation.Refusal` seals as `:refused`; W773 normalization maps tuple/atom errors to the W707 `%{"class", "detail"}` map idiom so the `:seal` update cannot be rejected by the receipt's `:map` error attribute. Receipts bind the semantic projection hash (`ontology_projection_hash` on both intent and receipt), confirming the doc's projection-binding claim.
- **Authority ceiling.** `Xaas.Actuation.Validations.ReactorContext` (`lib/xaas/actuation/validations/reactor_context.ex`) rejects any consequential action whose changeset context lacks the Reactor-manufactured `:xaas_actuation` map (`intent_id`, `receipt_id`, projection hash matching the resource's `ontology_projection_hash/0`). `authorize?: false` alone never satisfies it. `admit_authority/2` additionally refuses struct-shaped (claim-candidate) authority maps with `:claim_shaped_authority_refused` (W780). Public semantic projection (`Xaas.Semantics.Registry`) appears only inside `do_admit/2` as admitted metadata (`Registry.admit/1` + `Registry.hash/1`); it computes no authority and executes nothing — the doc's central claim holds unchanged.
- **Quiescent-stop pattern** (`lib/xaas/actuation/quiescent_stop.ex`): the Art. 14(4)(e) emergency stop issues through `Xaas.Actuation.run/4` (`:actuate_status` on `Xaas.Marketplace.Provider`, guarded by the same `ReactorContext` validation, `lib/xaas/marketplace/provider.ex:79`), inheriting the same admission court, idempotency ledger, and sealed receipt — no side channel; once the subject is `:suspended`, the stop surface admits no further actuation for that subject (same key replays, fresh key refuses typed).

Reference doc truth-pass: `docs/sjira/v26.10.6/plans/w984eg-probe.md` (W984eg, same date) covered the sibling reference docs; this pass covers the explanation doc.
