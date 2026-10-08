# How to Actuate Provider Lifecycle State

Use this procedure when a marketplace provider's lifecycle status must change. Do not call the internal Ash update action directly; the repository deliberately fences that path.

## Preconditions

- A real `Xaas.Marketplace.Provider` record exists.
- The caller has an explicit authority context appropriate to the operation.
- You can supply a unique, stable idempotency key for the intended consequence.
- The repository/Postgres runtime is available.

## Perform the transition

Call the exclusive control-plane API:

```elixir
{:ok, envelope} =
  Xaas.Actuation.run(
    Xaas.Marketplace.Provider,
    :actuate_status,
    %{status: :active},
    subject_id: provider.id,
    idempotency_key: "provider-#{provider.id}-activate-v1",
    actor: actor,
    authority: %{kind: "operator", source: "approved-change"}
  )
```

The first successful execution returns `status: :succeeded` and `replay?: false`. Preserve the returned receipt as the evidence for the mutation.

## Retry safely

If transport or caller state is uncertain, retry with the **same** idempotency key and the **same** consequence. A completed prior operation returns the existing receipt as `status: :replayed`; the target mutation is not executed again.

Do not reuse a key for a different target consequence. The control plane refuses that case as `{:error, {:idempotency_conflict, key}}`.

## Diagnose refusals

- `{:error, :idempotency_key_required}` — supply a non-empty key.
- `{:error, :delegated_actuation_requires_authority_evidence}` — when `authorize?: false`, a non-empty `authority:` map is required (`Xaas.Actuation.run/4` admits authority at `lib/xaas/actuation.ex:635-664`).
- `{:error, {:idempotency_not_replayable, key, status}}` — the key matches an intent that is not `:succeeded` (e.g. still `:executing`); retry only after the intent reaches a terminal status (`lib/xaas/actuation.ex:753`).
- `{:error, {:spg_gate_refused, reason}}` — when the authority map carries the opt-in `:spg` key, `Xaas.Actuation.SpgGate.admit/1` (`lib/xaas/actuation/spg_gate.ex`) fail-closes on missing/ill-typed graph identity keys or non-`ADMITTED` state; opening the gate grants no authority.
- Direct `Ash.update` of `:actuate_status` fails — expected; the action is `public?(false)` and guarded by the `Xaas.Actuation.Validations.ReactorContext` validation; only `Xaas.Actuation.Reactor` manufactures the required context.
- Projection/admission failure — inspect `Xaas.Semantics.Registry` output; public-ontology admission must succeed before consequential DO.
- Reactor failure/halt — treat the operation as failed; the transaction is rolled back rather than committing an unreceipted mutation.

## Verify the result

Read the provider through Ash and confirm the expected status. Then verify the returned envelope/receipt and, when testing changes to this path, run:

```bash
mix test test/xaas/actuation_test.exs
```

For repository-level standing, follow `CLAUDE.md` and expand to the required compile/test gates. A source-level inspection is not a substitute for this execution.

## Do not

- add `status` to the public `:update` accept list merely to make lifecycle changes convenient;
- expose `:actuate_status` as a JSON:API route without a separately admitted authority design;
- bypass the Reactor-context validation;
- treat ontology identity as execution authority.

> **Verified 2026-10-08** (lane W984kx): all actionable claims re-verified against
> the current tree — `Xaas.Actuation.run/4` at `lib/xaas/actuation.ex:26`;
> `:idempotency_key_required` at line 177, `{:idempotency_conflict, key}` unwrap
> path at lines 241-252, `delegated_actuation_requires_authority_evidence` at
> lines 635-664 (line refs corrected in place from stale 576-582/677);
> `:actuate_status` at `lib/xaas/marketplace/provider.ex:79` is `public?(false)`
> with the `ReactorContext` validation (line 83); `test/xaas/actuation_test.exs`
> present. SpgGate landed this campaign (commit `f0321df2`, W650h22) and is now
> part of the `run/4` refusal surface — a `{:spg_gate_refused, reason}` bullet was
> added above (opt-in only; absent `:spg` key is a no-op). No graphql or
> `ash-manufacture-pack` claims in this guide.
