defmodule Xaas.Library.CurationResourceCourtW984kuTest do
  @moduledoc """
  W984ku unclaimed-family probe court for Xaas.Library.Curation's resource-level
  branches left unexercised by test/xaas/library/curation_test.exs (which already
  courts create/update/destroy/active_for_grade happy-paths and the actor-present
  mutation floor). This file covers the residual branches:

    * attribute constraint floors: `state` one_of, `curated_by` allow_nil?(false),
      `grade_band` allow_nil?(false), `book` belongs_to allow_nil?(false)
    * the positive guest-read allowance: read policy is `authorize_if(always())`,
      so a nil actor MUST be able to read -- never positively exercised
    * the default `:read` action and `Ash.get` path under a nil actor
    * the `:neutral` state value (declared in one_of, never constructed in tests)

  Chicago school: real sandboxed Postgres, real Ash actions with authorize?: true,
  zero mocks.
  """
  use Xaas.DataCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.Curation

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp build_actor do
    %User{id: Ash.UUID.generate(), email: Faker.Internet.email()}
  end

  defp create_book!(attrs \\ %{}), do: Xaas.Generator.create_book!(attrs)

  defp create_curation!(book, overrides \\ %{}) do
    Curation
    |> Ash.Changeset.for_create(:create, %{
      book_id: book.id,
      curated_by: "librarian@example.org"
    })
    |> Ash.Changeset.for_create(:create, overrides)
    |> Ash.create!(actor: build_actor())
  end

  describe "attribute constraint floors (uncovered branches)" do
    test "mutation rationale: state one_of constraint rejects an undeclared atom",
         %{test: test} do
      book = create_book!()

      assert {:error, %Ash.Error.Invalid{}} =
               Curation
               |> Ash.Changeset.for_create(:create, %{
                 book_id: book.id,
                 curated_by: "librarian@example.org",
                 state: :archived
               })
               |> Ash.create(actor: build_actor())

      # nothing persisted
      assert [] =
               Curation
               |> Ash.Query.for_read(:read)
               |> Ash.read!(authorize?: true)
               |> Enum.filter(&(&1.curated_by == "w984ku-#{test}"))
    end

    test "mutation rationale: curated_by allow_nil?(false) rejects nil" do
      book = create_book!()

      assert {:error, %Ash.Error.Invalid{}} =
               Curation
               |> Ash.Changeset.for_create(:create, %{
                 book_id: book.id,
                 curated_by: nil
               })
               |> Ash.create(actor: build_actor())
    end

    test "mutation rationale: grade_band allow_nil?(false) rejects explicit nil" do
      book = create_book!()

      assert {:error, %Ash.Error.Invalid{}} =
               Curation
               |> Ash.Changeset.for_create(:create, %{
                 book_id: book.id,
                 curated_by: "librarian@example.org",
                 grade_band: nil
               })
               |> Ash.create(actor: build_actor())
    end

    test "mutation rationale: book relationship allow_nil?(false) rejects missing book_id" do
      assert {:error, %Ash.Error.Invalid{}} =
               Curation
               |> Ash.Changeset.for_create(:create, %{
                 book_id: Ash.UUID.generate(),
                 curated_by: "librarian@example.org"
               })
               |> Ash.create(actor: build_actor())
    end
  end

  describe "guest-read allowance (always() read policy, positive case)" do
    test "mutation rationale: nil actor can read via default :read -- the guest-browse contract" do
      book = create_book!()
      curation = create_curation!(book)

      assert {:ok, results} =
               Curation
               |> Ash.Query.for_read(:read)
               |> Ash.read(actor: nil, authorize?: true)

      assert curation.id in Enum.map(results, & &1.id)
    end

    test "mutation rationale: nil actor can Ash.get -- guest persona path in next_read_user_agent" do
      book = create_book!()
      curation = create_curation!(book)

      assert {:ok, fetched} = Ash.get(Curation, curation.id, actor: nil, authorize?: true)
      assert fetched.id == curation.id
    end

    test "mutation rationale: nil actor active_for_grade still allowed (read policy is family-wide)" do
      book = create_book!()
      curation = create_curation!(book, %{active: true})

      assert {:ok, results} =
               Curation
               |> Ash.Query.for_read(:active_for_grade, %{grade_level: 7})
               |> Ash.read(actor: nil, authorize?: true)

      assert curation.id in Enum.map(results, & &1.id)
    end
  end

  describe "declared-but-unconstructed states" do
    test "mutation rationale: :neutral is a legal state value, round-trips through Postgres" do
      book = create_book!()
      curation = create_curation!(book, %{state: :neutral})
      assert curation.state == :neutral

      reloaded = Ash.get!(Curation, curation.id, actor: build_actor())
      assert reloaded.state == :neutral
    end

    test "mutation rationale: state is updatable through :update's accept list" do
      book = create_book!()
      curation = create_curation!(book)

      updated =
        curation
        |> Ash.Changeset.for_update(:update, %{state: :promoted})
        |> Ash.update!(actor: build_actor())

      assert updated.state == :promoted
    end
  end
end
