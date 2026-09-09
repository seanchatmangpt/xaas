defmodule Xaas.GraphqlSchemaTest do
  @moduledoc """
  Chicago-school test confirming Xaas.Library's AshGraphql-exposed resources are
  actually wired into Xaas.GraphqlSchema's domain list (not just declared with a
  `graphql do type: ...` block on the resource with no schema-level registration).

  Runs a real GraphQL query through Absinthe.run/3 against the real compiled
  Xaas.GraphqlSchema module, against real seeded Postgres data via the Sandbox --
  no mocking of the schema, resolver, or data layer.
  """
  use Xaas.DataCase, async: false

  alias Xaas.Library.{Book, Embeddings}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_book!(attrs) do
    title = Map.get(attrs, :title, Faker.Commerce.product_name())
    author = Map.get(attrs, :author, Faker.Person.name())
    isbn = Map.get(attrs, :isbn, Faker.Commerce.color() <> "-#{System.unique_integer([:positive])}")
    grade_level = Map.get(attrs, :grade_level, Enum.random(3..8))
    genres = Map.get(attrs, :genres, ["Fiction", "Adventure"])
    synopsis = Map.get(attrs, :synopsis, Faker.Lorem.paragraph(2))
    available_copies = Map.get(attrs, :available_copies, 2)
    total_copies = Map.get(attrs, :total_copies, 2)

    {:ok, embedding} = Embeddings.embed("#{title} #{synopsis} #{Enum.join(genres, " ")}")

    Book
    |> Ash.Changeset.for_create(:create, %{
      title: title,
      author: author,
      isbn: isbn,
      grade_level: grade_level,
      genres: genres,
      synopsis: synopsis,
      available_copies: available_copies,
      total_copies: total_copies,
      embedding: embedding
    })
    |> Ash.create!(authorize?: false)
  end

  test "libraryBooks field exists on the real compiled schema's query type" do
    query_type = Absinthe.Schema.lookup_type(Xaas.GraphqlSchema, :query)
    assert Map.has_key?(query_type.fields, :library_books)
  end

  test "libraryBooks GraphQL query returns real seeded Library.Book data" do
    book = create_book!(%{title: "The Real Query Test Book"})

    query = """
    query {
      libraryBooks {
        results {
          id
          title
          author
        }
      }
    }
    """

    assert {:ok, %{data: %{"libraryBooks" => %{"results" => results}}}} =
             Absinthe.run(query, Xaas.GraphqlSchema)

    assert Enum.any?(results, fn r -> r["id"] == book.id and r["title"] == book.title end)
  end
end
