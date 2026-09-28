defmodule XaasWeb.ExecutionFabricSurfaceTest do
  @moduledoc """
  Chicago-style qualification of the two runtime-surface MCP tools on the
  execution fabric (`resolve_capability`, `surface`) and of the claim
  payload's `surface`/`work` envelope -- real ConnCase HTTP JSON-RPC behind
  the real `RequireInternalApiToken` gate, real sandboxed Run/Epoch rows,
  real tmp git repositories, and a REAL (simple) capability source module
  injected through the resolver's own config seam
  (`:ultracode_capability_sources`, put/restored per test -- hence
  `async: false`).
  """

  use XaasWeb.ConnCase, async: false

  alias Xaas.Ultracode.{Epoch, Run, RuntimeSurface}

  defmodule PublishSource do
    @moduledoc false
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx),
      do:
        {:ok,
         [
           %{capability_id: "sa2a:publish_change", satisfies: ["publish_change"]},
           %{capability_id: "recipe:mix-format", satisfies: ["recipe:mix-format"]}
         ]}
  end

  @git_env [
    {"GIT_AUTHOR_NAME", "t"},
    {"GIT_AUTHOR_EMAIL", "t@t"},
    {"GIT_COMMITTER_NAME", "t"},
    {"GIT_COMMITTER_EMAIL", "t@t"}
  ]

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    keys = [:ultracode_capability_sources, :ultracode_capability_gap_path]
    saved = Map.new(keys, &{&1, Application.fetch_env(:xaas, &1)})

    tmp = Path.join(System.tmp_dir!(), "fabric-surface-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    gap = Path.join(tmp, "gaps.ndjson")
    Application.put_env(:xaas, :ultracode_capability_gap_path, gap)

    on_exit(fn ->
      Enum.each(saved, fn
        {key, {:ok, value}} -> Application.put_env(:xaas, key, value)
        {key, :error} -> Application.delete_env(:xaas, key)
      end)

      File.rm_rf(tmp)
    end)

    {:ok, tmp: tmp, gap: gap}
  end

  defp mcp_result(conn, method, params) do
    conn
    |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> post(
      "/internal-api/execution/mcp",
      Jason.encode!(%{jsonrpc: "2.0", id: 1, method: method, params: params})
    )
    |> json_response(200)
    |> Map.fetch!("result")
  end

  defp tool_call(conn, name, arguments) do
    result = mcp_result(conn, "tools/call", %{"name" => name, "arguments" => arguments})
    [%{"text" => text}] = result["content"]
    {result["isError"] == true, Jason.decode!(text)}
  end

  defp tmp_repo(tmp) do
    dir = Path.join(tmp, "repo")
    File.mkdir_p!(dir)
    {_, 0} = System.cmd("git", ["-C", dir, "init", "--quiet", "-b", "main"], env: @git_env)
    File.write!(Path.join(dir, "a.txt"), "base\n")
    {_, 0} = System.cmd("git", ["-C", dir, "add", "a.txt"], env: @git_env)
    {_, 0} = System.cmd("git", ["-C", dir, "commit", "--quiet", "-m", "base"], env: @git_env)
    {sha, 0} = System.cmd("git", ["-C", dir, "rev-parse", "HEAD"])
    {dir, String.trim(sha)}
  end

  defp claimed(conn, attrs, worktree) do
    provider = "fabric-surface-#{System.unique_integer([:positive])}"

    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        Map.merge(%{goal: "Qualify the fabric runtime surface.", provider: provider}, attrs),
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
          exact_subject: "fabric surface qualification",
          state: :running,
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()

    {false, claim} =
      tool_call(conn, "claim_next", %{
        provider: provider,
        provider_worker_id: "worker-surface",
        epoch_id: epoch.id
      })

    {run, epoch, claim}
  end

  test "tools/list declares resolve_capability and surface with their input schemas", %{
    conn: conn
  } do
    tools = conn |> mcp_result("tools/list", %{}) |> Map.fetch!("tools")
    by_name = Map.new(tools, &{&1["name"], &1})

    assert %{"inputSchema" => %{"required" => ["lease_token", "capability"]} = rc} =
             by_name["resolve_capability"]

    assert Map.keys(rc["properties"]) |> Enum.sort() ==
             ["capability", "constraints", "lease_token"]

    assert %{"inputSchema" => %{"required" => ["lease_token"]}} = by_name["surface"]
    # The pre-existing tools are still declared.
    for name <- ~w(claim_next admit_tool actuate close_candidate cancel_work),
        do: assert(Map.has_key?(by_name, name))
  end

  test "claim_next carries the effective surface and a tracker-neutral work object", %{
    conn: conn,
    tmp: tmp
  } do
    {repo, base} = tmp_repo(tmp)

    {run, epoch, claim} =
      claimed(conn, %{base_sha: base, repository_identity: "demo-repo"}, repo)

    assert claim["epoch_id"] == epoch.id
    assert claim["surface"]["semantic_ports"] == ["sa2a", "sjira"]
    assert claim["surface"]["direct_external"] == []
    assert claim["surface"]["subject"]["base_sha"] == base
    assert claim["work"]["id"] == run.id

    assert claim["work"]["subject"] == %{
             "repo" => "demo-repo",
             "base_sha" => base,
             "branch" => nil
           }

    assert claim["work"]["objective"] == run.goal

    assert Enum.sort(Map.keys(claim["work"])) ==
             ~w(acceptance dependencies id objective provenance subject)
  end

  test "surface returns sa2a+sjira, no direct external edge, authority NONE", %{
    conn: conn,
    tmp: tmp
  } do
    {repo, base} = tmp_repo(tmp)
    {_run, _epoch, claim} = claimed(conn, %{base_sha: base, repository_identity: "demo"}, repo)

    assert {false, surface} = tool_call(conn, "surface", %{lease_token: claim["lease_token"]})
    assert surface["schema"] == "xaas-ultracode-runtime-surface/v1"
    assert surface["semantic_ports"] == ["sa2a", "sjira"]
    assert surface["direct_external"] == []
    assert surface["authority"] == "NONE"
    assert surface["policy_digest"] == RuntimeSurface.policy_digest()
    assert Map.has_key?(surface, "lease_id")
    refute "WebFetch" in surface["agent_tools"]
    refute "Bash" in surface["agent_tools"]
  end

  test "surface and resolve_capability on an unknown lease are WORK_NOT_FOUND", %{conn: conn} do
    assert {true, %{"error" => "WORK_NOT_FOUND", "failure" => %{"code" => "WORK_NOT_FOUND"}}} =
             tool_call(conn, "surface", %{lease_token: "no-such-lease"})

    assert {true, %{"error" => "WORK_NOT_FOUND", "failure" => failure}} =
             tool_call(conn, "resolve_capability", %{
               lease_token: "no-such-lease",
               capability: "publish_change"
             })

    assert failure["details"]["reason"] == "no_lease"
  end

  test "admit_tool WebFetch is refused as a forbidden external semantic edge", %{
    conn: conn,
    tmp: tmp
  } do
    {repo, base} = tmp_repo(tmp)
    {_run, _epoch, claim} = claimed(conn, %{base_sha: base}, repo)

    assert {true, %{"error" => error}} =
             tool_call(conn, "admit_tool", %{lease_token: claim["lease_token"], tool: "WebFetch"})

    assert error =~ "forbidden_external_semantic_edge"
    assert error =~ "UltraCode -> SA2A"

    # Bash keeps its exact pre-existing refusal shape on the wire.
    assert {true, %{"error" => "refused_no_authority:\"Bash\""}} =
             tool_call(conn, "admit_tool", %{lease_token: claim["lease_token"], tool: "Bash"})
  end

  test "resolve_capability binds a consequential handle to the LEASE subject over HTTP", %{
    conn: conn,
    tmp: tmp,
    gap: gap
  } do
    Application.put_env(:xaas, :ultracode_capability_sources, %{"local" => PublishSource})
    {repo, base} = tmp_repo(tmp)

    {_run, _epoch, claim} =
      claimed(conn, %{base_sha: base, repository_identity: "demo-repo"}, repo)

    assert {false, handle} =
             tool_call(conn, "resolve_capability", %{
               lease_token: claim["lease_token"],
               capability: "publish_change",
               constraints: %{"subject" => %{"repo" => "demo-repo"}}
             })

    assert handle["state"] == "bound"
    assert handle["capability_id"] == "sa2a:publish_change"
    assert handle["subject"] == %{"repo" => "demo-repo", "base_sha" => base, "branch" => nil}
    assert handle["authority_requirement"] == "brce"
    assert handle["invocation_contract"] == "actuate"
    assert handle["provenance"]["policy_digest"] == RuntimeSurface.policy_digest()
    assert handle["lease_token"] == claim["lease_token"]

    # A wire subject that disagrees with the lease is a claim, refused.
    assert {true, %{"error" => "PROVENANCE_MISMATCH", "failure" => mismatch}} =
             tool_call(conn, "resolve_capability", %{
               lease_token: claim["lease_token"],
               capability: "publish_change",
               constraints: %{"subject" => %{"base_sha" => String.duplicate("f", 40)}}
             })

    assert mismatch["details"]["keys"] == ["base_sha"]

    # Nothing answers "deploy_everything": NO_CAPABILITY + one gap record.
    assert {true, %{"error" => "NO_CAPABILITY"}} =
             tool_call(conn, "resolve_capability", %{
               lease_token: claim["lease_token"],
               capability: "deploy_everything"
             })

    assert %{"deploy_everything" => 1} = Xaas.Ultracode.CapabilityPort.gap_stats(gap)
  end
end
