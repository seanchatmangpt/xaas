defmodule Xaas.Actuation.QuiescentStopTest do
  @moduledoc """
  Chicago-style qualification for `Xaas.Actuation.QuiescentStop.execute/2`.

  Real Ash resources, real actuation kernel, real sandboxed Postgres. Proves the
  Theorem 5.2 emergency-stop contract: typed receipt on stop, idempotent replay,
  fail-closed authority gate, and the monotone quiescent attractor (once
  stopped, no further actuation is admitted through the stop surface).
  """

  use ExUnit.Case, async: true

  alias Xaas.Actuation.QuiescentStop
  alias Xaas.Marketplace.Provider

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_provider! do
    Xaas.Generator.create_provider!(%{name: "Quiescent Provider", org_id: "org-estop"})
  end

  defp authority do
    %{kind: "test_authority", source: "quiescent_stop_test"}
  end

  defp stop_key do
    "estop-#{System.unique_integer([:positive])}"
  end

  test "stop with authority drives the subject quiescent and returns a typed receipt" do
    provider = create_provider!()
    key = stop_key()

    assert {:ok, receipt} =
             QuiescentStop.execute(Provider,
               subject_id: provider.id,
               idempotency_key: key,
               authority: authority()
             )

    assert receipt.target == :quiescent
    assert %DateTime{} = receipt.stopped_at
    assert receipt.authority == authority()

    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) ==
             :suspended
  end

  test "double stop with the same key is idempotent and performs no new DO" do
    provider = create_provider!()
    key = stop_key()
    opts = [subject_id: provider.id, idempotency_key: key, authority: authority()]

    assert {:ok, _first} = QuiescentStop.execute(Provider, opts)
    receipts_before = Ash.read!(Xaas.Operations.ActuationReceipt, authorize?: false)

    assert {:ok, %{already_stopped: true}} = QuiescentStop.execute(Provider, opts)
    assert length(Ash.read!(Xaas.Operations.ActuationReceipt, authorize?: false)) ==
             length(receipts_before)
  end

  test "missing authority is refused typed, fail-closed, before any DO" do
    provider = create_provider!()
    key = stop_key()

    assert {:error, :REFUSED_STOP_AUTHORITY} =
             QuiescentStop.execute(Provider,
               subject_id: provider.id,
               idempotency_key: key,
               authority: %{}
             )

    assert {:error, :REFUSED_STOP_AUTHORITY} =
             QuiescentStop.execute(Provider,
               subject_id: provider.id,
               idempotency_key: key
             )

    # No DO occurred: the subject is untouched.
    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) ==
             :pending
  end

  test "Lyapunov convergence: once stopped, further actuation through the stop surface refuses (monotone)" do
    provider = create_provider!()
    key = stop_key()

    assert {:ok, %{target: :quiescent}} =
             QuiescentStop.execute(Provider,
               subject_id: provider.id,
               idempotency_key: key,
               authority: authority()
             )

    # Same key: idempotent, already at the attractor.
    assert {:ok, %{already_stopped: true}} =
             QuiescentStop.execute(Provider,
               subject_id: provider.id,
               idempotency_key: key,
               authority: authority()
             )

    # Fresh key on the stopped subject: typed refusal, no new DO admitted.
    assert {:error, :REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT} =
             QuiescentStop.execute(Provider,
               subject_id: provider.id,
               idempotency_key: stop_key(),
               authority: authority()
             )

    # The subject remains at the quiescent fixed point.
    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) ==
             :suspended
  end

  test "missing idempotency key is refused before any DO" do
    provider = create_provider!()

    assert {:error, :idempotency_key_required} =
             QuiescentStop.execute(Provider, subject_id: provider.id, authority: authority())
  end
end
