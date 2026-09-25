defmodule Xaas.Operations.CapabilityLivenessReceiptStressTest do
  @moduledoc """
  Real concurrency stress test: 50 real concurrent Elixir Tasks, each doing
  a real `Ash.create!` ingest against the real live Postgres (via the
  Ecto.Adapters.SQL.Sandbox's `{:shared, self()}` mode, so every spawned
  Task connection reuses the same sandboxed transaction as the test
  process). No mocking -- real Task.async/await, real Ash.create!, real
  Ash.read! count assertion on real persisted rows.
  """

  use ExUnit.Case, async: false
  @moduletag :stress

  alias Xaas.Operations.CapabilityLivenessReceipt

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
    end)

    :ok
  end

  test "50 real concurrent Tasks each ingest a unique capability, all rows real-persisted" do
    run_tag = System.unique_integer([:positive, :monotonic])

    tasks =
      for i <- 1..50 do
        Task.async(fn ->
          Ash.create!(
            CapabilityLivenessReceipt,
            %{
              capability: "stress.capability.#{run_tag}.#{i}",
              authority: "stress-test",
              status: "ALIVE",
              executed: true,
              exit_code: 0,
              subject: "stress-subject-#{i}",
              detail: "concurrent stress ingest ##{i}"
            },
            action: :ingest,
            authorize?: false
          )
        end)
      end

    results = Task.await_many(tasks, 30_000)

    assert length(results) == 50
    assert Enum.all?(results, &match?(%CapabilityLivenessReceipt{}, &1))

    expected_capabilities_list = Enum.map(1..50, &"stress.capability.#{run_tag}.#{&1}")
    expected_set = MapSet.new(expected_capabilities_list)

    persisted =
      CapabilityLivenessReceipt
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&MapSet.member?(expected_set, &1.capability))

    assert length(persisted) == 50

    persisted_capabilities = MapSet.new(persisted, & &1.capability)

    assert persisted_capabilities == expected_set
  end
end
