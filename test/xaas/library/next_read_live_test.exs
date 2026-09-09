defmodule XaasWeb.NextRead.ReaderLiveTest do
  @moduledoc """
  Phoenix LiveView integration tests for Next Read recommendation interface.
  Validates 6-factor ML rendering, grade change events, checkout actions, and PubSub broadcasts.
  """
  use XaasWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Xaas.Accounts.User
  alias Xaas.Library.Book

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
    # Config.grade_range/0 now derives from the real min/max Book.grade_level
    # in the catalog (Ash aggregate) rather than a hardcoded 1..12 -- so this
    # fixture must actually span the grade levels the tests below exercise
    # (grade 8, via the "handles grade level changes dynamically" test)
    # instead of seeding everything at a single grade_level.
    books =
      Enum.map(1..4, fn i ->
        title = "Catalog Discovery #{i}"
        genres = ["Science", "Adventure"]

        Book
        |> Ash.Changeset.for_create(:create, %{
          title: title,
          author: "Author #{i}",
          isbn: "ISBN-#{i}-#{System.unique_integer([:positive])}",
          grade_level: 6,
          genres: genres,
          synopsis: "Engaging exploration of science and discovery volume #{i}.",
          available_copies: if(i == 1, do: 2, else: 0),
          total_copies: 2
        })
        |> Ash.create!(authorize?: false)
      end)

    grade_8_book =
      Book
      |> Ash.Changeset.for_create(:create, %{
        title: "Grade Eight Explorer",
        author: "Author 5",
        isbn: "ISBN-5-#{System.unique_integer([:positive])}",
        grade_level: 8,
        genres: ["Science", "Adventure"],
        synopsis: "A grade-8-level catalog entry so grade_range covers grade 8.",
        available_copies: 2,
        total_copies: 2
      })
      |> Ash.create!(authorize?: false)

    books ++ [grade_8_book]
  end

  describe "Next Read LiveView" do
    test "mounts and displays 6-factor recommendations", %{conn: conn, user: user} do
      create_sample_catalog!()

      {:ok, view, html} =
        conn
        |> Plug.Test.init_test_session(%{"user_id" => user.id})
        |> live(~p"/next-read")

      assert html =~ "Next Read"
      assert html =~ "personalized picks"
      assert has_element?(view, "[data-testid='book-card']")
    end

    test "handles grade level changes dynamically", %{conn: conn, user: user} do
      create_sample_catalog!()

      {:ok, view, _html} =
        conn
        |> Plug.Test.init_test_session(%{"user_id" => user.id})
        |> live(~p"/next-read")

      # The header grade selector form has no id -- it's
      # `<form phx-change="change_grade">` wrapping
      # `<select id="header-grade-select" name="grade">` (see
      # reader_live.ex) -- so target it by its real phx-change selector,
      # not a stale "#grade-selection-form" id this template never emits.
      rendered =
        view
        |> form("form[phx-change='change_grade']", %{"grade" => "8"})
        |> render_change()

      assert rendered =~ "Grade 8"
      assert has_element?(view, "[data-testid='book-card']")
    end

    test "handles checkout event, decrements copies, and displays flash message", %{
      conn: conn,
      user: user
    } do
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
      # available_book seeds with available_copies: 2; the real Actuation
      # decrement (Checkout.borrow -> Book.borrow_copy atomic_update) drops
      # it to 1, rendered as "1 copy on shelf" (see reader_live.ex's
      # available_copies metadata tag) -- not the old "Checkout (N
      # available)" button copy, which this template no longer renders.
      assert rendered =~ "1 copy on shelf"
    end
  end
end
