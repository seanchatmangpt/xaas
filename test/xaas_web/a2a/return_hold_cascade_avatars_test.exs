defmodule XaasWeb.A2A.ReturnHoldCascadeAvatarsTest do
  @moduledoc """
  Real avatar simulations for this cycle's return -> hold-fulfillment
  cascade (`Xaas.Library.Changes.FulfillNextHold` wired onto
  `Checkout.return`, `lib/xaas/library/checkout.ex:74-78`) plus the P2
  rollback fix on `HoldRequest`'s `:fulfill` action
  (`lib/xaas/library/hold_request.ex:120-138`). Chicago-style throughout --
  real Ash resources, real sandboxed Postgres, real `A2A.call/3` against
  the real `A2A.Agent` GenServer, and a real HTTP `POST /mcp` JSON-RPC call
  against the real `AshAi.Mcp.Router`. No mocking of any collaborator.

  Five avatars:

  1. Baseline return, zero active holds -- no cascade fires, inventory is
     simply incremented.
  2. Return with exactly one active hold -- the hold transitions to
     `:fulfilled` (net available_copies unchanged, since return+refulfill
     cancel out) and NOT left in a state where the book itself shows an
     open, uncommitted checkout for the hold holder -- per the design
     landed in this cycle, fulfilling a hold marks the *hold* fulfilled and
     decrements inventory the same way a checkout does, but does not
     create a second `Xaas.Library.Checkout` row for the hold holder. This
     avatar asserts that exact, real behavior: no new `Checkout` row is
     created for the waiting reader.
  3. Return with multiple active holds (placed in known order) -- only the
     OLDEST active hold transitions to `:fulfilled`; every other active
     hold on the same book stays `:active` untouched.
  4. Regression: the existing A2A `PersonaGrant`-gated checkout avatar path
     (`XaasWeb.A2A.NextReadUserAgent`, real `Xaas.Actuation.run/4`) still
     succeeds end-to-end after these changes.
  5. MCP avatar: a real `POST /mcp` `list_books` call confirms the
     documented, unchanged current behavior for the `/mcp` surface --
     unscoped, any-bearer-token-holder reads every book, no per-actor
     binding -- is exactly what is implemented (no accidental narrowing
     introduced by this cycle's return/hold changes, no accidental
     widening either).
  """

  use XaasWeb.ConnCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.{Book, Checkout, HoldRequest, PersonaGrant}

  require Ash.Query

  @internal_api_caller_id "internal_api_token"

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    agent_name = :"return_hold_cascade_avatars_test_#{System.unique_integer([:positive])}"
    {:ok, pid} = XaasWeb.A2A.NextReadUserAgent.start_link(name: agent_name)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    %{agent: pid}
  end

  defp create_user!(email \\ nil) do
    Ash.Seed.seed!(User, %{email: email || Faker.Internet.email()})
  end

  defp grant_persona!(user_id) do
    PersonaGrant.grant!(@internal_api_caller_id, user_id, "return_hold_cascade_avatars_test", authorize?: false)
  end

  defp create_granted_user!(email \\ nil) do
    user = create_user!(email)
    grant_persona!(user.id)
    user
  end

  defp create_book!(available_copies) do
    tag = "cascade-avatar-#{System.unique_integer([:positive])}"

    Book
    |> Ash.Changeset.for_create(:create, %{
      title: "#{tag} book",
      author: "Avatar Author",
      grade_level: Decimal.new("5.0"),
      available_copies: available_copies,
      total_copies: available_copies
    })
    |> Ash.create!(authorize?: false)
  end

  defp borrow!(book, user) do
    Checkout
    |> Ash.Changeset.for_create(:borrow, %{book_id: book.id, user_id: user.id, school_id: "willow-creek"})
    |> Ash.create!(authorize?: false)
  end

  defp place_hold!(book, user) do
    HoldRequest
    |> Ash.Changeset.for_create(:place, %{book_id: book.id, user_id: user.id, school_id: "willow-creek"})
    |> Ash.create!(authorize?: false)
  end

  defp task_text(task) do
    (task.artifacts ++ [%{parts: []}])
    |> Enum.flat_map(& &1.parts)
    |> Enum.map_join(" ", fn %A2A.Part.Text{text: text} -> text end)
  end

  describe "avatar 1: baseline return, zero active holds -- no cascade" do
    test "returning a checkout on a book with no active holds simply increments inventory, no hold touched" do
      borrower = create_user!()
      book = create_book!(2)
      checkout = borrow!(book, borrower)

      assert Ash.get!(Book, book.id, authorize?: false).available_copies == 1

      returned =
        checkout
        |> Ash.Changeset.for_update(:return, %{})
        |> Ash.update!(authorize?: false)

      assert returned.status == :returned

      book_after = Ash.get!(Book, book.id, authorize?: false)
      assert book_after.available_copies == 2

      # No hold exists at all for this book -- confirms FulfillNextHold's
      # `:oldest_active_for_book` lookup is a real no-op here, not a
      # silent side effect.
      holds =
        HoldRequest
        |> Ash.Query.for_read(:for_book, %{book_id: book.id})
        |> Ash.read!(authorize?: false)

      assert holds == []
    end
  end

  describe "avatar 2: return with exactly one active hold" do
    test "the sole active hold is fulfilled by the cascade, and no separate Checkout row is auto-created for the hold holder" do
      borrower = create_user!()
      waiting_reader = create_user!()
      book = create_book!(1)

      checkout = borrow!(book, borrower)
      assert Ash.get!(Book, book.id, authorize?: false).available_copies == 0

      hold = place_hold!(book, waiting_reader)
      assert hold.status == :active

      before_checkout_count = Ash.count!(Checkout, authorize?: false)

      checkout
      |> Ash.Changeset.for_update(:return, %{})
      |> Ash.update!(authorize?: false)

      hold_after = Ash.get!(HoldRequest, hold.id, authorize?: false)
      assert hold_after.status == :fulfilled
      assert %DateTime{} = hold_after.fulfilled_at

      # Per the design landed in this cycle: fulfilling a hold decrements
      # book inventory directly (Book.borrow_copy) -- it does NOT create a
      # new Xaas.Library.Checkout row for the hold holder. Confirm the
      # real Checkout table count is unchanged by the cascade, and no
      # Checkout row exists linking this book to the waiting reader.
      after_checkout_count = Ash.count!(Checkout, authorize?: false)
      assert after_checkout_count == before_checkout_count

      reader_checkout =
        Checkout
        |> Ash.Query.filter(book_id == ^book.id and user_id == ^waiting_reader.id)
        |> Ash.read_one!(authorize?: false)

      assert reader_checkout == nil

      # Net effect of return (+1) immediately re-consumed by the hold's own
      # fulfillment (-1): available_copies settles back at 0.
      book_after = Ash.get!(Book, book.id, authorize?: false)
      assert book_after.available_copies == 0
    end
  end

  describe "avatar 3: return with multiple active holds -- only the oldest is fulfilled" do
    test "the oldest active hold is fulfilled; every other active hold on the same book stays active" do
      borrower = create_user!()
      first_waiter = create_user!()
      second_waiter = create_user!()
      third_waiter = create_user!()
      book = create_book!(1)

      checkout = borrow!(book, borrower)
      assert Ash.get!(Book, book.id, authorize?: false).available_copies == 0

      first_hold = place_hold!(book, first_waiter)
      # Force distinct inserted_at ordering deterministically -- Postgres
      # timestamp resolution could otherwise tie within the same
      # microsecond under fast test execution.
      Process.sleep(5)
      second_hold = place_hold!(book, second_waiter)
      Process.sleep(5)
      third_hold = place_hold!(book, third_waiter)

      assert first_hold.position == 1
      assert second_hold.position == 2
      assert third_hold.position == 3

      checkout
      |> Ash.Changeset.for_update(:return, %{})
      |> Ash.update!(authorize?: false)

      first_after = Ash.get!(HoldRequest, first_hold.id, authorize?: false)
      second_after = Ash.get!(HoldRequest, second_hold.id, authorize?: false)
      third_after = Ash.get!(HoldRequest, third_hold.id, authorize?: false)

      assert first_after.status == :fulfilled
      assert %DateTime{} = first_after.fulfilled_at

      assert second_after.status == :active
      assert is_nil(second_after.fulfilled_at)

      assert third_after.status == :active
      assert is_nil(third_after.fulfilled_at)

      book_after = Ash.get!(Book, book.id, authorize?: false)
      assert book_after.available_copies == 0
    end
  end

  describe "avatar 4: regression -- real A2A PersonaGrant-gated checkout still works" do
    test "a real granted \"as:<user_id> checkout book:<id> school:<id>\" A2A call still succeeds end-to-end", %{
      agent: agent
    } do
      student = create_granted_user!()
      book = create_book!(2)

      assert {:ok, checkout_task} =
               A2A.call(agent, "as:#{student.id} checkout book:#{book.id} school:vision-2030-school")

      assert checkout_task.status.state == :completed
      assert task_text(checkout_task) =~ "Checked out book #{book.id}"
      assert task_text(checkout_task) =~ "for user #{student.id}"

      real_checkout =
        Checkout
        |> Ash.Query.filter(book_id == ^book.id and user_id == ^student.id)
        |> Ash.read_one!(authorize?: false)

      assert real_checkout != nil
      assert real_checkout.status == :borrowed

      reloaded_book = Ash.get!(Book, book.id, authorize?: false)
      assert reloaded_book.available_copies == 1
    end
  end

  describe "avatar 5: MCP avatar -- documented current /mcp behavior is exactly what is implemented" do
    defp with_internal_api_token(conn) do
      put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    end

    defp mcp_post(conn, body) do
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json")
      |> post("/mcp", Jason.encode!(body))
    end

    defp initialize!(conn) do
      conn =
        mcp_post(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => %{
            "protocolVersion" => "2024-11-05",
            "capabilities" => %{},
            "clientInfo" => %{"name" => "return_hold_cascade_avatars_test", "version" => "0.0.0"}
          }
        })

      body = json_response(conn, 200)
      assert body["result"]["protocolVersion"] == "2024-11-05"

      conn
      |> get_resp_header("mcp-session-id")
      |> List.first()
    end

    test "real POST /mcp list_books remains unscoped -- no actor-binding was added to /mcp by this cycle", %{
      conn: conn
    } do
      tag = "mcp-cascade-avatar-#{System.unique_integer([:positive])}"

      _owner = create_granted_user!()
      book = create_book!(3)

      book =
        book
        |> Ash.Changeset.for_update(:update, %{})
        |> Ash.Changeset.force_change_attribute(:title, "#{tag}-book")
        |> Ash.update!(authorize?: false)

      session_id = initialize!(conn)

      list_conn =
        build_conn()
        |> put_req_header("mcp-session-id", session_id)
        |> mcp_post(%{
          "jsonrpc" => "2.0",
          "id" => 2,
          "method" => "tools/call",
          "params" => %{"name" => "list_books", "arguments" => %{"input" => %{}}}
        })

      body = json_response(list_conn, 200)
      assert body["result"]["isError"] == false
      [%{"type" => "text", "text" => encoded}] = body["result"]["content"]
      decoded = Jason.decode!(encoded)

      # The book is visible with no as:<user_id>/persona claim of any kind
      # -- /mcp has no actor-binding concept, exactly as documented; this
      # cycle's return/hold cascade did not introduce or remove any such
      # binding on this surface.
      returned = Enum.find(decoded, &(&1["id"] == book.id))
      assert returned != nil
      assert returned["title"] == "#{tag}-book"

      # No bearer token at all is still refused -- the real auth floor
      # remains intact, only per-caller scoping is the documented gap.
      unauth_conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("accept", "application/json")
        |> post(
          "/mcp",
          Jason.encode!(%{
            "jsonrpc" => "2.0",
            "id" => 1,
            "method" => "initialize",
            "params" => %{"protocolVersion" => "2024-11-05", "capabilities" => %{}}
          })
        )

      assert unauth_conn.status == 401
    end
  end
end
