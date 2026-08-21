defmodule Xaas.DevSeeds do
  @moduledoc """
  Real local-dev fixture chain, invoked by `priv/repo/seeds.exs` (`mix run
  priv/repo/seeds.exs`). Selected as the ERRC grid's twelfth-pass CREATE
  item (`docs/claude/diataxis/explanation/errc-innovation-grid.md`, item
  11) after `priv/repo/seeds.exs` sat as the unmodified 19-line book stub
  (zero real `Xaas.*` calls) across 6 consecutive audit passes.

  Builds one bounded, realistic dependency chain -- not an attempt to seed
  all 62+ resources in one pass:

    1. One `Xaas.Accounts.Org` (`:create` accepts `[:name, :slug]`).
    2. One `Xaas.Billing.Subscription` on that org (`:create` accepts
       `[:org_id, :stripe_customer_id, :stripe_subscription_id, :tier,
       :status, :current_period_end]`), `:standard` tier, `org_id` set to
       the org's real `slug` (the same string every existing `org_id`
       column in this repo is meant to reference -- see
       `Xaas.Accounts.Org`'s own moduledoc).
    3. A real `Xaas.Ledger.Account` opened for the org (`:open` accepts
       `[:identifier, :currency]`, `identifier` = the org's slug), so the
       account the next step's overage charge would debit already exists
       rather than being silently opened for the first time inside that
       transaction.
    4. One representative pending `Xaas.Governance.ApprovalBackupRetentionChange`
       row (`:pro` tier, 45 requested days -- inside `:pro`'s real 7-90
       day range from `ApprovalBackupRetentionChangeWithinTierRange`, and
       15 days above `:pro`'s real 30-day default from
       `ApprovalBackupRetentionChangeChargeOverage`) that a new developer
       can approve by hand
       (`mix run -e 'Xaas.DevSeeds.approve_seeded_pending!()'` or from
       IEx) to smoke-test the real atomic Ledger-credit path end-to-end:
       approving it real-charges a $1.50 overage fee from the org's real
       `Xaas.Ledger.Account` to the platform revenue account, inside the
       same transaction as the approval itself.

  Real internal-write convention (`authorize?: false`), matching every
  other Chicago-style test and change module in this repo that creates
  records outside an authenticated HTTP request (see
  `Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage`'s
  own `open_or_get_account/1`, and the module docs of
  `test/xaas/billing/subscription_test.exs` /
  `test/xaas/governance/approval_backup_retention_change_test.exs`).

  Idempotent: `run/0` looks up each row by its real natural key
  (`Org.slug`, `Subscription.org_id`, `Ledger.Account.identifier`, an
  unapproved `ApprovalBackupRetentionChange` for the org) before creating
  it, so re-running `mix run priv/repo/seeds.exs` on a dev database that
  already has this fixture chain is a real no-op read, not a duplicate-row
  error or a second Stripe/ledger side effect.
  """
  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Billing.Subscription
  alias Xaas.Governance.ApprovalBackupRetentionChange
  alias Xaas.Ledger.Account, as: LedgerAccount

  @org_slug "acme-dev"
  @org_name "Acme Dev Org"
  @pending_approval_tier :pro
  @pending_approval_requested_days 45

  @doc """
  Runs the real fixture chain, returning the four real persisted records
  as a map: `%{org:, subscription:, ledger_account:, pending_approval:}`.
  """
  def run do
    org = get_or_create_org()
    subscription = get_or_create_subscription(org)
    ledger_account = get_or_open_ledger_account(org)
    pending_approval = get_or_create_pending_approval(org)

    %{
      org: org,
      subscription: subscription,
      ledger_account: ledger_account,
      pending_approval: pending_approval
    }
  end

  @doc """
  Real hand-approval helper for the seeded pending row -- the smoke test
  named in this module's own moduledoc. Approves
  `#{@org_slug}`'s pending `ApprovalBackupRetentionChange` (creating the
  fixture chain first via `run/0` if it does not already exist), which
  real-charges the atomic Ledger overage fee described above.
  """
  def approve_seeded_pending! do
    %{pending_approval: pending_approval, org: org} = run()

    pending_approval
    |> Ash.Changeset.for_update(:approve, %{approved_by: "dev-seed-approver@example.com"},
      tenant: org.slug
    )
    |> Ash.update!(authorize?: false)
  end

  defp get_or_create_org do
    case Org |> Ash.Query.filter(slug: @org_slug) |> Ash.read_one!(authorize?: false) do
      nil ->
        Org
        |> Ash.Changeset.for_create(:create, %{name: @org_name, slug: @org_slug})
        |> Ash.create!(authorize?: false)

      existing ->
        existing
    end
  end

  defp get_or_create_subscription(org) do
    case Subscription |> Ash.Query.filter(org_id: org.slug) |> Ash.read_one!(authorize?: false) do
      nil ->
        Subscription
        |> Ash.Changeset.for_create(:create, %{
          org_id: org.slug,
          stripe_customer_id: "cus_dev_seed",
          stripe_subscription_id: "sub_dev_seed",
          tier: :standard,
          status: :active,
          current_period_end:
            DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(30 * 86_400, :second)
        })
        |> Ash.create!(authorize?: false)

      existing ->
        existing
    end
  end

  defp get_or_open_ledger_account(org) do
    case LedgerAccount
         |> Ash.Query.filter(identifier: org.slug)
         |> Ash.read_one!(authorize?: false) do
      nil ->
        LedgerAccount
        |> Ash.Changeset.for_create(:open, %{identifier: org.slug, currency: "USD"})
        |> Ash.create!(authorize?: false)

      existing ->
        existing
    end
  end

  defp get_or_create_pending_approval(org) do
    ApprovalBackupRetentionChange
    |> Ash.Query.filter(org_id == ^org.slug and is_nil(approved_by))
    |> Ash.read!(authorize?: false, tenant: org.slug)
    |> List.first()
    |> case do
      nil ->
        ApprovalBackupRetentionChange
        |> Ash.Changeset.for_create(
          :create,
          %{
            org_id: org.slug,
            requested_by: "dev-seed-requester@example.com",
            requested_retention_days: @pending_approval_requested_days,
            tier: @pending_approval_tier
          },
          tenant: org.slug
        )
        |> Ash.create!(authorize?: false)

      existing ->
        existing
    end
  end
end
