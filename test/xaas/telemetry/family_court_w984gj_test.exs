defmodule Xaas.Telemetry.FamilyCourtW984gjTest do
  @moduledoc """
  W984gj unclaimed-family probe court for the residue of
  `lib/xaas/telemetry/` left after W984ev's OcelNdjson court: the
  genuinely unexercised state-bearing branches of
  `Xaas.Telemetry.OcelForwarder` (the `forward_cancellation/1` egress
  branches for real-resource and non-resource subjects, and the
  `do_forward/2` rescue path when wire encoding raises) and
  `Xaas.Telemetry.OcelAshEmitter.attach!/0` (real telemetry-handler
  registration over a real Ash domain).

  Chicago-style: real Bandit receiver on real TCP (lane-local, distinct
  from the deepening test's receiver), real telemetry registration, real
  processes; zero mocks. Disjoint from W984ev (which owns
  `test/xaas/telemetry/ocel_ndjson_test.exs` /
  `lib/xaas/telemetry/ocel_ndjson.ex`).
  """

  use ExUnit.Case, async: false

  alias Xaas.Telemetry.OcelForwarder

  # -- real receiver (lane-local Bandit plug) --------------------------------

  defmodule GjReceiverPlug do
    @moduledoc """
    Real Bandit-served receiver: captures every POSTed envelope body in a
    real Agent; response mode is real state the test drives.
    """
    use Plug.Router

    plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
    plug(:match)
    plug(:dispatch)

    post "/api/v1/ocel/events" do
      Agent.update(:w984gj_receiver, fn state ->
        %{state | requests: [%{path: conn.request_path, body: conn.body_params} | state.requests]}
      end)

      case Agent.get(:w984gj_receiver, & &1.mode) do
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
  end

  defp start_receiver(initial_mode) do
    {:ok, _} =
      Agent.start_link(
        fn -> %{mode: initial_mode, requests: []} end,
        name: :w984gj_receiver
      )

    {:ok, server_pid} = Bandit.start_link(plug: GjReceiverPlug, port: 0, ip: {127, 0, 0, 1})
    Process.unlink(server_pid)
    {:ok, {_addr, port}} = ThousandIsland.listener_info(server_pid)

    on_exit(fn ->
      if Process.alive?(server_pid), do: Process.exit(server_pid, :shutdown)
    end)

    port
  end

  defp captured_requests do
    Agent.get(:w984gj_receiver, & &1.requests)
  end

  defp with_ingest_url(port, fun) do
    previous = Application.get_env(:xaas, :ex4pm_ocel_ingest_url)

    Application.put_env(
      :xaas,
      :ex4pm_ocel_ingest_url,
      "http://127.0.0.1:#{port}/api/v1/ocel/events"
    )

    try do
      fun.()
    after
      if previous,
        do: Application.put_env(:xaas, :ex4pm_ocel_ingest_url, previous),
        else: Application.delete_env(:xaas, :ex4pm_ocel_ingest_url)
    end
  end

  # -- OcelForwarder.forward_cancellation/1 ----------------------------------

  describe "OcelForwarder.forward_cancellation/1" do
    @tag :w984gj
    test "real Ash resource subject egresses a .cancelled envelope the receiver actually sees" do
      port = start_receiver(:ok_201)

      with_ingest_url(port, fn ->
        assert :ok =
                 OcelForwarder.forward_cancellation(%{
                   resource: Xaas.Library.Book,
                   action: :create,
                   idempotency_key: "w984gj-cancellation-resource"
                 })
      end)

      assert [%{path: "/api/v1/ocel/events", body: envelope}] = captured_requests()
      assert envelope["schema"] == "xaas.ocel.v2"

      assert [%{"ocel:activity" => "book.create.cancelled"} = event] = envelope["events"]
      assert event["ocel:vmap"]["outcome"] == "cancelled"
      assert event["ocel:vmap"]["idempotency_key"] == "w984gj-cancellation-resource"
      assert event["ocel:vmap"]["reason"] == "downstream_reactor_step_failed_after_action_execution"
      assert is_binary(event["ocel:eid"]) and event["ocel:eid"] != ""
      assert event["ocel:omap"] == ["book"]

      assert Regex.match?(
               ~r/^\d{4}-\d{2}-\d{2}T/,
               event["ocel:timestamp"]
             )

      assert {:ok, _} = Ex4pm.OCEL.validate_envelope(envelope)
    end

    @tag :w984gj
    test "non-resource subject falls back to the bare subject in the activity name" do
      port = start_receiver(:ok_201)

      with_ingest_url(port, fn ->
        assert :ok =
                 OcelForwarder.forward_cancellation(%{
                   resource: :NotAResourceModule,
                   action: :act,
                   idempotency_key: "w984gj-cancellation-atom"
                 })
      end)

      assert [%{body: envelope}] = captured_requests()

      assert [%{"ocel:activity" => "NotAResourceModule.act.cancelled"} = event] =
               envelope["events"]

      assert event["ocel:vmap"]["resource"] == inspect(:NotAResourceModule)
    end
  end

  # -- do_forward/2 rescue path ----------------------------------------------

  describe "OcelForwarder.do_forward/2 rescue branch" do
    # Jason encoding of an anonymous fun raises inside Req.post; the
    # forwarder must rescue and still return :ok, and the receiver must
    # see no egress. Mutation rationale: deleting the rescue clause (or
    # letting the raise escape) fails this test; forwarding anyway fails
    # the zero-egress assertion.
    @tag :w984gj
    test "a wire-unencodable payload is rescued into a logged :ok with zero egress" do
      port = start_receiver(:ok_201)

      with_ingest_url(port, fn ->
        assert :ok =
                 OcelForwarder.forward(%{
                   "ocel:eid" => Ash.UUIDv7.generate(),
                   "ocel:activity" => "Book.create",
                   "ocel:timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
                   "ocel:omap" => ["Book"],
                   "ocel:vmap" => %{"poison" => fn -> :boom end}
                 })
      end)

      assert captured_requests() == []
    end
  end

  # -- OcelAshEmitter.attach!/0 ----------------------------------------------

  describe "OcelAshEmitter.attach!/0" do
    @tag :w984gj
    test "registers real :telemetry handlers for a real domain, live and detachable" do
      previous = Application.get_env(:xaas, :ash_domains)
      Application.put_env(:xaas, :ash_domains, [Xaas.Library])

      ids =
        Xaas.Telemetry.OcelAshEmitter.attach!()

      try do
        assert is_list(ids) and ids != []

        assert {Xaas.Telemetry.OcelAshEmitter, Xaas.Library, :create, :stop} in ids

        # Real registration state: the handler is genuinely live on the
        # real event name, and the returned id is its real detach key.
        handler_id = {Xaas.Telemetry.OcelAshEmitter, Xaas.Library, :create, :stop}
        assert [%{id: ^handler_id}] = :telemetry.list_handlers([:ash, :library, :create, :stop])

        assert :ok = :telemetry.detach(handler_id)
        assert [] = :telemetry.list_handlers([:ash, :library, :create, :stop])
      after
        for id <- ids, do: :telemetry.detach(id)

        if previous,
          do: Application.put_env(:xaas, :ash_domains, previous),
          else: Application.delete_env(:xaas, :ash_domains)
      end
    end
  end
end
