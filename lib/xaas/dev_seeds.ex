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
    5. A small set of real `Xaas.Library.Book` rows (looked up by their
       real natural key, `isbn`, before creating) so the Next Read case
       study's `/next-read` route (`XaasWeb.NextRead.ReaderLive`) has
       non-empty `library_books` to recommend from in dev, instead of the
       empty recommendations grid caused by zero rows in that table.

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
  alias Xaas.Library.Book

  @org_slug "acme-dev"
  @org_name "Acme Dev Org"
  @pending_approval_tier :pro
  @pending_approval_requested_days 45

  @library_books [
    %{
      title: "The Hidden Orchard",
      author: "Maren Iyer",
      isbn: "978-0-000-00001-1",
      grade_level: Decimal.new("3.0"),
      genres: ["Fiction", "Adventure"],
      formats: ["Print", "Ebook"],
      synopsis: "A quiet grove hides a passage only the youngest reader in town can find.",
      available_copies: 3,
      total_copies: 3
    },
    %{
      title: "Circuits and Constellations",
      author: "Devon Achebe",
      isbn: "978-0-000-00002-8",
      grade_level: Decimal.new("6.0"),
      genres: ["Science", "Adventure"],
      formats: ["Print"],
      synopsis: "Two rival students build a homemade satellite to settle a science-fair bet.",
      available_copies: 2,
      total_copies: 2
    },
    %{
      title: "The Last Cartographer",
      author: "Priya Falconer",
      isbn: "978-0-000-00003-5",
      grade_level: Decimal.new("7.0"),
      genres: ["Fantasy", "Mystery"],
      formats: ["Print", "Audiobook"],
      synopsis: "An apprentice mapmaker discovers the kingdom's borders keep moving overnight.",
      available_copies: 1,
      total_copies: 2
    },
    %{
      title: "Recess Republic",
      author: "Tomas Whitfield",
      isbn: "978-0-000-00004-2",
      grade_level: Decimal.new("4.0"),
      genres: ["Humor", "Realistic Fiction"],
      formats: ["Print"],
      synopsis: "A fourth-grader wins the class election on a platform of longer recess.",
      available_copies: 4,
      total_copies: 4
    },
    %{
      title: "Deep Reef Diaries",
      author: "Amara Solheim",
      isbn: "978-0-000-00005-9",
      grade_level: Decimal.new("5.0"),
      genres: ["Nonfiction", "Science"],
      formats: ["Print", "Ebook"],
      synopsis: "A marine biologist's field notebook from three months tagging reef sharks.",
      available_copies: 2,
      total_copies: 2
    },
    %{
      title: "The Understudy's Secret",
      author: "Ines Karlsson",
      isbn: "978-0-000-00006-6",
      grade_level: Decimal.new("8.0"),
      genres: ["Drama", "Mystery"],
      formats: ["Print"],
      synopsis: "The school play's understudy uncovers who has been sabotaging opening night.",
      available_copies: 0,
      total_copies: 2
    }
  ]

  @doc """
  Runs the real fixture chain, returning the four real persisted records
  as a map: `%{org:, subscription:, ledger_account:, pending_approval:}`.
  """
  def run do
    org = get_or_create_org()
    subscription = get_or_create_subscription(org)
    ledger_account = get_or_open_ledger_account(org)
    pending_approval = get_or_create_pending_approval(org)
    library_books = get_or_create_library_books()

    %{
      org: org,
      subscription: subscription,
      ledger_account: ledger_account,
      pending_approval: pending_approval,
      library_books: library_books
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
  @doc """
  Real hand-curated `Xaas.Library.Book` fixture rows for the Next Read
  case study (`/next-read`, `XaasWeb.NextRead.ReaderLive`) -- looked up
  by `isbn` (this resource's real natural key) before creating, so
  re-running `run/0` on a dev database that already has these rows is a
  real no-op read rather than a duplicate-row error.
  """
  def get_or_create_library_books do
    Enum.map(@library_books, &get_or_create_library_book/1)
  end

  defp get_or_create_library_book(attrs) do
    case Book |> Ash.Query.filter(isbn: attrs.isbn) |> Ash.read_one!(authorize?: false) do
      nil ->
        Book
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.create!(authorize?: false)

      existing ->
        existing
    end
  end
end
