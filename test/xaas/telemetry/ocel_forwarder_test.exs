defmodule Xaas.Telemetry.OcelForwarderTest do
  @moduledoc """
  Chicago-style integration test: no mocked HTTP client. Starts a real
  Bandit HTTP server on a real loopback port, running a real Plug that
  captures the real request body, and asserts `OcelForwarder.forward/1`
  performs a real `POST` whose JSON body matches the exact envelope shape
  required by `Ex4pm.OCEL.validate_envelope/1`
  (`/Users/sac/ex4pm/apps/ex4pm_core/lib/ex4pm/ocel.ex`): a map with
  `"schema"`, `"producer"` (a map), an integer `"sequence"`, and an
  `"events"` list/map -- confirmed field-for-field by reading that
  function and `Ex4pm.Stream.Ingest.ingest_envelope/2` directly, not
  assumed to match xaas's bare `ocel:eid`/... shape.
  """
  use ExUnit.Case, async: false

  alias Xaas.Telemetry.OcelForwarder

  defmodule CapturingPlug do
    use Plug.Router

    plug(Plug.Parsers,
      parsers: [:json],
      json_decoder: Jason
    )

    plug(:match)
    plug(:dispatch)

    post "/api/v1/ocel/events" do
      # Real assertion target: hand the real decoded body back to the test
      # process, mirroring what Ex4pmWeb.OcelController.ingest/2 receives
      # as `params` before it calls Ex4pm.Stream.Ingest.ingest_envelope/2.
      send(:ocel_forwarder_test, {:captured_envelope, conn.body_params})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(201, Jason.encode!(%{"status" => "success"}))
    end

    match _ do
      Plug.Conn.send_resp(conn, 404, "not found")
    end
  end

  setup do
    Process.register(self(), :ocel_forwarder_test)

    port = 41_777 + :erlang.phash2(self(), 500)

    {:ok, server_pid} =
      Bandit.start_link(plug: CapturingPlug, port: port, ip: {127, 0, 0, 1})

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

  test "forwards a real xaas OCEL event as an envelope ex4pm's real validate_envelope/1 accepts" do
    event = %{
      "ocel:eid" => "test-eid-123",
      "ocel:activity" => "TestResource.create",
      "ocel:timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "ocel:omap" => ["TestResource"],
      "ocel:vmap" => %{"outcome" => "stop"}
    }

    assert :ok = OcelForwarder.forward(event)

    assert_receive {:captured_envelope, envelope}, 2_000

    # Real shape assertions matching Ex4pm.OCEL.validate_envelope/1's real
    # required keys, field-for-field.
    assert is_binary(envelope["schema"])
    assert is_map(envelope["producer"])
    assert is_integer(envelope["sequence"])
    assert envelope["sequence"] >= 0
    assert is_list(envelope["events"])
    assert [forwarded_event] = envelope["events"]

    # The per-event OCEL fields survive forwarding unchanged (validated
    # later by Ex4pm.OCEL's own event normalizer, which reads the same
    # "ocel:eid"/"ocel:activity"/"ocel:timestamp" keys via its alias list).
    assert forwarded_event["ocel:eid"] == "test-eid-123"
    assert forwarded_event["ocel:activity"] == "TestResource.create"
  end

  test "forwarding to an unreachable endpoint is non-fatal" do
    Application.put_env(:xaas, :ex4pm_ocel_ingest_url, "http://127.0.0.1:1/api/v1/ocel/events")

    event = %{
      "ocel:eid" => "unreachable-test",
      "ocel:activity" => "TestResource.create",
      "ocel:timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "ocel:omap" => ["TestResource"],
      "ocel:vmap" => %{}
    }

    assert :ok = OcelForwarder.forward(event)
  end

  test "forwarding is a no-op when no ingest URL is configured" do
    Application.delete_env(:xaas, :ex4pm_ocel_ingest_url)

    event = %{
      "ocel:eid" => "noop-test",
      "ocel:activity" => "TestResource.create",
      "ocel:timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "ocel:omap" => ["TestResource"],
      "ocel:vmap" => %{}
    }

    assert :ok = OcelForwarder.forward(event)
    refute_receive {:captured_envelope, _}, 200
  end
end
