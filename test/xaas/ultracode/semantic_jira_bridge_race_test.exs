defmodule Xaas.Ultracode.SemanticJiraBridgeRaceTest do
  @moduledoc """
  Six real OS processes race DIFFERENT sealed receipts for ONE work order at one
  barrier, against one transition-log directory. `:global.trans/4` cannot order
  them (it is per node); `Xaas.Ultracode.LogLock` (an flock) does.

  Contract: exactly one process appends; the other five are refused with
  `{:not_on_frontier, "standing=ALIVE"}`; the log holds one event and verifies.
  Before the fix the log answered the losers `:already_recorded` with the winner's
  event although their receipts were recorded nowhere; and once the event digest
  committed to the receipt, unserialized losers would each have appended a second
  UNKNOWN -> ALIVE transition.

  Tagged `:subprocess` (each racer is a fresh `elixir` OS process): run with
  `mix test --include subprocess`.
  """

  use ExUnit.Case, async: false

  # Needs ggen_igniter >= 26.9.20 (SemanticJira Shacl/TransitionLog.event_digest/1).
  @moduletag :requires_semantic_jira_api

  @moduletag :subprocess

  alias GgenIgniter.SemanticJira.TransitionLog
  alias Xaas.Ultracode.SemanticJiraBridge, as: Bridge
  alias Xaas.Ultracode.SemanticJiraBridgeFixtures, as: F

  @racers 6

  @script ~S"""
  graph = System.fetch_env!("SJB_GRAPH") |> File.read!() |> Jason.decode!()
  export = System.fetch_env!("SJB_EXPORT") |> File.read!() |> Jason.decode!()
  File.write!(System.fetch_env!("SJB_READY"), "ready")
  barrier = System.fetch_env!("SJB_BARRIER")

  wait = fn wait ->
    if File.exists?(barrier) do
      :ok
    else
      Process.sleep(2)
      wait.(wait)
    end
  end

  wait.(wait)

  tag =
    case Xaas.Ultracode.SemanticJiraBridge.admit(
           graph,
           "FIX-BROKEN",
           export,
           System.fetch_env!("SJB_LOG"),
           fabric_check: false
         ) do
      {:ok, %{disposition: disposition}} -> "ok:#{disposition}"
      {:error, {:refused_bridge, {reason, detail}}} -> "refused:#{reason}:#{inspect(detail)}"
      {:error, {:refused_bridge, reason}} -> "refused:#{inspect(reason)}"
      other -> "other:#{inspect(other)}"
    end

  IO.puts("SJB_RESULT:" <> tag)
  """

  test "six OS processes racing distinct receipts append exactly one transition" do
    base = F.tmp_dir("race")
    on_exit(fn -> File.rm_rf(base) end)
    log = Path.join(base, "log")

    root = F.work_order("FIX-BROKEN", F.sha("race-base"))
    dependent = F.work_order("VERIFY-CLEAN", F.sha("race-base"), ["FIX-BROKEN"])
    graph = [root, dependent]
    graph_path = Path.join(base, "graph.json")
    File.write!(graph_path, Jason.encode!(graph))

    {:ok, %{execution: execution}} =
      Bridge.descriptor(graph, log, "FIX-BROKEN",
        execution_repo_alias: "demo",
        verifier_suite: "bridge-suite",
        graph_digest: F.graph_digest(),
        court_map: F.court_map("FIX-BROKEN", "check.sh::a", "check.sh::b")
      )

    exports =
      for i <- 1..@racers do
        export =
          F.export(root, execution["bridge"], head: F.sha("racer-#{i}"), epoch_id: "epoch-#{i}")

        path = Path.join(base, "export-#{i}.json")
        File.write!(path, Jason.encode!(export))
        {i, path}
      end

    barrier = Path.join(base, "barrier")

    code_paths =
      Mix.Project.build_path()
      |> Path.join("lib/*/ebin")
      |> Path.wildcard()
      |> Enum.flat_map(&["-pa", &1])

    tasks =
      for {i, export_path} <- exports do
        Task.async(fn ->
          System.cmd("elixir", code_paths ++ ["-e", @script],
            stderr_to_stdout: true,
            env: [
              {"SJB_GRAPH", graph_path},
              {"SJB_EXPORT", export_path},
              {"SJB_LOG", log},
              {"SJB_BARRIER", barrier},
              {"SJB_READY", Path.join(base, "ready-#{i}")}
            ]
          )
        end)
      end

    await_ready(base, @racers)
    File.write!(barrier, "go")

    results =
      tasks
      |> Task.await_many(300_000)
      |> Enum.map(fn {out, status} ->
        assert status == 0, "racer failed: #{out}"

        [line] = out |> String.split("\n") |> Enum.filter(&String.starts_with?(&1, "SJB_RESULT:"))
        String.replace_prefix(line, "SJB_RESULT:", "")
      end)

    assert Enum.count(results, &(&1 == "ok:appended")) == 1, inspect(results)

    losers = Enum.reject(results, &(&1 == "ok:appended"))
    assert length(losers) == @racers - 1
    assert Enum.all?(losers, &String.starts_with?(&1, "refused:not_on_frontier")), inspect(losers)

    assert [%{"identity" => "FIX-BROKEN", "to" => "ALIVE", "seq" => 1}] = TransitionLog.read(log)
    state = Bridge.state(graph, log)
    refute Map.has_key?(state, "log_untrusted")
    assert state["eligible"] == ["VERIFY-CLEAN"]
  end

  defp await_ready(base, count, tries \\ 6_000) do
    ready = base |> File.ls!() |> Enum.count(&String.starts_with?(&1, "ready-"))

    cond do
      ready >= count ->
        :ok

      tries == 0 ->
        flunk("only #{ready} of #{count} racers started")

      true ->
        Process.sleep(50)
        await_ready(base, count, tries - 1)
    end
  end
end
