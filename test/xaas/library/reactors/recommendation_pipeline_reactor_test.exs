defmodule Xaas.Library.Reactors.RecommendationPipelineReactorTest do
  use Xaas.DataCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.{Book, Checkout, Embeddings}
  alias Xaas.Library.Reactors.RecommendationPipelineReactor

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_user!(grade) do
    Ash.Seed.seed!(User, %{email: Faker.Internet.email(), grade_level: grade})
  end

  defp create_book!(title, grade, genres, available) do
    {:ok, emb} = Embeddings.embed("#{title} synopsis #{Enum.join(genres, " ")}")

    Book
    |> Ash.Changeset.for_create(:create, %{
      title: title,
      author: Faker.Person.name(),
      isbn: "isbn-#{System.unique_integer([:positive])}",
      grade_level: grade,
      genres: genres,
      synopsis: "test synopsis",
      available_copies: available,
      total_copies: available,
      embedding: emb
    })
    |> Ash.create!(authorize?: false)
  end

  test "RecommendationPipelineReactor ranks candidates concurrently with 6-factor scoring" do
    user = create_user!(5)
    b1 = create_book!("Science Explorers", 5, ["Science", "Adventure"], 2)
    _b2 = create_book!("Advanced Physics", 12, ["Science"], 1)

    # Seed one checkout for collaborative/past reading profile
    Checkout
    |> Ash.Changeset.for_create(:create, %{
      book_id: b1.id,
      user_id: user.id,
      school_id: "willow-creek",
      borrowed_at: DateTime.utc_now(),
      status: :borrowed
    })
    |> Ash.create!(authorize?: false)

    inputs = %{
      user_id: user.id,
      student_grade: 5,
      limit: 5,
      weights: Xaas.Library.Config.weights(),
      exclude_read: false
    }

    assert {:ok, ranked} = Reactor.run(RecommendationPipelineReactor, inputs, %{}, async?: false)
    assert length(ranked) >= 2
    top = List.first(ranked)
    assert top.book.grade_level == 5 or Decimal.equal?(top.book.grade_level, 5)
    assert top.factors.grade_fit > 0.8
  end
end
