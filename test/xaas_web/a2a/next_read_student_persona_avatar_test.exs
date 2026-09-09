defmodule XaasWeb.A2A.NextReadStudentPersonaAvatarTest do
  @moduledoc """
  Chicago-school test simulating a distinct A2A persona avatar: a granted
  "student" persona sending a real `checkout` message through the real
  `XaasWeb.A2A.NextReadUserAgent` GenServer (started via `start_link/1`,
  driven with real `A2A.call/3`). Follows the established
  PersonaGrant/Checkout pattern from `next_read_user_agent_test.exs` --
  a real `Xaas.Library.PersonaGrant.grant!/4` grant, then a real
  Ash-backed Postgres row assertion on `Xaas.Library.Checkout`, no
  mocking of A2A internals, Ash actions, or the persona grant.
  """
  use Xaas.DataCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.{Book, Checkout, PersonaGrant}
  require Ash.Query

  @internal_api_caller_id "internal_api_token"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    agent_name = :"next_read_student_persona_avatar_test_#{System.unique_integer([:positive])}"
    {:ok, pid} = XaasWeb.A2A.NextReadUserAgent.start_link(name: agent_name)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    %{agent: pid}
  end

  # Real Xaas.Library.PersonaGrant :grant create action -- same pattern as
  # next_read_user_agent_test.exs's grant_persona!/1 -- used here to model a
  # distinct "student" persona avatar being granted impersonation rights.
  defp grant_student_persona!(user_id) do
    PersonaGrant.grant!(@internal_api_caller_id, user_id, "student_persona_avatar", authorize?: false)
  end

  defp create_student_user! do
    Ash.Seed.seed!(User, %{email: Faker.Internet.email()})
  end

  defp create_book!(attrs) do
    title = Map.get(attrs, :title, Faker.Commerce.product_name())
    author = Map.get(attrs, :author, Faker.Person.name())
    isbn = Map.get(attrs, :isbn, Faker.Commerce.color() <> "-#{System.unique_integer([:positive])}")
    grade_level = Map.get(attrs, :grade_level, 5)
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

  defp task_text(task) do
    (task.artifacts ++ [%{parts: []}])
    |> Enum.flat_map(& &1.parts)
    |> Enum.map_join(" ", fn %A2A.Part.Text{text: text} -> text end)
  end

  describe "student persona avatar checkout" do
    test "real \"as:<user_id> checkout ...\" message from a granted student persona creates a real Checkout row", %{
      agent: agent
    } do
      student = create_student_user!()
      grant_student_persona!(student.id)
      book = create_book!(%{available_copies: 2, total_copies: 2})
      school_id = "student-persona-school"

      before_count = Ash.count!(Checkout, authorize?: false)

      assert {:ok, task} =
               A2A.call(agent, "as:#{student.id} checkout book:#{book.id} school:#{school_id}")

      assert task.status.state == :completed
      text = task_text(task)
      assert text =~ "Checked out book #{book.id}"
      assert text =~ "for user #{student.id}"

      after_count = Ash.count!(Checkout, authorize?: false)
      assert after_count == before_count + 1

      checkout =
        Checkout
        |> Ash.Query.filter(book_id == ^book.id and user_id == ^student.id)
        |> Ash.read_one!(authorize?: false)

      assert checkout != nil
      assert checkout.status == :borrowed
      assert checkout.book_id == book.id
      assert checkout.user_id == student.id
      assert checkout.school_id == school_id

      reloaded_book = Ash.get!(Book, book.id, authorize?: false)
      assert reloaded_book.available_copies == 1
    end
  end
end
