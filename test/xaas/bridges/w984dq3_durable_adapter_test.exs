defmodule Xaas.Bridges.W984dq3DurableAdapterTest do
  @moduledoc """
  W984dq3 depth court — `Xaas.Bridges.PPlan.DurableAdapter` (the adapter surface
  inside lib/xaas/bridges/pplan.ex), the first direct tests of the adapter behind
  the Ferroplan/P-PLAN bridge's plan persistence. The bridge-level behavior
  (park/resume envelopes) is already covered by Xaas.Chicago.Bridges.PPlanTest;
  this court pins the ADAPTER's own surface:

    * adapter metadata + step-table mapping (deterministic table lookup);
    * the typed unknown-op refusal shape;
    * the real step-module boundary behavior the adapter names;
    * the real-store recovery semantics (consume-once signal, sealed terminal
      runs, adopt-on-restart determinism).

  Chicago: real ETS durable store, real facade/engine execution, real step
  modules — no mocks, assertions on real store state, never call counts.
  """

  use ExUnit.Case, async: false

  alias Xaas.Bridges.PPlan
  alias Xaas.Bridges.PPlan.DurableAdapter

  @store_mod AshPPlan.Reactor.Durable.Store.Ets

  setup do
    {:ok, _} = Application.ensure_all_started(:reactor)
    {:ok, store} = @store_mod.start_link([])
    previous = Application.get_env(:xaas, :pplan_durable_store)
    Application.put_env(:xaas, :pplan_durable_store, store)

    ExUnit.Callbacks.on_exit(fn ->
      Application.put_env(:xaas, :pplan_durable_store, previous)
    end)

    %{store: store}
  end

  @tag :w984dq3
  test "adapter metadata and step-table mapping are deterministic" do
    # The adapter is the only module allowed to name the payment-spine step
    # implementations; its metadata contract and table must be stable.
    assert DurableAdapter.id() == :xaas_pplan
    assert DurableAdapter.available?() == true
    assert Enum.sort(DurableAdapter.ops()) == [:process_authorize, :process_renew]

    # Mutation rationale: if the table silently remaps an op to a different
    # (or option-carrying) step, the durable engine executes a different
    # implementation than the one the ontology projection binds — these
    # assertions kill that mutation class.
    for op <- DurableAdapter.ops() do
      expected =
        case op do
          :process_authorize -> Xaas.Bridges.PPlan.Steps.AuthorizePayment
          :process_renew -> Xaas.Bridges.PPlan.Steps.RenewSubscription
        end

      assert {:ok, {^expected, []}} = DurableAdapter.step(op, [])
    end

    # Determinism: the lookup is a pure table fetch, not a computed value.
    assert DurableAdapter.step(:process_authorize, []) ==
             DurableAdapter.step(:process_authorize, [])

    assert DurableAdapter.step(:process_renew, []) == DurableAdapter.step(:process_renew, [])
  end

  @tag :w984dqq3_marker
  test "unknown ops get a typed refusal and ops/step agree" do
    # Mutation rationale: an adapter that returns {:error, reason} with a
    # string, or a bare atom, breaks the caller's typed-refusal matching.
    # Pin the exact real shape the module emits.
    assert {:error, {:unsupported_op, :nonexistent}} = DurableAdapter.step(:nonexistent, [])
    assert {:error, {:unsupported_op, :file_write}} = DurableAdapter.step(:file_write, [])

    # Bijection: every declared op resolves; an op belonging to a DIFFERENT
    # adapter (the durable adapter's :file_write family) must not leak in.
    for op <- DurableAdapter.ops(), do: assert(match?({:ok, _}, DurableAdapter.step(op, [])))

    for op <- [:file_write, :await, :command, :domain_action] do
      assert match?({:error, {:unsupported_op, ^op}}, DurableAdapter.step(op, []))
    end
  end

  @tag :w984dq3
  test "AuthorizePayment boundary: invalid claims refuse, limit comparison is strict >" do
    alias Xaas.Bridges.PPlan.Steps.AuthorizePayment

    # Mutation rationale: number/1 parsing and the > (not >=) comparison are
    # the authorization boundary — flipping > to >= or accepting a
    # partially-parsed string changes who gets charged without a human.
    assert {:error, :invalid_claim} = AuthorizePayment.run(%{input: %{"claim" => %{"amount" => nil, "limit" => 500}}}, %{}, [])
    assert {:error, :invalid_claim} = AuthorizePayment.run(%{input: %{"claim" => %{"amount" => "12abc", "limit" => 500}}}, %{}, [])
    assert {:error, :invalid_claim} = AuthorizePayment.run(%{input: %{"claim" => %{}}}, %{}, [])

    # amount == limit is authorized: the boundary is strict greater-than.
    assert {:ok, %{status: :authorized, requires_human_release: false, amount: 500, limit: 500}} =
             AuthorizePayment.run(%{input: %{"claim" => %{"amount" => 500, "limit" => 500}}}, %{}, [])

    assert {:ok, %{status: :over_limit, requires_human_release: true, amount: 501, limit: 500}} =
             AuthorizePayment.run(%{input: %{"claim" => %{"amount" => 501, "limit" => 500}}}, %{}, [])

    # String amounts go through the bridge's number/1 parser deterministically.
    assert {:ok, %{status: :authorized, amount: 250}} =
             AuthorizePayment.run(%{input: %{"claim" => %{"amount" => "250", "limit" => 500}}}, %{}, [])

    # Pure function: same input, same observation.
    claim = %{input: %{"claim" => %{"amount" => 501, "limit" => 500}}}
    assert AuthorizePayment.run(claim, %{}, []) == AuthorizePayment.run(claim, %{}, [])
  end

  @tag :w984dq3
  test "RenewSubscription: context release completes, no-gate completes, park without durable context is a typed crash" do
    alias Xaas.Bridges.PPlan.Steps.RenewSubscription

    # Mutation rationale: the release gate decides whether a parked run needs
    # a human. If context :human_release stopped being honored, every
    # over-limit purchase would park forever — kill that mutation here.
    assert {:ok, %{renewed: true, released_by: "operator-ok"}} =
             RenewSubscription.run(
               %{predecessor_0: %{requires_human_release: true, amount: 1500, limit: 500}},
               %{human_release: "operator-ok"},
               []
             )

    # Under-limit authorization renews with released_by: nil — no gate.
    assert {:ok, %{renewed: true, released_by: nil}} =
             RenewSubscription.run(
               %{predecessor_0: %{requires_human_release: false}},
               %{},
               []
             )

    # Over-limit with no release and NO durable context: the step cannot park,
    # so it refuses by crashing (park_and_halt/2 has no nil clause) — a typed
    # FunctionClauseError, not a silent guessed park. Pinning the crash makes
    # the durable-context requirement an explicit contract.
    assert_raise FunctionClauseError, fn ->
      RenewSubscription.run(
        %{predecessor_0: %{requires_human_release: true, amount: 1500, limit: 500}},
        %{},
        []
      )
    end
  end

  @tag :w984dq3
  test "recovery semantics on a real store: persist/adopt roundtrip, consume-once signal, sealed terminal run", %{store: store} do
    subject = "urn:xaas:subject:w984dq3-" <> Integer.to_string(System.unique_integer([:positive]))

    # Persist: an over-limit purchase parks as a real durable run.
    assert {:ok, parked} = PPlan.run_purchase(%{"amount" => 1500, "limit" => 500}, subject: subject)
    assert parked.state == :awaiting_human_release

    # Reload roundtrip: the record is really in the store under the exact
    # subject identity, not a derived key.
    assert {:ok, record} = AshPPlan.A2A.Facade.fetch(store, subject, store_module: @store_mod)
    assert record.id == subject
    assert record.status == :waiting

    # Adopt-on-restart determinism: re-running the same subject adopts the
    # same run (same record id), it does not mint a sibling run.
    assert {:ok, _parked2} = PPlan.run_purchase(%{"amount" => 1500, "limit" => 500}, subject: subject)

    assert {:ok, record2} = AshPPlan.A2A.Facade.fetch(store, subject, store_module: @store_mod)
    assert record2.id == record.id

    # Consume-once: release delivers one signal; once consumed, the store's
    # signal/waiter surface is drained — a second delivery cannot double-spend.
    assert {:ok, done} = PPlan.release_purchase(parked.provenance.continuation, release: "operator-release")
    assert done.state == :completed
    assert done.provenance.resumed_from_continuation == subject
    assert @store_mod.pending_signal(store, subject, "human_release") == nil
    assert @store_mod.get_waiter(store, subject, "human_release") == nil

    # Sealed terminal run: a further resume returns the sealed completion —
    # the finished run is idempotent under re-delivery, not re-executed.
    assert {:ok, :completed, sealed} =
             AshPPlan.A2A.Facade.resume(store, subject, "second-release", store_module: @store_mod)

    assert sealed != nil

    assert {:ok, final} = AshPPlan.A2A.Facade.fetch(store, subject, store_module: @store_mod)
    assert final.status == :completed
  end
end
