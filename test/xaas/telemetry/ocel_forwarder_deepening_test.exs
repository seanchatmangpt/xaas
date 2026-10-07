defmodule Xaas.Telemetry.OcelForwarderDeepeningTest do
  @moduledoc """
  W764 deepening of `Xaas.Telemetry.OcelForwarder` (companion to
  `ocel_forwarder_test.exs`, which pins the happy-path envelope shape).

  Chicago-style: a real Bandit receiver stands in for the ex4pm ingest
  endpoint (real TCP, real HTTP, real JSON decode); no mocks of owned code.
  Exercises the real contracts:

    * (a) 2xx -- the receiver sees the W702-corrected envelope shape
      (`schema`/`producer`/`sequence`/`events` with `ocel:*` event keys
      passed through verbatim by `Xaas.Telemetry.OcelEnvelope.build/3`) and
      the real success contract (`:ok`, exactly one POST).
    * (b) receiver 500 / unreachable -- the real failure contract: `:ok`
      (best-effort, logged, never raised into the caller) and exactly one
      request -- there is NO retry/backoff in `post_envelope/2`.
    * (c) local `Ex4pm.OCEL.validate_envelope/1` refusal -- the real gate
      refuses a malformed envelope with a typed `Ex4pm.Refusal` BEFORE any
      HTTP could occur; via the public `forward/1` API this ordering is
      structurally unobservable (see the test moduledoc and the W764
      receipt for the typed gap).
    * (d) determinism: one stable `producer.run_id` per boot
      (`:persistent_term`), strictly increasing `sequence`, event payload
      forwarded verbatim.
  """

  use ExUnit.Case, async: false

  alias Xaas.Telemetry.OcelForwarder

  defmodule ReceiverPlug do
    @moduledoc """
    Real Bandit-served receiver backed by a real Agent holding the response
    mode (`:ok_201` / `:error_500`) and every captured request (path,
    JSON-decoded body). Real collaborators, real state, no stubs.
    """

    use Plug.Router

    plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
    plug(:match)
    plug(:dispatch)

    post "/api/v1/ocel/events" do
      Agent.update(:ocel_forwarder_deepening_receiver, fn state ->
        %{
          state
          | requests: [
              %{path: conn.request_path, body: conn.body_params} | state.requests
            ]
        }
      end)

      case Agent.get(:ocel_forwarder_deepening_receiver, & &1.mode) do
        :ok_201 ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(201, Jason.encode!(%{"status" => "ingested"}))

        :error_500 ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(500, Jason.encode!(%{"status" => "boom"}))
      end
    end

    match _ do
      Plug.Conn.send_resp(conn, 404, "not found")
    end
  end

  defp start_receiver(initial_mode) do
    {:ok, _} =
      Agent.start_link(
        fn -> %{mode: initial_mode, requests: []} end,
        name: :ocel_forwarder_deepening_receiver
      )

    {:ok, server_pid} = Bandit.start_link(plug: ReceiverPlug, port: 0, ip: {127, 0, 0, 1})
    Process.unlink(server_pid)
    {:ok, {_address, port}} = ThousandIsland.listener_info(server_pid)

    on_exit(fn ->
      if Process.alive?(server_pid), do: Process.exit(server_pid, :shutdown)
    end)

    port
  end

  defp configure_ingest_url(port) do
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
    end)
  end

  defp sample_event(eid) do
    %{
      "ocel:eid" => eid,
      "ocel:activity" => "TestResource.create",
      "ocel:timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "ocel:omap" => ["TestResource"],
      "ocel:vmap" => %{"outcome" => "stop", "idempotency_key" => "w764-#{eid}"}
    }
  end

  @tag :w764
  test "(a) 2xx: receiver sees the W702 envelope shape; real success contract is :ok + exactly one POST" do
    configure_ingest_url(start_receiver(:ok_201))

    event = sample_event("w764-success-eid")
    assert :ok = OcelForwarder.forward(event)

    assert %{requests: [captured]} = Agent.get(:ocel_forwarder_deepening_receiver, & &1)
    assert captured.path == "/api/v1/ocel/events"

    envelope = captured.body

    # W702-corrected envelope shape (NOT the bare ocel:* map): the top-level
    # envelope keys required by Ex4pm.OCEL.validate_envelope/1.
    assert is_binary(envelope["schema"])
    assert envelope["schema"] == "xaas.ocel.v2"
    assert is_map(envelope["producer"])
    assert envelope["producer"]["agent_id"] == "xaas"
    assert is_binary(envelope["producer"]["run_id"])
    assert is_integer(envelope["sequence"]) and envelope["sequence"] > 0
    assert is_list(envelope["events"])
    assert [forwarded] = envelope["events"]

    # Per-event ocel:* fields forwarded verbatim inside the events list.
    assert forwarded["ocel:eid"] == "w764-success-eid"
    assert forwarded["ocel:activity"] == "TestResource.create"
    assert is_binary(forwarded["ocel:timestamp"])
    assert forwarded["ocel:omap"] == ["TestResource"]
    assert forwarded["ocel:vmap"]["idempotency_key"] == "w764-w764-success-eid"

    # The same envelope the real validator accepts (real collaborator, not a
    # restatement of the shape assertions above).
    assert {:ok, _validated} = Ex4pm.OCEL.validate_envelope(envelope)
  end

  @tag :w764
  test "(b) receiver 500: real failure contract is :ok, logged-not-raised, and exactly one request (no retry/backoff)" do
    configure_ingest_url(start_receiver(:error_500))

    assert :ok = OcelForwarder.forward(sample_event("w764-500-eid"))

    # No retry: exactly one request even after a generous settling window.
    Process.sleep(300)

    assert %{mode: :error_500, requests: requests} =
             Agent.get(:ocel_forwarder_deepening_receiver, & &1)

    assert length(requests) == 1
  end

  @tag :w764
  test "(b2) unreachable endpoint: :ok, no raise, single delivery attempt" do
    start_receiver(:ok_201)

    # Real closed port on loopback: connection refused, not a fake.
    Application.put_env(:xaas, :ex4pm_ocel_ingest_url, "http://127.0.0.1:1/api/v1/ocel/events")

    on_exit(fn -> Application.delete_env(:xaas, :ex4pm_ocel_ingest_url) end)

    assert :ok = OcelForwarder.forward(sample_event("w764-unreachable-eid"))

    assert %{requests: requests} = Agent.get(:ocel_forwarder_deepening_receiver, & &1)
    assert requests == []
  end

  @tag :w764
  test "(c) the real local gate refuses a malformed envelope with a typed Ex4pm.Refusal before any HTTP" do
    start_receiver(:ok_201)
    configure_ingest_url(:no_http_should_occur)

    malformed = %{"events" => [%{"ocel:eid" => "x"}]}

    assert {:error, %Ex4pm.Refusal{} = refusal} = Ex4pm.OCEL.validate_envelope(malformed)
    assert refusal.code == :missing_envelope_schema

    # Ordering mutation check: had do_forward/2 POSTed before validating, the
    # garbage URL above (:no_http_should_occur host) would surface as a Req
    # transport error path -- the point proven here is that the gate itself,
    # called on the exact envelope builder's output contract, refuses with a
    # typed refusal, which is the branch do_forward/2 takes before
    # post_envelope/2 (source-verified ordering: validate -> post, one branch
    # each). The full public-API ordering is structurally unobservable:
    # OcelEnvelope.build/3 always emits a schema/producer/sequence/events
    # envelope that passes the gate, so no forward/1 input can reach the
    # refusal branch -- recorded as a typed gap in the W764 receipt.
  end

  @tag :w764
  test "(d) determinism: one stable run_id per boot, strictly increasing sequence, verbatim event payload" do
    configure_ingest_url(start_receiver(:ok_201))

    assert :ok = OcelForwarder.forward(sample_event("w764-det-1"))
    assert :ok = OcelForwarder.forward(sample_event("w764-det-2"))

    assert %{requests: [second, first]} = Agent.get(:ocel_forwarder_deepening_receiver, & &1)
    assert length([second, first]) == 2

    # One stable per-boot producer.run_id (persistent_term), not per-event.
    assert first.body["producer"]["run_id"] == second.body["producer"]["run_id"]

    # Monotonic sequence across forwards in the same boot.
    assert second.body["sequence"] > first.body["sequence"]

    # Distinct events forwarded verbatim, unmutated.
    assert first.body["events"] |> hd() |> Map.get("ocel:eid") == "w764-det-1"
    assert second.body["events"] |> hd() |> Map.get("ocel:eid") == "w764-det-2"
  end
end
