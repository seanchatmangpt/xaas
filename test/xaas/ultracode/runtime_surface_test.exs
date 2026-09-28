defmodule Xaas.Ultracode.RuntimeSurfaceTest do
  @moduledoc """
  Pure, Chicago-style qualification of the runtime surface law against the
  real policy JSON (`priv/ultracode/runtime_surface.json`). No DB, no doubles.
  """
  use ExUnit.Case, async: true

  alias Xaas.Ultracode.RuntimeSurface
  alias Xaas.Ultracode.RuntimeSurface.Failure

  @required ~w(name category consequence agent_visible mediated_by authority_required lease_admit refusal)

  describe "policy rows" do
    test "every tool row has all required fields within the JSON vocabularies" do
      policy = RuntimeSurface.policy()
      assert policy["schema"] == "xaas-ultracode-runtime-surface/v1"
      assert RuntimeSurface.tools() != []

      for row <- RuntimeSurface.tools() do
        for f <- @required, do: assert(Map.has_key?(row, f), "#{row["name"]} missing #{f}")
        assert row["consequence"] in policy["consequences"], row["name"]
        assert row["mediated_by"] in policy["mediations"], row["name"]
      end

      names = Enum.map(RuntimeSurface.tools(), & &1["name"])
      assert names == Enum.uniq(names)
    end

    test "classify_tool returns the row or unknown_tool_class" do
      assert {:ok, %{"name" => "Read", "mediated_by" => "local"}} =
               RuntimeSurface.classify_tool("Read")

      assert {:error, {:unknown_tool_class, "GitHubClient"}} =
               RuntimeSurface.classify_tool("GitHubClient")
    end

    test "sprawl guard: every gate.deny_tools name is a forbidden_external_semantic_edge row" do
      deny = RuntimeSurface.gate_policy()["deny_tools"]
      assert deny != []

      for name <- deny do
        assert {:ok, row} = RuntimeSurface.classify_tool(name)
        assert row["refusal"] == "forbidden_external_semantic_edge"
        assert row["lease_admit"] == false
      end
    end

    test "gate pre_lease_ok tools are classified rows or declared local_only" do
      gate = RuntimeSurface.gate_policy()

      for name <- gate["pre_lease_ok"], name not in gate["local_only"] do
        assert {:ok, _} = RuntimeSurface.classify_tool(name)
      end
    end
  end

  describe "admit_tool/2" do
    test "allows local construction tools" do
      for t <- ~w(Read Edit Write Grep Glob Task TodoWrite) do
        assert {:ok, %{decision: :allow}} = RuntimeSurface.admit_tool(t, nil), t
      end
    end

    test "refuses consequence tools with refused_no_authority" do
      for t <- ~w(Bash git_push publish) do
        assert {:error, {:refused_no_authority, ^t}} = RuntimeSurface.admit_tool(t, nil)
      end
    end

    test "refuses web tools as forbidden external semantic edges naming the lawful route" do
      for t <- ~w(WebFetch WebSearch) do
        assert {:error, {:forbidden_external_semantic_edge, diag}} =
                 RuntimeSurface.admit_tool(t, nil)

        assert diag == %{
                 "from" => "ultracode",
                 "to" => t,
                 "required" => "UltraCode -> SA2A -> resolve_capability"
               }
      end
    end

    test "unknown tool is unknown_tool_class" do
      assert {:error, {:unknown_tool_class, "GitHubClient"}} =
               RuntimeSurface.admit_tool("GitHubClient", nil)
    end

    test "semantic port rows are not lease-admitted general tools" do
      assert {:error, {:unknown_tool_class, "mcp__xaas-execution__actuate"}} =
               RuntimeSurface.admit_tool("mcp__xaas-execution__actuate", nil)
    end

    test "provider override narrows but never adds" do
      assert {:ok, %{decision: :allow}} = RuntimeSurface.admit_tool("Read", ["Read"])
      assert {:error, {:unknown_tool_class, "Edit"}} = RuntimeSurface.admit_tool("Edit", ["Read"])

      assert {:error, {:forbidden_external_semantic_edge, %{"to" => "WebFetch"}}} =
               RuntimeSurface.admit_tool("WebFetch", ["WebFetch", "Read"])

      assert {:error, {:refused_no_authority, "Bash"}} =
               RuntimeSurface.admit_tool("Bash", ["Bash"])

      assert {:error, {:unknown_tool_class, "GitHubClient"}} =
               RuntimeSurface.admit_tool("GitHubClient", ["GitHubClient"])
    end
  end

  describe "admit_declaration/1" do
    test "default nil declaration is the policy surface" do
      assert {:ok, surface} = RuntimeSurface.admit_declaration(nil)
      assert surface["semantic_ports"] == ["sa2a", "sjira"]
      assert surface["direct_external"] == []
      assert surface["local_primitives"] == RuntimeSurface.local_primitives()
    end

    test "POLICY DRIFT falsifier: a generated declaration adding external edges is refused" do
      decl = %{
        "semantic_ports" => ["sa2a", "sjira", "github"],
        "direct_external" => ["GitHubClient"],
        "tools" => ["Read", "github.create_pull_request"],
        "provenance" => %{"generator" => "fixture"}
      }

      assert {:error, {:forbidden_external_semantic_edge, diags}} =
               RuntimeSurface.admit_declaration(decl)

      assert Enum.all?(diags, &(&1["from"] == "ultracode"))

      assert Enum.sort(Enum.map(diags, & &1["to"])) ==
               Enum.sort(["github", "GitHubClient", "github.create_pull_request"])

      assert Enum.all?(diags, &is_binary(&1["required"]))
    end

    test "unknown local primitive and non-local tools are refused" do
      assert {:error, {:forbidden_external_semantic_edge, diags}} =
               RuntimeSurface.admit_declaration(%{
                 "local_primitives" => ["filesystem", "docker_daemon"],
                 "tools" => ["WebFetch", "git_push"]
               })

      by_to = Map.new(diags, &{&1["to"], &1})
      assert Map.keys(by_to) |> Enum.sort() == ["WebFetch", "docker_daemon", "git_push"]
      assert by_to["git_push"]["required"] =~ "BRCE"
    end

    test "a narrower declaration within policy is admitted as the narrowed request" do
      assert {:ok, surface} =
               RuntimeSurface.admit_declaration(%{
                 "semantic_ports" => ["sjira"],
                 "tools" => ["Read"],
                 "direct_external" => []
               })

      assert surface["semantic_ports"] == ["sjira"]
      assert surface["agent_tools"] == ["Read"]
      assert surface["direct_external"] == []
    end
  end

  describe "effective_surface/1" do
    test "shape and digest over the raw policy bytes" do
      ctx = %{
        "work_id" => "W-1",
        "repo" => "/tmp/repo",
        "base_sha" => "abc",
        "branch" => "main",
        "lease_id" => "L-1",
        "env_keys" => ["PATH"]
      }

      s = RuntimeSurface.effective_surface(ctx)
      raw = File.read!(RuntimeSurface.policy_path())
      digest = "sha256:" <> Base.encode16(:crypto.hash(:sha256, raw), case: :lower)

      assert RuntimeSurface.policy_digest() == digest
      assert s["policy_digest"] == digest
      assert s["schema"] == "xaas-ultracode-runtime-surface/v1"
      assert s["semantic_ports"] == ["sa2a", "sjira"]
      assert s["direct_external"] == []
      assert s["subject"] == %{"repo" => "/tmp/repo", "base_sha" => "abc", "branch" => "main"}
      assert s["work_id"] == "W-1"
      assert s["lease_id"] == "L-1"
      assert s["authority"] == "NONE"
      assert s["env_keys"] == ["PATH"]

      assert Enum.sort(s["agent_tools"]) ==
               Enum.sort(~w(Read Grep Glob Edit Write Task TodoWrite))

      assert RuntimeSurface.effective_surface(Map.put(ctx, "authority", "BRCE"))["authority"] ==
               "BRCE"

      assert RuntimeSurface.effective_surface(%{})["env_keys"] == []
      assert Jason.encode!(s) |> Jason.decode!() == s
    end
  end

  describe "Failure" do
    test "codes and new/2" do
      assert length(Failure.codes()) == 10

      assert Failure.new(:stale_subject, %{"bound" => "a"}) ==
               %{"code" => "STALE_SUBJECT", "details" => %{"bound" => "a"}}

      bogus = String.to_atom("github_down")
      assert_raise ArgumentError, fn -> Failure.new(bogus, %{}) end
    end

    test "from_term mappings" do
      code = fn t -> Failure.from_term(t)["code"] end

      assert code.({:idempotency_conflict, "k"}) == "CONFLICTING_REPLAY"
      assert code.({:stale_subject, %{"bound" => "a", "observed" => "b"}}) == "STALE_SUBJECT"
      assert code.({:provenance_mismatch, %{}}) == "PROVENANCE_MISMATCH"

      assert code.({:forbidden_external_semantic_edge, %{"to" => "WebFetch"}}) ==
               "FORBIDDEN_EXTERNAL_SEMANTIC_EDGE"

      assert code.({:refused_no_authority, "Bash"}) == "UNAUTHORIZED"
      assert code.(:delegated_actuation_requires_authority_evidence) == "UNAUTHORIZED"

      for r <- [:lease_expired, :unknown_lease, :not_found, :lease_not_live] do
        assert code.(r) == "WORK_NOT_FOUND"
      end

      for t <- [
            {:sa2a_transport, :econnrefused},
            {:sa2a_status, 503},
            :sa2a_body_malformed,
            {:raised, :error, %RuntimeError{message: "x"}},
            {:invalid_endpoint_config, :missing}
          ] do
        assert code.(t) == "CAPABILITY_UNAVAILABLE"
      end

      assert code.({:invalid_transition, %{}}) == "INVALID_TRANSITION"

      assert Failure.from_term({:weird, 1}) ==
               %{"code" => "CAPABILITY_UNAVAILABLE", "details" => %{"term" => "{:weird, 1}"}}

      assert Failure.from_term({:stale_subject, %{"bound" => "a"}})["details"] == %{
               "bound" => "a"
             }
    end
  end
end
