defmodule Xaas.Tunnel.FabricTest do
  use ExUnit.Case, async: true

  alias Xaas.Tunnel.{Capabilities, Fabric, Receipt}

  @caps Capabilities.allowlist()

  defp step!(state, event) do
    {:ok, next} = Fabric.transition(state, event)
    next
  end

  defp at(:new), do: Fabric.new()
  defp at(:probed), do: step!(at(:new), {:probed, @caps})
  defp at(:admitted), do: step!(at(:probed), {:admitted, %{admitted: @caps}})
  defp at(:submitted), do: step!(at(:admitted), {:submitted, "run-1", "epoch-1"})
  defp at(:executing), do: step!(at(:submitted), :lease_observed)
  defp at(:sealed), do: step!(at(:executing), {:sealed, "d1"})
  defp at(:replayed), do: step!(at(:sealed), {:replayed, "d1"})

  @phases [:new, :probed, :admitted, :submitted, :executing, :sealed, :replayed]

  @events %{
    probed: {:probed, @caps},
    admitted: {:admitted, %{admitted: @caps}},
    submitted: {:submitted, "run-1", "epoch-1"},
    lease_observed: :lease_observed,
    sealed: {:sealed, "d1"},
    replayed: {:replayed, "d1"}
  }

  # The only legal (phase, event-tag) pairs.
  @legal MapSet.new([
           {:new, :probed},
           {:probed, :admitted},
           {:admitted, :submitted},
           {:submitted, :lease_observed},
           {:submitted, :sealed},
           {:executing, :sealed},
           {:sealed, :replayed}
         ])

  test "the legal sequence reaches :replayed and keeps identities" do
    s = at(:replayed)
    assert s.phase == :replayed
    assert s.run_id == "run-1"
    assert s.epoch_id == "epoch-1"
    assert s.digest == "d1"
  end

  test "a receipt can seal before a lease was observed (fast executor)" do
    assert step!(at(:submitted), {:sealed, "d9"}).phase == :sealed
  end

  test "every out-of-order event is an illegal transition" do
    for phase <- @phases, {tag, event} <- @events, not MapSet.member?(@legal, {phase, tag}) do
      assert Fabric.transition(at(phase), event) ==
               {:error, {:illegal_transition, phase, tag}},
             "#{phase} + #{tag} must be illegal"
    end
  end

  test "actuate is refused in every state and never changes it" do
    for phase <- @phases ++ [{:refused, :contract_mismatch}] do
      state = if is_atom(phase), do: at(phase), else: %{Fabric.new() | phase: phase}
      assert Fabric.transition(state, :actuate) == {:refused, {:authority_ceiling, "actuate"}}

      assert Fabric.transition(state, {:actuate, %{"resource" => "x"}}) ==
               {:refused, {:authority_ceiling, "actuate"}}
    end
  end

  test "contract mismatch, missing admission and replay mismatch are typed refusals" do
    assert step!(at(:new), {:probed, ["fabric.probe"]}).phase == {:refused, :contract_mismatch}

    assert step!(at(:probed), {:admitted, %{admitted: ["fabric.probe"]}}).phase ==
             {:refused, :capability_not_admitted}

    assert step!(at(:sealed), {:replayed, "other"}).phase == {:refused, :replay_digest_mismatch}
  end

  test "terminal refused states accept no further events" do
    refused = step!(at(:new), {:probed, []})

    assert Fabric.transition(refused, {:probed, @caps}) ==
             {:error, {:illegal_transition, {:refused, :contract_mismatch}, :probed}}
  end

  test "wait_ms is clamped to [0, 25000]" do
    assert Fabric.wait_ms(100) == 100
    assert Fabric.wait_ms(999_999) == 25_000
    assert Fabric.wait_ms(-5) == 0
    assert Fabric.wait_ms("1500") == 1500
    assert Fabric.wait_ms("25001") == 25_000
    assert Fabric.wait_ms("junk") == 25_000
    assert Fabric.wait_ms(nil) == 25_000
  end

  describe "reconcile/1 (one row per crash-window decision)" do
    @now ~U[2026-09-25 10:00:00Z]

    defp epoch(attrs),
      do:
        Map.merge(%{id: "epoch-1", state: :running, leased_to: nil, lease_expires_at: nil}, attrs)

    test ":not_submitted when no epoch exists" do
      assert Fabric.reconcile(%{epoch: nil, receipts: [], now: @now}) == :not_submitted
    end

    test "{:await_execution, id} for a submitted, unsealed epoch" do
      assert Fabric.reconcile(%{epoch: epoch(%{}), receipts: [], now: @now}) ==
               {:await_execution, "epoch-1"}

      live = epoch(%{leased_to: "w", lease_expires_at: DateTime.add(@now, 60)})

      assert Fabric.reconcile(%{epoch: live, receipts: [], now: @now}) ==
               {:await_execution, "epoch-1"}
    end

    test "{:lease_expired, id} when the lease ran out" do
      stale = epoch(%{leased_to: "w", lease_expires_at: DateTime.add(@now, -1)})

      assert Fabric.reconcile(%{epoch: stale, receipts: [], now: @now}) ==
               {:lease_expired, "epoch-1"}
    end

    test "{:sealed, digest} when a receipt is sealed" do
      wire = %{"epoch_id" => "epoch-1", "outcome" => "alive"}

      assert Fabric.reconcile(%{epoch: epoch(%{state: :completed}), receipts: [wire], now: @now}) ==
               {:sealed, Receipt.digest(wire)}
    end

    test "{:resume_external_seal, intent_id} for an executing intent with a prepared receipt" do
      facts = %{
        epoch: epoch(%{}),
        receipts: [],
        intent: %{id: "intent-7", status: :executing},
        prepared_receipt?: true,
        now: @now
      }

      assert Fabric.reconcile(facts) == {:resume_external_seal, "intent-7"}
      # Without a prepared receipt there is nothing to resume.
      assert Fabric.reconcile(%{facts | prepared_receipt?: false}) ==
               {:await_execution, "epoch-1"}
    end

    test "{:refused, :receipt_missing_for_succeeded_intent}" do
      facts = %{
        epoch: epoch(%{}),
        receipts: [],
        intent: %{id: "i", status: :succeeded},
        now: @now
      }

      assert Fabric.reconcile(facts) == {:refused, :receipt_missing_for_succeeded_intent}
    end
  end
end
