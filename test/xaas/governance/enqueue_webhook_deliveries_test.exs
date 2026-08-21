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

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    # Real `Xaas.Vault` (AshCloak's backing Cloak.Vault, used by
    # `Xaas.Platform.Webhook`'s `cloak do attributes [:secret] end`) is not
    # in this app's supervision tree (`lib/kanban/application.ex` never
    # starts it -- a real, pre-existing gap this test does not attempt to
    # fix). `start_supervised!` here starts the real vault for the
    # duration of this test only, so `Webhook.secret`'s real
    # encrypt/decrypt round-trip runs for real rather than being mocked.
    start_supervised!(Xaas.Vault)
    :ok
  end

  defp create_webhook!(event_types, opts \\ []) do
    Webhook
    |> Ash.Changeset.for_create(
      :create,
      %{
        org_id: "webhook-test-org",
        url: "https://example.com/webhook",
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

  test "approving ApprovalBackupRetentionChange enqueues a real WebhookDelivery for a matching enabled webhook" do
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
      create_webhook!(["governance.approval_backup_retention_change.approved"])

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
        authorize?: false
      )
      |> Ash.create!()

    approved =
      approval
      |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-#{run}"}, authorize?: false)
      |> Ash.update!()

    [delivery] = deliveries_for(webhook.id)

    assert delivery.event_type == "governance.approval_backup_retention_change.approved"
    assert delivery.webhook_id == webhook.id
    assert delivery.status == :pending
    assert delivery.payload["id"] == approved.id
    assert delivery.payload["org_id"] == org.slug
    assert delivery.payload["approved_by"] == "approver-#{run}"
  end

  test "approving ApprovalDrFailover enqueues a real WebhookDelivery for a matching enabled webhook" do
    run = System.unique_integer([:positive, :monotonic])

    incident =
      Incident
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: "dr-org-#{run}",
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

    webhook = create_webhook!(["governance.approval_dr_failover.approved"])

    approval =
      ApprovalDrFailover
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: "dr-org-#{run}",
          requested_by: "requester-#{run}",
          from_region: incident.region,
          to_region: "us-west-#{run}",
          reason: "real failover test #{run}"
        },
        authorize?: false
      )
      |> Ash.create!()

    approved =
      approval
      |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-#{run}"}, authorize?: false)
      |> Ash.update!()

    [delivery] = deliveries_for(webhook.id)

    assert delivery.event_type == "governance.approval_dr_failover.approved"
    assert delivery.webhook_id == webhook.id
    assert delivery.payload["id"] == approved.id
  end

  test "no delivery is created when no enabled webhook matches the event type" do
    run = System.unique_integer([:positive, :monotonic])

    # Wrong event type -- should not match.
    wrong_event_webhook =
      create_webhook!(["governance.approval_legal_hold_release.some_other_event"])

    # Right event type but disabled -- should not match.
    disabled_webhook =
      create_webhook!(["governance.approval_legal_hold_release.approved"], enabled: false)

    approval =
      ApprovalLegalHoldRelease
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: "lhr-org-#{run}",
          requested_by: "requester-#{run}",
          hold_id: "hold-#{run}",
          release_reason: "real no-match test #{run}"
        },
        authorize?: false
      )
      |> Ash.create!()

    approval
    |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-#{run}"}, authorize?: false)
    |> Ash.update!()

    assert deliveries_for(wrong_event_webhook.id) == []
    assert deliveries_for(disabled_webhook.id) == []
  end
end
