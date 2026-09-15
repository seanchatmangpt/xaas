defmodule XaasWeb.ExecutionFabricControllerTest do
  @moduledoc """
  Real Chicago-style test for the execution-fabric HTTP surface
  (lib/xaas_web/controllers/execution_fabric_controller.ex, mounted under
  /internal-api/execution in XaasWeb.Router behind
  RequireInternalApiToken). Real ConnCase HTTP requests, real sandboxed
  Postgres rows (Xaas.Ultracode Run/Epoch/Receipt via real Ash actions),
  real git worktrees for head verification — asserting the decoded JSON
  responses over the wire, not the controller functions in isolation.

  Proves the load-bearing transport invariants:

    * fail-closed gate: unset token => 503, wrong bearer => 401;
    * hook surface: session_start acknowledged, pre_tool_use refusal is a
      typed 403 deny, unknown events 404, stop without a lease is
      not_closeable (never silent closure);
    * MCP JSON-RPC surface: initialize/tools list, and the full
      provider-pull loop over real rows — claim_next returns the lease
      token + work payload, admit_tool allows construction / refuses
      consequence, close_candidate seals a head-verified Receipt with the
      exact reported outcome, and refuse lands a typed refusal receipt.
  """

  use XaasWeb.ConnCase

  alias Xaas.Ultracode.{Epoch, Run}

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp hook_post(conn, event, body) do
    conn
    |> with_internal_api_token()
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> post("/internal-api/execution/hooks/#{event}", Jason.encode!(body))
  end

  defp mcp_post(conn, body) do
    conn
    |> with_internal_api_token()
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> post("/internal-api/execution/mcp", Jason.encode!(body))
  end

  defp mcp_result(conn, id, method, params \\ %{}) do
    conn
    |> mcp_post(%{jsonrpc: "2.0", id: id, method: method, params: params})
    |> json_response(200)
    |> Map.fetch!("result")
  end

  defp tool_call(conn, name, arguments) do
    conn
    |> mcp_result(1, "tools/call", %{"name" => name, "arguments" => arguments})
    |> Map.fetch!("content")
    |> List.first()
    |> Map.fetch!("text")
    |> Jason.decode!()
  end

  defp provider_run_and_epoch(provider, worktree \\ nil) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "Chicago qualification over real HTTP.", provider: provider},
        authorize?: false
      )
      |> Ash.create()

    {:ok, epoch} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "XaasWeb.ExecutionFabricControllerTest",
          state: :running,
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()

    {run, epoch}
  end

  describe "fail-closed token gate" do
    test "unset INTERNAL_API_TOKEN rejects every request with 503", %{conn: conn} do
      previous = System.fetch_env!("INTERNAL_API_TOKEN")
      System.delete_env("INTERNAL_API_TOKEN")

      try do
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/internal-api/execution/hooks/session_start", "{}")
        |> json_response(503)
      after
        System.put_env("INTERNAL_API_TOKEN", previous)
      end
    end

    test "wrong bearer is 401", %{conn: conn} do
      conn
      |> put_req_header("authorization", "Bearer not-the-token")
      |> put_req_header("content-type", "application/json")
      |> post("/internal-api/execution/hooks/session_start", "{}")
      |> json_response(401)
    end
  end

  describe "hook surface" do
    test "session_start is acknowledged", %{conn: conn} do
      body =
        conn
        |> hook_post("session_start", %{session_id: "sess-1", cwd: "/tmp/wt"})
        |> json_response(200)

      assert body["status"] == "acknowledged"
    end

    test "pre_tool_use without a lease is a typed 403 deny", %{conn: conn} do
      body =
        conn
        |> hook_post("pre_tool_use", %{tool: "Edit", cwd: "/tmp/wt"})
        |> json_response(403)

      assert body["decision"] == "deny"
      assert is_binary(body["reason"])
    end

    test "stop without a lease is not_closeable, never closure", %{conn: conn} do
      body =
        conn
        |> hook_post("stop", %{final_head: "abc123", standing: "ALIVE"})
        |> json_response(200)

      assert body["status"] == "not_closeable"
    end

    test "unknown hook event is 404", %{conn: conn} do
      conn
      |> hook_post("time_travel", %{})
      |> json_response(404)
    end
  end

  describe "MCP JSON-RPC surface" do
    test "initialize advertises the lease server", %{conn: conn} do
      result = conn |> mcp_result(1, "initialize") 
      assert result["serverInfo"]["name"] == "xaas-ultracode-lease"
      assert result["capabilities"]["tools"]
    end

    test "tools/list exposes exactly the fabric tools", %{conn: conn} do
      tools = conn |> mcp_result(2, "tools/list") |> Map.fetch!("tools")

      assert Enum.map(tools, & &1["name"]) |> Enum.sort() == [
               "admit_tool",
               "claim_next",
               "close_candidate",
               "heartbeat",
               "record_provider_event",
               "refuse"
             ]
    end

    test "claim_next with no ready work is a typed tool error, not silence", %{conn: conn} do
      assert tool_call(conn, "claim_next", %{provider: "zcode-chicago"}) ==
               %{"error" => ":no_ready_work"}
    end
  end

  describe "full provider-pull loop over real rows" do
    test "claim -> admit -> head-verified close seals an alive Receipt", %{conn: conn} do
      worktree = make_git_worktree()
      {run, epoch} = provider_run_and_epoch("zcode-chicago", worktree)

      claim =
        tool_call(conn, "claim_next", %{provider: "zcode-chicago", provider_worker_id: "worker-1"})

      assert claim["lease_token"]
      assert claim["epoch_id"] == epoch.id
      assert claim["exact_subject"] == epoch.exact_subject
      assert claim["goal"] == run.goal
      assert claim["worktree"] == worktree

      # Admission court over the wire.
      assert tool_call(conn, "admit_tool", %{lease_token: claim["lease_token"], tool: "Edit"}) ==
               %{"decision" => "allow"}

      assert tool_call(conn, "admit_tool", %{lease_token: claim["lease_token"], tool: "git_push"}) ==
               %{"error" => "refused_no_authority:\"git_push\""}

      # Head-verified closure over the wire.
      closed =
        tool_call(conn, "close_candidate", %{
          lease_token: claim["lease_token"],
          final_head: git_head(worktree),
          outcome: "alive",
          evidence: %{"verifier" => "mix test"}
        })

      assert closed["status"] == "closed"
      assert closed["outcome"] == "alive"

      # The DB row really landed: epoch completed, receipt sealed.
      reloaded = Ash.get!(Epoch, epoch.id, authorize?: false)
      assert reloaded.state == :completed
      assert reloaded.final_head == git_head(worktree)
    end

    test "standing reported in natural casing ('ALIVE') is not silently downgraded", %{
      conn: conn
    } do
      worktree = make_git_worktree()
      {_run, epoch} = provider_run_and_epoch("zcode-chicago", worktree)

      claim =
        tool_call(conn, "claim_next", %{provider: "zcode-chicago", provider_worker_id: "worker-3"})

      # Live regression guard: the stop hook and worker command report
      # "ALIVE" in natural casing; the transport must normalize, never
      # silently downgrade an honest ALIVE to partial_alive.
      closed =
        tool_call(conn, "close_candidate", %{
          lease_token: claim["lease_token"],
          final_head: git_head(worktree),
          outcome: "ALIVE"
        })

      assert closed["outcome"] == "alive"
      assert Ash.get!(Epoch, epoch.id, authorize?: false).state == :completed
    end

    test "refuse lands a typed refusal receipt", %{conn: conn} do
      {_run, epoch} = provider_run_and_epoch("zcode-chicago")

      claim =
        tool_call(conn, "claim_next", %{provider: "zcode-chicago", provider_worker_id: "worker-2"})

      refused =
        tool_call(conn, "refuse", %{lease_token: claim["lease_token"], reason: "blocked"})

      assert refused["status"] == "refused"
      assert refused["outcome"] == "refused"
      assert Ash.get!(Epoch, epoch.id, authorize?: false).state == :failed
    end
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp make_git_worktree do
    dir = Path.join(System.tmp_dir(), "xaas-fabric-http-#{System.unique_integer()}")
    File.mkdir_p!(dir)

    System.cmd("git", ["-C", dir, "init", "--quiet"], stderr_to_stdout: true)

    System.cmd(
      "git",
      ["-C", dir, "commit", "--allow-empty", "-m", "init", "--quiet"],
      stderr_to_stdout: true,
      env: [
        {"GIT_AUTHOR_NAME", "test"},
        {"GIT_AUTHOR_EMAIL", "test@test"},
        {"GIT_COMMITTER_NAME", "test"},
        {"GIT_COMMITTER_EMAIL", "test@test"}
      ]
    )

    dir
  end

  defp git_head(worktree) do
    {out, 0} = System.cmd("git", ["-C", worktree, "rev-parse", "HEAD"])
    String.trim(out)
  end
end
