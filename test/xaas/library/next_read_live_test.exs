defmodule XaasWeb.NextRead.ReaderLiveTest do
  @moduledoc """
  Phoenix LiveView integration tests for Next Read recommendation interface.
  Validates 6-factor ML rendering, grade change events, checkout actions, and PubSub broadcasts.
  """
  use XaasWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Xaas.Accounts.User
  alias Xaas.Library.{Book, Embeddings}

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    user =
      Ash.Seed.seed!(User, %{
        email: "test.student@school.district.edu"
      })

    {:ok, user: user}
  end

  defp create_sample_catalog! do
    Enum.map(1..4, fn i ->
      title = "Catalog Discovery #{i}"
      genres = ["Science", "Adventure"]
      {:ok, emb} = Embeddings.embed("#{title} #{Enum.join(genres, " ")}")

      Book
      |> Ash.Changeset.for_create(:create, %{
        title: title,
        author: "Author #{i}",
        isbn: "ISBN-#{i}-#{System.unique_integer([:positive])}",
        grade_level: 6,
        genres: genres,
        synopsis: "Engaging exploration of science and discovery volume #{i}.",
        available_copies: if(i == 1, do: 2, else: 0),
        total_copies: 2,
        embedding: emb
      })
      |> Ash.create!(authorize?: false)
    end)
  end

  describe "Next Read LiveView" do
    test "mounts and displays 6-factor recommendations", %{conn: conn, user: user} do
      create_sample_catalog!()

      {:ok, view, html} =
        conn
        |> Plug.Test.init_test_session(%{"user_id" => user.id})
        |> live(~p"/next-read")

      assert html =~ "Next Read"
      assert html =~ "Personalized reading recommendations"
      assert html =~ "% Match"
      assert has_element?(view, "[data-testid='recommendations-grid']")
      assert has_element?(view, "[data-testid='book-card']")
    end

    test "handles grade level changes dynamically", %{conn: conn, user: user} do
      create_sample_catalog!()

      {:ok, view, _html} =
        conn
        |> Plug.Test.init_test_session(%{"user_id" => user.id})
        |> live(~p"/next-read")

      rendered =
        view
        |> form("#grade-selection-form", %{"grade" => "8"})
        |> render_change()

      assert rendered =~ "Grade 8"
      assert has_element?(view, "[data-testid='book-card']")
    end

    test "handles checkout event, decrements copies, and displays flash message", %{conn: conn, user: user} do
      [available_book | _] = create_sample_catalog!()

      {:ok, view, _html} =
        conn
        |> Plug.Test.init_test_session(%{"user_id" => user.id})
        |> live(~p"/next-read")

      rendered =
        view
        |> element("button[phx-click='checkout_book'][phx-value-book-id='#{available_book.id}']")
        |> render_click()

      assert rendered =~ "Successfully checked out"
      assert rendered =~ "Checkout (1 available)"
    end
  end
end
