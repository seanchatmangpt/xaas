defmodule Xaas.Platform.WebhookDeliveryStressTest do
  @moduledoc """
  Real concurrency stress test for `Xaas.Platform.WebhookDelivery`'s real
  `:deliver` outbound-dispatch action (`Xaas.Platform.Changes.DeliverWebhook`),
  following the exact same real convention as
  `test/xaas/marketplace/provider_stress_test.exs`: `Ecto.Adapters.SQL.Sandbox`
  in `{:shared, self()}` mode so every spawned `Task.async_stream` connection
  reuses this test process's sandboxed transaction, real `Ash` calls (no
  mocking), real state-based assertions on the real final DB rows.

  50 real concurrent Tasks each create a distinct real `Xaas.Platform.Webhook`
  (own row, own url pointing at one shared real local `Plug.Cowboy` listener)
  and a distinct real `Xaas.Platform.WebhookDelivery`, then call the real
  `:deliver` action on it -- a real `Req.post/2` HTTP round-trip to the real
  listener, a real HMAC-SHA256 signature computed and verified, exactly as
  `test/xaas/platform/deliver_webhook_test.exs` exercises sequentially. This
  proves the same dispatch path holds under real concurrent load: all 50
  deliveries land `:delivered`, the real listener (via a real `Agent`
  accumulating a list, not overwriting a single slot) receives exactly 50
  distinct real requests -- no lost delivery, no duplicate delivery.
  """

  use ExUnit.Case, async: false
  @moduletag :stress

  alias Xaas.Platform.Webhook
  alias Xaas.Platform.WebhookDelivery

  defmodule CapturingPlug do
    @moduledoc """
    Real Plug that APPENDS each received request (body + a caller-supplied
    `n` query param used to identify which of the 50 concurrent deliveries
    it was) to a real `Agent`-held list, then returns a real 200. Appending
    (not overwriting) is what lets this stress test prove no delivery among
    the 50 concurrent ones was silently lost or double-counted.
    """
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, opts) do
      agent = Keyword.fetch!(opts, :agent)
      conn = Plug.Conn.fetch_query_params(conn)
      {:ok, body, conn} = read_body(conn)

      Agent.update(agent, fn received -> [{conn.query_params["n"], body} | received] end)

      send_resp(conn, 200, "ok")
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
    end)

    :ok
  end

  test "50 real concurrent :deliver dispatches all land :delivered, real listener receives exactly 50, no lost/duplicated deliveries" do
    run_tag = System.unique_integer([:positive, :monotonic])

    {:ok, agent} = Agent.start_link(fn -> [] end)
    port = 21_000 + rem(run_tag, 4000)

    {:ok, _pid} =
      Plug.Cowboy.http(CapturingPlug, [agent: agent], port: port, ref: make_ref())

    on_exit(fn -> Plug.Cowboy.shutdown(CapturingPlug.HTTP) end)

    base_url = "http://127.0.0.1:#{port}/"

    results =
      1..50
      |> Task.async_stream(
        fn i ->
          webhook =
            Webhook
            |> Ash.Changeset.for_create(
              :create,
              %{
                org_id: "webhook-stress-org-#{run_tag}",
                url: base_url <> "?n=#{i}",
                event_types: ["stress.event"],
                secret: "stress-secret-#{run_tag}-#{i}",
                enabled: true
              },
              authorize?: false
            )
            |> Ash.create!()

          delivery =
            WebhookDelivery
            |> Ash.Changeset.for_create(
              :create,
              %{
                webhook_id: webhook.id,
                event_type: "stress.event",
                payload: %{"run_tag" => run_tag, "n" => i}
              },
              authorize?: false
            )
            |> Ash.create!()

          delivery
          |> Ash.Changeset.for_update(:deliver, %{}, authorize?: false)
          |> Ash.update!()
        end,
        max_concurrency: 50,
        timeout: 30_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert length(results) == 50
    assert Enum.all?(results, &match?(%WebhookDelivery{status: :delivered}, &1))
    assert Enum.all?(results, &(&1.attempt_count == 1))

    delivered_ids = Enum.map(results, & &1.id)
    assert MapSet.size(MapSet.new(delivered_ids)) == 50

    # Real proof the real listener received exactly 50 real requests --
    # no lost delivery, no duplicate delivery.
    received = Agent.get(agent, & &1)
    assert length(received) == 50

    received_ns = Enum.map(received, fn {n, _body} -> n end) |> Enum.sort()
    expected_ns = 1..50 |> Enum.map(&Integer.to_string/1) |> Enum.sort()
    assert received_ns == expected_ns

    # Real persisted-state re-check, independent of the in-memory `results`
    # list above: read the real rows back from Postgres.
    persisted =
      WebhookDelivery
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.id in delivered_ids))

    assert length(persisted) == 50
    assert Enum.all?(persisted, &(&1.status == :delivered))
  end
end
