defmodule XaasWeb.A2A.NextReadUserAgentTest do
  @moduledoc """
  Chicago-school test suite for `XaasWeb.A2A.NextReadUserAgent`: a real
  `A2A.Agent` GenServer started via `start_link/1`, driven with real
  `A2A.call/3` messages against real seeded `Xaas.Library.Book`/
  `Xaas.Accounts.User` Postgres rows. No mocking of A2A internals --
  the agent process is the genuine `use A2A.Agent` GenServer, and every
  Ash read/create it triggers hits the real sandboxed database.
  """
  use Xaas.DataCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.{Book, Checkout, Embeddings}
  require Ash.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    # Each test gets its own uniquely-named agent process so start_link/1
    # calls across async-unsafe-but-sequential tests never collide on the
    # module-name-registered GenServer.
    agent_name = :"next_read_user_agent_test_#{System.unique_integer([:positive])}"
    {:ok, pid} = XaasWeb.A2A.NextReadUserAgent.start_link(name: agent_name)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    %{agent: pid}
  end

  defp create_user!(email \\ nil) do
    Ash.Seed.seed!(User, %{email: email || Faker.Internet.email()})
  end

  defp create_book!(attrs) do
    title = Map.get(attrs, :title, Faker.Commerce.product_name())
    author = Map.get(attrs, :author, Faker.Person.name())
    isbn = Map.get(attrs, :isbn, Faker.Commerce.color() <> "-#{System.unique_integer([:positive])}")
    grade_level = Map.get(attrs, :grade_level, 5)
    genres = Map.get(attrs, :genres, ["Fiction", "Adventure"])
    synopsis = Map.get(attrs, :synopsis, Faker.Lorem.paragraph(2))
    available_copies = Map.get(attrs, :available_copies, 3)
    total_copies = Map.get(attrs, :total_copies, 3)

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

  defp task_text(task) do
    (task.artifacts ++ [%{parts: []}])
    |> Enum.flat_map(& &1.parts)
    |> Enum.map_join(" ", fn %A2A.Part.Text{text: text} -> text end)
  end

  describe "browse" do
    test "real \"as:<user_id> browse grade:N\" message lists real seeded books via A2A.call", %{agent: agent} do
      user = create_user!()
      book = create_book!(%{title: "The Real Grade Five Adventure", grade_level: 5})
      # A book outside the requested grade band should not show up.
      _other = create_book!(%{title: "Unrelated High School Book", grade_level: 11})

      assert {:ok, task} = A2A.call(agent, "as:#{user.id} browse grade:5")
      assert task.status.state == :completed

      text = task_text(task)
      assert text =~ book.title
      refute text =~ "Unrelated High School Book"
    end
  end

  describe "checkout refusal for guest" do
    test "real \"as:guest checkout ...\" message refuses without creating a Checkout row", %{agent: agent} do
      book = create_book!(%{available_copies: 3, total_copies: 3})
      before_count = Ash.count!(Checkout, authorize?: false)

      assert {:ok, task} =
               A2A.call(agent, "as:guest checkout book:#{book.id} school:test-school")

      assert task.status.state == :completed
      assert task_text(task) =~ "requires a real as:<user_id> actor"

      after_count = Ash.count!(Checkout, authorize?: false)
      assert after_count == before_count

      reloaded = Ash.get!(Book, book.id, authorize?: false)
      assert reloaded.available_copies == 3
    end
  end

  describe "checkout success" do
    test "real successful \"as:<user_id> checkout ...\" message creates a real Checkout row", %{agent: agent} do
      user = create_user!()
      book = create_book!(%{available_copies: 2, total_copies: 2})
      school_id = "test-school"

      assert {:ok, task} =
               A2A.call(agent, "as:#{user.id} checkout book:#{book.id} school:#{school_id}")

      assert task.status.state == :completed
      text = task_text(task)
      assert text =~ "Checked out book #{book.id}"
      assert text =~ "for user #{user.id}"

      checkout =
        Checkout
        |> Ash.Query.filter(book_id == ^book.id and user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert checkout != nil
      assert checkout.status == :borrowed
      assert checkout.book_id == book.id
      assert checkout.user_id == user.id

      reloaded_book = Ash.get!(Book, book.id, authorize?: false)
      assert reloaded_book.available_copies == 1
    end
  end
end
