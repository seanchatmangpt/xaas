defmodule Xaas.Platform.WebhookDeliveryLifecycleW984dcTest do
  @moduledoc """
  Lane W984dc depth court -- webhook delivery lifecycle beyond W984bq's
  policy/retry boundary.

  Chicago-style: real Bandit receiver, real Postgres via the sandbox, real
  Ash `:deliver`/`:record_attempt` actions, no mocks of owned code.

  Uncovered-by-census contracts asserted here (each test names the mutant
  it kills; a surviving mutant = vacuous test):

  1. Payload integrity: the receiver's raw body JSON-decodes to exactly
     the stored `payload` map, nested structures included (kills any
     mutant that re-serializes, drops, or reorders the payload into
     something other than what is persisted).
  2. Attempt ordering: successive `:deliver` calls on one delivery produce
     strictly incrementing `attempt_count` and non-decreasing
     `last_attempted_at`, with the failed->delivered recovery transition
     on a later 2xx (kills a mutant that overwrites rather than
     increments, or stamps timestamps backwards).
  3. Dead-letter semantics: at the real `@max_delivery_attempts` ceiling,
     `:deliver` makes zero real HTTP calls -- receiver request count stays
     0 -- and the row is untouched (kills the mutant that skips the
     counter bump but still burns the network call).
  4. Delivery immutability: `:record_attempt` cannot retarget `webhook_id`
     or rewrite `payload` (kills a mutant that widens the accept list;
     a replayed event must not be redirectable to a different webhook).
  5. Typed refusal: `:record_attempt` with a non-enum status is refused by
     the real `Xaas.Platform.Types.WebhookDeliveryStatus` type (kills a
     mutant that loosens the enum to a free-form string).
  """

  use ExUnit.Case, async: true

  alias Xaas.Platform.WebhookDelivery

  defmodule CapturePlug do
    @moduledoc "Real receiver: captures raw bodies, replays queued statuses."
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, opts) do
      agent = Keyword.fetch!(opts, :agent)
      {:ok, raw_body, conn} = read_body(conn)

      Agent.update(agent, fn state ->
        %{state | requests: [%{body: raw_body} | state.requests]}
      end)

      status =
        Agent.get_and_update(agent, fn state ->
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

    {:ok, server_pid} =
      Bandit.start_link(plug: {CapturePlug, [agent: agent]}, port: 0, ip: {127, 0, 0, 1})

    Process.unlink(server_pid)
    {:ok, {_addr, port}} = ThousandIsland.listener_info(server_pid)

    on_exit(fn ->
      if Process.alive?(server_pid), do: Process.exit(server_pid, :shutdown)
    end)

    %{agent: agent, port: port}
  end

  defp create_webhook!(url) do
    Xaas.Generator.create_webhook!(%{org_id: "w984dc-delivery-lifecycle-org", url: url})
  end

  defp create_delivery!(webhook, payload) do
    WebhookDelivery
    |> Ash.Changeset.for_create(
      :create,
      %{webhook_id: webhook.id, event_type: "w984dc.test.event", payload: payload},
      authorize?: false
    )
    |> Ash.create!()
  end

  defp deliver!(delivery) do
    delivery
    |> Ash.Changeset.for_update(:deliver, %{}, authorize?: false)
    |> Ash.update!()
  end

  defp record_attempt!(delivery, attrs) do
    delivery
    |> Ash.Changeset.for_update(:record_attempt, attrs, authorize?: false)
    |> Ash.update!()
  end

  test "(1) payload integrity: receiver body JSON-decodes to exactly the stored payload",
       %{agent: agent, port: port} do
    webhook = create_webhook!("http://127.0.0.1:#{port}/hook")

    payload = %{
      "event" => "w984dc.integrity",
      "n" => System.unique_integer([:positive]),
      "nested" => %{"b" => [1, 2, 3], "a" => %{"deep" => true}},
      "list" => [%{"z" => 1, "a" => 2}]
    }

    delivery = create_delivery!(webhook, payload)
    deliver!(delivery)

    [%{body: raw_body}] = Agent.get(agent, & &1.requests)

    assert Jason.decode!(raw_body) == payload
    # and the wire bytes are the exact canonical encoding of the stored map
    assert raw_body == Jason.encode!(delivery.payload)
  end

  test "(2) attempt ordering: counts strictly increment, timestamps non-decreasing, failed->delivered recovery on later 2xx",
       %{agent: agent, port: port} do
    # two real 503s, then a real 200
    Agent.update(agent, fn state -> %{state | statuses: [503, 503]} end)

    webhook = create_webhook!("http://127.0.0.1:#{port}/")
    payload = %{"event" => "w984dc.ordering"}

    delivery = create_delivery!(webhook, payload)

    d1 = deliver!(delivery)
    assert d1.status == :failed
    assert d1.attempt_count == 1
    t1 = d1.last_attempted_at
    assert t1 != nil

    d2 = deliver!(d1)
    assert d2.status == :failed
    assert d2.attempt_count == 2
    assert not DateTime.before?(d2.last_attempted_at, t1)

    d3 = deliver!(d2)
    assert d3.status == :delivered
    assert d3.attempt_count == 3
    assert not DateTime.before?(d3.last_attempted_at, d2.last_attempted_at)

    # receiver saw exactly one request per :deliver, in order
    requests = Agent.get(agent, & &1.requests)
    assert length(requests) == 3

    # and the failed->delivered transition is durable in real Postgres
    reloaded = Ash.reload!(d3, authorize?: false)
    assert reloaded.status == :delivered
    assert reloaded.attempt_count == 3
  end

  test "(3) dead-letter: at-ceiling delivery gets zero real HTTP calls and an untouched row",
       %{agent: agent, port: port} do
    webhook = create_webhook!("http://127.0.0.1:#{port}/")

    delivery = create_delivery!(webhook, %{"event" => "w984dc.deadletter"})

    at_ceiling =
      record_attempt!(delivery, %{
        status: :failed,
        attempt_count: 5,
        last_attempted_at: DateTime.utc_now()
      })

    before = DateTime.utc_now()

    result = deliver!(at_ceiling)

    assert result.status == :failed
    assert result.attempt_count == 5
    assert not DateTime.before?(before, result.last_attempted_at)

    # the load-bearing claim the earlier ceiling test never checked: no
    # HTTP call was made at all
    assert Agent.get(agent, & &1.requests) == []
  end

  test "(4) delivery immutability: :record_attempt cannot retarget webhook_id or rewrite payload",
       %{port: port} do
    webhook_a = create_webhook!("http://127.0.0.1:#{port}/a")
    webhook_b = create_webhook!("http://127.0.0.1:#{port}/b")

    original_payload = %{"event" => "w984dc.immutable", "v" => 1}

    delivery = create_delivery!(webhook_a, original_payload)

    assert {:error, %Ash.Error.Invalid{} = error} =
             delivery
             |> Ash.Changeset.for_update(
               :record_attempt,
               %{
                 webhook_id: webhook_b.id,
                 payload: %{"event" => "forged"}
               },
               authorize?: false
             )
             |> Ash.update()

    msg = Exception.message(error)
    assert msg =~ "webhook_id" or msg =~ "payload"

    # row is untouched by the refused transition
    reloaded = Ash.reload!(delivery, authorize?: false)
    assert reloaded.webhook_id == webhook_a.id
    assert reloaded.payload == original_payload
  end

  test "(5) typed refusal: non-enum status is refused by WebhookDeliveryStatus",
       %{port: port} do
    webhook = create_webhook!("http://127.0.0.1:#{port}/")
    delivery = create_delivery!(webhook, %{"event" => "w984dc.enum"})

    assert {:error, %Ash.Error.Invalid{}} =
             delivery
             |> Ash.Changeset.for_update(
               :record_attempt,
               %{status: "shipped_yesterday_trust_me", attempt_count: 1},
               authorize?: false
             )
             |> Ash.update()

    # defaults on a fresh, never-attempted row are the real initial state
    assert delivery.status == :pending
    assert delivery.attempt_count == 0
    assert delivery.last_attempted_at == nil
  end
end
