defmodule XaasWeb.StripeWebhookDeepeningTest do
  @moduledoc """
  Lane W775 deepening of `XaasWeb.StripeWebhookController` (route
  `POST /webhooks/stripe`, deliberately un-tokened; authenticity via real
  Stripe `t=`/`v1=` HMAC-SHA256 signature verification through
  `Stripe.Webhook.construct_event/3`).

  Chicago-style: real ConnCase POST through the real endpoint pipeline,
  real HMACs computed in-test per the actual scheme the shipped
  `stripity_stripe` `Stripe.Webhook` module enforces
  (`v1 = hex(hmac_sha256(secret, "\#{t}.\#{payload}"))`, header
  `t=\#{t},v1=\#{v1}`, one-sided tolerance: rejected iff `t < now - 300`),
  real `Xaas.Billing.Subscription` rows and real
  `Xaas.Operations.ActuationReceipt` rows read back from the sandboxed
  repo. No mocks of owned code. The secret is the real env the controller
  reads (`STRIPE_WEBHOOK_SECRET`, pinned in `test/test_helper.exs`).
  """

  use XaasWeb.ConnCase

  require Ash.Query

  alias Xaas.Billing.Subscription

  @webhook_secret "whsec_test_only_secret"

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # --- fixtures -----------------------------------------------------------

  defp create_subscription!(org_id, stripe_subscription_id) do
    Subscription
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      stripe_customer_id: "cus_#{System.unique_integer([:positive])}",
      stripe_subscription_id: stripe_subscription_id,
      tier: :standard,
      status: :active
    })
    |> Ash.create!(authorize?: false)
  end

  defp reload!(subscription), do: Ash.reload!(subscription, authorize?: false)

  defp env_secret, do: System.get_env("STRIPE_WEBHOOK_SECRET")

  # The real scheme Stripe.Webhook.verify_header/4 enforces.
  defp signature_header(payload, secret, timestamp \\ System.system_time(:second)) do
    v1 =
      :crypto.mac(:hmac, :sha256, secret, "#{timestamp}.#{payload}")
      |> Base.encode16(case: :lower)

    "t=#{timestamp},v1=#{v1}"
  end

  defp event_payload(type, object) do
    Jason.encode!(%{
      id: "evt_#{System.unique_integer([:positive])}",
      type: type,
      data: %{object: object}
    })
  end

  defp updated_object(stripe_subscription_id, status, period_end_unix) do
    %{
      id: stripe_subscription_id,
      object: "subscription",
      status: status,
      current_period_end: period_end_unix
    }
  end

  defp signed_update(conn, stripe_subscription_id, status, period_end_unix, opts \\ []) do
    timestamp = Keyword.get(opts, :timestamp, System.system_time(:second))
    secret = Keyword.get(opts, :secret, env_secret())
    payload = event_payload("customer.subscription.updated", updated_object(stripe_subscription_id, status, period_end_unix))
    sig = signature_header(payload, secret, timestamp)

    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("stripe-signature", sig)
    |> post("/webhooks/stripe", payload)
  end

  defp post_signed_raw(conn, payload, signature) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("stripe-signature", signature)
    |> post("/webhooks/stripe", payload)
  end

  defp receipt_count!(idempotency_key) do
    intent =
      Xaas.Operations.ActuationIntent
      |> Ash.Query.filter(idempotency_key == ^idempotency_key)
      |> Ash.read_one!(authorize?: false)

    case intent do
      nil ->
        0

      intent ->
        Xaas.Operations.ActuationReceipt
        |> Ash.Query.filter(intent_id == ^intent.id)
        |> Ash.read!(authorize?: false)
        |> length()
    end
  end

  # --- (a) validly signed payload -> real success contract ----------------

  test "(a) validly signed payload with real env secret -> 200 %{received: true} and real row state",
       %{conn: conn} do
    assert is_binary(env_secret()) and env_secret() != ""
    stripe_subscription_id = "sub_#{System.unique_integer([:positive])}"
    subscription = create_subscription!("org-#{System.unique_integer([:positive])}", stripe_subscription_id)

    period_end_unix = System.system_time(:second) + 30 * 24 * 60 * 60
    conn = signed_update(conn, stripe_subscription_id, "past_due", period_end_unix)

    assert json_response(conn, 200) == %{"received" => true}
    reloaded = reload!(subscription)
    assert reloaded.status == :past_due
    assert DateTime.to_unix(reloaded.current_period_end) == period_end_unix
  end

  # --- (b) signature mutation kills ---------------------------------------

  test "(b1) tampered payload byte (signed body, different body sent) -> 400, no state change",
       %{conn: conn} do
    stripe_subscription_id = "sub_#{System.unique_integer([:positive])}"
    subscription = create_subscription!("org-#{System.unique_integer([:positive])}", stripe_subscription_id)

    payload = event_payload("customer.subscription.updated", updated_object(stripe_subscription_id, "past_due", System.system_time(:second)))
    sig = signature_header(payload, env_secret())

    # One byte mutated after signing: "past_due" -> "fast_due" on the wire.
    tampered = String.replace(payload, "past_due", "fast_due")
    assert tampered != payload

    conn = post_signed_raw(conn, tampered, sig)

    assert json_response(conn, 400) == %{
             "error" => "invalid_signature",
             "detail" => "missing or invalid Stripe-Signature"
           }
    assert reload!(subscription).status == :active
  end

  test "(b2) flipped signature char -> 400, no state change",
       %{conn: conn} do
    stripe_subscription_id = "sub_#{System.unique_integer([:positive])}"
    subscription = create_subscription!("org-#{System.unique_integer([:positive])}", stripe_subscription_id)

    payload = event_payload("customer.subscription.updated", updated_object(stripe_subscription_id, "past_due", System.system_time(:second)))
    sig = signature_header(payload, env_secret())

    flipped =
      sig
      |> String.graphemes()
      |> List.update_at(-1, fn
        "0" -> "1"
        other -> "0"
      end)
      |> Enum.join()

    assert flipped != sig
    conn = post_signed_raw(conn, payload, flipped)

    assert json_response(conn, 400)
    assert reload!(subscription).status == :active
  end

  test "(b3) signature computed with wrong secret -> 400, no state change",
       %{conn: conn} do
    stripe_subscription_id = "sub_#{System.unique_integer([:positive])}"
    subscription = create_subscription!("org-#{System.unique_integer([:positive])}", stripe_subscription_id)

    conn =
      signed_update(conn, stripe_subscription_id, "past_due", System.system_time(:second),
        secret: "whsec_wrong_secret_entirely"
      )

    assert json_response(conn, 400)
    assert reload!(subscription).status == :active
  end

  test "(b4) missing Stripe-Signature header -> 400, no state change",
       %{conn: conn} do
    stripe_subscription_id = "sub_#{System.unique_integer([:positive])}"
    subscription = create_subscription!("org-#{System.unique_integer([:positive])}", stripe_subscription_id)

    payload = event_payload("customer.subscription.updated", updated_object(stripe_subscription_id, "past_due", System.system_time(:second)))

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/webhooks/stripe", payload)

    assert json_response(conn, 400) == %{
             "error" => "invalid_signature",
             "detail" => "missing or invalid Stripe-Signature"
           }
    assert reload!(subscription).status == :active
  end

  test "(b5) stale timestamp outside the 300s tolerance zone -> 400 (scheme checks it, one-sided)",
       %{conn: conn} do
    stripe_subscription_id = "sub_#{System.unique_integer([:positive])}"
    subscription = create_subscription!("org-#{System.unique_integer([:positive])}", stripe_subscription_id)

    stale = System.system_time(:second) - 301
    conn = signed_update(conn, stripe_subscription_id, "past_due", System.system_time(:second), timestamp: stale)

    assert json_response(conn, 400)
    assert reload!(subscription).status == :active
  end

  test "(b6) timestamp at the tolerance boundary edge (now - 300) with valid HMAC is accepted as coded",
       %{conn: conn} do
    stripe_subscription_id = "sub_#{System.unique_integer([:positive])}"
    subscription = create_subscription!("org-#{System.unique_integer([:positive])}", stripe_subscription_id)

    period_end_unix = System.system_time(:second) + 60
    conn =
      signed_update(conn, stripe_subscription_id, "past_due", period_end_unix,
        timestamp: System.system_time(:second) - 300
      )

    # One-sided check: `t < now - 300` rejects, `t == now - 300` does not.
    assert json_response(conn, 200) == %{"received" => true}
    assert reload!(subscription).status == :past_due
  end

  # --- (c) unrecognized event type ----------------------------------------

  test "(c) unrecognized event type with valid signature -> real 200 ack, no row change",
       %{conn: conn} do
    stripe_subscription_id = "sub_#{System.unique_integer([:positive])}"
    subscription = create_subscription!("org-#{System.unique_integer([:positive])}", stripe_subscription_id)

    payload =
      event_payload("customer.discount.created", %{
        id: "di_#{System.unique_integer([:positive])}",
        object: "discount"
      })

    conn = post_signed_raw(conn, payload, signature_header(payload, env_secret()))

    assert json_response(conn, 200) == %{"received" => true}
    reloaded = reload!(subscription)
    assert reloaded.status == :active
    assert receipt_count!("stripe_event:" <> Jason.decode!(payload)["id"]) == 0
  end

  # --- (d) replay of the same signed payload ------------------------------

  test "(d) replay of the same signed payload -> 200 both times, exactly one ActuationReceipt",
       %{conn: conn} do
    stripe_subscription_id = "sub_#{System.unique_integer([:positive])}"
    subscription = create_subscription!("org-#{System.unique_integer([:positive])}", stripe_subscription_id)

    period_end_unix = System.system_time(:second) + 30 * 24 * 60 * 60
    payload = event_payload("customer.subscription.updated", updated_object(stripe_subscription_id, "past_due", period_end_unix))
    sig = signature_header(payload, env_secret())
    %{"id" => event_id} = Jason.decode!(payload)

    conn1 = post_signed_raw(conn, payload, sig)
    assert json_response(conn1, 200) == %{"received" => true}
    assert reload!(subscription).status == :past_due
    assert receipt_count!("stripe_event:#{event_id}") == 1

    # Real redelivery: fresh conn, identical body, fresh valid signature.
    conn2 = build_conn()
    conn2 = post_signed_raw(conn2, payload, signature_header(payload, env_secret()))
    assert json_response(conn2, 200) == %{"received" => true}
    assert reload!(subscription).status == :past_due
    assert receipt_count!("stripe_event:#{event_id}") == 1
  end

  # --- (e) determinism -----------------------------------------------------

  test "(e) determinism: same payload+secret signed twice yields byte-identical signatures and identical responses",
       %{conn: conn} do
    stripe_subscription_id = "sub_#{System.unique_integer([:positive])}"
    create_subscription!("org-#{System.unique_integer([:positive])}", stripe_subscription_id)

    payload = event_payload("customer.subscription.updated", updated_object(stripe_subscription_id, "past_due", System.system_time(:second) + 60))
    t = System.system_time(:second)

    assert signature_header(payload, env_secret(), t) == signature_header(payload, env_secret(), t)

    conn1 = post_signed_raw(conn, payload, signature_header(payload, env_secret(), t))
    assert json_response(conn1, 200) == %{"received" => true}

    conn2 = build_conn()
    conn2 = post_signed_raw(conn2, payload, signature_header(payload, env_secret(), t))
    assert json_response(conn2, 200) == %{"received" => true}
  end
end
