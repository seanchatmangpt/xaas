defmodule Xaas.Governance.EnqueueWebhookDeliveriesTest do
  @moduledoc """
  Real Chicago-style coverage for
  `Xaas.Governance.Changes.EnqueueWebhookDeliveries`, wired onto
  `ApprovalBackupRetentionChange`, `ApprovalDrFailover`, and
  `ApprovalLegalHoldRelease`'s real `:approve` actions.

  Real Ecto.Adapters.SQL.Sandbox against real Postgres, real
  `Ash.create!`/`Ash.update!` calls, state-based assertions on the real
  persisted `Xaas.Platform.WebhookDelivery` rows -- never an interaction
  assertion ("was create called").

  `EnqueueWebhookDeliveries` now real-dispatches each enqueued delivery
  (via `WebhookDelivery`'s real `:deliver` action -- see
  `Xaas.Platform.Changes.DeliverWebhook`) right after creating it, so a
  webhook's `url` here points at a real local `Plug.Cowboy` listener
  (started once, real 200 always) rather than a real external host --
  keeps this suite fast and deterministic while still exercising a real
  outbound HTTP POST end to end.
  """
  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalBackupRetentionChange
  alias Xaas.Governance.ApprovalDrFailover
  alias Xaas.Governance.ApprovalLegalHoldRelease
  alias Xaas.Operations.Incident
  alias Xaas.Platform.Webhook
  alias Xaas.Platform.WebhookDelivery

  defmodule Always200Plug do
    @moduledoc "Real Plug that always real-200s, for real dispatch in this suite."
    import Plug.Conn

    def init(opts), do: opts
    def call(conn, _opts), do: send_resp(conn, 200, "ok")
  end

  setup_all do
    port = 21_000 + :erlang.phash2(__MODULE__, 5_000)
    {:ok, _pid} = Plug.Cowboy.http(Always200Plug, [], port: port, ref: __MODULE__)
    on_exit(fn -> Plug.Cowboy.shutdown(__MODULE__) end)
    {:ok, listener_url: "http://127.0.0.1:#{port}/"}
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    # `Xaas.Vault` (AshCloak's backing Cloak.Vault, used by
    # `Xaas.Platform.Webhook`'s `cloak do attributes [:secret] end`) is now
    # a real, permanent child of the app's supervision tree
    # (`lib/kanban/application.ex`), so it's already running for real by
    # the time this test boots -- no per-test workaround needed.
    :ok
  end

  defp create_webhook!(event_types, listener_url, opts \\ []) do
    Webhook
    |> Ash.Changeset.for_create(
      :create,
      %{
        org_id: "webhook-test-org",
        url: listener_url,
        event_types: event_types,
        secret: "real-hmac-secret",
        enabled: Keyword.get(opts, :enabled, true)
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp deliveries_for(webhook_id) do
    WebhookDelivery
    |> Ash.Query.filter(webhook_id: webhook_id)
    |> Ash.read!(authorize?: false)
  end

  test "approving ApprovalBackupRetentionChange enqueues a real WebhookDelivery for a matching enabled webhook",
       %{listener_url: listener_url} do
    run = System.unique_integer([:positive, :monotonic])

    org =
      Org
      |> Ash.Changeset.for_create(
        :create,
        %{name: "BRC Org #{run}", slug: "brc-org-#{run}"},
        authorize?: false
      )
      |> Ash.create!()

    webhook =
      create_webhook!(["governance.approval_backup_retention_change.approved"], listener_url)

    approval =
      ApprovalBackupRetentionChange
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: org.slug,
          requested_by: "requester-#{run}",
          requested_retention_days: 30,
          tier: :pro
        },
        authorize?: false,
        tenant: org.slug
      )
      |> Ash.create!()

    approved =
      approval
      |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-#{run}"}, authorize?: false)
      |> Ash.update!()

    [delivery] = deliveries_for(webhook.id)

    assert delivery.event_type == "governance.approval_backup_retention_change.approved"
    assert delivery.webhook_id == webhook.id
    assert delivery.status == :delivered
    assert delivery.payload["id"] == approved.id
    assert delivery.payload["org_id"] == org.slug
    assert delivery.payload["approved_by"] == "approver-#{run}"
  end

  test "approving ApprovalDrFailover enqueues a real WebhookDelivery for a matching enabled webhook",
       %{listener_url: listener_url} do
    run = System.unique_integer([:positive, :monotonic])

    org =
      Org
      |> Ash.Changeset.for_create(
        :create,
        %{name: "DR Org #{run}", slug: "dr-org-#{run}"},
        authorize?: false
      )
      |> Ash.create!()

    incident =
      Incident
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: org.slug,
          title: "real open incident for webhook-delivery test #{run}",
          description: "real open incident for webhook-delivery test #{run}",
          severity: :major,
          region: "us-east-#{run}",
          status: :open,
          opened_at: DateTime.utc_now()
        },
        authorize?: false
      )
      |> Ash.create!()

    webhook = create_webhook!(["governance.approval_dr_failover.approved"], listener_url)

    approval =
      ApprovalDrFailover
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: org.slug,
          requested_by: "requester-#{run}",
          from_region: incident.region,
          to_region: "us-west-#{run}",
          reason: "real failover test #{run}"
        },
        authorize?: false,
        tenant: org.slug
      )
      |> Ash.create!()

    approved =
      approval
      |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-#{run}"}, authorize?: false)
      |> Ash.update!()

    [delivery] = deliveries_for(webhook.id)

    assert delivery.event_type == "governance.approval_dr_failover.approved"
    assert delivery.webhook_id == webhook.id
    assert delivery.status == :delivered
    assert delivery.payload["id"] == approved.id
  end

  test "no delivery is created when no enabled webhook matches the event type",
       %{listener_url: listener_url} do
    run = System.unique_integer([:positive, :monotonic])

    # Wrong event type -- should not match.
    wrong_event_webhook =
      create_webhook!(["governance.approval_legal_hold_release.some_other_event"], listener_url)

    # Right event type but disabled -- should not match.
    disabled_webhook =
      create_webhook!(["governance.approval_legal_hold_release.approved"], listener_url,
        enabled: false
      )

    org =
      Org
      |> Ash.Changeset.for_create(
        :create,
        %{name: "LHR Org #{run}", slug: "lhr-org-#{run}"},
        authorize?: false
      )
      |> Ash.create!()

    approval =
      ApprovalLegalHoldRelease
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: org.slug,
          requested_by: "requester-#{run}",
          hold_id: "hold-#{run}",
          release_reason: "real no-match test #{run}"
        },
        authorize?: false,
        tenant: org.slug
      )
      |> Ash.create!()

    approval
    |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-#{run}"}, authorize?: false)
    |> Ash.update!()

    assert deliveries_for(wrong_event_webhook.id) == []
    assert deliveries_for(disabled_webhook.id) == []
  end
end
