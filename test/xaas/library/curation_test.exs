defmodule Xaas.Library.CurationTest do
  @moduledoc """
  Chicago-school test suite for Xaas.Library.Curation: exercises the real actions
  block (create, update, active_for_grade read, destroy) and policies against the
  real Postgres test database via Ecto sandbox. No mocks.
  """
  use Xaas.DataCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.{Book, Curation}
  require Ash.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  # Curation's policy floor only checks `actor_present()` -- it does not
  # dereference or validate the actor against any relationship, so a real,
  # unpersisted %User{} struct is a legitimate actor for this policy check
  # without depending on the Accounts.User migration/schema, which is owned
  # by a separate concurrent workflow and not in scope for this test file.
  defp build_actor(email \\ nil) do
    %User{id: Ash.UUID.generate(), email: email || Faker.Internet.email()}
  end

  defp create_book!(attrs \\ %{}) do
    title = Map.get(attrs, :title, Faker.Commerce.product_name())
    author = Map.get(attrs, :author, Faker.Person.name())

    isbn =
      Map.get(attrs, :isbn, Faker.Commerce.color() <> "-#{System.unique_integer([:positive])}")

    grade_level = Map.get(attrs, :grade_level, Enum.random(3..8))
    genres = Map.get(attrs, :genres, ["Fiction", "Adventure"])
    synopsis = Map.get(attrs, :synopsis, Faker.Lorem.paragraph(2))

    Book
    |> Ash.Changeset.for_create(:create, %{
      title: title,
      author: author,
      isbn: isbn,
      grade_level: grade_level,
      genres: genres,
      synopsis: synopsis,
      available_copies: 2,
      total_copies: 2
    })
    |> Ash.create!(authorize?: false)
  end

  describe "create" do
    test "creates a curation with accepted attributes and defaults, given a real actor" do
      book = create_book!()
      actor = build_actor()

      assert {:ok, curation} =
               Curation
               |> Ash.Changeset.for_create(:create, %{
                 book_id: book.id,
                 curated_by: "librarian@example.org",
                 grade_band: "3-5",
                 student_id: "student-42",
                 reason: "Great for reluctant readers",
                 state: :promoted,
                 active: true
               })
               |> Ash.create(actor: actor)

      assert curation.book_id == book.id
      assert curation.curated_by == "librarian@example.org"
      assert curation.grade_band == "3-5"
      assert curation.student_id == "student-42"
      assert curation.reason == "Great for reluctant readers"
      assert curation.state == :promoted
      assert curation.active == true
      assert curation.inserted_at
      assert curation.updated_at
    end

    test "applies defaults for grade_band, state, and active when omitted" do
      book = create_book!()
      actor = build_actor()

      assert {:ok, curation} =
               Curation
               |> Ash.Changeset.for_create(:create, %{
                 book_id: book.id,
                 curated_by: "librarian@example.org"
               })
               |> Ash.create(actor: actor)

      assert curation.grade_band == "6-8"
      assert curation.state == :pinned
      assert curation.active == true
    end

    test "denies creation when no actor is present (deny-by-default floor)" do
      book = create_book!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Curation
               |> Ash.Changeset.for_create(:create, %{
                 book_id: book.id,
                 curated_by: "librarian@example.org"
               })
               |> Ash.create(actor: nil)
    end
  end

  describe "update" do
    test "updates grade_band, student_id, reason, state, and active" do
      book = create_book!()
      actor = build_actor()

      curation =
        Curation
        |> Ash.Changeset.for_create(:create, %{
          book_id: book.id,
          curated_by: "librarian@example.org"
        })
        |> Ash.create!(actor: actor)

      assert {:ok, updated} =
               curation
               |> Ash.Changeset.for_update(:update, %{
                 grade_band: "9-12",
                 student_id: "student-99",
                 reason: "Updated reason",
                 state: :suppressed,
                 active: false
               })
               |> Ash.update(actor: actor)

      assert updated.grade_band == "9-12"
      assert updated.student_id == "student-99"
      assert updated.reason == "Updated reason"
      assert updated.state == :suppressed
      assert updated.active == false
      # unchanged, not accepted by :update
      assert updated.curated_by == "librarian@example.org"
      assert updated.book_id == book.id
    end

    test "update rejects book_id and curated_by as unknown inputs (not in :update's accept list)" do
      book = create_book!()
      other_book = create_book!()
      actor = build_actor()

      curation =
        Curation
        |> Ash.Changeset.for_create(:create, %{
          book_id: book.id,
          curated_by: "librarian@example.org"
        })
        |> Ash.create!(actor: actor)

      changeset =
        curation
        |> Ash.Changeset.for_update(:update, %{
          book_id: other_book.id,
          curated_by: "someone-else@example.org"
        })

      assert {:error, %Ash.Error.Invalid{errors: errors}} = Ash.update(changeset, actor: actor)
      inputs = Enum.map(errors, & &1.input)
      assert :book_id in inputs
      assert :curated_by in inputs
    end

    test "denies update when no actor is present (deny-by-default floor)" do
      book = create_book!()
      actor = build_actor()

      curation =
        Curation
        |> Ash.Changeset.for_create(:create, %{
          book_id: book.id,
          curated_by: "librarian@example.org"
        })
        |> Ash.create!(actor: actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               curation
               |> Ash.Changeset.for_update(:update, %{reason: "should be denied"})
               |> Ash.update(actor: nil)
    end
  end

  describe "active_for_grade read action" do
    test "returns only active curations and requires grade_level argument" do
      book = create_book!()
      actor = build_actor()

      active_curation =
        Curation
        |> Ash.Changeset.for_create(:create, %{
          book_id: book.id,
          curated_by: "librarian@example.org",
          active: true
        })
        |> Ash.create!(actor: actor)

      _inactive_curation =
        Curation
        |> Ash.Changeset.for_create(:create, %{
          book_id: book.id,
          curated_by: "librarian@example.org",
          active: false
        })
        |> Ash.create!(actor: actor)

      assert {:ok, results} =
               Curation
               |> Ash.Query.for_read(:active_for_grade, %{grade_level: 5})
               |> Ash.read()

      ids = Enum.map(results, & &1.id)
      assert active_curation.id in ids
      assert Enum.all?(results, & &1.active)
    end

    test "requires the grade_level argument" do
      assert {:error, %Ash.Error.Invalid{}} =
               Curation
               |> Ash.Query.for_read(:active_for_grade, %{})
               |> Ash.read()
    end
  end

  describe "destroy" do
    test "removes the curation record" do
      book = create_book!()
      actor = build_actor()

      curation =
        Curation
        |> Ash.Changeset.for_create(:create, %{
          book_id: book.id,
          curated_by: "librarian@example.org"
        })
        |> Ash.create!(actor: actor)

      assert :ok = Ash.destroy(curation, actor: actor)

      assert {:error, %Ash.Error.Invalid{}} = Ash.get(Curation, curation.id)
    end

    test "denies destroy when no actor is present (deny-by-default floor)" do
      book = create_book!()
      actor = build_actor()

      curation =
        Curation
        |> Ash.Changeset.for_create(:create, %{
          book_id: book.id,
          curated_by: "librarian@example.org"
        })
        |> Ash.create!(actor: actor)

      assert {:error, %Ash.Error.Forbidden{}} = Ash.destroy(curation, actor: nil)
    end
  end
end
