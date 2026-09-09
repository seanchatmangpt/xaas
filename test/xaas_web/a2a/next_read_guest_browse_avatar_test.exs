defmodule XaasWeb.A2A.NextReadGuestBrowseAvatarTest do
  @moduledoc """
  Real A2A persona-avatar simulation: a guest reader persona (no
  PersonaGrant, `as:guest`) drives the real `XaasWeb.A2A.NextReadUserAgent`
  `A2A.Agent` GenServer via `A2A.call/3` with a real "browse" message,
  against real seeded `Xaas.Library.Book` Postgres rows. No mocking of
  A2A internals, Ash, or the catalog read path -- this exercises the same
  `Xaas.Library.Book` `:by_grade_band` read (and, via the sibling
  `recommend` alias in the agent's own command grammar, the
  embedding/ranker-backed recommendation surface in
  `Xaas.Library.Ranker`/`Xaas.Library.Embeddings`) that a real guest
  browsing session would hit.
  """
  use Xaas.DataCase, async: false

  alias Xaas.Library.Book

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    agent_name = :"next_read_guest_browse_avatar_test_#{System.unique_integer([:positive])}"
    {:ok, pid} = XaasWeb.A2A.NextReadUserAgent.start_link(name: agent_name)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    %{agent: pid}
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

  test "real \"as:guest browse grade:N\" A2A message returns a real successful task referencing a real seeded book",
       %{agent: agent} do
    book = create_book!(%{title: "The Guest Avatar Reading Quest", grade_level: 6})
    _other = create_book!(%{title: "Off Band Kindergarten Primer", grade_level: 0})

    assert {:ok, task} = A2A.call(agent, "as:guest browse grade:6")

    assert task.status.state == :completed
    text = task_text(task)
    assert text =~ book.title
    assert text =~ "available"
    refute text =~ "Off Band Kindergarten Primer"
  end
end
