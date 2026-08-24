# Tutorial: A Receipted Provider Lifecycle Transition

This tutorial demonstrates the repository's current consequential-actuation model with one provider status change and one deterministic replay.

## 1. Prepare the real runtime

Follow `CLAUDE.md` to start the repository's Postgres-backed development/test environment. The learning goal is to use real Ash/Reactor behavior, not a mock.

## 2. Create a provider

Create a marketplace provider through its ordinary Ash `:create` action. The resource enters the lifecycle at `:pending`; the create action cannot smuggle in an already-actuated status.

```elixir
provider =
  Xaas.Marketplace.Provider
  |> Ash.Changeset.for_create(:create, %{
    name: "Tutorial Provider",
    slug: "tutorial-provider",
    org_id: "tutorial-org"
  })
  |> Ash.create!(authorize?: false)
```

For a production caller, use the real actor/authorization policy. `authorize?: false` here mirrors the repository test harness; it does not bypass the Reactor lifecycle fence.

## 3. Observe the direct-path refusal

Try the internal action directly:

```elixir
provider
|> Ash.Changeset.for_update(:actuate_status, %{status: :active})
|> Ash.update(authorize?: false)
```

The operation must fail because `:actuate_status` requires Reactor-manufactured context. If it succeeds, the safety invariant has regressed.

## 4. Actuate through Reactor

```elixir
key = "tutorial-provider-activate-v1"

{:ok, first} =
  Xaas.Actuation.run(
    Xaas.Marketplace.Provider,
    :actuate_status,
    %{status: :active},
    subject_id: provider.id,
    idempotency_key: key,
    authorize?: false,
    authority: %{kind: "tutorial", source: "diataxis"}
  )
```

Expect `first.status == :succeeded`, `first.replay? == false`, and a sealed receipt carrying the ontology projection hash plus consequence evidence.

## 5. Verify the consequence

Read the provider through Ash and confirm its status is now `:active`.

```elixir
updated = Ash.get!(Xaas.Marketplace.Provider, provider.id, authorize?: false)
:active = updated.status
```

## 6. Replay the same intent

Run the same actuation again with the same key and same consequence.

```elixir
{:ok, replay} =
  Xaas.Actuation.run(
    Xaas.Marketplace.Provider,
    :actuate_status,
    %{status: :active},
    subject_id: provider.id,
    idempotency_key: key,
    authorize?: false,
    authority: %{kind: "tutorial", source: "diataxis"}
  )
```

Expect `replay.status == :replayed`, `replay.replay? == true`, and the same receipt identity as the first execution. No second lifecycle mutation should occur.

## 7. Run the repository falsifier

```bash
mix test test/xaas/actuation_test.exs
```

That test file exercises the same production resources and Reactor path against sandboxed Postgres. A passing exact-subject run is the evidence that graduates the tutorial path from prose to observed behavior.

## What you learned

The public ontology projection identifies what the resource means; admission and authority decide whether a consequence may proceed; Reactor is the exclusive consequential DO path; and the sealed receipt makes replay deterministic. Those roles are intentionally separate.
