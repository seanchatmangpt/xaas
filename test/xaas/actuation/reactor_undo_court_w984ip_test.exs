defmodule Xaas.Actuation.ReactorUndoCourtW984ipTest do
  @moduledoc """
  Lane W984ip unclaimed-family probe: the reactor-level `undo` wiring of
  `Xaas.Actuation.Reactor`'s `:do` step.

  Census (before this court):

    * `test/xaas/actuation_ocel_undo_test.exs` — covers `undo_actuate/3` at
      UNIT level (both clauses, called directly with a real admission) and
      `forward_cancellation/1`'s no-URL no-op arm. Nothing there runs the
      reactor, so the claim "Reactor actually invokes the undo callback when
      a later step fails" was UNWITNESSED.
    * `test/xaas/actuation/*` deepening courts — cover admit/refusal/replay/
      halt/spg branches of `Xaas.Actuation.run/4`. None drives the reactor
      into a post-`:do` step failure, so `run_reactor_or_rollback/2`'s
      `{:error, ...} -> rollback` arm and the undo firing inside a real
      `Reactor.run` were also UNWITNESSED.
    * `test/xaas/telemetry/family_court_w984gj_test.exs` — covers
      `forward_cancellation/1`'s envelope-shape arms at the forwarder level.

  This court witnesses the whole arm end to end with real collaborators
  (real Postgres sandbox, real Reactor, real Bandit loopback HTTP capture):

  1. A real `Xaas.Actuation.run/4` whose `:do` step succeeds but whose
     `:receipt` step fails for a REAL reason (the sealed result is not
     castable into the receipt's `:map`-typed `:result` attribute), so
     Reactor rolls back and invokes `undo_actuate/3`, which forwards a real
     OCEL cancellation event over real HTTP.
  2. The outer `Ash.DataLayer.transaction` rolls back: no `ActuationIntent`
     or `ActuationReceipt` rows survive for the idempotency key, and the
     idempotency ledger is clean enough that the same key can be reused for
     a fresh (non-replay) admission afterwards.

  Zero mocks: the HTTP capture server is the same real-Bandit pattern the
  existing OCEL courts already use.
  """

  use ExUnit.Case, async: false

  import Ecto.Query

  alias Xaas.Operations.{ActuationIntent, ActuationReceipt}

  defmodule CapturingPlug do
    use Plug.Router

    plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
    plug(:match)
    plug(:dispatch)

    post "/api/v1/ocel/events" do
      send(:reactor_undo_court_w984ip, {:captured_envelope, conn.body_params})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(201, Jason.encode!(%{"status" => "success"}))
    end

    match _ do
      Plug.Conn.send_resp(conn, 404, "not found")
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Process.register(self(), :reactor_undo_court_w984ip)

    # Real OS-assigned ephemeral port (same SJ-009 fix as
    # actuation_ocel_undo_test.exs -- no hash-derived port collisions).
    {:ok, server_pid} = Bandit.start_link(plug: CapturingPlug, port: 0, ip: {127, 0, 0, 1})
    Process.unlink(server_pid)
    {:ok, {_address, port}} = ThousandIsland.listener_info(server_pid)

    previous_url = Application.get_env(:xaas, :ex4pm_ocel_ingest_url)

    Application.put_env(
      :xaas,
      :ex4pm_ocel_ingest_url,
      "http://127.0.0.1:#{port}/api/v1/ocel/events"
    )

    on_exit(fn ->
      if previous_url do
        Application.put_env(:xaas, :ex4pm_ocel_ingest_url, previous_url)
      else
        Application.delete_env(:xaas, :ex4pm_ocel_ingest_url)
      end

      if Process.alive?(server_pid), do: Process.exit(server_pid, :shutdown)
    end)

    :ok
  end

  # `Xaas.Accounts.Token.action :is_revoked` is the one real, registry-
  # admitted (verified by a real `Xaas.Semantics.Registry.admit/1` probe run
  # against the real app before writing this court) generic action that
  # (a) runs with no external service and no mutation, and (b) returns a
  # bare BOOLEAN. `json_safe/1` preserves booleans, and the receipt's
  # `:result` attribute is typed `:map`, so the `:receipt` step's
  # `Ash.update ... action: :seal` fails with a real invalid-attribute
  # error. That is the one genuinely reachable, unmocked way to fail a step
  # AFTER `:do` has already succeeded -- the exact precondition for Reactor
  # to invoke `undo_actuate/3`.
  defp run_is_revoked(key) do
    Xaas.Actuation.run(
      Xaas.Accounts.Token,
      :is_revoked,
      %{token: "court-token-#{key}", jti: "court-jti-#{key}"},
      authorize?: false,
      idempotency_key: key,
      authority: %{kind: "test_authority", source: "reactor_undo_court_w984ip"}
    )
  end

  # Admit creates intent + receipt rows; OcelAshEmitter forwards real OCEL
  # events for those Ash writes (and for the `:do` action itself) to the
  # capture server. Drain everything emitted BEFORE the run under test so
  # the cancellation envelope is unambiguous; the await helper filters by
  # idempotency key for the rest.
  defp drain_captured_envelopes do
    receive do
      {:captured_envelope, _} -> drain_captured_envelopes()
    after
      100 -> :ok
    end
  end

  defp await_cancelled_envelope(key) do
    deadline = System.monotonic_time(:millisecond) + 5_000
    do_await(deadline, key)
  end

  defp do_await(deadline, key) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      flunk("no cancellation envelope arrived for key #{key}")
    end

    receive do
      {:captured_envelope, envelope} ->
        events = envelope["events"] || []

        cancelled? =
          Enum.any?(events, fn event ->
            vmap = event["ocel:vmap"] || %{}
            vmap["outcome"] == "cancelled" and vmap["idempotency_key"] == key
          end)

        if cancelled?, do: envelope, else: do_await(deadline, key)
    after
      200 -> do_await(deadline, key)
    end
  end

  defp intent_for(key) do
    from(i in ActuationIntent, where: i.idempotency_key == ^key)
    |> Xaas.Repo.one()
  end

  defp receipt_count_for_subject(subject_id) do
    from(r in ActuationReceipt, where: r.subject_id == ^subject_id)
    |> Xaas.Repo.aggregate(:count, :id)
  end

  test "mid-reactor :receipt failure rolls the whole actuation back and the undo arm forwards a real OCEL cancellation event" do
    key = "w984ip-rollback-#{System.unique_integer([:positive])}"
    assert is_nil(intent_for(key))
    drain_captured_envelopes()

    result = run_is_revoked(key)

    assert {:error, {:reactor_failed, %Reactor.Error.Invalid{}} = unwrapped} = result
    assert unwrapped |> elem(1) |> Map.get(:errors) |> is_list()

    # Undo arm fired: a real cancellation event crossed real HTTP carrying
    # the real idempotency key threaded through run/4.
    envelope = await_cancelled_envelope(key)
    assert is_binary(envelope["schema"])
    assert is_map(envelope["producer"])
    assert [event] = envelope["events"]
    short_name = Ash.Resource.Info.short_name(Xaas.Accounts.Token)
    assert event["ocel:activity"] == "#{short_name}.is_revoked.cancelled"

    # Outer Ash.DataLayer.transaction rolled back: neither the intent nor the
    # receipt survived, even though :admit and :do both really succeeded.
    assert is_nil(intent_for(key))
    assert receipt_count_for_subject("court-jti-#{key}") == 0
  end

  test "after a rolled-back run the same idempotency key admits fresh (no ledger residue)" do
    key = "w984ip-rollback-#{System.unique_integer([:positive])}"
    drain_captured_envelopes()

    assert {:error, _} = run_is_revoked(key)
    await_cancelled_envelope(key)
    assert is_nil(intent_for(key))

    # The rolled-back admission left no ledger residue: the same key is
    # lawfully reusable for a completely different consequence.
    provider =
      Xaas.Generator.create_provider!(%{name: "W984IP Replay Provider", org_id: "org-w984ip"})

    {:ok, envelope} =
      Xaas.Actuation.run(
        Xaas.Marketplace.Provider,
        :actuate_status,
        %{status: :active},
        subject_id: provider.id,
        authorize?: false,
        idempotency_key: key,
        authority: %{kind: "test_authority", source: "reactor_undo_court_w984ip"}
      )

    assert envelope.status == :succeeded
    assert envelope.replay? == false

    # And the mutation really happened.
    assert {:ok, reloaded} = Ash.get(Xaas.Marketplace.Provider, provider.id, authorize?: false)
    assert reloaded.status == :active
  end
end
