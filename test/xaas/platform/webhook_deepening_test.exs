defmodule Xaas.Platform.WebhookDeepeningTest do
  @moduledoc """
  Lane W725 deepening coverage for the `Xaas.Platform` outbound webhook
  surface (Webhook + WebhookDelivery + `Xaas.Platform.Changes.DeliverWebhook`).

  Chicago-style: the receiver is a real in-test Bandit HTTP server (the
  W674 idiom, as in `Xaas.Telemetry.OcelForwarderTest`), the dispatch is
  a real Ash `:deliver` action against the real sandboxed Postgres -- no
  mocks of owned code, no fakes of `Req` or the signing path.

  Contracts asserted (read from
  `lib/xaas/platform/changes/deliver_webhook.ex`, not assumed):

  - Signature: `x-webhook-signature` header, value
    `"sha256=" <> Base.encode16(hmac, case: :lower)` where
    `hmac = :crypto.mac(:hmac, :sha256, secret, raw_json_body)`.
  - 2xx -> `:delivered`; non-2xx or transport error -> `:failed`; both
    increment `attempt_count` and set `last_attempted_at`. The retry
    schedule itself is the ash_oban `"*/5 * * * *"` cron in
    `WebhookDelivery` (real scheduling, no backoff intervals -- typed
    gap below).
  """
  use ExUnit.Case, async: true

  alias Xaas.Platform.WebhookDelivery

  @max_delivery_attempts 5

  defmodule VerifyingPlug do
    @moduledoc """
    Real Plug receiver. Captures the raw body + signature header into an
    Agent, verifies the HMAC exactly as an external receiver would
    (recompute over the raw bytes received), and returns a configurable
    status per request.
    """
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, opts) do
      agent = Keyword.fetch!(opts, :agent)
      {:ok, raw_body, conn} = read_body(conn)

      signature = conn |> get_req_header("x-webhook-signature") |> List.first()

      Agent.update(agent, fn state ->
        %{state | requests: [%{body: raw_body, signature: signature} | state.requests]}
      end)

      # pop the status queue, defaulting to 200
      status = Agent.get_and_update(agent, fn state ->
        case state.statuses do
          [s | rest] -> {s, %{state | statuses: rest}}
          [] -> {200, state}
        end
      end)

      send_resp(conn, status, "ok")
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    {:ok, agent} = Agent.start_link(fn -> %{requests: [], statuses: []} end)

    {:ok, server_pid} = Bandit.start_link(plug: {VerifyingPlug, [agent: agent]}, port: 0, ip: {127, 0, 0, 1})
    Process.unlink(server_pid)
    {:ok, {_addr, port}} = ThousandIsland.listener_info(server_pid)

    on_exit(fn ->
      if Process.alive?(server_pid), do: Process.exit(server_pid, :shutdown)
    end)

    %{agent: agent, port: port}
  end

  defp create_webhook!(url, secret) do
    Xaas.Generator.create_webhook!(%{org_id: "w725-webhook-deepening-org", url: url, secret: secret})
  end

  defp create_delivery!(webhook, payload) do
    WebhookDelivery
    |> Ash.Changeset.for_create(
      :create,
      %{webhook_id: webhook.id, event_type: "w725.test.event", payload: payload},
      authorize?: false
    )
    |> Ash.create!()
  end

  defp deliver!(delivery) do
    delivery
    |> Ash.Changeset.for_update(:deliver, %{}, authorize?: false)
    |> Ash.update!()
  end

  defp expected_signature(secret, raw_body) do
    hmac = :crypto.mac(:hmac, :sha256, secret, raw_body)
    "sha256=" <> Base.encode16(hmac, case: :lower)
  end

  defp verify_hmac(secret, raw_body, signature) do
    if is_binary(signature) do
      Plug.Crypto.secure_compare(signature, expected_signature(secret, raw_body))
    else
      false
    end
  end

  test "(a) dispatch signs the payload with the webhook's secret; receiver verifies the HMAC exactly",
       %{agent: agent, port: port} do
    secret = "w725-real-secret-#{System.unique_integer([:positive])}"
    payload = %{"event" => "w725.a", "n" => System.unique_integer([:positive])}

    webhook = create_webhook!("http://127.0.0.1:#{port}/hook", secret)
    delivery = create_delivery!(webhook, payload)

    delivered = deliver!(delivery)

    assert delivered.status == :delivered
    assert delivered.attempt_count == 1
    assert delivered.last_attempted_at != nil

    assert [%{body: raw_body, signature: signature}] = Agent.get(agent, & &1.requests)

    # exact header name from DeliverWebhook.dispatch/2
    assert is_binary(signature)
    # exact value shape: "sha256=" <> lowercase-hex HMAC-SHA256 over the exact raw bytes sent
    assert signature == expected_signature(secret, raw_body)
    assert String.starts_with?(signature, "sha256=")
    assert signature == "sha256=" <> (hmac = :crypto.mac(:hmac, :sha256, secret, raw_body) |> Base.encode16(case: :lower))
    assert byte_size(hmac) == 64

    # receiver-side verification: recomputed HMAC over raw bytes matches
    assert verify_hmac(secret, raw_body, signature)
  end

  test "(b) tampered payload at the receiver fails verification (signature mutation check)",
       %{agent: agent, port: port} do
    secret = "w725-tamper-secret-#{System.unique_integer([:positive])}"
    payload = %{"event" => "w725.b", "amount" => 1}

    webhook = create_webhook!("http://127.0.0.1:#{port}/hook", secret)
    delivery = create_delivery!(webhook, payload)

    assert %{status: :delivered} = deliver!(delivery)

    assert [%{body: raw_body, signature: signature}] = Agent.get(agent, & &1.requests)

    # mutation 1: flip one byte of the received body -> verification fails
    tampered_body = String.replace(raw_body, "1", "2", global: false)
    assert tampered_body != raw_body
    refute verify_hmac(secret, tampered_body, signature)

    # mutation 2: flip the signature -> verification fails
    flipped_sig =
      signature
      |> String.graphemes()
      |> Enum.map(fn
        "a" -> "b"
        other -> other
      end)
      |> Enum.join()

    assert flipped_sig != signature
    refute verify_hmac(secret, raw_body, flipped_sig)

    # mutation 3: wrong secret (receiver keyed differently) -> fails
    refute verify_hmac("wrong-secret", raw_body, signature)
  end

  test "(c) delivery record transitions: 2xx -> :delivered, non-2xx -> :failed, both bump attempt_count",
       %{agent: agent, port: port} do
    secret = "w725-status-secret-#{System.unique_integer([:positive])}"
    payload = %{"event" => "w725.c", "n" => System.unique_integer([:positive])}

    webhook = create_webhook!("http://127.0.0.1:#{port}/hook", secret)

    # request 1 -> receiver answers 200; request 2 -> receiver answers 500
    Agent.update(agent, fn state -> %{state | statuses: [200, 500]} end)

    delivery = create_delivery!(webhook, payload)

    first = deliver!(delivery)
    assert first.status == :delivered
    assert first.attempt_count == 1
    assert first.last_attempted_at != nil

    second = deliver!(first)
    assert second.status == :failed
    assert second.attempt_count == 2
    assert second.last_attempted_at != nil

    assert length(Agent.get(agent, & &1.requests)) == 2

    # terminal-ceiling contract (real code path in deliver/1): at 5
    # attempts no HTTP call is made at all
    at_ceiling =
      second
      |> Ash.Changeset.for_update(
        :record_attempt,
        %{status: :failed, attempt_count: @max_delivery_attempts, last_attempted_at: DateTime.utc_now()},
        authorize?: false
      )
      |> Ash.update!()

    before = Agent.get(agent, &length(&1.requests))
    ceiling_result = deliver!(at_ceiling)
    assert ceiling_result.status == :failed
    assert ceiling_result.attempt_count == @max_delivery_attempts
    assert Agent.get(agent, &length(&1.requests)) == before
  end

  test "(d) signature is deterministic for identical payload + secret",
       %{agent: agent, port: port} do
    secret = "w725-det-secret-#{System.unique_integer([:positive])}"
    payload = %{"event" => "w725.d", "n" => System.unique_integer([:positive])}

    webhook = create_webhook!("http://127.0.0.1:#{port}/hook", secret)
    delivery = create_delivery!(webhook, payload)

    # two real dispatches of the same delivery row (same payload + secret)
    first = deliver!(delivery)
    second = deliver!(first)

    assert [%{body: b2, signature: s2}, %{body: b1, signature: s1}] =
             Agent.get(agent, & &1.requests)

    # identical raw bytes on the wire both times (the exact bytes the
    # dispatch signed -- the jsonb round-trip may re-order keys, so the
    # contract asserted is stability of the signed bytes per delivery row)
    assert b1 == b2
    assert b1 == Jason.encode!(second.payload)

    assert s1 == s2
    assert s1 == expected_signature(secret, b1)
  end
end
