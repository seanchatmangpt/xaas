defmodule Xaas.SystemAuthorityCapabilityChicagoTest do
  @moduledoc """
  Chicago-style closure tests for XAAS-2601's authority boundary.

  These tests prove that the service label is a real capability, not audit-only
  metadata, and that the HoldRequest AshOban path carries scheduler authority
  through the consequence-bearing per-row `:expire` mutation.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Library.HoldRequest
  alias Xaas.Ultracode.Run

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  @ordinary_actor %{id: "ordinary", org_id: "org_normal", role: :member}

  defp pending_run!(goal) do
    Run
    |> Ash.Changeset.for_create(:create, %{goal: goal, max_cycles: 1}, authorize?: false)
    |> Ash.create!()
  end

  defp expired_hold! do
    user = Xaas.Generator.create_user!()

    book =
      Xaas.Generator.create_book!(%{
        available_copies: 0,
        total_copies: 1
      })

    hold =
      HoldRequest
      |> Ash.Changeset.for_create(:place, %{user_id: user.id, book_id: book.id})
      |> Ash.create!(authorize?: false)

    hold
    |> Ash.Changeset.for_update(:update, %{})
    |> Ash.Changeset.force_change_attribute(
      :expires_at,
      DateTime.add(DateTime.utc_now(), -60, :second)
    )
    |> Ash.update!(authorize?: false)
  end

  test "system authority vocabulary is closed" do
    assert_raise ArgumentError, fn -> Xaas.SystemAuthority.new(:fabricated_service) end

    refute Xaas.SystemAuthority.system?(%Xaas.SystemAuthority{service: :fabricated_service})
    refute Xaas.SystemAuthority.system?(%Xaas.SystemAuthority{service: nil})
  end

  test "Ultracode mutations refuse a valid system actor from the wrong service" do
    run = pending_run!("cross-service authority must fail closed")

    assert {:error, %Ash.Error.Forbidden{}} =
             run
             |> Ash.Changeset.for_update(:transition_state, %{state: :running})
             |> Ash.update(actor: Xaas.SystemAuthority.new(:webhook_dispatcher))

    assert Ash.get!(Run, run.id, authorize?: false).state == :pending
  end

  test "Run.tick admits the scheduler capability and refuses the reactor capability" do
    assert {:error, %Ash.Error.Forbidden{}} =
             Run
             |> Ash.ActionInput.for_action(:tick, %{})
             |> Ash.run_action(actor: Xaas.SystemAuthority.new(:ultracode_reactor))

    assert {:ok, %{advanced: _}} =
             Run
             |> Ash.ActionInput.for_action(:tick, %{})
             |> Ash.run_action(actor: Xaas.SystemAuthority.new(:oban_scheduler))
  end

  test "webhook retry entry point is scheduler-only" do
    assert {:error, %Ash.Error.Forbidden{}} =
             Xaas.Platform.WebhookDelivery
             |> Ash.ActionInput.for_action(:retry_failed_deliveries, %{})
             |> Ash.run_action(actor: Xaas.SystemAuthority.new(:webhook_dispatcher))

    assert {:ok, %{candidates: 0, updated: 0, errored: 0}} =
             Xaas.Platform.WebhookDelivery
             |> Ash.ActionInput.for_action(:retry_failed_deliveries, %{})
             |> Ash.run_action(actor: Xaas.SystemAuthority.new(:oban_scheduler))
  end

  test "HoldRequest.expire is scheduler-only and expire_stale carries the actor through the real mutation" do
    directly_targeted = expired_hold!()

    assert {:error, %Ash.Error.Forbidden{}} =
             directly_targeted
             |> Ash.Changeset.for_update(:expire, %{})
             |> Ash.update(actor: @ordinary_actor)

    assert {:error, %Ash.Error.Forbidden{}} =
             directly_targeted
             |> Ash.Changeset.for_update(:expire, %{})
             |> Ash.update(actor: Xaas.SystemAuthority.new(:ultracode_reactor))

    cron_target = expired_hold!()

    assert {:ok, %{expired_count: 2}} =
             HoldRequest
             |> Ash.ActionInput.for_action(:expire_stale, %{})
             |> Ash.run_action(actor: Xaas.SystemAuthority.new(:oban_scheduler))

    assert Ash.get!(HoldRequest, directly_targeted.id, authorize?: false).status == :expired
    assert Ash.get!(HoldRequest, cron_target.id, authorize?: false).status == :expired
  end
end
