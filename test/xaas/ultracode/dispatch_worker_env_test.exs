defmodule Xaas.Ultracode.DispatchWorkerEnvTest do
  @moduledoc """
  Negative credential falsifier for the REAL dispatch spawn input: the
  node's environment carries fixture forge/cloud credentials, and the
  environment `Dispatch` hands to `/usr/bin/env -i` must not. The child is a
  real subprocess; `System.put_env/2` makes the fixture part of this node's
  real environment (restored afterwards), hence `async: false`.
  """
  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{Dispatch, RuntimeSurface, WorkerEnv}

  @fixtures %{
    "GITHUB_TOKEN" => "fixture-gh-dispatch",
    "AWS_SECRET_ACCESS_KEY" => "fixture-aws-dispatch",
    "SLACK_BOT_TOKEN" => "fixture-slack-dispatch",
    "ERL_AFLAGS" => "-eval fixture-eval"
  }

  setup do
    previous = Map.new(@fixtures, fn {k, _} -> {k, System.get_env(k)} end)
    Enum.each(@fixtures, fn {k, v} -> System.put_env(k, v) end)

    on_exit(fn ->
      Enum.each(previous, fn
        {k, nil} -> System.delete_env(k)
        {k, v} -> System.put_env(k, v)
      end)
    end)
  end

  test "the worker spawn environment carries no ambient credential" do
    built = %{
      env_added: [
        {"XAAS_WORKER", "1"},
        {"XAAS_LEASE_ID", "epoch-fixture"},
        {"FAKE_LOG", "/tmp/fake-log"},
        # explicit smuggling attempts through :extra_env
        {"GITHUB_TOKEN", "fixture-gh-smuggled"},
        {"XAAS_SURFACE_PATH", "/tmp/fixture-permissive-policy.json"},
        {"XAAS_ALLOW_SUBAGENTS", "1"}
      ]
    }

    env = Dispatch.worker_env(built)
    names = WorkerEnv.key_names(env)

    for name <- Map.keys(@fixtures), do: refute(name in names, name)
    refute "XAAS_ALLOW_SUBAGENTS" in names
    assert {"XAAS_SURFACE_PATH", RuntimeSurface.policy_path()} in env
    assert {"FAKE_LOG", "/tmp/fake-log"} in env

    {out, 0} = System.cmd("/usr/bin/env", WorkerEnv.env_argv(env) ++ ["/usr/bin/env"])

    refute out =~ "fixture-"
    assert out =~ "XAAS_LEASE_ID=epoch-fixture"
    assert out =~ "XAAS_SURFACE_PATH=#{RuntimeSurface.policy_path()}"
  end
end
