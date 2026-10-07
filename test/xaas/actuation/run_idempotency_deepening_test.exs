defmodule Xaas.Actuation.RunIdempotencyDeepeningTest do
  @moduledoc """
  W747 — deepening of the `Xaas.Actuation.run/4` idempotency/replay contract.

  Chicago-style: real Ash resources, real Reactor, real sandboxed Postgres.
  Reuses the authority-context idiom of `test/xaas/actuation_test.exs`.
  Never touches `:actuate_status` outside the admitted `Xaas.Actuation.run/4`
  DO path (except the pre-existing bypass refusal, unchanged).
  """

  use ExUnit.Case, async: true

  alias Xaas.Marketplace.Provider
  alias Xaas.Operations.{ActuationIntent, ActuationReceipt}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_provider! do
    Xaas.Generator.create_provider!(%{name: "Reactor Provider", org_id: "org-reactor"})
  end

  defp run_actuation(provider, status, key) do
    Xaas.Actuation.run(
      Provider,
      :actuate_status,
      %{status: status},
      subject_id: provider.id,
      idempotency_key: key,
      authorize?: false,
      authority: %{kind: "test_authority", source: "w747"}
    )
  end

  test "(a) same key twice: second run is a replay, no new intent or receipt rows" do
    provider = create_provider!()
    key = "w747-replay-#{System.unique_integer([:positive])}"

    assert {:ok, first} = run_actuation(provider, :active, key)
    assert first.status == :succeeded
    refute first.replay?

    assert {:ok, replay} = run_actuation(provider, :active, key)
    assert replay.status == :replayed
    assert replay.replay?
    assert replay.receipt.id == first.receipt.id
    assert replay.intent.id == first.intent.id

    assert Ash.read!(ActuationIntent, authorize?: false)
           |> Enum.count(&(&1.idempotency_key == key)) == 1

    assert Ash.read!(ActuationReceipt, authorize?: false)
           |> Enum.count(&(&1.intent_id == first.intent.id)) == 1
  end

  test "(a2) replay returns the original consequence state, not a re-executed mutation" do
    provider = create_provider!()
    key = "w747-state-#{System.unique_integer([:positive])}"

    assert {:ok, first} = run_actuation(provider, :active, key)
    assert {:ok, replay} = run_actuation(provider, :active, key)

    # The replay must reflect the durable receipt's recorded consequence: the
    # subject still holds the first run's status, and the first receipt's
    # result snapshot/hash are what the replay envelope carries.
    assert Ash.get!(Provider, provider.id, authorize?: false).status == :active
    assert replay.receipt.result_hash == first.receipt.result_hash
    assert replay.receipt.result == first.receipt.result
    assert replay.receipt.status == :succeeded
  end

  test "(b) different keys for equivalent intents: two real receipts, no dedup" do
    provider = create_provider!()
    key_a = "w747-key-a-#{System.unique_integer([:positive])}"
    key_b = "w747-key-b-#{System.unique_integer([:positive])}"

    assert {:ok, first} = run_actuation(provider, :active, key_a)
    assert {:ok, second} = run_actuation(provider, :active, key_b)

    refute first.replay?
    refute second.replay?
    assert second.receipt.id != first.receipt.id
    assert second.intent.id != first.intent.id

    # Equivalent consequence happened twice (real DO both times).
    assert Ash.read!(ActuationIntent, authorize?: false)
           |> Enum.count(&(&1.idempotency_key in [key_a, key_b])) == 2

    assert Ash.read!(ActuationReceipt, authorize?: false)
           |> Enum.count(&(&1.intent_id in [first.intent.id, second.intent.id])) == 2
  end

  test "(c) replay after process restart: new process, same key, still replay" do
    provider = create_provider!()
    key = "w747-restart-#{System.unique_integer([:positive])}"

    assert {:ok, first} = run_actuation(provider, :active, key)
    assert first.status == :succeeded

    parent = self()

    task =
      Task.async(fn ->
        assert {:ok, replay} = run_actuation(provider, :active, key)
        replay
      end)

    # Grant the fresh process real sandbox access to the checked-out connection.
    :ok = Ecto.Adapters.SQL.Sandbox.allow(Xaas.Repo, parent, task.pid)

    replay = Task.await(task)

    assert replay.status == :replayed
    assert replay.replay?
    assert replay.receipt.id == first.receipt.id
    assert replay.intent.id == first.intent.id
    assert replay.receipt.status == :succeeded
  end

  test "(d1) missing idempotency key refused with exact atom" do
    provider = create_provider!()

    assert {:error, :idempotency_key_required} =
             Xaas.Actuation.run(
               Provider,
               :actuate_status,
               %{status: :active},
               subject_id: provider.id,
               authorize?: false,
               authority: %{kind: "test_authority", source: "w747"}
             )

    # Nothing was durably admitted.
    assert Ash.read!(ActuationIntent, authorize?: false) == []
  end

  test "(d2) delegated actuation without authority evidence is refused, nothing durably admitted" do
    provider = create_provider!()
    key = "w747-noauth-#{System.unique_integer([:positive])}"

    # The typed atom is raised inside the :admit step; `unwrap_reactor_error/1`
    # only surfaces the two idempotency tuples raw, so the refusal arrives as
    # the Reactor error envelope with the atom as the RunStepError payload.
    assert {:error, {:reactor_failed, %Reactor.Error.Invalid{} = err}} =
             Xaas.Actuation.run(
               Provider,
               :actuate_status,
               %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{}
             )

    assert [%Reactor.Error.Invalid.RunStepError{error: :delegated_actuation_requires_authority_evidence}] =
             err.errors

    # The transaction rolled back: no intent/receipt survives the refusal.
    assert Ash.read!(ActuationIntent, authorize?: false) == []
    assert Ash.read!(ActuationReceipt, authorize?: false) == []
  end

  test "(d3) malformed intent (non-atom action / non-map input) rejected at the guard boundary" do
    provider = create_provider!()

    assert_raise FunctionClauseError, fn ->
      Xaas.Actuation.run(
        Provider,
        "actuate_status",
        %{status: :active},
        subject_id: provider.id,
        idempotency_key: "w747-malformed-#{System.unique_integer([:positive])}",
        authorize?: false,
        authority: %{kind: "test_authority", source: "w747"}
      )
    end

    assert_raise FunctionClauseError, fn ->
      Xaas.Actuation.run(
        Provider,
        :actuate_status,
        "not-a-map",
        subject_id: provider.id,
        idempotency_key: "w747-malformed-#{System.unique_integer([:positive])}",
        authorize?: false,
        authority: %{kind: "test_authority", source: "w747"}
      )
    end

    assert Ash.read!(ActuationIntent, authorize?: false) == []
  end

  test "(d4) idempotency key reuse while intent still :executing is not replayable" do
    provider = create_provider!()
    key = "w747-executing-#{System.unique_integer([:positive])}"

    assert {:ok, %{status: :succeeded}} = run_actuation(provider, :active, key)

    # Force the durable intent back to :executing (simulating an interrupted
    # run whose outer seal never completed) — the transactional run/4 path has
    # no resume semantics; that is the external three-commit protocol.
    intent =
      Ash.read!(ActuationIntent, authorize?: false)
      |> Enum.find(&(&1.idempotency_key == key))

    Ash.update!(intent, %{status: :executing}, action: :transition, authorize?: false)

    assert {:error, {:idempotency_not_replayable, ^key, :executing}} =
             run_actuation(provider, :active, key)
  end

  test "(f) W773: tuple-shaped execution error is durably sealed :failed with a normalized map error" do
    provider = create_provider!()
    key = "w773-unknown-action-#{System.unique_integer([:positive])}"

    # `:does_not_exist` passes the run/4 atom guard but is not a real action;
    # `execute_action/8` returns the raw tuple {:unknown_action, resource, action}.
    assert {:error, {:unknown_action, Provider, :does_not_exist}} =
             Xaas.Actuation.run(
               Provider,
               :does_not_exist,
               %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{kind: "test_authority", source: "w773"}
             )

    # The durable ledger sealed the failure instead of rolling it back:
    # the persisted receipt row carries the normalized json-safe map error.
    receipt =
      Ash.read!(ActuationReceipt, authorize?: false)
      |> Enum.find(&(&1.intent_id && Ash.get!(ActuationIntent, &1.intent_id, authorize?: false).idempotency_key == key))

    assert %ActuationReceipt{status: :failed, error: error, completed_at: completed_at} = receipt
    assert %{"class" => "unknown_action",
             "detail" => ["Elixir.Xaas.Marketplace.Provider", "does_not_exist"]} = error
    assert %DateTime{} = completed_at

    intent =
      Ash.read!(ActuationIntent, authorize?: false)
      |> Enum.find(&(&1.idempotency_key == key))

    assert %ActuationIntent{status: :failed} = intent
  end

  test "(e) determinism x2: two full succeed-then-replay cycles give identical envelopes" do
    for cycle <- 1..2 do
      provider = create_provider!()
      key = "w747-det-#{cycle}-#{System.unique_integer([:positive])}"

      assert {:ok, first} = run_actuation(provider, :active, key)
      assert {:ok, replay} = run_actuation(provider, :active, key)

      assert %{status: :succeeded, replay?: false} = first
      assert %{status: :replayed, replay?: true} = replay

      assert first.receipt.status == :succeeded
      assert is_binary(first.receipt.input_hash)
      assert is_binary(first.receipt.result_hash)

      assert replay.receipt.id == first.receipt.id
      assert replay.receipt.result_hash == first.receipt.result_hash
      assert replay.receipt.input_hash == first.receipt.input_hash
    end
  end
end
