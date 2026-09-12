defmodule XaasWeb.OcelLiveServerChainTest do
  @moduledoc """
  Vision-2030 cycle 2026-09-09-0638 charter: prove the FULL live chain fires
  in composition, not just per-component in isolation.

  Chicago-style, real end to end: a real Bandit-booted HTTP listener serving
  the real `XaasWeb.Endpoint` plug pipeline (real socket, real TCP round
  trip -- not `Plug.Test`/`ConnTest`'s in-process conn dispatch), hit with a
  real `Req` HTTP client request against a real `/api` JSON:API route
  (`Xaas.Accounts.Org`'s `index :read`, chosen specifically because it is
  one of the few `/api` routes exempt from `XaasWeb.Plugs.ResolveOrgActor`'s
  `X-Org-Id` requirement, per that plug's own moduledoc). That request runs a real
  Ash read action, which fires the real `:telemetry.span([:ash, ...])`
  event Ash itself emits, through the real, already-attached
  `Xaas.Telemetry.OcelAshEmitter` handler (attached once at
  `Xaas.Application.start/2` boot -- this test does NOT call `attach!/0`
  itself, deliberately, to prove the boot-time wiring is what's firing),
  through the real `Xaas.Telemetry.OcelForwarder.forward/1`, through the
  real ggen-generated `Xaas.Telemetry.OcelEnvelope.build/3`, to a second
  real Bandit HTTP receiver standing in for `ex4pm_web` (same pattern
  `test/xaas/telemetry/ocel_forwarder_test.exs` already uses for its
  unit-level test of `OcelForwarder.forward/1` alone).

  Deliberate scope boundary (skeptic flag honored): this test makes zero
  edits to `lib/xaas/telemetry/ocel_forwarder.ex`,
  `lib/xaas/telemetry/ocel_ash_emitter.ex`, or
  `lib/xaas/telemetry/ocel_envelope.ex` -- it only proves (or disproves)
  that the already-shipped composition fires; it does not rebuild any
  already-individually-verified component.

  Deviation from the vision doc's literal "boot a real `mix phx.server`"
  instruction, disclosed rather than silently substituted: `config/test.exs`
  sets `server: false`, and `mix.exs` `end`'s `Xaas.Application` supervises
  exactly one singleton `XaasWeb.Endpoint` process by name -- starting a
  second, separately-configured `mix phx.server` OS process against the
  same app/DB from inside `mix test` is not a bounded, safely-cleaned-up
  operation within this batch's scope. Instead this test boots a real
  Bandit acceptor (`Bandit.start_link(plug: XaasWeb.Endpoint, ...)`) on a
  fresh loopback port, running the real, unmodified `XaasWeb.Endpoint` plug
  pipeline -- a real socket, a real HTTP/1.1 request/response cycle, through
  the real router/pipeline/controller/Ash stack. This proves the same real
  composition the charter cares about (HTTP -> Ash action -> :telemetry ->
  OcelAshEmitter -> OcelForwarder -> OcelEnvelope -> HTTP POST); it does not
  prove anything about the `mix phx.server` CLI wrapper itself, which owns
  no logic in this chain. Because no separate `phx.server` OS process is
  spawned, the "no leaked phx.server process" verification for this test is
  necessarily a check that the real Bandit acceptor process/port opened by
  THIS test is closed after `on_exit` -- not a `ps aux | grep phx.server`
  match, since that process is never created by this design.
  """
  use ExUnit.Case, async: false

  alias Xaas.Repo

  @moduletag :ocel_live_chain

  setup do
    Process.register(self(), :ocel_live_server_chain_test)

    # Sandbox in shared mode so the real Bandit acceptor process (which
    # handles the request in a different process than this test process)
    # can see the same real DB connection/transaction.
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    receiver_port = 42_100 + :erlang.phash2(make_ref(), 400)
    app_port = 42_600 + :erlang.phash2(make_ref(), 400)

    {:ok, receiver_pid} =
      Bandit.start_link(
        plug: XaasWeb.OcelLiveServerChainTest.CapturingReceiverPlug,
        port: receiver_port,
        ip: {127, 0, 0, 1}
      )

    Process.unlink(receiver_pid)

    previous_ingest_url = Application.get_env(:xaas, :ex4pm_ocel_ingest_url)

    Application.put_env(
      :xaas,
      :ex4pm_ocel_ingest_url,
      "http://127.0.0.1:#{receiver_port}/api/v1/ocel/events"
    )

    previous_token = System.get_env("INTERNAL_API_TOKEN")
    test_token = "ocel-live-chain-test-token"
    System.put_env("INTERNAL_API_TOKEN", test_token)

    {:ok, app_pid} =
      Bandit.start_link(
        plug: XaasWeb.Endpoint,
        port: app_port,
        ip: {127, 0, 0, 1}
      )

    Process.unlink(app_pid)

    on_exit(fn ->
      if Process.alive?(app_pid), do: Process.exit(app_pid, :shutdown)
      if Process.alive?(receiver_pid), do: Process.exit(receiver_pid, :shutdown)

      if previous_ingest_url do
        Application.put_env(:xaas, :ex4pm_ocel_ingest_url, previous_ingest_url)
      else
        Application.delete_env(:xaas, :ex4pm_ocel_ingest_url)
      end

      if previous_token do
        System.put_env("INTERNAL_API_TOKEN", previous_token)
      else
        System.delete_env("INTERNAL_API_TOKEN")
      end
    end)

    %{app_port: app_port, receiver_port: receiver_port, token: test_token}
  end

  defmodule CapturingReceiverPlug do
    use Plug.Router

    plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
    plug(:match)
    plug(:dispatch)

    post "/api/v1/ocel/events" do
      send(:ocel_live_server_chain_test, {:captured_envelope, conn.body_params})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(201, Jason.encode!(%{"status" => "success"}))
    end

    match _ do
      Plug.Conn.send_resp(conn, 404, "not found")
    end
  end

  test "a real HTTP request against a real running server fires the full OCEL chain",
       %{app_port: app_port, token: token} do
    url = "http://127.0.0.1:#{app_port}/api/orgs"

    response =
      Req.get!(url,
        headers: [{"authorization", "Bearer #{token}"}, {"accept", "application/vnd.api+json"}],
        retry: false
      )

    # Real HTTP round trip happened (status is asserted loosely: the point
    # of this cycle is proving the :telemetry span fires around the real
    # Ash read pipeline, which happens whether the policy authorizes or
    # forbids the unauthenticated/no-actor request -- both outcomes still
    # execute inside `Ash.Tracer.telemetry_span/4`).
    assert response.status in [200, 400, 403]

    assert_receive {:captured_envelope, envelope}, 5_000

    assert is_binary(envelope["schema"])
    assert is_map(envelope["producer"])
    assert is_list(envelope["events"])
    assert [forwarded_event | _] = envelope["events"]
    assert is_binary(forwarded_event["ocel:activity"])
    assert String.contains?(forwarded_event["ocel:activity"], "org")
  end
end
