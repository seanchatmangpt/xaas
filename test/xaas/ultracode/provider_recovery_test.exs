defmodule Xaas.Ultracode.ProviderRecoveryTest do
  @moduledoc """
  Chicago-style qualification of `Xaas.Ultracode.ProviderRecovery`: a real
  GenServer per test (distinct name, `start_supervised!`), real
  classification of real provider output strings, breaker transitions
  driven by an injected clock FUNCTION backed by a real Agent (not a mock),
  and the REAL `Dispatch` launching a real fake-CLI subprocess whose 429 the
  breaker must count. Registry skip and WaveLoop gate run against the real
  modules with the test's own recovery server.
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{Dispatch, Epoch, ProviderRecovery, ProviderRegistry, Run, WaveLoop}

  doctest ProviderRecovery

  @sh Path.expand("../../support/fake-node.sh", __DIR__)
  @git_env [
    {"GIT_AUTHOR_NAME", "recovery-test"},
    {"GIT_AUTHOR_EMAIL", "recovery-test@xaas.local"},
    {"GIT_COMMITTER_NAME", "recovery-test"},
    {"GIT_COMMITTER_EMAIL", "recovery-test@xaas.local"}
  ]

  defp start_recovery!(opts \\ []) do
    {:ok, clock} = Agent.start_link(fn -> 1_000_000 end)
    name = :"provider_recovery_test_#{System.unique_integer([:positive])}"

    start_supervised!(
      {ProviderRecovery,
       Keyword.merge(
         [name: name, now_ms: fn -> Agent.get(clock, & &1) end, threshold: 3, base_ms: 1_000],
         opts
       )}
    )

    %{name: name, advance: fn ms -> Agent.update(clock, &(&1 + ms)) end}
  end

  # ------------------------------------------------------------------
  # classify/1 -- real provider output strings
  # ------------------------------------------------------------------

  describe "classify/1" do
    test "GLM 1302 with its real message is :overloaded; bare 1302 code is :rate_limited" do
      real =
        ~s({"error":{"code":"1302","message":"High concurrency usage of this API, please reduce concurrency or contact customer service to increase limits"}})

      assert ProviderRecovery.classify(real) == :overloaded
      assert ProviderRecovery.classify(~s({"code": "1302"})) == :rate_limited
    end

    test "HTTP 429 forms are :rate_limited" do
      assert ProviderRecovery.classify("Too Many Requests (HTTP 429)") == :rate_limited
      assert ProviderRecovery.classify(~s({"statusCode":429})) == :rate_limited

      assert ProviderRecovery.classify(
               {:ok, %{status: :rate_limited, output_tail: "Too Many Requests (HTTP 429)"}}
             ) == :rate_limited

      assert ProviderRecovery.classify(
               {:ok, %{status: :rate_limited, output_tail: "High concurrency usage"}}
             ) == :overloaded
    end

    test "401/403/invalid api key on a failed run is :auth" do
      assert ProviderRecovery.classify(
               {:ok,
                %{status: :failed, exit_code: 1, output_tail: "Error: HTTP 401 Unauthorized"}}
             ) == :auth

      assert ProviderRecovery.classify(
               {:ok, %{status: :failed, exit_code: 1, output_tail: "403 Forbidden"}}
             ) == :auth

      assert ProviderRecovery.classify(
               {:ok, %{status: :failed, exit_code: 1, output_tail: "Invalid API key provided"}}
             ) == :auth

      assert ProviderRecovery.classify({:error, {:dispatch_failed, 1, "invalid api key"}}) ==
               :auth
    end

    test "typed errors and statuses" do
      assert ProviderRecovery.classify({:error, {:spawn_failed, "enoent"}}) == :unavailable
      assert ProviderRecovery.classify({:error, {:dispatch_crashed, "boom"}}) == :crash
      assert ProviderRecovery.classify({:ok, %{status: :timeout, output_tail: ""}}) == :timeout
      assert ProviderRecovery.classify({:error, {:dispatch_timeout, "tail"}}) == :timeout

      assert ProviderRecovery.classify(
               {:ok, %{status: :failed, exit_code: 2, output_tail: "segfault"}}
             ) == :crash

      assert ProviderRecovery.classify({:ok, %{status: :ok, output_tail: "done"}}) == :ok
      assert ProviderRecovery.classify(:ok) == :ok
      assert ProviderRecovery.classify(:rate_limited) == :rate_limited
      assert ProviderRecovery.classify({:error, {:epoch_not_ready, "x"}}) == :malformed
    end
  end

  # ------------------------------------------------------------------
  # Breaker transitions (injected clock)
  # ------------------------------------------------------------------

  describe "circuit breaker" do
    test "closed -> open after threshold, half_open after backoff, closed on success" do
      %{name: name, advance: advance} = start_recovery!()
      rl = {:ok, %{status: :rate_limited, output_tail: "HTTP 429"}}

      assert ProviderRecovery.state("p", name) == :closed
      assert ProviderRecovery.record("p", rl, name) == :closed
      assert ProviderRecovery.record("p", rl, name) == :closed
      assert ProviderRecovery.record("p", rl, name) == :open
      assert ProviderRecovery.state("p", name) == :open
      refute ProviderRecovery.available?("p", name)

      advance.(999)
      assert ProviderRecovery.state("p", name) == :open

      advance.(1)
      assert ProviderRecovery.state("p", name) == :half_open
      assert ProviderRecovery.available?("p", name)

      assert ProviderRecovery.record("p", {:ok, %{status: :ok, output_tail: ""}}, name) ==
               :closed

      assert %{"p" => %{state: :closed, failures: 0, backoff_ms: 1_000}} =
               ProviderRecovery.snapshot(name)
    end

    test "half_open failure reopens with doubled backoff, capped" do
      %{name: name, advance: advance} = start_recovery!(cap_ms: 3_000)
      crash = {:error, {:dispatch_crashed, "boom"}}

      for _ <- 1..3, do: ProviderRecovery.record("p", crash, name)
      assert ProviderRecovery.state("p", name) == :open

      advance.(1_000)
      assert ProviderRecovery.record("p", crash, name) == :open
      assert %{"p" => %{backoff_ms: 2_000}} = ProviderRecovery.snapshot(name)

      advance.(1_999)
      assert ProviderRecovery.state("p", name) == :open
      advance.(1)
      assert ProviderRecovery.state("p", name) == :half_open

      assert ProviderRecovery.record("p", crash, name) == :open
      assert %{"p" => %{backoff_ms: 3_000}} = ProviderRecovery.snapshot(name)
    end

    test "success resets consecutive count; malformed does not move the breaker" do
      %{name: name} = start_recovery!()
      rl = :rate_limited

      ProviderRecovery.record("p", rl, name)
      ProviderRecovery.record("p", rl, name)
      ProviderRecovery.record("p", :ok, name)
      ProviderRecovery.record("p", rl, name)
      ProviderRecovery.record("p", {:error, {:epoch_not_ready, "x"}}, name)
      assert ProviderRecovery.record("p", rl, name) == :closed
      assert ProviderRecovery.record("p", rl, name) == :open
    end

    test "emits a transition telemetry event with provider/from/to/class" do
      %{name: name} = start_recovery!(threshold: 1)
      ref = make_ref()
      parent = self()
      handler = "provider-recovery-test-#{inspect(ref)}"

      :telemetry.attach(
        handler,
        ProviderRecovery.event(),
        fn _event, measurements, meta, _ -> send(parent, {ref, measurements, meta}) end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler) end)

      ProviderRecovery.record("tp", {:error, {:spawn_failed, "enoent"}}, name)

      assert_receive {^ref, %{count: 1},
                      %{provider: "tp", from: :closed, to: :open, class: :unavailable}}
    end

    test "absent server: record is :not_running, reads are closed/available" do
      assert ProviderRecovery.record("p", :rate_limited, :no_such_recovery_server) ==
               :not_running

      assert ProviderRecovery.state("p", :no_such_recovery_server) == :closed
      assert ProviderRecovery.available?("p", :no_such_recovery_server)
      assert ProviderRecovery.snapshot(:no_such_recovery_server) == %{}
    end

    test "the application starts the default server" do
      assert is_pid(Process.whereis(ProviderRecovery))
    end
  end

  # ------------------------------------------------------------------
  # Registry skip + WaveLoop gate
  # ------------------------------------------------------------------

  describe "ProviderRegistry.select/2" do
    setup do
      previous = Application.get_env(:xaas, :ultracode_providers)

      Application.put_env(:xaas, :ultracode_providers, %{
        "cheap" => %{authority_ceiling: :construction, cost: 1},
        "dear" => %{authority_ceiling: :construction, cost: 5}
      })

      on_exit(fn ->
        if previous,
          do: Application.put_env(:xaas, :ultracode_providers, previous),
          else: Application.delete_env(:xaas, :ultracode_providers)
      end)

      :ok
    end

    test "skips an open provider, admits it again at half_open, refuses typed when all open" do
      %{name: name, advance: advance} = start_recovery!()
      opts = [provider_recovery: name]

      assert {:ok, "cheap", _} = ProviderRegistry.select(%{}, opts)

      for _ <- 1..3, do: ProviderRecovery.record("cheap", :rate_limited, name)
      assert {:ok, "dear", _} = ProviderRegistry.select(%{}, opts)

      for _ <- 1..3, do: ProviderRecovery.record("dear", :rate_limited, name)

      assert {:error, {:all_providers_open, details}} = ProviderRegistry.select(%{}, opts)
      assert %{provider: "cheap", verdict: :breaker_open} in details
      assert %{provider: "dear", verdict: :breaker_open} in details

      advance.(1_000)
      assert {:ok, "cheap", _} = ProviderRegistry.select(%{}, opts)
    end

    test "non-breaker refusals keep the :no_qualifying_provider shape" do
      %{name: name} = start_recovery!()

      assert {:error, {:no_qualifying_provider, _}} =
               ProviderRegistry.select(%{authority: :actuation}, provider_recovery: name)
    end
  end

  describe "WaveLoop.provider_overloaded?/2" do
    test "an open breaker for the loop's provider is an overload; closed falls back to telemetry" do
      %{name: name} = start_recovery!()

      telemetry =
        Path.join(System.tmp_dir!(), "absent-telemetry-#{System.unique_integer()}.jsonl")

      opts = [provider_recovery: name]

      refute WaveLoop.provider_overloaded?(telemetry, opts)

      for _ <- 1..3, do: ProviderRecovery.record("zcode", :rate_limited, name)
      assert WaveLoop.provider_overloaded?(telemetry, opts)

      # provider comes from dispatch_opts when overridden
      refute WaveLoop.provider_overloaded?(
               telemetry,
               opts ++ [dispatch_opts: [provider: "other"]]
             )
    end
  end

  # ------------------------------------------------------------------
  # Integration: the REAL Dispatch feeds the breaker
  # ------------------------------------------------------------------

  describe "Dispatch integration" do
    setup do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
      :ok
    end

    test "a real 429 dispatch (no retry) is counted by the breaker" do
      %{name: name} = start_recovery!(threshold: 1)
      provider = "zcode-recovery-test"
      worktree = git_worktree!()
      epoch = create_epoch!(worktree, provider)

      cli_dir =
        fake_cli_dir("""
        echo 'Too Many Requests (HTTP 429)'
        exit 0
        """)

      {:ok, result} =
        Dispatch.dispatch(epoch.id,
          provider: provider,
          cli_dir: cli_dir,
          node_path: @sh,
          timeout_seconds: 30,
          failover_retries: 0,
          provider_recovery: name
        )

      assert result.status == :rate_limited
      assert result.attempts == 1
      assert ProviderRecovery.state(provider, name) == :open

      assert %{^provider => %{last_class: :rate_limited, failures: 1}} =
               ProviderRecovery.snapshot(name)
    end
  end

  # ------------------------------------------------------------------
  # Helpers (pattern from dispatch_test.exs)
  # ------------------------------------------------------------------

  defp create_epoch!(worktree, provider) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "recovery test goal", provider: provider, max_cycles: 1},
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
          exact_subject: "recovery-test:#{System.unique_integer([:positive])}",
          state: :running,
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()

    epoch
  end

  defp git_worktree! do
    dir = mktmp("wt")
    {_, 0} = System.cmd("git", ["init", "-q"], cd: dir, env: @git_env)

    {_, 0} =
      System.cmd("git", ["commit", "-q", "--allow-empty", "-m", "init"], cd: dir, env: @git_env)

    dir
  end

  defp fake_cli_dir(script) do
    dir = mktmp("cli")
    File.mkdir_p!(Path.join(dir, "bin"))
    path = Path.join([dir, "bin", "zcode.js"])
    File.write!(path, script)
    File.chmod!(path, 0o755)

    File.write!(
      Path.join(dir, "package.json"),
      Jason.encode!(%{
        "name" => "zcode-app-cli",
        "version" => "0.0.0-test",
        "bin" => %{"zcode" => "bin/zcode.js"},
        "engines" => %{"node" => ">=22.19.0"}
      })
    )

    dir
  end

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-recovery-test-#{label}-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end
end
