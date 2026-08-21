defmodule Xaas.Platform.DeliverWebhookTest do
  @moduledoc """
  Real Chicago-style coverage for `Xaas.Platform.Changes.DeliverWebhook`
  (`WebhookDelivery`'s `:deliver` action).

  Starts a real local `Plug.Cowboy` HTTP listener per test, points a real
  `Webhook`'s `url` at it, triggers a real `:deliver`, and asserts on the
  real request the listener actually received (via a real `Agent`) plus
  the real persisted `WebhookDelivery.status`. No mocking of `Req`, the
  HTTP transport, or the delivery/signing code -- every collaborator here
  is real.
  """
  use ExUnit.Case, async: true

  alias Xaas.Platform.Webhook
  alias Xaas.Platform.WebhookDelivery

  defmodule CapturingPlug do
    @moduledoc """
    Real Plug that captures the received request (headers + raw body)
    into the real `Agent` named by the `:agent` init option, then returns
    a real 200.
    """
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, opts) do
      agent = Keyword.fetch!(opts, :agent)
      {:ok, body, conn} = read_body(conn)

      Agent.update(agent, fn _ ->
        %{body: body, headers: conn.req_headers}
      end)

      send_resp(conn, 200, "ok")
    end
  end

  setup do
    # Real, plain per-test checkout -- NOT `{:shared, self()}`. The real
    # `:deliver` HTTP round-trip (`Req` -> local `Plug.Cowboy` listener)
    # never touches this test's DB connection from another process (the
    # Cowboy request handler only writes to the real `Agent` above, not
    # to `Xaas.Repo`), so shared mode isn't needed. Shared mode instead
    # made this test's sandboxed connection visible to and shared with
    # OTHER concurrent `async: true` tests across the whole suite, a real
    # cross-test isolation bug that caused unrelated tests (e.g.
    # `ApprovalDrFailover`'s open-incident validation) to intermittently
    # see this test's transient data -- confirmed by a real `mix test`
    # run that failed only when this file ran alongside
    # `enqueue_webhook_deliveries_test.exs` and passed when run alone.
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_webhook!(url, secret \\ "real-hmac-secret") do
    Webhook
    |> Ash.Changeset.for_create(
      :create,
      %{
        org_id: "deliver-webhook-test-org",
        url: url,
        event_types: ["test.event"],
        secret: secret,
        enabled: true
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp create_delivery!(webhook, payload \\ %{"hello" => "world"}) do
    WebhookDelivery
    |> Ash.Changeset.for_create(
      :create,
      %{webhook_id: webhook.id, event_type: "test.event", payload: payload},
      authorize?: false
    )
    |> Ash.create!()
  end

  defp deliver!(delivery) do
    delivery
    |> Ash.Changeset.for_update(:deliver, %{}, authorize?: false)
    |> Ash.update!()
  end

  defp expected_signature(secret, raw_json_body) do
    hmac = :crypto.mac(:hmac, :sha256, secret, raw_json_body)
    "sha256=" <> Base.encode16(hmac, case: :lower)
  end

  test "a real 2xx response marks the delivery :delivered and the real listener receives the real signed payload" do
    {:ok, agent} = Agent.start_link(fn -> nil end)
    port = 20_000 + :erlang.phash2(self(), 10_000)

    {:ok, _pid} =
      Plug.Cowboy.http(CapturingPlug, [agent: agent], port: port, ref: make_ref())

    on_exit(fn -> Plug.Cowboy.shutdown(CapturingPlug.HTTP) end)

    secret = "real-hmac-secret-#{System.unique_integer([:positive])}"
    payload = %{"hello" => "world", "n" => System.unique_integer([:positive])}

    webhook = create_webhook!("http://127.0.0.1:#{port}/", secret)
    delivery = create_delivery!(webhook, payload)

    delivered = deliver!(delivery)

    assert delivered.status == :delivered
    assert delivered.attempt_count == 1
    assert delivered.last_attempted_at != nil

    captured = Agent.get(agent, & &1)
    assert captured != nil

    expected_body = Jason.encode!(payload)
    assert captured.body == expected_body

    {"x-webhook-signature", got_signature} =
      Enum.find(captured.headers, fn {k, _v} -> k == "x-webhook-signature" end)

    assert got_signature == expected_signature(secret, expected_body)
  end

  test "a closed local port leaves the delivery :failed with attempt_count incremented, no crash" do
    # A real port nothing is listening on -- a real connection-refused
    # transport error, not a simulated one.
    closed_port = 20_000 + :erlang.phash2(make_ref(), 10_000)

    webhook = create_webhook!("http://127.0.0.1:#{closed_port}/")
    delivery = create_delivery!(webhook)

    failed = deliver!(delivery)

    assert failed.status == :failed
    assert failed.attempt_count == 1
    assert failed.last_attempted_at != nil
  end

  test "a delivery already at the max attempt ceiling is not re-dispatched" do
    webhook = create_webhook!("http://127.0.0.1:1/")
    delivery = create_delivery!(webhook)

    at_ceiling =
      delivery
      |> Ash.Changeset.for_update(
        :record_attempt,
        %{status: :failed, attempt_count: 5, last_attempted_at: DateTime.utc_now()},
        authorize?: false
      )
      |> Ash.update!()

    result = deliver!(at_ceiling)

    assert result.status == :failed
    assert result.attempt_count == 5
  end
end
