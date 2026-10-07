defmodule XaasWeb.NextRead.ReaderLiveDeepeningTest do
  @moduledoc """
  W766 lane — Next Read LiveView deepening over the real surface.

  Chicago-style: real Phoenix LiveView mount over real sandbox Postgres data,
  real 6-factor Ranker output as the ranking oracle (the test asserts the
  rendered card order equals `Ranker.rank_recommendations/2`'s real output for
  the same fixture inputs), and a real `XaasWeb.Endpoint.broadcast/3` driving
  the subscribed `handle_info/2` re-render. No mocks.
  """

  use XaasWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Xaas.Accounts.User
  alias Xaas.Library.{Book, Ranker}

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    user = Ash.Seed.seed!(User, %{email: "w766.student@willowcreek.edu"})

    {:ok, user: user}
  end

  # Real Book/Curation fixtures spanning differentiated ranker inputs:
  # available vs. unavailable, grade-fit delta, curated vs. not, distinct genres.
  defp create_fixture_catalog! do
    books =
      Enum.map(1..4, fn i ->
        Book
        |> Ash.Changeset.for_create(:create, %{
          title: "W766 Signal Volume #{i}",
          author: "Author #{i}",
          isbn: "ISBN-W766-#{i}-#{System.unique_integer([:positive])}",
          grade_level: 7,
          genres: ["Science", "Adventure"],
          synopsis: "W766 deepening fixture volume #{i} of science and discovery.",
          available_copies: if(i <= 2, do: 2, else: 0),
          total_copies: 2
        })
        |> Ash.create!(authorize?: false)
      end)

    grade_8_book =
      Book
      |> Ash.Changeset.for_create(:create, %{
        title: "W766 Grade Eight Explorer",
        author: "Author 5",
        isbn: "ISBN-W766-8-#{System.unique_integer([:positive])}",
        grade_level: 8,
        genres: ["Science", "Adventure"],
        synopsis: "W766 fixture so the real grade_range spans the exercised grade.",
        available_copies: 1,
        total_copies: 1
      })
      |> Ash.create!(authorize?: false)

    books ++ [grade_8_book]
  end

  # Extracts the rendered recommendation order (top-level student cards) from
  # the real HTML — `data-book-id` appears on the book-card divs themselves.
  defp rendered_card_ids(html) do
    # data-book-id appears twice per book (the student card div and its
    # librarian pin-button) in the same order; dedupe preserving first-seen
    # order to recover the rendered ranking sequence.
    Regex.scan(~r/data-book-id="([^"]+)"/, html)
    |> Enum.map(&Enum.at(&1, 1))
    |> Enum.uniq()
  end

  # The ranker is the oracle: real Ranker output for the same inputs the
  # LiveView uses (same user_id, same grade). Both must agree on order.
  defp expected_ranking!(user, grade) do
    {:ok, ranked} =
      Ranker.rank_recommendations(user.id, grade, limit: 6, exclude_read: false)

    Enum.map(ranked, & &1.book.id)
  end

  describe "W766 Next Read LiveView deepening" do
    test "(a) mount renders the real 6-factor ranker order for crafted fixtures", %{
      conn: conn,
      user: user
    } do
      books = create_fixture_catalog!()
      grade = Xaas.Library.Config.default_grade()

      {:ok, _view, html} =
        conn
        |> Plug.Test.init_test_session(%{"user_id" => user.id})
        |> live(~p"/next-read")

      rendered_ids = rendered_card_ids(html)

      # All 5 fixture books must be ranked into the live render (limit 6).
      assert length(rendered_ids) == length(books)

      # Order must equal the real ranker's output for the same inputs.
      assert rendered_ids == expected_ranking!(user, grade)

      # The ranker itself must be non-degenerate on these fixtures (real
      # differentiated scores, not an all-ties flat list).
      {:ok, ranked} = Ranker.rank_recommendations(user.id, grade, limit: 6, exclude_read: false)
      scores = Enum.map(ranked, & &1.score)
      assert Enum.max(scores) >= Enum.min(scores)
      assert Enum.uniq(scores) |> length() > 1
    end

    test "(b) real PubSub inventory broadcast updates rendered availability", %{
      conn: conn,
      user: user
    } do
      books = create_fixture_catalog!()

      # Pick an available book from the live ranking surface.
      target = Enum.find(books, &(&1.available_copies > 0))
      assert target

      {:ok, view, html} =
        conn
        |> Plug.Test.init_test_session(%{"user_id" => user.id})
        |> live(~p"/next-read")

      assert html =~ "#{target.available_copies} copy on shelf"

      # Real inventory change, then a real broadcast on a topic the mounted
      # LiveView actually subscribes to ("library:books:events",
      # reader_live.ex mount/2). handle_info/2 reloads recommendations, so the
      # re-render must reflect the new DB state.
      target
      |> Ash.Changeset.for_update(:update, %{available_copies: 0})
      |> Ash.update!(authorize?: false)

      XaasWeb.Endpoint.broadcast("library:books:events", "inventory_changed", %{
        book_id: target.id
      })

      html_after = render(view)

      assert html_after =~ "all copies checked out"

      # Scoped to the target card: other fixture books legitimately still
      # render their own on-shelf counts.
      target_card_html =
        view
        |> element("[data-testid='book-card'][data-book-id='#{target.id}']")
        |> render()

      assert target_card_html =~ "all copies checked out"
      refute target_card_html =~ "#{target.available_copies} copy on shelf"
    end

    test "(c) unauthenticated public access renders the surface", %{conn: conn} do
      create_fixture_catalog!()

      # Route /next-read is public in lib/xaas_web/router.ex (no pipe-line
      # auth before live/1). No session -> resolve_current_user falls back to
      # the real guest user path.
      {:ok, view, html} = live(conn, ~p"/next-read")

      assert html =~ "Next Read"
      assert html =~ "personalized picks"
      assert has_element?(view, "[data-testid='book-card']")
      assert has_element?(view, "[data-testid='librarian-window']")
    end

    test "(d) determinism x2: two mounts rank identically", %{
      conn: conn,
      user: user
    } do
      create_fixture_catalog!()
      grade = Xaas.Library.Config.default_grade()

      {:ok, _view1, html1} =
        conn
        |> Plug.Test.init_test_session(%{"user_id" => user.id})
        |> live(~p"/next-read")

      {:ok, _view2, html2} =
        conn
        |> Plug.Test.init_test_session(%{"user_id" => user.id})
        |> live(~p"/next-read")

      ids1 = rendered_card_ids(html1)
      ids2 = rendered_card_ids(html2)

      assert ids1 == ids2
      assert ids1 == expected_ranking!(user, grade)
    end
  end
end
