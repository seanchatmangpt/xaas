defmodule Xaas.ActuationOcelUndoTest do
  @moduledoc """
  Chicago-style integration test for the OCEL non-transactional side-effect
  gap closed in `lib/xaas/actuation.ex` and
  `lib/xaas/telemetry/ocel_forwarder.ex`.

  `Xaas.Telemetry.OcelAshEmitter` is a single global `:telemetry` handler
  attached once for every configured Ash domain (see its `attach!/0`) --
  there is no per-call opt-out to suppress the OCEL POST for one actuation.
  So `Xaas.Actuation.Reactor`'s `:do` ash_step instead carries a real
  `undo/4` callback (`Xaas.Actuation.Kernel.undo_actuate/3`) that Reactor
  invokes when this step has already succeeded but a later step in the same
  reactor run fails and the run must roll back -- the real semantics for
  "already happened, must now be corrected," as opposed to `compensate/4`,
  which only fires when the step's own `run/3` itself returns an error (it
  never would here, since `actuate/2` always returns `{:ok, _}`, wrapping
  the target Ash action's own errors inside that ok tuple).

  No HTTP client mock is used. This test starts a real Bandit HTTP server on
  a real loopback port running a real Plug that captures the real decoded
  request body, exactly as `test/xaas/telemetry/ocel_forwarder_test.exs`
  already does for `OcelForwarder.forward/1` -- extended here to also cover
  the new `forward_cancellation/1` function and the real
  `Xaas.Actuation.Kernel.undo_actuate/3` callback that calls it, using a
  real `admission` produced by the real `Xaas.Actuation.Kernel.admit/2`
  function against a real sandboxed Postgres-backed `Provider` resource --
  not a fabricated struct.
  """

  use ExUnit.Case, async: false

  alias Xaas.Actuation.Kernel
  alias Xaas.Marketplace.Provider

  defmodule CapturingPlug do
    use Plug.Router

    plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
    plug(:match)
    plug(:dispatch)

    post "/api/v1/ocel/events" do
      send(:actuation_ocel_undo_test, {:captured_envelope, conn.body_params})

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
    Process.register(self(), :actuation_ocel_undo_test)

    port = 42_777 + :erlang.phash2(self(), 500)

    {:ok, server_pid} = Bandit.start_link(plug: CapturingPlug, port: port, ip: {127, 0, 0, 1})
    Process.unlink(server_pid)

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

  # This file's own defaults (name/org_id) differ deliberately from
  # Xaas.Generator.create_provider!/1's own generic defaults ("Test
  # Provider"/"org-generated") -- kept for readability of the captured OCEL
  # envelopes this test asserts on. Slug is left to Xaas.Generator's own
  # unique sequence.
  defp create_provider! do
    Xaas.Generator.create_provider!(%{name: "OCEL Undo Provider", org_id: "org-ocel-undo"})
  end

  # `Xaas.Telemetry.OcelAshEmitter` is a real, already-attached global
  # `:telemetry` handler for every Ash action -- `create_provider!/0` and
  # `Kernel.admit/2`'s own internal Ash reads/writes for the intent/receipt
  # each produce their own real OCEL event forwarded to the same capturing
  # server this test configured. Drain those unrelated real events before
  # asserting on the one this test cares about, rather than asserting on
  # message order.
  defp drain_captured_envelopes do
    receive do
      {:captured_envelope, _} -> drain_captured_envelopes()
    after
      100 -> :ok
    end
  end

  defp real_admission(provider, key) do
    args = %{
      resource: Provider,
      action: :actuate_status,
      input: %{status: :active},
      subject_id: provider.id,
      actor: nil,
      tenant: nil,
      authorize?: false,
      authority: %{kind: "test_authority", source: "actuation_ocel_undo_test"},
      idempotency_key: key
    }

    {:ok, admission} = Kernel.admit(args, %{})
    admission
  end

  test "undo_actuate/3 forwards a real OCEL cancellation event keyed by the real idempotency key" do
    provider = create_provider!()
    key = "test-ocel-undo-#{System.unique_integer([:positive])}"
    admission = real_admission(provider, key)
    drain_captured_envelopes()

    assert :ok = Kernel.undo_actuate(:irrelevant_run_value, %{admission: admission}, %{})

    assert_receive {:captured_envelope, envelope}, 2_000

    assert is_binary(envelope["schema"])
    assert is_map(envelope["producer"])
    assert is_integer(envelope["sequence"])
    assert [event] = envelope["events"]

    short_name = Ash.Resource.Info.short_name(Provider)
    assert event["ocel:activity"] == "#{short_name}.actuate_status.cancelled"
    assert event["ocel:vmap"]["outcome"] == "cancelled"
    assert event["ocel:vmap"]["action"] == "actuate_status"
    assert event["ocel:vmap"]["idempotency_key"] == key
  end

  test "undo_actuate/3 is a real no-op on a replayed admission -- nothing new was forwarded to cancel" do
    provider = create_provider!()
    key = "test-ocel-undo-replay-#{System.unique_integer([:positive])}"

    real_admission = real_admission(provider, key)
    replayed_admission = %{real_admission | replay?: true}
    drain_captured_envelopes()

    assert :ok = Kernel.undo_actuate(:irrelevant_run_value, %{admission: replayed_admission}, %{})

    refute_receive {:captured_envelope, _}, 200
  end

  test "OcelForwarder.forward_cancellation/1 is a real no-op when no ingest URL is configured" do
    Application.delete_env(:xaas, :ex4pm_ocel_ingest_url)

    assert :ok =
             Xaas.Telemetry.OcelForwarder.forward_cancellation(%{
               resource: Provider,
               action: :actuate_status,
               idempotency_key: "test-ocel-undo-noop"
             })

    refute_receive {:captured_envelope, _}, 200
  end
end
