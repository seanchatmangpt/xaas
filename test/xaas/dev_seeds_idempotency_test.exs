defmodule Xaas.DevSeedsIdempotencyTest do
  @moduledoc """
  Seed idempotency court (lane W984co, complementary unit surface to
  W984bs's e2e seed/guard-drift fix). Exercises the replay properties the
  `Xaas.DevSeeds` moduledoc promises: `run/0` looks every fixture up by
  its real natural key before creating, so a replay is a real no-op read.

  Note on baseline: `xaas_test` legitimately carries committed seed rows
  (the sanctioned `run(e2e: true)` boot path, lane W984bs) that sandbox
  rollbacks cannot remove, so these courts assert on natural-key slots
  and on the identity of the rows a given run returns -- never on
  table-wide count deltas against an assumed-empty table.

  Four real-Postgres courts, no mocking: real `Ecto.Adapters.SQL.Sandbox`,
  real `Ash` writes, real `DBConnection.Ownership` manager probes -- same
  discipline as `test/xaas/dev_seeds_test.exs` and
  `test/xaas/dev_seeds_env_guard_test.exs`.

  `async: false` for the same AshEvents global advisory-lock reason
  documented in `Xaas.DevSeedsTest` (Ledger writes inside the seed chain).
  """
  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Billing.Subscription
  alias Xaas.Governance.ApprovalBackupRetentionChange
  alias Xaas.Library.{Book, Checkout, Curation}
  alias Xaas.Ledger.Account, as: LedgerAccount

  @org_slug "acme-dev"
  @dev_reader_email "dev-reader@example.com"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp dev_reader_id do
    case Xaas.Repo.query!("SELECT id FROM users WHERE email = $1::citext", [@dev_reader_email]) do
      %{rows: [[id]]} -> id
      %{rows: []} -> nil
    end
  end

  # Ids visible right now for every resource the seed chain touches,
  # keyed by the same slot names `seed_slots/0` uses. The before/after
  # diff over these sets is the zero-residue invariant.
  defp visible_id_sets do
    reader_id = dev_reader_id()

    %{
      orgs:
        Org |> Ash.Query.filter(slug: @org_slug) |> Ash.read!(authorize?: false) |> MapSet.new(& &1.id),
      subscriptions:
        Subscription
        |> Ash.Query.filter(org_id: @org_slug)
        |> Ash.read!(authorize?: false)
        |> MapSet.new(& &1.id),
      ledger_accounts:
        LedgerAccount
        |> Ash.Query.filter(identifier: @org_slug)
        |> Ash.read!(authorize?: false)
        |> MapSet.new(& &1.id),
      pending_approvals:
        ApprovalBackupRetentionChange
        |> Ash.Query.filter(org_id == @org_slug and is_nil(approved_by))
        |> Ash.read!(authorize?: false, tenant: @org_slug)
        |> MapSet.new(& &1.id),
      books: Ash.read!(Book, authorize?: false) |> MapSet.new(& &1.id),
      reader_checkouts:
        case reader_id do
          nil ->
            MapSet.new()

          user_id ->
            Checkout
            |> Ash.Query.filter(user_id: user_id)
            |> Ash.read!(authorize?: false)
            |> MapSet.new(& &1.id)
        end,
      curations: Ash.read!(Curation, authorize?: false) |> MapSet.new(& &1.id),
      dev_reader_users:
        case reader_id do
          nil -> MapSet.new()
          id -> MapSet.new([id])
        end
    }
  end

  # Real read-back of every natural-key slot the seed chain owns, through
  # the same Ash resources / SQL the seed itself uses.
  defp seed_slots do
    reader_id = dev_reader_id()

    %{
      orgs: Org |> Ash.Query.filter(slug: @org_slug) |> Ash.read!(authorize?: false) |> length(),
      subscriptions:
        Subscription
        |> Ash.Query.filter(org_id: @org_slug)
        |> Ash.read!(authorize?: false)
        |> length(),
      ledger_accounts:
        LedgerAccount
        |> Ash.Query.filter(identifier: @org_slug)
        |> Ash.read!(authorize?: false)
        |> length(),
      pending_approvals:
        ApprovalBackupRetentionChange
        |> Ash.Query.filter(org_id == @org_slug and is_nil(approved_by))
        |> Ash.read!(authorize?: false, tenant: @org_slug)
        |> length(),
      seeded_books:
        Book
        |> Ash.Query.filter(isbn in ["978-0-000-00001-1", "978-0-000-00002-8", "978-0-000-00003-5",
        "978-0-000-00004-2", "978-0-000-00005-9", "978-0-000-00006-6", "978-0-000-00007-3",
        "978-0-000-00008-0", "978-0-000-00009-7", "978-0-000-00010-3"])
        |> Ash.read!(authorize?: false)
        |> length(),
      dev_reader_users:
        case reader_id do
          nil -> 0
          _ -> 1
        end,
      reader_checkouts:
        case reader_id do
          nil ->
            0

          user_id ->
            Checkout |> Ash.Query.filter(user_id: user_id) |> Ash.read!(authorize?: false) |> length()
        end,
      curations: Ash.count!(Curation, authorize?: false)
    }
  end

  # W984co-1: the documented delta of a replay is zero -- every row is
  # looked up by its natural key, so run #2 reuses run #1's rows instead
  # of inserting duplicates.
  test "run/0 twice grows row counts by exactly zero (full dedupe per the idempotency contract)" do
    first = Xaas.DevSeeds.run()
    slots_after_first = seed_slots()

    second = Xaas.DevSeeds.run()
    slots_after_second = seed_slots()

    # The replay returns the same real rows...
    assert first.org.id == second.org.id
    assert first.subscription.id == second.subscription.id
    assert first.ledger_account.id == second.ledger_account.id
    assert first.pending_approval.id == second.pending_approval.id
    assert Enum.map(first.library_books, & &1.id) == Enum.map(second.library_books, & &1.id)
    assert Enum.map(first.library_checkouts, & &1.id) ==
             Enum.map(second.library_checkouts, & &1.id)
    assert Enum.map(first.library_curations, & &1.id) ==
             Enum.map(second.library_curations, & &1.id)

    # ...and the real tables grew by the documented replay delta: zero.
    assert slots_after_second == slots_after_first

    # Non-vacuous check: after the runs, every seeded natural-key slot is
    # exactly populated (regardless of whether the rows were created by
    # this run or pre-committed by the sanctioned e2e boot seed).
    assert slots_after_first == %{
             orgs: 1,
             subscriptions: 1,
             ledger_accounts: 1,
             pending_approvals: 1,
             seeded_books: 10,
             dev_reader_users: 1,
             reader_checkouts: 2,
             curations: 1
           }
  end

  # W984co-2: replayed rows satisfy the unique constraints -- no duplicate
  # titles, isbns, org slugs, or dev-reader emails across replays.
  test "replayed rows satisfy the real unique constraints (no duplicate titles/users/slugs across replays)" do
    Xaas.DevSeeds.run()
    Xaas.DevSeeds.run()

    orgs = Org |> Ash.Query.filter(slug: @org_slug) |> Ash.read!(authorize?: false)
    assert length(orgs) == 1, "org slug is the natural key -- a replay must not duplicate it"

    subs = Subscription |> Ash.Query.filter(org_id: @org_slug) |> Ash.read!(authorize?: false)
    assert length(subs) == 1

    books = Ash.read!(Book, authorize?: false)
    assert length(books) == 10
    assert books |> Enum.map(& &1.isbn) |> Enum.uniq() |> length() == 10
    assert books |> Enum.map(&String.downcase(&1.title)) |> Enum.uniq() |> length() == 10

    %{rows: [[user_count]]} =
      Xaas.Repo.query!("SELECT count(*) FROM users WHERE email = $1::citext", [@dev_reader_email])

    assert user_count == 1, "users_unique_email_index forbids a duplicate dev reader"

    ledger = LedgerAccount |> Ash.Query.filter(identifier: @org_slug) |> Ash.read!(authorize?: false)
    assert length(ledger) == 1

    # One checkout per (user_id, book_id) pair and one curation spotlight
    # per book, per the seed's own lookup keys.
    checkouts = Ash.read!(Checkout, authorize?: false)
    assert checkouts |> Enum.map(&{&1.user_id, &1.book_id}) |> Enum.uniq() |> length() ==
             length(checkouts)
    assert length(checkouts) == 2

    curations = Ash.read!(Curation, authorize?: false)
    assert curations |> Enum.map(& &1.book_id) |> Enum.uniq() |> length() == length(curations)
    assert length(curations) == 1
  end

  # W984co-3: the sandboxed-allow path's pollution-prevention mechanism is
  # the rollback itself. `xaas_test` legitimately carries committed e2e
  # boot-seed rows, so the precise zero-residue invariant is: every row a
  # sandboxed run returns is either a pre-existing committed row the run
  # reused (idempotent lookup) or is gone after checkin. No third state.
  test "sandbox rollback of the allowed path leaves zero residue of this run's rows" do
    before = visible_id_sets()

    seeded = Xaas.DevSeeds.run()

    assert seeded.org.slug == @org_slug
    assert length(seeded.library_books) == 10
    assert length(seeded.library_checkouts) == 2
    assert length(seeded.library_curations) == 1

    run_ids = %{
      orgs: [seeded.org.id],
      subscriptions: [seeded.subscription.id],
      ledger_accounts: [seeded.ledger_account.id],
      pending_approvals: [seeded.pending_approval.id],
      books: Enum.map(seeded.library_books, & &1.id),
      reader_checkouts: Enum.map(seeded.library_checkouts, & &1.id),
      curations: Enum.map(seeded.library_curations, & &1.id),
      dev_reader_users: [seeded.dev_reader.id]
    }

    # ...and the sandbox checkin rolls the whole transaction back.
    :ok = Ecto.Adapters.SQL.Sandbox.checkin(Xaas.Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    after_sets = visible_id_sets()

    for {slot, ids} <- run_ids,
        id <- ids do
      assert MapSet.member?(Map.fetch!(before, slot), id) or
               not MapSet.member?(Map.fetch!(after_sets, slot), id),
             "row #{inspect(id)} (#{slot}) was created by this sandboxed run but survived " <>
               "the checkin rollback -- seed residue"
    end

    # Non-vacuous: the sandbox is not just an empty read -- the pre/post
    # views agree on the committed e2e rows (reused, not re-created).
    assert before == after_sets

    # A fresh replay after the rollback still runs clean end to end.
    assert %{org: %{slug: @org_slug}} = Xaas.DevSeeds.run()
  end

  # W984co-4: the guard's typed refusal message shape is stable
  # (`REFUSED(dev_seeds, env=...)`), so callers and receipts can match on
  # it. Raw spawned process = the real unsandboxed shape (no $callers, no
  # checkout), same probe discipline as DevSeedsEnvGuardTest.
  test "guard refusal message shape is stable: REFUSED(dev_seeds, env=...)" do
    # This test process deliberately holds NO checkout for the refusal
    # probe (the setup checkout is checked back in first).
    :ok = Ecto.Adapters.SQL.Sandbox.checkin(Xaas.Repo)

    parent = self()

    pid =
      spawn(fn ->
        result =
          try do
            Xaas.DevSeeds.run()
            :ran
          rescue
            e -> {:raised, e}
          end

        send(parent, {:w984co_refusal, result})
      end)

    assert_receive {:w984co_refusal, {:raised, %Mix.Error{message: msg}}}, 15_000
    refute Process.alive?(pid)

    assert msg =~ ~r/REFUSED\(dev_seeds/
    assert msg =~ "env=test"
    # The remediation text names all sanctioned paths.
    assert msg =~ "mix run priv/repo/seeds.exs"
    assert msg =~ "e2e: true"

    # Nothing leaked from the refused call: re-checkout and confirm every
    # seeded slot is still exactly populated.
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    assert seed_slots() == %{
             orgs: 1,
             subscriptions: 1,
             ledger_accounts: 1,
             pending_approvals: 1,
             seeded_books: 10,
             dev_reader_users: 1,
             reader_checkouts: 2,
             curations: 1
           }
  end
end
