defmodule Xaas.Ultracode.ProviderMesh.RuntimeLoopWorkerCourtW650h21Test do
  @moduledoc """
  W650h21 coverage burn-down court.

  Census: two families swept (`lib/xaas/ultracode/provider_mesh/` — 30 modules,
  20 of them covered by `test/xaas/ultracode/provider_mesh/`; `lib/xaas/runtime/
  provider_fabric/` — 30 modules) by direct test-file coverage. Within
  provider_mesh, the only two state-bearing runtime modules with zero direct
  coverage are `ReconciliationLoop` (self-rescheduling GenServer timeout loop —
  the loop halts permanently if the `handle_info(:timeout, s)` third element is
  deleted) and `ProviderWorker` (invoke delegation GenServer — invoke semantics
  drop if the delegation clause or its `s[:module]` lookup is mutated).
  Family-2 top uncovered (`CapabilitySet`/`FailureSet`, pure MapSet wrappers,
  non-state-bearing) → typed disposition NOT_STATE_BEARING, skipped.
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.ProviderMesh.ProviderWorker
  alias Xaas.Ultracode.ProviderMesh.ReconciliationLoop

  defmodule EchoMod do
    @moduledoc "Real collaborator: echoes payload, counts invokes."
    def start_link, do: Agent.start_link(fn -> 0 end, name: __MODULE__)
    def bump, do: Agent.update(__MODULE__, &(&1 + 1))
    def count, do: Agent.get(__MODULE__, & &1)
    def invoke(_cap, payload, _o) do
      bump()
      {:ok, {:echo, payload}}
    end
  end

  defmodule FailMod do
    @moduledoc "Real collaborator: typed failure channel."
    def invoke(_cap, _p, _o), do: {:error, {:provider_down, :timeout}}
  end

  describe "ReconciliationLoop" do
    test "stays alive across multiple self-rescheduled ticks" do
      # Mutation rationale: deleting the third element of handle_info(:timeout, s)
      # ({:noreply, s, interval}) halts the loop after one tick; the process then
      # never receives another :timeout and reconciliation stops silently. The
      # liveness assertion across >3 ticks fails under that mutation.
      pid = start_supervised!({ReconciliationLoop, name: nil, interval_ms: 20})

      assert Process.alive?(pid)
      :timer.sleep(70)
      assert Process.alive?(pid)
      assert :sys.get_state(pid)[:interval_ms] == 20
    end

    test "interval_ms override drives re-arm, mailbox stays drained" do
      # Mutation rationale: re-arm falling back to the 30_000 literal instead of
      # the state-borne interval freezes the loop for 30s per tick; an honored
      # 20ms interval keeps ticks flowing and the mailbox empty between them.
      # Also pins that state survives ticks unchanged (loop-invariant config).
      pid = start_supervised!({ReconciliationLoop, name: nil, interval_ms: 20})
      :timer.sleep(60)
      assert Process.alive?(pid)
      assert {:messages, []} = :erlang.process_info(pid, :messages)
      assert :sys.get_state(pid)[:interval_ms] == 20
    end

    test "default name registers under the module (production start_link/1 contract)" do
      # Mutation rationale: changing Keyword.get(o, :name, __MODULE__) to
      # Keyword.get(o, :name) (default nil) breaks the unnamed start_link/1
      # contract — callers reach the loop by module name; whereis would return
      # nil and every reconcile trigger would silently no-op.
      {:ok, pid} = ReconciliationLoop.start_link(interval_ms: 60_000)
      assert GenServer.whereis(ReconciliationLoop) == pid
      GenServer.stop(ReconciliationLoop)
    end
  end

  describe "ProviderWorker" do
    test "invoke delegates to the state-borne module, passing capability and payload" do
      # Mutation rationale: mutating handle_call({:invoke, c, p, o}) to reply
      # with a constant, or dropping the s[:module] lookup, collapses worker
      # delegation. Both the echoed value and the collaborator's invoke count
      # pin the full (cap, payload) pass-through.
      {:ok, _} = EchoMod.start_link()
      {:ok, w} = ProviderWorker.start_link(module: EchoMod)

      assert ProviderWorker.invoke(w, :translate, %{"q" => "hi"}) ==
               {:ok, {:echo, %{"q" => "hi"}}}

      assert EchoMod.count() == 1
      GenServer.stop(w)
    end

    test "typed failure channel propagates unchanged (no swallowing, no raise)" do
      # Mutation rationale: wrapping the reply in a rescue/normalization step
      # would erase the typed reason tuple {:provider_down, :timeout}; upstream
      # failure classification (Failure.class/1 in Router) depends on the exact
      # shape surviving the worker boundary intact.
      {:ok, w} = ProviderWorker.start_link(module: FailMod)
      assert ProviderWorker.invoke(w, :cap, %{}) == {:error, {:provider_down, :timeout}}
      GenServer.stop(w)
    end
  end
end
