defmodule Xaas.Ultracode.LeaseReclaimTest do
  use ExUnit.Case, async: true

  alias Xaas.Ultracode.{Epoch, Lease, Receipt, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  test "expired ownership converges on one reclaim transition" do
    provider = provider_id()
    {_run, epoch} = running_epoch(provider)

    assert {:ok, leased, _token, _run} =
             Lease.claim_next(provider, "worker-a", epoch_id: epoch.id, pool_capacity: nil)

    {:ok, _expired} =
      leased
      |> Ash.Changeset.for_update(
        :renew_lease,
        %{lease_expires_at: DateTime.add(DateTime.utc_now(), -60, :second)},
        authorize?: false
      )
      |> Ash.update()

    assert {:reclaimed, reclaimed, %Receipt{} = receipt} =
             Lease.reclaim_epoch(epoch.id, :lease_expired, %{"observer" => "test"})

    assert reclaimed.state == :failed
    assert receipt.outcome == :refused
    assert receipt.evidence["reclaimed_by"] == "xaas-lease-kernel"
    assert receipt.evidence["reclaim_reason"] == "lease_expired"
    assert Lease.live_leases(provider) == 0

    # Idempotent terminal observation: no second terminal Receipt.
    assert {:already_terminal, :failed} =
             Lease.reclaim_epoch(epoch.id, :lease_expired, %{"observer" => "test"})

    receipts =
      Receipt
      |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch.id})
      |> Ash.read!(authorize?: false)

    assert length(receipts) == 1
  end

  test "expiry observation never steals a live worker lease" do
    provider = provider_id()
    {_run, epoch} = running_epoch(provider)

    assert {:ok, _leased, _token, _run} =
             Lease.claim_next(provider, "worker-live", epoch_id: epoch.id, pool_capacity: nil)

    assert :handed_off =
             Lease.reclaim_epoch(epoch.id, :lease_expired, %{"observer" => "test"})

    assert Lease.live_leases(provider) == 1
  end

  test "direct worker-down observation atomically frees a still-live slot" do
    provider = provider_id()
    {_run, epoch} = running_epoch(provider)

    assert {:ok, _leased, _token, _run} =
             Lease.claim_next(provider, "worker-dead", epoch_id: epoch.id, pool_capacity: nil)

    assert Lease.live_leases(provider) == 1

    assert {:reclaimed, reclaimed, receipt} =
             Lease.reclaim_epoch(epoch.id, :worker_down, %{
               "observer" => "dispatch-monitor"
             })

    assert reclaimed.state == :failed
    assert receipt.evidence["reclaim_reason"] == "worker_down"
    assert receipt.evidence["lease_was_live"] == true
    assert is_binary(receipt.evidence["lease_fingerprint"])
    assert Lease.live_leases(provider) == 0
  end

  defp running_epoch(provider) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "lease reclaim qualification", provider: provider},
        authorize?: false
      )
      |> Ash.create()

    {:ok, epoch} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "lease-reclaim:#{provider}",
          state: :running
        },
        authorize?: false
      )
      |> Ash.create()

    {run, epoch}
  end

  defp provider_id,
    do: "reclaim-test-#{System.unique_integer([:positive, :monotonic])}"
end
