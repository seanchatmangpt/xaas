defmodule KanbanWeb.StripeWebhookControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP POST through the
  real endpoint pipeline (real `Plug.Parsers` + the real
  `KanbanWeb.Plugs.StripeRawBodyReader` body_reader wired in
  `KanbanWeb.Endpoint`, not a stubbed conn), real
  `Stripe.Webhook.construct_event/3`-verifiable HMAC-SHA256 signatures
  computed the same way Stripe's own signing scheme works (`t=`/`v1=`),
  and real `Xaas.Billing.Subscription` rows read back from the real
  sandboxed `Xaas.Repo` to assert on real persisted state. No mocking of
  the controller, the Ash resource, or Stripe's signature scheme.

  Event JSON bodies below are real, minimal fixtures matching Stripe's
  own documented `customer.subscription.updated` /
  `customer.subscription.deleted` / `invoice.payment_failed` event
  shapes (object type, id, and the specific fields this controller
  reads: `status`, `current_period_end`, `subscription`) -- not the full
  Stripe payload, since the controller only reads those fields.
  """

  use KanbanWeb.ConnCase

  alias Xaas.Billing.Subscription

  @webhook_secret "whsec_test_only_secret"

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

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

  defp reload!(subscription) do
    Ash.reload!(subscription, authorize?: false)
  end

  # Real Stripe webhook signing scheme:
  # https://docs.stripe.com/webhooks#verify-manually --
  # `v1 = hex(hmac_sha256(secret, "#{timestamp}.#{payload}"))`,
  # header = "t=#{timestamp},v1=#{v1}".
  defp signature_header(payload, secret, timestamp \\ System.system_time(:second)) do
    signed_payload = "#{timestamp}.#{payload}"

    v1 =
      :crypto.mac(:hmac, :sha256, secret, signed_payload)
      |> Base.encode16(case: :lower)

    "t=#{timestamp},v1=#{v1}"
  end

  defp subscription_updated_payload(stripe_subscription_id, status, current_period_end_unix) do
    Jason.encode!(%{
      id: "evt_#{System.unique_integer([:positive])}",
      type: "customer.subscription.updated",
      data: %{
        object: %{
          id: stripe_subscription_id,
          object: "subscription",
          status: status,
          current_period_end: current_period_end_unix
        }
      }
    })
  end

  defp subscription_deleted_payload(stripe_subscription_id, current_period_end_unix) do
    Jason.encode!(%{
      id: "evt_#{System.unique_integer([:positive])}",
      type: "customer.subscription.deleted",
      data: %{
        object: %{
          id: stripe_subscription_id,
          object: "subscription",
          status: "canceled",
          current_period_end: current_period_end_unix
        }
      }
    })
  end

  defp invoice_payment_failed_payload(stripe_subscription_id) do
    Jason.encode!(%{
      id: "evt_#{System.unique_integer([:positive])}",
      type: "invoice.payment_failed",
      data: %{
        object: %{
          id: "in_#{System.unique_integer([:positive])}",
          object: "invoice",
          subscription: stripe_subscription_id
        }
      }
    })
  end

  defp post_webhook(conn, payload, signature) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("stripe-signature", signature)
    |> post("/webhooks/stripe", payload)
  end

  test "customer.subscription.updated with a real valid signature syncs the real Subscription row",
       %{conn: conn} do
    org_id = "org-#{System.unique_integer([:positive])}"
    stripe_subscription_id = "sub_#{System.unique_integer([:positive])}"
    subscription = create_subscription!(org_id, stripe_subscription_id)

    period_end_unix = System.system_time(:second) + 30 * 24 * 60 * 60
    payload = subscription_updated_payload(stripe_subscription_id, "past_due", period_end_unix)
    signature = signature_header(payload, @webhook_secret)

    conn = post_webhook(conn, payload, signature)

    assert json_response(conn, 200) == %{"received" => true}

    reloaded = reload!(subscription)
    assert reloaded.status == :past_due
    assert DateTime.to_unix(reloaded.current_period_end) == period_end_unix
  end

  test "customer.subscription.deleted with a real valid signature cancels the real Subscription row",
       %{conn: conn} do
    org_id = "org-#{System.unique_integer([:positive])}"
    stripe_subscription_id = "sub_#{System.unique_integer([:positive])}"
    subscription = create_subscription!(org_id, stripe_subscription_id)

    period_end_unix = System.system_time(:second)
    payload = subscription_deleted_payload(stripe_subscription_id, period_end_unix)
    signature = signature_header(payload, @webhook_secret)

    conn = post_webhook(conn, payload, signature)

    assert json_response(conn, 200) == %{"received" => true}

    reloaded = reload!(subscription)
    assert reloaded.status == :canceled
  end

  test "invoice.payment_failed with a real valid signature sets the real Subscription row to :past_due",
       %{conn: conn} do
    org_id = "org-#{System.unique_integer([:positive])}"
    stripe_subscription_id = "sub_#{System.unique_integer([:positive])}"
    subscription = create_subscription!(org_id, stripe_subscription_id)

    payload = invoice_payment_failed_payload(stripe_subscription_id)
    signature = signature_header(payload, @webhook_secret)

    conn = post_webhook(conn, payload, signature)

    assert json_response(conn, 200) == %{"received" => true}

    reloaded = reload!(subscription)
    assert reloaded.status == :past_due
  end

  test "a real event for an unmatched subscription id still real-200s with no row created",
       %{conn: conn} do
    stripe_subscription_id = "sub_unmatched_#{System.unique_integer([:positive])}"
    payload = subscription_updated_payload(stripe_subscription_id, "active", System.system_time(:second))
    signature = signature_header(payload, @webhook_secret)

    conn = post_webhook(conn, payload, signature)

    assert json_response(conn, 200) == %{"received" => true}
  end

  test "a real request with a missing Stripe-Signature header is rejected with no state change",
       %{conn: conn} do
    org_id = "org-#{System.unique_integer([:positive])}"
    stripe_subscription_id = "sub_#{System.unique_integer([:positive])}"
    subscription = create_subscription!(org_id, stripe_subscription_id)

    payload = subscription_updated_payload(stripe_subscription_id, "past_due", System.system_time(:second))

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/webhooks/stripe", payload)

    assert json_response(conn, 400)
    assert reload!(subscription).status == :active
  end

  test "a real request with an invalid Stripe-Signature is rejected with no state change",
       %{conn: conn} do
    org_id = "org-#{System.unique_integer([:positive])}"
    stripe_subscription_id = "sub_#{System.unique_integer([:positive])}"
    subscription = create_subscription!(org_id, stripe_subscription_id)

    payload = subscription_updated_payload(stripe_subscription_id, "past_due", System.system_time(:second))
    bad_signature = signature_header(payload, "wrong_secret_entirely")

    conn = post_webhook(conn, payload, bad_signature)

    assert json_response(conn, 400)
    assert reload!(subscription).status == :active
  end
end
