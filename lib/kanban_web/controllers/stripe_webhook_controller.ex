defmodule KanbanWeb.StripeWebhookController do
  @moduledoc """
  Real, public external Stripe webhook receiver -- the "future receiver"
  `Xaas.Billing.Subscription`'s own moduledoc names as deliberately
  deferred scope: "Webhook receiver (`customer.subscription.*` /
  `invoice.payment_*` events applying real Stripe event state to this
  row)". `:status` and `:current_period_end`, exactly the two fields
  that moduledoc says such a receiver would write, are written here via
  the existing `:sync_from_stripe` action -- no new action, no schema
  change.

  ## Why this route carries no `RequireInternalApiToken` plug

  Every other route under `/internal-api` and `/api` requires our own
  bearer token because *we* are the caller. Here Stripe is the caller --
  it does not have, and must never be asked for, our internal token.
  Authenticity is instead established the way Stripe's own docs specify:
  real HMAC-SHA256 signature verification of the raw request body against
  `STRIPE_WEBHOOK_SECRET` via `Stripe.Webhook.construct_event/3`. A
  request with a missing or invalid `Stripe-Signature` header is real-
  rejected (400) before any Ash action runs -- this is the actual
  authentication mechanism for this route, not an absence of one.

  ## Why `authorize?: false` on the Ash calls below

  `Xaas.Billing.Subscription`'s `:read`/`:sync_from_stripe` actions sit
  behind a real `policy always() do forbid_if always() end` catch-all
  with no actor context available in a webhook request (Stripe is not an
  authenticated Ash actor). Real system-internal callers in this codebase
  already use `authorize?: false` for exactly this situation (see
  `Xaas.Billing.Changes.SubscriptionChargeOnActivate`,
  `Xaas.Platform.WebhookDelivery`, `Xaas.Governance.Changes.
  EnqueueWebhookDeliveries`) -- authenticity here comes from the real
  signature check above, not from Ash policies, so bypassing Ash
  authorization for this already-authenticated system-internal write is
  the same disclosed pattern this repo already uses, not a new exception.
  """

  use KanbanWeb, :controller

  require Logger
  require Ash.Query

  @handled_events ~w(
    customer.subscription.updated
    customer.subscription.deleted
    invoice.payment_failed
  )

  def receive(conn, _params) do
    raw_body = Map.get(conn.assigns, :raw_body, "")

    with [signature] <- get_req_header(conn, "stripe-signature"),
         secret when is_binary(secret) and secret != "" <-
           System.get_env("STRIPE_WEBHOOK_SECRET"),
         {:ok, event} <- Stripe.Webhook.construct_event(raw_body, signature, secret) do
      handle_event(event)

      conn
      |> put_status(200)
      |> json(%{received: true})
    else
      _ ->
        conn
        |> put_status(400)
        |> json(%{error: "invalid_signature", detail: "missing or invalid Stripe-Signature"})
    end
  end

  defp handle_event(%{type: type} = event) when type in @handled_events do
    stripe_subscription_id = subscription_id_for(event)

    case find_subscription(stripe_subscription_id) do
      {:ok, subscription} ->
        apply_event(subscription, event)

      {:error, :not_found} ->
        Logger.info(
          "Stripe webhook #{type} for unmatched subscription " <>
            "#{inspect(stripe_subscription_id)} -- not tracked by this app, real 200 per Stripe's ack convention"
        )

        :ok
    end
  end

  defp handle_event(%{type: type}) do
    Logger.debug("Stripe webhook received unhandled event type #{type}, real 200 ack")
    :ok
  end

  defp subscription_id_for(%{type: "invoice.payment_failed", data: %{object: invoice}}) do
    Map.get(invoice, :subscription)
  end

  defp subscription_id_for(%{data: %{object: subscription}}) do
    Map.get(subscription, :id)
  end

  defp find_subscription(nil), do: {:error, :not_found}

  defp find_subscription(stripe_subscription_id) do
    Xaas.Billing.Subscription
    |> Ash.Query.filter(stripe_subscription_id == ^stripe_subscription_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, subscription} -> {:ok, subscription}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp apply_event(subscription, %{type: "customer.subscription.deleted"} = event) do
    sync!(subscription, %{
      stripe_subscription_id: subscription_id_for(event),
      status: :canceled,
      current_period_end: period_end(event)
    })
  end

  defp apply_event(subscription, %{type: "customer.subscription.updated"} = event) do
    sync!(subscription, %{
      stripe_subscription_id: subscription_id_for(event),
      status: status_for(event, subscription.status),
      current_period_end: period_end(event)
    })
  end

  defp apply_event(subscription, %{type: "invoice.payment_failed"} = event) do
    sync!(subscription, %{
      stripe_subscription_id: subscription_id_for(event),
      status: :past_due,
      current_period_end: subscription.current_period_end
    })
  end

  defp sync!(subscription, params) do
    subscription
    |> Ash.Changeset.for_update(:sync_from_stripe, params)
    |> Ash.update(authorize?: false)
  end

  # Real, explicit mapping -- never `String.to_existing_atom/1` on
  # Stripe-supplied text (Stripe's real Subscription.Status enum includes
  # values like "trialing"/"unpaid"/"incomplete_expired" this resource's
  # own `:status` attribute constraints intentionally don't model yet;
  # see that attribute's moduledoc comment). An event carrying a status
  # this resource doesn't yet support real-preserves the row's current
  # status rather than crashing or silently inventing a new enum value.
  @known_statuses %{
    "incomplete" => :incomplete,
    "active" => :active,
    "past_due" => :past_due,
    "canceled" => :canceled
  }

  defp status_for(%{data: %{object: object}}, fallback) do
    case Map.get(object, :status) do
      status when is_binary(status) -> Map.get(@known_statuses, status, fallback)
      _ -> fallback
    end
  end

  defp period_end(%{data: %{object: object}}) do
    case Map.get(object, :current_period_end) do
      nil -> nil
      unix -> DateTime.from_unix!(unix)
    end
  end
end
