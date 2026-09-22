defmodule Xaas.Sjira.YieldTest do
  @moduledoc """
  XAAS-26922-21 (C02 + C10). Chicago-style: the fixture is a real subset of the
  v26.9.22 OCEL log (`/Users/sac/wt/v26922/ocel/v26922.ocel.json`, projected by
  `~/.claude/dfcm/ocel_from_workflows.py` from this release's Workflow
  journals; subset rule in `test/fixtures/sjira/ocel_subset.py`). Mutations are
  written to real files in a tmp dir and re-read through `mine_file!/2`; the
  planner case calls the real `autofde beam-bridge` SA2A allocator over a real
  Port when that binary exists, and is a named skip otherwise.

  async: false because `Xaas.Sa2a.Bridge` registers a global name.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Xaas.Sa2a.Bridge
  alias Xaas.Sjira.Yield

  @fixture Path.expand("../../fixtures/sjira/v26922.ocel.subset.json", __DIR__)
  @driver Path.expand("../../../docs/sjira/v26.9.22/sa2a_loop.exs", __DIR__)
  # the xaas build agent for XAAS-26922-21 in the fixture: no result -> non-success
  @xaas_build_end "ev:a7ffb08e1cac4a9bb:end"
  @autofde System.find_executable("autofde") ||
             (File.exists?(Path.expand("~/autofde-lab/.venv/bin/autofde")) &&
                Path.expand("~/autofde-lab/.venv/bin/autofde")) || nil

  # Five real v26.9.22 orders, one per fixture repo, equal deps so the ranking
  # is decided by mined yield alone.
  @orders [
    %{"id" => "AFDE-26922-01", "repo" => "autofde-lab", "deps" => []},
    %{"id" => "ASH_A2A-26922-14", "repo" => "ash_a2a", "deps" => []},
    %{"id" => "FERROPLAN-26922-09", "repo" => "ferroplan", "deps" => []},
    %{"id" => "GYMACT-26922-02", "repo" => "gymact", "deps" => []},
    %{"id" => "XAAS-26922-21", "repo" => "xaas", "deps" => []}
  ]

  setup do
    dir = Path.join(System.tmp_dir!(), "xaas-yield-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir, ocel: @fixture |> File.read!() |> Jason.decode!()}
  end

  defp write!(dir, name, ocel) do
    path = Path.join(dir, name)
    File.write!(path, Jason.encode!(ocel))
    path
  end

  defp flip_completed(ocel, event_id) do
    update_in(ocel["events"], fn events ->
      Enum.map(events, fn
        %{"id" => ^event_id} = e ->
          update_in(e["attributes"], fn attrs ->
            Enum.map(attrs, fn
              %{"name" => "completed", "value" => v} = a ->
                %{a | "value" => if(v == "True", do: "False", else: "True")}

              a ->
                a
            end)
          end)

        e ->
          e
      end)
    end)
  end

  defp row(mined, class, repo, stage),
    do:
      Enum.find(
        mined["classes"]["rows"],
        &(&1["class"] == class and &1["repo"] == repo and &1["stage"] == stage)
      )

  defp ranking(mined), do: mined |> Yield.candidates(@orders) |> Yield.rank()

  test "mines per-(class, repo, stage) outcome rates from the real fixture" do
    mined = Yield.mine_file!(@fixture)

    assert mined["source"]["sha256"] =~ ~r/^[0-9a-f]{64}$/
    assert length(mined["classes"]["rows"]) == 29
    assert map_size(mined["classes"]["by_class"]) == 7
    assert mined["global"] == %{"n" => 29, "successes" => 21, "yield" => 22 / 31}

    # standing "BLOCKED:DISK. ..." is a failure; "PARTIAL_ALIVE. ..." a success
    assert %{"n" => 1, "successes" => 0} = row(mined, "baseline", "autofde-lab", "Baseline")
    assert %{"n" => 1, "successes" => 1} = row(mined, "baseline", "ferroplan", "Baseline")
    # an agent with no result (completed=False) is not a success
    assert %{"n" => 1, "successes" => 0} = row(mined, "build", "xaas", "Construct")

    # every estimate is mined, and an unobserved key inherits its parent
    assert Yield.yield_for(mined, "build", "autofde-lab", "Construct") ==
             Yield.yield_for(mined, "build", "gymact", "Construct")

    assert Yield.yield_for(mined, "build", "xaas", "Construct") <
             Yield.yield_for(mined, "build", "autofde-lab", "Construct")
  end

  test "flipping one real outcome on disk changes the plan ranking", %{dir: dir, ocel: ocel} do
    before = @fixture |> Yield.mine_file!() |> ranking()

    flipped =
      dir
      |> write!("flipped.ocel.json", flip_completed(ocel, @xaas_build_end))
      |> Yield.mine_file!()

    after_flip = ranking(flipped)

    assert Enum.map(before, & &1["item_id"]) ==
             ~w(AFDE-26922-01 GYMACT-26922-02 ASH_A2A-26922-14 FERROPLAN-26922-09 XAAS-26922-21)

    assert Enum.map(after_flip, & &1["item_id"]) ==
             ~w(XAAS-26922-21 AFDE-26922-01 GYMACT-26922-02 ASH_A2A-26922-14 FERROPLAN-26922-09)

    # strict, not a tie-break: XAAS moves from strictly below to strictly above every other order
    [top | rest] = after_flip
    assert Enum.all?(rest, &(top["salience"] > &1["salience"]))
    assert List.last(before)["salience"] < hd(before)["salience"]
    assert row(flipped, "build", "xaas", "Construct")["successes"] == 1
  end

  @tag skip:
         if(@autofde, do: false, else: "autofde (SA2A beam-bridge) not installed on this host")
  test "the flipped outcome reaches the real SA2A allocator's lane order", %{dir: dir, ocel: ocel} do
    unless Process.whereis(Bridge), do: start_supervised!({Bridge, port_command: @autofde})

    plan = fn mined ->
      cands =
        mined
        |> ranking()
        |> Enum.map(
          &Map.take(&1, ~w(item_id description option_entropy estimated_cost historical_yield))
        )

      {:ok, %{"ok" => true} = resp} =
        Bridge.plan(cands, plan_id: "yield-test", ticks: 5000, tokens: 500_000, experiments: 20)

      Map.new(resp["allocations"], &{&1["item_id"], &1})
    end

    lane0 = fn allocs ->
      allocs |> Map.values() |> Enum.min_by(& &1["lane"]) |> Map.fetch!("item_id")
    end

    before = plan.(Yield.mine_file!(@fixture))

    after_flip =
      plan.(
        dir
        |> write!("flipped.ocel.json", flip_completed(ocel, @xaas_build_end))
        |> Yield.mine_file!()
      )

    # before: lane 0 is one of the two orders tied at the highest mined yield (the
    # allocator breaks that tie by its own item hash); after: the flipped order, strictly
    assert lane0.(before) in ~w(AFDE-26922-01 GYMACT-26922-02)
    assert lane0.(after_flip) == "XAAS-26922-21"
    assert after_flip["XAAS-26922-21"]["fraction"] > before["XAAS-26922-21"]["fraction"]
  end

  test "machinery-vs-LLM hop share is computed, and moves when a machinery hop appears", %{
    dir: dir,
    ocel: ocel
  } do
    mined = Yield.mine_file!(@fixture)
    assert mined["hops"]["total"] == 58
    assert mined["hops"]["llm"] == 58
    assert mined["machinery_share"] == 0.0

    assert Enum.map(mined["by_run"], & &1["run"]) ==
             ~w(wf_36b97888-44b wf_5c2db1e9-3e8 wf_9860a56f-96b)

    pack = %{"id" => "pack:observe", "type" => "pack", "attributes" => [], "relationships" => []}

    ev = %{
      "id" => "ev:pack:observe:1",
      "type" => "repo_observed",
      "time" => "2026-09-22T20:00:00Z",
      "attributes" => [],
      "relationships" => [
        %{"objectId" => "pack:observe", "qualifier" => "actor"},
        %{"objectId" => "run:wf_9860a56f-96b", "qualifier" => "in_run"}
      ]
    }

    grown = %{ocel | "objects" => [pack | ocel["objects"]], "events" => ocel["events"] ++ [ev]}
    grown_mined = dir |> write!("grown.ocel.json", grown) |> Yield.mine_file!()
    assert grown_mined["hops"]["machinery"] == 1
    assert grown_mined["machinery_share"] == 1 / 59

    assert Enum.find(grown_mined["by_run"], &(&1["run"] == "wf_9860a56f-96b"))["machinery_share"] >
             0.0

    # no hops at all -> the share is undefined (null), never a vacuous 0
    no_hops = %{
      ocel
      | "events" => Enum.filter(ocel["events"], &(&1["type"] == "agent_completed"))
    }

    assert (dir |> write!("no-hops.ocel.json", no_hops) |> Yield.mine_file!())["machinery_share"] ==
             nil
  end

  test "order classes key work-order-linked outcomes by class" do
    mined =
      Yield.mine(@fixture |> File.read!() |> Jason.decode!(),
        classes: %{"XAAS-26922-21" => "design/capability"}
      )

    assert %{"n" => 1} = row(mined, "design/capability", "xaas", "Construct")
    assert row(mined, "build", "xaas", "Construct") == nil
  end

  test "mix xaas.sjira.yield prints the mining and a ranking as JSON", %{dir: dir} do
    orders =
      write!(dir, "orders.json", %{
        "xaas" => %{"orders" => [%{"id" => "XAAS-26922-21", "title" => "t", "deps" => []}]}
      })

    out = capture_io(fn -> Mix.Tasks.Xaas.Sjira.Yield.run([@fixture, "--orders", orders]) end)
    json = Jason.decode!(out)

    assert length(json["classes"]["rows"]) > 0
    assert json["machinery_share"] == 0.0
    assert json["classes"]["machinery_share"] == json["machinery_share"]

    assert [%{"item_id" => "XAAS-26922-21", "yield_basis" => %{"repo" => "xaas"}}] =
             json["ranking"]
  end

  @jq System.find_executable("jq")
  @acceptance_jq ".classes|length>0 and .machinery_share!=null"

  @tag skip: if(@jq, do: false, else: "jq not installed on this host")
  test "the order's literal jq acceptance admits a mined log and refuses empty or hop-free ones",
       %{dir: dir, ocel: ocel} do
    jq = fn name, log ->
      out = capture_io(fn -> Mix.Tasks.Xaas.Sjira.Yield.run([write!(dir, name, log)]) end)
      json = Path.join(dir, name <> ".out.json")
      File.write!(json, out)
      {_, status} = System.cmd(@jq, ["-e", @acceptance_jq, json], stderr_to_stdout: true)
      status
    end

    assert jq.("fixture.ocel.json", ocel) == 0
    assert jq.("empty.ocel.json", %{ocel | "events" => []}) != 0

    no_hops = %{
      ocel
      | "events" => Enum.filter(ocel["events"], &(&1["type"] == "agent_completed"))
    }

    assert jq.("no-hops.ocel.json", no_hops) != 0
  end

  test "the v26.9.22 SA2A driver carries no literal historical_yield table" do
    src = File.read!(@driver)
    refute src =~ ~r/"UNSUPPORTED"\s*=>\s*0\.9/
    refute src =~ ~r/weight\s*=\s*%\{/
    assert src =~ "Yield.candidates"
  end
end
