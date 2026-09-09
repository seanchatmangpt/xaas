defmodule Xaas.Library.PubSubTest do
  @moduledoc """
  Chicago-school real-PubSub tests for the Ash.Notifier.PubSub `pub_sub` blocks on
  Book, Checkout, and Curation -- including the "events"/"student"/"grade" topics
  added this session. Subscribes to the real topic via Phoenix.PubSub against the
  real `Xaas.PubSub` server (see config/config.exs's `pubsub_server: Xaas.PubSub`),
  runs the real Ash action, and asserts a real `%Phoenix.Socket.Broadcast{}` arrives.
  No mocking of Ash, PubSub, or the notifier.
  """
  use Xaas.DataCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.{Book, Checkout, Curation}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_user!(email \\ nil) do
    user_email = email || Faker.Internet.email()
    Ash.Seed.seed!(User, %{email: user_email})
  end

  defp create_book!(attrs \\ %{}) do
    title = Map.get(attrs, :title, Faker.Commerce.product_name())
    author = Map.get(attrs, :author, Faker.Person.name())
    isbn = Map.get(attrs, :isbn, Faker.Commerce.color() <> "-#{System.unique_integer([:positive])}")
    grade_level = Map.get(attrs, :grade_level, Enum.random(3..8))
    genres = Map.get(attrs, :genres, ["Fiction", "Adventure"])
    synopsis = Map.get(attrs, :synopsis, Faker.Lorem.paragraph(2))
    available_copies = Map.get(attrs, :available_copies, 2)
    total_copies = Map.get(attrs, :total_copies, 2)

    Book
    |> Ash.Changeset.for_create(:create, %{
      title: title,
      author: author,
      isbn: isbn,
      grade_level: grade_level,
      genres: genres,
      synopsis: synopsis,
      available_copies: available_copies,
      total_copies: total_copies
    })
    |> Ash.create!(authorize?: false)
  end

  describe "Book pub_sub (prefix \"library:books\")" do
    test "create broadcasts on the created and events topics" do
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "library:books:created")
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "library:books:events")

      book = create_book!()

      assert_receive %Phoenix.Socket.Broadcast{topic: "library:books:created", payload: payload}, 1_000
      assert payload.data.id == book.id

      assert_receive %Phoenix.Socket.Broadcast{topic: "library:books:events"}, 1_000
    end

    test "update broadcasts on the updated:<id> and events topics" do
      book = create_book!()

      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "library:books:updated:#{book.id}")
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "library:books:events")

      book
      |> Ash.Changeset.for_update(:update, %{title: "Updated Title"})
      |> Ash.update!(authorize?: false)

      assert_receive %Phoenix.Socket.Broadcast{topic: "library:books:updated:" <> id}, 1_000
      assert id == book.id

      assert_receive %Phoenix.Socket.Broadcast{topic: "library:books:events"}, 1_000
    end

    test "borrow_copy broadcasts on the inventory:<id> and events topics" do
      book = create_book!(%{available_copies: 2})

      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "library:books:inventory:#{book.id}")
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "library:books:events")

      book
      |> Ash.Changeset.for_update(:borrow_copy, %{})
      |> Ash.update!(authorize?: false)

      assert_receive %Phoenix.Socket.Broadcast{topic: "library:books:inventory:" <> id}, 1_000
      assert id == book.id

      assert_receive %Phoenix.Socket.Broadcast{topic: "library:books:events"}, 1_000
    end

    test "return_copy broadcasts on the inventory:<id> and events topics" do
      book = create_book!(%{available_copies: 1})

      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "library:books:inventory:#{book.id}")
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "library:books:events")

      book
      |> Ash.Changeset.for_update(:return_copy, %{})
      |> Ash.update!(authorize?: false)

      assert_receive %Phoenix.Socket.Broadcast{topic: "library:books:inventory:" <> id}, 1_000
      assert id == book.id

      assert_receive %Phoenix.Socket.Broadcast{topic: "library:books:events"}, 1_000
    end
  end

  describe "Checkout pub_sub (prefix \"circulation\")" do
    test "create broadcasts on school, events, and student topics" do
      user = create_user!()
      book = create_book!()

      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "circulation:school:willow-creek")
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "circulation:events")
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "circulation:student:#{user.id}")

      Checkout
      |> Ash.Changeset.for_create(:create, %{user_id: user.id, book_id: book.id})
      |> Ash.create!(authorize?: false)

      assert_receive %Phoenix.Socket.Broadcast{topic: "circulation:school:willow-creek"}, 1_000
      assert_receive %Phoenix.Socket.Broadcast{topic: "circulation:events"}, 1_000
      assert_receive %Phoenix.Socket.Broadcast{topic: "circulation:student:" <> user_id}, 1_000
      assert user_id == user.id
    end

    test "borrow broadcasts on the real circulation:student:<user_id> topic" do
      user = create_user!()
      book = create_book!(%{available_copies: 3})

      topic = "circulation:student:#{user.id}"
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, topic)
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "circulation:events")

      checkout =
        Checkout
        |> Ash.Changeset.for_create(:borrow, %{user_id: user.id, book_id: book.id})
        |> Ash.create!(authorize?: false)

      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, payload: payload}, 1_000
      assert payload.data.id == checkout.id

      assert_receive %Phoenix.Socket.Broadcast{topic: "circulation:events"}, 1_000
    end

    test "return broadcasts on events and student topics" do
      user = create_user!()
      book = create_book!(%{available_copies: 3})

      checkout =
        Checkout
        |> Ash.Changeset.for_create(:borrow, %{user_id: user.id, book_id: book.id})
        |> Ash.create!(authorize?: false)

      topic = "circulation:student:#{user.id}"
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, topic)
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "circulation:events")

      checkout
      |> Ash.Changeset.for_update(:return, %{})
      |> Ash.update!(authorize?: false)

      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic}, 1_000
      assert_receive %Phoenix.Socket.Broadcast{topic: "circulation:events"}, 1_000
    end

    test "update broadcasts on school, events, and student topics" do
      user = create_user!()
      book = create_book!()

      checkout =
        Checkout
        |> Ash.Changeset.for_create(:create, %{user_id: user.id, book_id: book.id})
        |> Ash.create!(authorize?: false)

      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "circulation:school:willow-creek")
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "circulation:events")
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "circulation:student:#{user.id}")

      checkout
      |> Ash.Changeset.for_update(:update, %{renewed_count: 1})
      |> Ash.update!(authorize?: false)

      assert_receive %Phoenix.Socket.Broadcast{topic: "circulation:school:willow-creek"}, 1_000
      assert_receive %Phoenix.Socket.Broadcast{topic: "circulation:events"}, 1_000
      assert_receive %Phoenix.Socket.Broadcast{topic: "circulation:student:" <> _}, 1_000
    end
  end

  describe "Curation pub_sub (prefix \"recommendations\")" do
    test "create broadcasts on student, curation_events, and grade topics" do
      book = create_book!()
      student_id = "student-#{System.unique_integer([:positive])}"
      grade_band = "6-8"

      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "recommendations:student:#{student_id}")
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "recommendations:curation_events")
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "recommendations:grade:#{grade_band}")

      curation =
        Curation
        |> Ash.Changeset.for_create(:create, %{
          book_id: book.id,
          curated_by: "librarian@example.com",
          grade_band: grade_band,
          student_id: student_id,
          reason: "Great fit"
        })
        |> Ash.create!(authorize?: false)

      assert_receive %Phoenix.Socket.Broadcast{topic: "recommendations:student:" <> sid, payload: payload}, 1_000
      assert sid == student_id
      assert payload.data.id == curation.id

      assert_receive %Phoenix.Socket.Broadcast{topic: "recommendations:curation_events"}, 1_000
      assert_receive %Phoenix.Socket.Broadcast{topic: "recommendations:grade:" <> gb}, 1_000
      assert gb == grade_band
    end

    test "update broadcasts on student, curation_events, and grade topics" do
      book = create_book!()
      student_id = "student-#{System.unique_integer([:positive])}"
      grade_band = "6-8"

      curation =
        Curation
        |> Ash.Changeset.for_create(:create, %{
          book_id: book.id,
          curated_by: "librarian@example.com",
          grade_band: grade_band,
          student_id: student_id
        })
        |> Ash.create!(authorize?: false)

      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "recommendations:student:#{student_id}")
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "recommendations:curation_events")
      :ok = Phoenix.PubSub.subscribe(Xaas.PubSub, "recommendations:grade:#{grade_band}")

      curation
      |> Ash.Changeset.for_update(:update, %{reason: "Updated reason"})
      |> Ash.update!(authorize?: false)

      assert_receive %Phoenix.Socket.Broadcast{topic: "recommendations:student:" <> _}, 1_000
      assert_receive %Phoenix.Socket.Broadcast{topic: "recommendations:curation_events"}, 1_000
      assert_receive %Phoenix.Socket.Broadcast{topic: "recommendations:grade:" <> _}, 1_000
    end
  end
end
