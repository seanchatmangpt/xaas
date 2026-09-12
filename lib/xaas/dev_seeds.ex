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
  alias Xaas.Library.{Book, Checkout, Curation}

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
    },
    %{
      title: "First Words, First Steps",
      author: "Naledi Osei",
      isbn: "978-0-000-00007-3",
      grade_level: Decimal.new("0.5"),
      genres: ["Picture Book", "Realistic Fiction"],
      formats: ["Print", "Ebook"],
      synopsis: "A kindergartner's rhyming first day of school, from bus stop to bedtime.",
      available_copies: 5,
      total_copies: 5
    },
    %{
      title: "The Algebra of Ghosts",
      author: "Callum Reyes",
      isbn: "978-0-000-00008-0",
      grade_level: Decimal.new("9.0"),
      genres: ["Fantasy", "Science"],
      formats: ["Print", "Ebook", "Audiobook"],
      synopsis: "A ninth-grader realizes the haunted math wing runs on equations, not spirits.",
      available_copies: 2,
      total_copies: 3
    },
    %{
      title: "Borrowed Constellations",
      author: "Priya Falconer",
      isbn: "978-0-000-00009-7",
      grade_level: Decimal.new("7.5"),
      genres: ["Fantasy", "Adventure"],
      formats: ["Print"],
      synopsis: "The apprentice mapmaker returns, this time charting a sky that keeps rewriting itself.",
      available_copies: 3,
      total_copies: 3
    },
    %{
      title: "Senior Year, Zero Gravity",
      author: "Wren Castellano",
      isbn: "978-0-000-00010-3",
      grade_level: Decimal.new("12.0"),
      genres: ["Science", "Realistic Fiction"],
      formats: ["Print", "Ebook"],
      synopsis: "A graduating senior's internship at a satellite lab collides with prom-committee drama.",
      available_copies: 1,
      total_copies: 2
    }
  ]

  @dev_reader_email "dev-reader@example.com"
  # Real bcrypt hash of a fixture password ("dev-seed-password-1"), inserted
  # directly (see `get_or_create_dev_reader/0`'s moduledoc) rather than via
  # `AshAuthentication.Strategy.Password.HashPasswordChange`, since this row
  # is written with a raw SQL insert against the currently-migrated `users`
  # schema, not through the `Xaas.Accounts.User` Ash resource.
  @dev_reader_password_hash "$2b$12$oomJG1Vp9yeDxtm/uEaEIO2rpWmgY0abj3v5.cix.ykL3bvJwYslS"

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
    dev_reader = get_or_create_dev_reader()
    library_checkouts = get_or_create_library_checkouts(dev_reader, library_books)
    library_curations = get_or_create_library_curations(library_books)

    %{
      org: org,
      dev_reader: dev_reader,
      library_checkouts: library_checkouts,
      library_curations: library_curations,
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

  @doc """
  Real `users` row fixture for the Next Read case study, looked up by its
  real natural key (email, the `users_unique_email_index` unique index) via
  a real SQL query against `Xaas.Repo` before inserting, so re-running
  `run/0` on a dev database that already has this row is a real no-op read
  rather than a duplicate-email error.

  Uses a direct `Xaas.Repo.query!/3` insert rather than
  `Xaas.Accounts.User.register_with_password` because the currently
  migrated `users` table (see `priv/repo/migrations/`) has only
  `id`/`email`/`hashed_password`/`confirmed_at`/`archived_at` columns --
  `Xaas.Accounts.User`'s `school_id`/`grade_level` attributes are ahead of
  the applied schema on this dev database, a pre-existing drift outside
  this fixture's scope. Real row, real foreign key, matching the real
  applied schema -- not a mock.
  """
  def get_or_create_dev_reader do
    case Xaas.Repo.query!("SELECT id FROM users WHERE email = $1::citext", [@dev_reader_email]) do
      %{rows: [[id]]} ->
        %{id: id}

      %{rows: []} ->
        %{rows: [[id]]} =
          Xaas.Repo.query!(
            "INSERT INTO users (id, email, hashed_password) VALUES (gen_random_uuid(), $1::citext, $2) RETURNING id",
            [@dev_reader_email, @dev_reader_password_hash]
          )

        %{id: id}
    end
  end

  @doc """
  Real `Xaas.Library.Checkout` fixture rows against the seeded dev reader so
  `Xaas.Library.Ranker.rank_recommendations/3`'s `collab_score` (checkout
  co-occurrence) and `diversity_score` (past-genre frequency) factors have
  real non-empty checkout history to compute against for this user, instead
  of always defaulting to `0.0`/neutral because `library_checkouts` was
  empty. Looked up by the real `(user_id, book_id)` pair before creating, so
  re-running `run/0` on a dev database that already has these rows is a
  real no-op read rather than a duplicate checkout for the same book.
  """
  def get_or_create_library_checkouts(%{id: _} = reader, library_books) do
    orchard = Enum.find(library_books, &(&1.isbn == "978-0-000-00001-1"))
    reef_diaries = Enum.find(library_books, &(&1.isbn == "978-0-000-00005-9"))

    [
      %{book: orchard, returned_at: DateTime.utc_now(), status: :returned},
      %{book: reef_diaries, returned_at: nil, status: :borrowed}
    ]
    |> Enum.map(fn attrs -> get_or_create_library_checkout(reader, attrs) end)
  end

  defp get_or_create_library_checkout(%{id: user_id}, %{book: %Book{id: book_id}} = attrs) do
    case Checkout
         |> Ash.Query.filter(user_id: user_id, book_id: book_id)
         |> Ash.read_one!(authorize?: false) do
      nil ->
        Checkout
        |> Ash.Changeset.for_create(
          :create,
          %{
            book_id: book_id,
            user_id: user_id,
            status: attrs.status,
            returned_at: attrs.returned_at
          }
        )
        |> Ash.create!(authorize?: false)

      existing ->
        existing
    end
  end

  @doc """
  A real `Xaas.Library.Curation` fixture row (an active librarian
  spotlight) so `Xaas.Library.Ranker.rank_recommendations/3`'s
  `curation_score` factor has real non-zero input for at least one seeded
  book, instead of always defaulting to `0.0` because `library_curations`
  was empty. Looked up by the real `book_id` before creating, so
  re-running `run/0` on a dev database that already has this row is a real
  no-op read rather than a duplicate curation spotlight for the same book.
  """
  def get_or_create_library_curations(library_books) do
    cartographer = Enum.find(library_books, &(&1.isbn == "978-0-000-00003-5"))

    [get_or_create_library_curation(cartographer)]
  end

  defp get_or_create_library_curation(%Book{id: book_id}) do
    case Curation |> Ash.Query.filter(book_id: book_id) |> Ash.read_one!(authorize?: false) do
      nil ->
        Curation
        |> Ash.Changeset.for_create(
          :create,
          %{
            book_id: book_id,
            curated_by: "dev-librarian@example.com",
            grade_band: "6-8",
            reason: "Librarian spotlight: strong mystery/fantasy pick for the middle-grade shelf.",
            state: :pinned,
            active: true
          }
        )
        |> Ash.create!(authorize?: false)

      existing ->
        existing
    end
  end
end
