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
- Direct `Ash.update` of `:actuate_status` fails — expected; only `Xaas.Actuation.Reactor` manufactures the required context.
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
