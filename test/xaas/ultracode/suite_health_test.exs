defmodule Xaas.Ultracode.SuiteHealthTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @moduledoc """
  Chicago-style qualification of the suite health court
  (`Xaas.Ultracode.SuiteHealth`): a suite must pass a known-green fixture and
  FAIL a known-red fixture, drift or vacuity quarantines it, and a healthy
  result releases it -- with no human step anywhere.

  Real everything: git repos (a green tag, a red tag on a side branch), real
  `/bin/sh` suites through the real `Verifier.run/2` (`env -i`, containment
  root, process groups), a real receipt store on disk, the real
  `Autonomic.suite_health_gate/1` and the real `mix xaas.ultracode.suite_health`
  task. The deliberately vacuous suite is `exit 0`.
  """

  alias Xaas.Test.DodFixture, as: Fx
  alias Xaas.Ultracode.{Autonomic, SuiteHealth, TargetSuites, Verifier}
  alias Mix.Tasks.Xaas.Ultracode.SuiteHealth, as: HealthTask

  @env %{"PATH" => "/usr/bin:/bin"}
  @strong ~s|test "$(cat answer.txt)" = 42|
  @max_age 1_000

  setup do
    original =
      for key <- [
            :ultracode_verifier_suites,
            :ultracode_worktree_root,
            :ultracode_suite_health_dir,
            :ultracode_target_suites,
            :ultracode_repos,
            :ultracode_repos_file
          ],
          into: %{},
          do: {key, Application.get_env(:xaas, key)}

    on_exit(fn ->
      for {key, value} <- original do
        if is_nil(value),
          do: Application.delete_env(:xaas, key),
          else: Application.put_env(:xaas, key, value)
      end
    end)

    root = Fx.tmp("root")
    store = Fx.tmp("store")
    parent = Fx.tmp("origin")

    Application.put_env(:xaas, :ultracode_worktree_root, root)
    Application.put_env(:xaas, :ultracode_suite_health_dir, store)
    Application.delete_env(:xaas, :ultracode_target_suites)

    {repo, green} = Fx.repo(parent, %{"answer.txt" => "42\n"})
    Fx.tag(repo, "dod-green", green)
    Fx.git!(repo, ["checkout", "--quiet", "-b", "red-side"])
    red = Fx.commit(repo, %{"answer.txt" => "41\n"}, "break the answer")
    Fx.tag(repo, "dod-red", red)
    Fx.git!(repo, ["checkout", "--quiet", "main"])

    %{root: root, store: store, repo: repo, green: green, red: red}
  end

  defp health(repo, extra \\ %{}),
    do:
      Map.merge(
        %{repo: repo, green_ref: "dod-green", red_ref: "dod-red", max_age_seconds: @max_age},
        extra
      )

  defp suite(script, health \\ nil, extra \\ %{}) do
    base = %{
      env: @env,
      steps: [%{id: "dod", argv: ["/bin/sh", "-c", script], timeout_ms: 20_000}]
    }

    base = if health, do: Map.put(base, :health, health), else: base
    Map.merge(base, extra)
  end

  defp register(suites), do: Application.put_env(:xaas, :ultracode_verifier_suites, suites)

  defp suite_struct(name), do: elem(Verifier.suite(name), 1)

  defp history_lines(store) do
    case File.read(Path.join(store, "history.ndjson")) do
      {:ok, text} -> text |> String.split("\n", trim: true) |> length()
      {:error, _} -> 0
    end
  end

  describe "the court" do
    test "a strong suite passes green, fails red, and is healthy with a sealed receipt", %{
      repo: repo,
      store: store,
      green: green,
      red: red
    } do
      register(%{"strong" => suite(@strong, health(repo))})

      assert {:ok, receipt} = SuiteHealth.check("strong")

      assert receipt["verdict"] == "healthy"
      assert receipt["healthy"] == true
      assert %{"status" => "pass", "sha" => ^green, "ref" => "dod-green"} = receipt["green"]
      assert %{"status" => "fail", "sha" => ^red, "ref" => "dod-red"} = receipt["red"]
      assert [%{"id" => "dod", "status" => "fail", "exit" => 1}] = receipt["red"]["steps"]
      assert "sha256:" <> _ = receipt["receipt_digest"]

      assert {:ok, ^receipt} = SuiteHealth.latest("strong")
      assert SuiteHealth.status("strong", suite_struct("strong")) == :healthy
      assert Verifier.admission("strong") == :ok
      assert history_lines(store) == 1

      # a healthy suite still runs normally
      assert {:ok, %{"status" => "pass"}} = run_on_green("strong", repo, root_of_test())
    end

    test "a VACUOUS suite (exit 0) passes the known-red fixture: verdict vacuous, quarantined", %{
      repo: repo
    } do
      register(%{"vacuous" => suite("exit 0", health(repo))})

      assert {:ok, receipt} = SuiteHealth.check("vacuous")
      assert receipt["verdict"] == "vacuous"
      assert receipt["red"]["status"] == "pass"
      assert receipt["reason"] =~ "known-red"

      assert SuiteHealth.status("vacuous", suite_struct("vacuous")) ==
               {:quarantined, {:unhealthy, "vacuous"}}

      assert {:quarantined, {:unhealthy, "vacuous"}} = Verifier.admission("vacuous")
    end

    test "a quarantined suite is REFUSED by Verifier.run before any step runs", %{
      repo: repo,
      root: root
    } do
      marker = Path.join(root, "step-ran")
      register(%{"vacuous" => suite("touch #{marker}; exit 0", health(repo))})
      assert {:ok, %{"verdict" => "vacuous"}} = SuiteHealth.check("vacuous")

      # the court itself ran the suite (that is how it measured it) ...
      assert File.exists?(marker)
      File.rm!(marker)

      {wt, head} = fresh_worktree(repo, root)

      assert {:ok, result} =
               Verifier.run("vacuous", %{
                 worktree: wt,
                 head: head,
                 run_id: Ecto.UUID.generate(),
                 epoch_id: Ecto.UUID.generate()
               })

      # ... but a normal run is refused typed, and its steps never execute
      assert result["status"] == "error"
      assert result["refusal"] == "suite_unhealthy"
      assert result["reason"] =~ "suite_unhealthy"
      refute File.exists?(marker)
    end

    test "drift (suite fails the known-green fixture) quarantines; fixing the suite releases it with no human",
         %{repo: repo} do
      # environment/toolchain drift stand-in: the suite now expects the wrong answer
      register(%{"drifty" => suite(~s|test "$(cat answer.txt)" = 43|, health(repo))})

      assert {:ok, receipt} = SuiteHealth.check("drifty")
      assert receipt["verdict"] == "green_failed"
      assert receipt["green"]["status"] == "fail"
      assert {:quarantined, {:unhealthy, "green_failed"}} = Verifier.admission("drifty")

      # the operator (or a generator) fixes the suite definition; nobody clears anything
      register(%{"drifty" => suite(@strong, health(repo))})
      assert {:quarantined, :suite_changed_since_check} = Verifier.admission("drifty")

      assert [%{suite: "drifty", action: :checked, verdict: "healthy", status: :healthy}] =
               SuiteHealth.sweep(suites: ["drifty"])

      assert Verifier.admission("drifty") == :ok
    end

    test "editing a healthy suite invalidates its receipt (binding digest)", %{repo: repo} do
      register(%{"s" => suite(@strong, health(repo))})
      assert {:ok, %{"verdict" => "healthy"}} = SuiteHealth.check("s")
      assert Verifier.admission("s") == :ok

      register(%{"s" => suite("#{@strong} || true", health(repo))})
      assert {:quarantined, :suite_changed_since_check} = Verifier.admission("s")

      register(%{"s" => suite(@strong, health(repo, %{max_age_seconds: @max_age + 1}))})
      assert {:quarantined, :suite_changed_since_check} = Verifier.admission("s")
    end

    test "staleness: healthy inside max_age, quarantined past it, refreshed by sweep before it lapses",
         %{repo: repo, store: store} do
      register(%{"s" => suite(@strong, health(repo))})
      t0 = System.os_time(:second)
      assert {:ok, %{"verdict" => "healthy"}} = SuiteHealth.check("s", now: t0)
      s = suite_struct("s")

      assert SuiteHealth.status("s", s, now: t0 + @max_age) == :healthy
      assert SuiteHealth.status("s", s, now: t0 + @max_age + 1) == {:quarantined, :stale}

      # fresh: not re-run
      assert [%{action: :fresh, status: :healthy}] =
               SuiteHealth.sweep(suites: ["s"], now: t0 + 10)

      assert history_lines(store) == 1

      # past half-life but still healthy: refreshed BEFORE it lapses
      assert [%{action: :checked, verdict: "healthy"}] =
               SuiteHealth.sweep(suites: ["s"], now: t0 + div(@max_age, 2) + 1)

      assert history_lines(store) == 2

      # already stale: re-checked and released
      assert [%{action: :checked, status: :healthy}] =
               SuiteHealth.sweep(suites: ["s"], now: t0 + 5 * @max_age)
    end

    test "a receipt from the future is refused", %{repo: repo} do
      register(%{"s" => suite(@strong, health(repo))})
      assert {:ok, _} = SuiteHealth.check("s", now: System.os_time(:second) + 100_000)
      assert {:quarantined, :receipt_from_future} = Verifier.admission("s")
    end

    test "a tampered receipt (verdict flipped, digest kept) is refused", %{
      repo: repo,
      store: store
    } do
      register(%{"vacuous" => suite("exit 0", health(repo))})
      assert {:ok, _} = SuiteHealth.check("vacuous")

      file = Path.join(store, "vacuous.json")

      forged =
        file
        |> File.read!()
        |> Jason.decode!()
        |> Map.merge(%{"verdict" => "healthy", "healthy" => true})

      File.write!(file, Jason.encode!(forged))

      assert {:error, :receipt_digest_mismatch} = SuiteHealth.latest("vacuous")
      assert {:quarantined, :receipt_digest_mismatch} = Verifier.admission("vacuous")

      File.write!(file, "not json")
      assert {:quarantined, :receipt_unreadable} = Verifier.admission("vacuous")
    end

    test "never-checked, unconfigured store and unmanaged suites", %{repo: repo} do
      register(%{"managed" => suite(@strong, health(repo)), "plain" => suite(@strong)})

      assert {:quarantined, :never_checked} = Verifier.admission("managed")
      assert SuiteHealth.status("plain", suite_struct("plain")) == :unmanaged
      assert Verifier.admission("plain") == :ok
      assert [%{action: :unmanaged, status: :unmanaged}] = SuiteHealth.sweep(suites: ["plain"])
      assert {:error, :unmanaged} = SuiteHealth.check("plain")
      assert {:error, :unknown_suite} = SuiteHealth.check("nope")

      Application.delete_env(:xaas, :ultracode_suite_health_dir)
      assert {:quarantined, :health_store_unconfigured} = Verifier.admission("managed")
      assert Verifier.admission("plain") == :ok
    end

    test "the red fixture may be a mutation of the green ref (no maintained red branch)", %{
      repo: repo
    } do
      mutation = %{kind: "replace", file: "answer.txt", pattern: "42", replacement: "41"}

      register(%{
        "strong" => suite(@strong, %{repo: repo, green_ref: "dod-green", red_mutation: mutation}),
        "vacuous" =>
          suite("exit 0", %{repo: repo, green_ref: "dod-green", red_mutation: mutation})
      })

      assert {:ok,
              %{
                "verdict" => "healthy",
                "red" => %{"ref" => "green+health-red", "status" => "fail"}
              }} =
               SuiteHealth.check("strong")

      assert {:ok, %{"verdict" => "vacuous"}} = SuiteHealth.check("vacuous")
    end

    test "a court that cannot run records a blocked, quarantining receipt (never a silent pass)",
         %{repo: repo} do
      register(%{
        "bad-ref" => suite(@strong, health(repo, %{green_ref: "no-such-ref"})),
        "no-repo" => suite(@strong, %{green_ref: "dod-green", red_ref: "dod-red"})
      })

      assert {:ok, %{"verdict" => "blocked", "reason" => reason}} = SuiteHealth.check("bad-ref")
      assert reason =~ "ref_unresolvable"
      assert {:quarantined, {:unhealthy, "blocked"}} = Verifier.admission("bad-ref")

      assert {:ok, %{"verdict" => "blocked", "reason" => reason}} = SuiteHealth.check("no-repo")
      assert reason =~ "health_repo_unresolved"

      Application.delete_env(:xaas, :ultracode_worktree_root)
      assert {:ok, %{"verdict" => "blocked", "reason" => reason}} = SuiteHealth.check("bad-ref")
      assert reason =~ "worktree_root_unconfigured"
    end

    test "the repo defaults to the registered repo that names the suite", %{repo: repo} do
      Application.put_env(
        :xaas,
        :ultracode_repos_file,
        Path.join(Fx.tmp("reposfile"), "none.json")
      )

      Application.put_env(:xaas, :ultracode_repos, %{
        "hc" => %{
          "path" => repo,
          "sensing" => "aps",
          "suite" => "registered-strong",
          "canonical_suite" => nil
        }
      })

      register(%{
        "registered-strong" => suite(@strong, %{green_ref: "dod-green", red_ref: "dod-red"})
      })

      assert {:ok, %{"verdict" => "healthy"}} = SuiteHealth.check("registered-strong")
    end
  end

  describe "registration gate (TargetSuites.validate/1)" do
    test "DoD-trust declarations are validated; the shipped suites are still valid", %{repo: repo} do
      assert TargetSuites.validate(TargetSuites.devs()) == :ok

      ok = %{
        "ok" =>
          suite(@strong, health(repo), %{
            require_probes: true,
            probes: [
              %{id: "p", kind: "replace", file: "answer.txt", pattern: "42", replacement: "41"}
            ]
          })
      }

      assert TargetSuites.validate(ok) == :ok

      refused = fn extra_suite ->
        assert {:error, problems} = TargetSuites.validate(%{"bad" => extra_suite})
        Enum.join(problems, " | ")
      end

      assert refused.(suite(@strong, nil, %{probes: [%{id: "p", kind: "rm_rf"}]})) =~
               "unknown_kind"

      assert refused.(suite(@strong, nil, %{probes: :nope})) =~ "probes_must_be_a_list"

      assert refused.(suite(@strong, nil, %{require_probes: "yes"})) =~
               "require_probes must be a boolean"

      assert refused.(suite(@strong, %{green_ref: "g"})) =~
               "exactly one of red_ref or red_mutation"

      assert refused.(suite(@strong, %{green_ref: "g", red_ref: "r", red_mutation: %{}})) =~
               "exactly one"

      assert refused.(suite(@strong, %{red_ref: "r"})) =~ "green_ref is required"

      assert refused.(suite(@strong, %{green_ref: "--upload-pack=x", red_ref: "r"})) =~
               "not a safe ref"

      assert refused.(suite(@strong, %{green_ref: "g", red_ref: "r", max_age_seconds: 0})) =~
               "max_age_seconds"

      assert refused.(suite(@strong, %{green_ref: "g", red_ref: "r", repo: "relative/path"})) =~
               "absolute path"

      assert refused.(suite(@strong, %{green_ref: "g", red_mutation: %{kind: "nope"}})) =~
               "unknown_kind"
    end
  end

  describe "Autonomic.suite_health_gate/1 (the periodic half: every wave sweeps first)" do
    defp gate_ctx(suites) do
      ledger = Path.join(Fx.tmp("ledger"), "ledger.ndjson")

      repos =
        suites
        |> Enum.with_index()
        |> Map.new(fn {name, i} -> {"r#{i}", %{suite: name, canonical_suite: nil}} end)

      %{repos: repos, ledger: ledger}
    end

    defp ledger_events(ctx),
      do:
        ctx.ledger |> File.read!() |> String.split("\n", trim: true) |> Enum.map(&Jason.decode!/1)

    test "a never-checked but healthy suite is checked by the gate and the wave proceeds", %{
      repo: repo
    } do
      register(%{"strong" => suite(@strong, health(repo)), "plain" => suite(@strong)})
      ctx = gate_ctx(["strong", "plain"])

      assert Verifier.admission("strong") == {:quarantined, :never_checked}
      assert :ok = Autonomic.suite_health_gate(ctx)
      assert Verifier.admission("strong") == :ok

      assert [
               %{
                 "event" => "suite_health",
                 "data" => %{"suite" => "strong", "verdict" => "healthy"}
               }
             ] =
               ledger_events(ctx)
    end

    test "a vacuous suite stops the wave with a typed refusal and a ledger line", %{repo: repo} do
      register(%{"vacuous" => suite("exit 0", health(repo))})
      ctx = gate_ctx(["vacuous"])

      assert {:error, {:suite_unhealthy, [{"vacuous", {:unhealthy, "vacuous"}}]}} =
               Autonomic.suite_health_gate(ctx)

      events = ledger_events(ctx)
      assert Enum.any?(events, &(&1["event"] == "suite_quarantined"))
    end
  end

  describe "mix xaas.ultracode.suite_health" do
    test "reports, exits non-zero on quarantine, and heals on re-run", %{repo: repo} do
      register(%{
        "vacuous" => suite("exit 0", health(repo)),
        "strong" => suite(@strong, health(repo)),
        "plain" => suite(@strong)
      })

      out =
        capture_io(fn ->
          assert_raise Mix.Error, ~r/quarantined suites: vacuous/, fn -> HealthTask.run([]) end
        end)

      assert out =~ "strong  [healthy]  action=checked  verdict=healthy"
      assert out =~ "vacuous  [quarantined:{:unhealthy, \"vacuous\"}]"
      assert out =~ "plain  [unmanaged]  action=unmanaged"

      # read-only status run executes nothing and reports the recorded standing
      status =
        capture_io(fn ->
          assert_raise Mix.Error, fn -> HealthTask.run(["--status", "--suite", "vacuous"]) end
        end)

      assert status =~ "action=status"

      json = capture_io(fn -> HealthTask.run(["--suite", "strong", "--json"]) end)

      assert %{"suite" => "strong", "status" => "healthy", "action" => "fresh"} =
               Jason.decode!(String.trim(json))

      # `--strict` also fails on unmanaged suites
      capture_io(fn ->
        assert_raise Mix.Error, ~r/unmanaged suites/, fn ->
          HealthTask.run(["--strict", "--suite", "plain"])
        end
      end)

      # the vacuous suite is fixed; the next run releases it
      register(%{"vacuous" => suite(@strong, health(repo))})
      capture_io(fn -> HealthTask.run(["--suite", "vacuous"]) end)
      assert Verifier.admission("vacuous") == :ok
    end
  end

  # -- helpers over real repos ------------------------------------------------

  defp root_of_test, do: Application.get_env(:xaas, :ultracode_worktree_root)

  defp fresh_worktree(repo, root) do
    head = Fx.head(repo)
    {Fx.linked_worktree(repo, root, head), head}
  end

  defp run_on_green(name, repo, root) do
    {wt, head} = fresh_worktree(repo, root)

    Verifier.run(name, %{
      worktree: wt,
      head: head,
      run_id: Ecto.UUID.generate(),
      epoch_id: Ecto.UUID.generate()
    })
  end
end
