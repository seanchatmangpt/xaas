defmodule Xaas.Billing.ApprovalPricingOverrideApproveW984dvTest do
  @moduledoc """
  Lane W984dv Chicago court for `Xaas.Billing.Changes.ApprovalPricingOverrideApprove`.

  Census (W984du fifth re-census): the surrounding `:approve` surface is
  heavily covered (controller court, W982s lifecycle court -- re-approve
  StaleRecord guard, self-approval refusal, double-approve race,
  multitenancy), but the change module's OWN contract is unexercised:

    1. the no-op pass-through contract (init/change/atomic) -- the stub
       must never mutate the changeset or silently drop opts;
    2. an end-to-end atomic `:approve` under a REAL `SystemAuthority`
       actor with `authorize?: true` (the controller court exercises the
       plug path, not the Ash policy surface with the system actor).

  Chicago style: real Ash actions on real sandboxed Postgres, assertions
  on persisted state, zero mocks.
  """

  use ExUnit.Case, async: false

  alias Xaas.Billing.ApprovalPricingOverride
  alias Xaas.Billing.Changes.ApprovalPricingOverrideApprove
  alias Xaas.SystemAuthority

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp uniq(suffix), do: "w984dv-#{suffix}-#{System.unique_integer([:positive])}"

  defp create_override!(requested_by) do
    ApprovalPricingOverride
    |> Ash.Changeset.for_create(
      :create,
      %{requested_by: requested_by, org_id: nil},
      authorize?: false
    )
    |> Ash.create!()
  end

  defp system_actor, do: SystemAuthority.new(:internal_api)

  # ------------------------------------------------------------------
  # (1) stub pass-through contract
  # ------------------------------------------------------------------

  test "(1a) init/1 passes opts through unchanged" do
    assert {:ok, [foo: :bar]} = ApprovalPricingOverrideApprove.init(foo: :bar)
    assert {:ok, []} = ApprovalPricingOverrideApprove.init([])
  end

  test "(1b) change/3 is an identity on a real :approve changeset" do
    record = create_override!(uniq("req"))

    changeset =
      record
      |> Ash.Changeset.for_update(:approve, %{approved_by: uniq("approver")},
        authorize?: false
      )

    assert changeset == ApprovalPricingOverrideApprove.change(changeset, [], %{})
  end

  test "(1c) atomic/3 is an identity {:ok, changeset} on a real :approve changeset" do
    record = create_override!(uniq("req"))

    changeset =
      record
      |> Ash.Changeset.for_update(:approve, %{approved_by: uniq("approver")},
        authorize?: false
      )

    assert {:ok, ^changeset} =
             ApprovalPricingOverrideApprove.atomic(changeset, [], %{})
  end

  # ------------------------------------------------------------------
  # (2) end-to-end atomic :approve under a real SystemAuthority actor
  # ------------------------------------------------------------------

  test "(2a) system actor approves a pending override: approved_by persisted on disk" do
    requester = uniq("req")
    approver = uniq("approver")
    record = create_override!(requester)

    assert %ApprovalPricingOverride{} =
             record
             |> Ash.Changeset.for_update(:approve, %{approved_by: approver},
               actor: system_actor(),
               authorize?: true
             )
             |> Ash.update!()

    reloaded = Ash.get!(ApprovalPricingOverride, record.id, authorize?: false)
    assert reloaded.approved_by == approver
    assert reloaded.requested_by == requester
  end

  test "(2b) system actor self-approval is refused typed (atomic RequiresApprover branch under authorize?: true)" do
    requester = uniq("req")
    record = create_override!(requester)

    assert_raise Ash.Error.Invalid, fn ->
      record
      |> Ash.Changeset.for_update(:approve, %{approved_by: requester},
        actor: system_actor(),
        authorize?: true
      )
      |> Ash.update!()
    end

    reloaded = Ash.get!(ApprovalPricingOverride, record.id, authorize?: false)
    assert is_nil(reloaded.approved_by)
  end

  test "(2c) non-system actor is forbidden on :approve under authorize?: true" do
    record = create_override!(uniq("req"))

    error =
      assert_raise Ash.Error.Forbidden, fn ->
        record
        |> Ash.Changeset.for_update(:approve, %{approved_by: uniq("approver")},
          actor: %{org_id: "some-org"},
          authorize?: true
        )
        |> Ash.update!()
      end

    reloaded = Ash.get!(ApprovalPricingOverride, record.id, authorize?: false)
    assert is_nil(reloaded.approved_by)
    assert error != nil
  end
end
