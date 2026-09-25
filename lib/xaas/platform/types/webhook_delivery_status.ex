defmodule Xaas.Platform.Types.WebhookDeliveryStatus do
  @moduledoc """
  Delivery status enum for `Xaas.Platform.WebhookDelivery`.

  Deliberately smaller than platform-console's real
  `webhook_delivery_attempts`/delivery status model
  (`pending_retry` / `dead_letter` / `delivered`, driven by
  `lib/webhook-poller.ts`'s scheduled retry loop): this pass models the
  three states real outbound dispatch via Req actually produces --
  `pending` (not yet attempted), `delivered` (2xx received), `failed`
  (attempted, non-2xx or transport error). A real retry-scheduling state
  machine (pending_retry / dead_letter, backoff, max-attempt cutoff) is
  disclosed as separate follow-up work -- see the moduledoc on
  `Xaas.Platform.WebhookDelivery`.
  """
  use Ash.Type.Enum, values: [:pending, :delivered, :failed]
end
