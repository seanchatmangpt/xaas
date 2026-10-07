defmodule Xaas.Accounts.StaleStructUpdateChainTest do
  @moduledoc """
  Hazard court (lane W984ct2) pinning the stale-redacted-struct update-chain
  hazard from W984bw's coordinator finding #1
  (`docs/sjira/v26.10.6/plans/w984bw-accounts-depth.md`).

  Mechanism, real-reproduced (not inferred): an authorized update on
  `Xaas.Accounts.Org` by the org-token actor shape
  (`%{org_id: slug}`, authorized through `Xaas.Accounts.Checks.
  ActorOrgSelfFilter`'s FilterCheck) returns a struct whose attribute fields
  are ALL re-loaded through `Org`'s `:read` policy — so every attribute comes
  back as a real `%Ash.ForbiddenField{}` redaction, including fields that
  were just written by the request itself.

  Chaining the next changeset directly off that redacted return value has two
  real, distinct failure modes (both pinned below):

  1. **Spurious rejection of the next legitimate mutation**: the chained
     changeset off the redacted struct fails at AUTHORIZATION before any
     validation runs — `Xaas.Accounts.Checks.ActorOrgSelfFilter` (the
     `:update` bypass's FilterCheck) builds its filter off the record's own
     `slug`, which is a `%Ash.ForbiddenField{}` on the redacted struct, so
     the filter is invalid (`Ash.Error.Query.InvalidFilterValue`). The
     org's next legitimate mutation is rejected outright.

  2. **Silent lost mutation (zero-change no-op)**: a changeset built off a
     STALE in-memory struct whose attributes still read their pre-update
     values turns an intended status mutation into a ZERO-CHANGE no-op: Ash
     records no changes, the UPDATE statement is legitimately skipped, and
     the caller still gets `{:ok, _}` — the mutation is silently lost while
     the caller believes it landed. (With the redacted-struct shape this
     cannot occur — a `ForbiddenField` never equals the requested value, so
     the change is always recorded — which is why the stale-struct variant is
     the one that bites.)

  Refuted sub-claim, honestly disclosed: W984bw's finding phrased the
  redacted-struct hazard as "skips validations entirely" for the
  suspend-without-reason chain. It does NOT: off a redacted struct the
  validation still runs and fails closed (test 2), and the chained mutation
  off a suspended org's redacted return fails even earlier, at
  authorization (test 3). What actually skips the update entirely is the
  ZERO-CHANGE no-op off a STALE (not redacted — stale) struct, which
  returns `{:ok, _}` while silently dropping the mutation (test 4).

  Defensive idiom (the passing control, already used by W984bw's depth court
  and W984cq): fresh `Ash.get!/2` before EVERY changeset — never chain off an
  update's return value.

  Chicago discipline: real Postgres sandbox, real Ash actions, real policies
  evaluated on every mutation under test (`authorize?: false` only for
  seeding and system-internal read-back, per the established accounts-test
  convention).
  """

  use ExUnit.Case, async: true

  alias Xaas.Accounts.Org

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_org!(prefix) do
    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "Chain Co",
      slug: "#{prefix}-#{System.unique_integer([:positive])}"
    })
    |> Ash.create!(authorize?: false)
  end

  defp org_token_actor(org), do: %{org_id: org.slug}

  test "AUTHORIZED UPDATE RETURN IS REDACTED: every attribute is a ForbiddenField" do
    org = create_org!("chain-redacted")

    {:ok, returned} =
      org
      |> Ash.Changeset.for_update(:update, %{name: "Chain Co II"}, actor: org_token_actor(org))
      |> Ash.update()

    # Even the field this very request just wrote comes back redacted.
    assert %Ash.ForbiddenField{} = returned.name
    assert %Ash.ForbiddenField{} = returned.status
    assert %Ash.ForbiddenField{} = returned.suspension_reason
  end

  test "FAIL-CLOSED, NOT BYPASSED: suspend-without-reason off a redacted struct is rejected" do
    org = create_org!("chain-fail-closed")

    {:ok, returned} =
      org
      |> Ash.Changeset.for_update(:update, %{name: "Chain Co II"}, actor: org_token_actor(org))
      |> Ash.update()

    # The redacted struct is data-poisoned: any unsupplied attribute reads as
    # a ForbiddenField, and the validation's blank? clause treats that as
    # blank -- so the suspension-reason rule still fires. W984bw's "skips
    # validations entirely" phrasing is REFUTED for this shape; the chain
    # fails CLOSED instead.
    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             returned
             |> Ash.Changeset.for_update(:update, %{status: :suspended},
               actor: org_token_actor(returned)
             )
             |> Ash.update()

    assert Enum.any?(errors, fn e ->
             e.field == :suspension_reason and
               e.message =~ "is required when suspending an org"
           end)

    persisted = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted.status == :active
  end

  test "SPURIOUS REJECTION: a legit chained rename of a suspended org is rejected off its redacted update return" do
    org = create_org!("chain-rename")

    # Suspend with a real reason (authorized).
    {:ok, suspended_ret} =
      org
      |> Ash.Changeset.for_update(
        :update,
        %{status: :suspended, suspension_reason: "non-payment"},
        actor: org_token_actor(org)
      )
      |> Ash.update()

    # The reason IS persisted.
    persisted_suspended = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted_suspended.status == :suspended
    assert persisted_suspended.suspension_reason == "non-payment"

    # The NEXT legitimate mutation -- a rename that never touches :status --
    # chained off the redacted return, is rejected BEFORE the validation even
    # runs: `Xaas.Accounts.Checks.ActorOrgSelfFilter` (the :update bypass's
    # FilterCheck) builds its authorization filter off the record's own
    # `slug` -- which is a ForbiddenField on the redacted struct -- so the
    # filter itself is invalid. A third, distinct failure mode of the same
    # stale-struct chain: authorization, not validation.
    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             suspended_ret
             |> Ash.Changeset.for_update(:update, %{name: "Chain Co III"},
               actor: org_token_actor(suspended_ret)
             )
             |> Ash.update()

    assert Enum.any?(errors, fn
             %Ash.Error.Query.InvalidFilterValue{value: %Ash.ForbiddenField{field: :slug}} ->
               true

             _ ->
               false
           end)

    persisted = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted.name == "Chain Co"
    assert persisted.status == :suspended
  end

  test "SILENT LOST MUTATION: reactivation off a STALE pre-update struct is a zero-change no-op that still returns ok" do
    org = create_org!("chain-stale")

    # DB goes suspended BEHIND the in-memory struct (system-internal write).
    org
    |> Ash.Changeset.for_update(
      :update,
      %{status: :suspended, suspension_reason: "non-payment"},
      authorize?: false
    )
    |> Ash.update!()

    # The in-memory `org` still reads status :active. Building the
    # reactivation changeset off it makes `status: :active` a ZERO change
    # (data already reads :active): Ash records no changes, skips the UPDATE,
    # and the caller still gets {:ok, _}. The mutation is silently lost.
    {:ok, _no_op} =
      org
      |> Ash.Changeset.for_update(:update, %{status: :active}, actor: org_token_actor(org))
      |> Ash.update()

    persisted = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted.status == :suspended, "the reactivation must NOT have landed"

    # CONTROL (the defensive idiom): the same mutation off a FRESH Ash.get!
    # actually lands.
    fresh = Org |> Ash.get!(org.id, authorize?: false)
    assert %Xaas.Accounts.Org{} = fresh

    {:ok, _} =
      fresh
      |> Ash.Changeset.for_update(:update, %{status: :active}, actor: org_token_actor(fresh))
      |> Ash.update()

    persisted_after = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted_after.status == :active
  end

  test "CONTROL: suspend-without-reason off a FRESH Ash.get! is rejected by the validation" do
    org = create_org!("chain-control")

    {:ok, _returned} =
      org
      |> Ash.Changeset.for_update(:update, %{name: "Chain Co II"}, actor: org_token_actor(org))
      |> Ash.update()

    fresh = Org |> Ash.get!(org.id, authorize?: false)

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             fresh
             |> Ash.Changeset.for_update(:update, %{status: :suspended},
               actor: org_token_actor(fresh)
             )
             |> Ash.update()

    assert Enum.any?(errors, fn e ->
             e.field == :suspension_reason and
               e.message =~ "is required when suspending an org"
           end)

    persisted = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted.status == :active
  end
end
