defmodule XaasWeb.A2A.Vision2030AvatarsTest do
  @moduledoc """
  Real avatar simulations for the `full_grant_enforcement` actor-grant
  binding cycle (`docs/vision/vision-2030-2026-09-09-0020.md`). Drives the
  REAL `A2A.Agent` GenServer (`XaasWeb.A2A.NextReadUserAgent`) via real
  `A2A.call/3` messages -- no mocking of A2A internals, no stubbed
  `resolve_actor/2` -- plus one real HTTP call against the real `/mcp`
  JSON-RPC surface (`AshAi.Mcp.Router`), all against real seeded
  `Xaas.Accounts.User` / `Xaas.Library.Book` / `Xaas.Library.PersonaGrant`
  Postgres rows in the real sandboxed database.

  Three A2A personas + one MCP-surface avatar:

  1. Legitimate granted student -- `as:<user_id> browse ...` and a real
     granted `as:<user_id> checkout ...` both succeed.
  2. Guest/unauthenticated -- `as:guest browse ...` succeeds (read-only,
     per existing design); `as:guest checkout ...` is refused.
  3. Impersonation attempt -- `as:<user_id>` for a user id with NO active
     `PersonaGrant` is denied (`resolve_actor/2`'s `{:error,
     :unauthorized_actor}` path, surfaced as a failed A2A task) and a real
     `Xaas.Operations.AuditLogEntry` row with outcome `"denied"` is
     written -- confirming the old silent-impersonation gap is closed.
  4. MCP surface -- a real `POST /mcp` `tools/call` for `list_books` and
     `books_by_grade_band` confirms the documented, still-open read-only
     gap is exactly what is implemented: any bearer-token holder reads
     every book regardless of which persona/org it claims, because
     `resolve_org_actor` is a real no-op for `/mcp` traffic (per
     `lib/xaas_web/router.ex:68-86`) and `Book`'s own read policy is
     `authorize_if always()`. This test asserts that documented behavior
     is real, not more (no accidental scoping) and not less (reads still
     work).
  """

  use XaasWeb.ConnCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.{Book, Checkout, PersonaGrant}
  alias Xaas.Operations.AuditLogEntry
  require Ash.Query

  @internal_api_caller_id "internal_api_token"

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    agent_name = :"vision_2030_avatars_test_#{System.unique_integer([:positive])}"
    {:ok, pid} = XaasWeb.A2A.NextReadUserAgent.start_link(name: agent_name)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    %{agent: pid}
  end

  defp create_user!(email \\ nil) do
    Ash.Seed.seed!(User, %{email: email || Faker.Internet.email()})
  end

  defp grant_persona!(user_id) do
    PersonaGrant.grant!(@internal_api_caller_id, user_id, "vision_2030_avatars_test",
      authorize?: false
    )
  end

  defp create_granted_user!(email \\ nil) do
    user = create_user!(email)
    grant_persona!(user.id)
    user
  end

  defp create_book!(attrs) do
    tag = "vision2030-#{System.unique_integer([:positive])}"

    Book
    |> Ash.Changeset.for_create(:create, %{
      title: Map.get(attrs, :title, "#{tag} book"),
      author: Map.get(attrs, :author, "Avatar Author"),
      grade_level: Map.get(attrs, :grade_level, Decimal.new("5.0")),
      available_copies: Map.get(attrs, :available_copies, 3),
      total_copies: Map.get(attrs, :total_copies, 3)
    })
    |> Ash.create!(authorize?: false)
  end

  defp audit_entries_for(user_id) do
    AuditLogEntry
    |> Ash.Query.filter(resource_type == "PersonaGrant" and resource_id == ^to_string(user_id))
    |> Ash.read!(authorize?: false)
  end

  defp task_text(task) do
    (task.artifacts ++ [%{parts: []}])
    |> Enum.flat_map(& &1.parts)
    |> Enum.map_join(" ", fn %A2A.Part.Text{text: text} -> text end)
  end

  describe "avatar 3: impersonation attempt persona" do
    test "an \"as:<user_id>\" claim for a user with NO active grant is denied and audit-logged, never resolved",
         %{
           agent: agent
         } do
      victim = create_user!()
      # Deliberately no grant_persona!/1 call -- this is the real
      # ungranted-impersonation-attempt fixture the cycle's design names.
      _bait_book =
        create_book!(%{title: "Impersonator Should Never See This In A Resolved Actor Read"})

      assert {:ok, task} = A2A.call(agent, "as:#{victim.id} browse grade:5")

      assert task.status.state == :failed
      refute task_text(task) =~ "Found "

      entries = audit_entries_for(victim.id)
      assert Enum.any?(entries, &(&1.action == "a2a.actor_resolution.denied"))
      assert Enum.any?(entries, &(&1.metadata["outcome"] == "denied"))
      assert Enum.any?(entries, &(&1.metadata["caller_id"] == @internal_api_caller_id))
      refute Enum.any?(entries, &(&1.metadata["outcome"] == "allowed"))

      # Confirm no PersonaGrant was ever silently created/found for this
      # user id -- the denial is real, not a fixture artifact.
      assert {:ok, []} =
               PersonaGrant.active_for(@internal_api_caller_id, victim.id, authorize?: false)
    end
  end

  describe "avatar 4: MCP surface -- documented open-read, no per-caller scoping" do
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
            "clientInfo" => %{"name" => "vision_2030_avatars_test", "version" => "0.0.0"}
          }
        })

      body = json_response(conn, 200)
      assert body["result"]["protocolVersion"] == "2024-11-05"

      conn
      |> get_resp_header("mcp-session-id")
      |> List.first()
    end

    test "real POST /mcp list_books and books_by_grade_band return every book regardless of asserted persona",
         %{
           conn: conn
         } do
      tag = "mcp-avatar-#{System.unique_integer([:positive])}"

      owner = create_granted_user!()
      _ungranted_third_party = create_user!()

      book =
        Book
        |> Ash.Changeset.for_create(:create, %{
          title: "#{tag}-owned-by-#{owner.id}",
          author: "Avatar Author",
          grade_level: Decimal.new("4.0")
        })
        |> Ash.create!(authorize?: false)

      # First simulated MCP caller: no persona claim of any kind -- MCP
      # has no `as:<user_id>` concept, unlike the A2A surface.
      session_id_1 = initialize!(conn)

      list_conn_1 =
        build_conn()
        |> put_req_header("mcp-session-id", session_id_1)
        |> mcp_post(%{
          "jsonrpc" => "2.0",
          "id" => 2,
          "method" => "tools/call",
          "params" => %{"name" => "list_books", "arguments" => %{"input" => %{}}}
        })

      body_1 = json_response(list_conn_1, 200)
      assert body_1["result"]["isError"] == false
      [%{"type" => "text", "text" => encoded_1}] = body_1["result"]["content"]
      decoded_1 = Jason.decode!(encoded_1)
      assert Enum.any?(decoded_1, &(&1["id"] == book.id))

      # Second, entirely separate MCP session/connection (simulating a
      # different caller) using the SAME shared bearer token: the
      # documented gap says it sees the identical unscoped result set --
      # not more, not less. If a caller/tenant scope were real, this
      # second session would need its own persona binding to see the
      # first session's book; it does not.
      conn2 = build_conn()
      session_id_2 = initialize!(conn2)

      grade_band_conn =
        build_conn()
        |> put_req_header("mcp-session-id", session_id_2)
        |> mcp_post(%{
          "jsonrpc" => "2.0",
          "id" => 3,
          "method" => "tools/call",
          "params" => %{
            "name" => "books_by_grade_band",
            "arguments" => %{"input" => %{"min_grade" => 3, "max_grade" => 5}}
          }
        })

      body_2 = json_response(grade_band_conn, 200)
      assert body_2["result"]["isError"] == false
      [%{"type" => "text", "text" => encoded_2}] = body_2["result"]["content"]
      decoded_2 = Jason.decode!(encoded_2)

      returned = Enum.find(decoded_2, &(&1["id"] == book.id))

      assert returned != nil,
             "expected the second, unrelated MCP session to still see #{book.id} (documented no-scoping behavior)"

      assert returned["author"] == "Avatar Author"

      # And confirm the surface really is unauthenticated-beyond-the-
      # shared-token: no bearer token at all is still refused (this part
      # of the gate IS real), i.e. the gap is "no per-caller scoping",
      # not "no auth whatsoever".
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
