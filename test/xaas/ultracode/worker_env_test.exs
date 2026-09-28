defmodule Xaas.Ultracode.WorkerEnvTest do
  @moduledoc """
  Chicago-style qualification of the worker environment law: the real
  compiled policy, and a real `/usr/bin/env` subprocess spawned with the
  built environment. Fixture credentials only.
  """
  use ExUnit.Case, async: true

  alias Xaas.Ultracode.WorkerEnv

  doctest WorkerEnv

  @denied ~w(GITHUB_TOKEN GH_TOKEN AWS_SECRET_ACCESS_KEY SLACK_BOT_TOKEN JIRA_API_TOKEN
             INTERNAL_API_TOKEN DATABASE_URL FOO_SECRET MY_API_KEY)
  @admitted ~w(PATH HOME LC_ALL XAAS_LEASE_ID XAAS_MCP_TOKEN ANTHROPIC_API_KEY
               ZCODE_SUBAGENT_MAX_TURNS ZCODE_OCEL)

  describe "allowed?/1" do
    for name <- @denied do
      test "refuses #{name}" do
        refute WorkerEnv.allowed?(unquote(name))
      end
    end

    for name <- @admitted do
      test "admits #{name}" do
        assert WorkerEnv.allowed?(unquote(name))
      end
    end

    test "refuses names the policy never mentions" do
      refute WorkerEnv.allowed?("RANDOM_UNLISTED_VAR")
      refute WorkerEnv.allowed?(nil)
    end
  end

  describe "build/2" do
    test "additions override parent but cannot smuggle a denied credential" do
      parent = %{"PATH" => "/bin", "HOME" => "/h", "GITHUB_TOKEN" => "fixture-gh"}

      additions = [
        {"GITHUB_TOKEN", "fixture-gh-smuggled"},
        {"HOME", "/lease"},
        {"XAAS_LEASE_ID", "lease-fixture"}
      ]

      env = WorkerEnv.build(parent, additions)

      assert env == [{"HOME", "/lease"}, {"PATH", "/bin"}, {"XAAS_LEASE_ID", "lease-fixture"}]
      assert WorkerEnv.key_names(env) == ["HOME", "PATH", "XAAS_LEASE_ID"]
      assert WorkerEnv.dropped(parent, additions) == ["GITHUB_TOKEN"]
    end

    test "is deterministic regardless of input order" do
      parent = %{"TERM" => "x", "PATH" => "/bin", "LC_ALL" => "C"}

      assert WorkerEnv.build(parent, []) ==
               WorkerEnv.build(Map.new(Enum.reverse(Map.to_list(parent))), [])

      assert Enum.map(WorkerEnv.build(parent, []), &elem(&1, 0)) == ["LC_ALL", "PATH", "TERM"]
    end

    test "env_argv starts from an empty environment" do
      assert WorkerEnv.env_argv([{"A", "1"}, {"B", "2"}]) == ["-i", "A=1", "B=2"]
    end
  end

  describe "real subprocess" do
    defp run_env(argv) do
      port =
        Port.open({:spawn_executable, "/usr/bin/env"}, [
          :binary,
          :exit_status,
          :stderr_to_stdout,
          args: argv
        ])

      collect(port, "")
    end

    defp collect(port, acc) do
      receive do
        {^port, {:data, data}} -> collect(port, acc <> data)
        {^port, {:exit_status, status}} -> {acc, status}
      after
        15_000 -> flunk("subprocess timed out; output so far: #{acc}")
      end
    end

    defp parent do
      Map.merge(System.get_env(), %{
        "GITHUB_TOKEN" => "fixture-gh",
        "AWS_SECRET_ACCESS_KEY" => "fixture-aws",
        "SLACK_BOT_TOKEN" => "fixture-slack"
      })
    end

    test "negative credential: child environment carries no forge/cloud/chat credential" do
      additions = [{"XAAS_LEASE_ID", "lease-fixture"}, {"GITHUB_TOKEN", "fixture-gh"}]
      env = WorkerEnv.build(parent(), additions)

      {out, 0} = run_env(WorkerEnv.env_argv(env) ++ ["/usr/bin/env"])

      refute out =~ "fixture-gh"
      refute out =~ "fixture-aws"
      refute out =~ "fixture-slack"
      assert out =~ "XAAS_LEASE_ID=lease-fixture"

      assert Enum.all?(
               WorkerEnv.dropped(parent(), additions),
               &(&1 not in WorkerEnv.key_names(env))
             )

      assert "GITHUB_TOKEN" in WorkerEnv.dropped(parent(), additions)
    end

    test "positive: child can still run a local primitive via PATH" do
      env = WorkerEnv.build(parent(), [{"XAAS_LEASE_ID", "lease-fixture"}])
      assert {"PATH", _} = List.keyfind(env, "PATH", 0)

      {out, 0} = run_env(WorkerEnv.env_argv(env) ++ ["git", "--version"])
      assert out =~ ~r/^git version /
    end
  end
end
