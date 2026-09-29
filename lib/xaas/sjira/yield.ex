defmodule Xaas.Sjira.Yield do
  @lifecycle ~w(agent_started agent_completed)
  @failure_standings ~w(BLOCKED BUILD_BROKEN REFUSED REFUTED UNSUPPORTED UNKNOWN)
  @failure_verdicts ~w(fail failed refuted refused reject rejected)
  @prior 2

  @moduledoc """
  C02 "factory that learns its own yield" (+ the C10 retirement-curve metric),
  work order XAAS-26922-21.

  Mines outcome rates per `(class, repo, stage)` from an OCEL 2.0 JSON log of
  the manufacturing process itself (`~/.claude/dfcm/ocel_from_workflows.py`
  projects Claude Code Workflow journals into that shape) and turns them into
  the `historical_yield` term of SA2A planner candidates. This replaces the
  literal standing->weight table the v26.9.21 driver
  (`docs/sjira/v26.9.21/sa2a_loop.exs`) carried; the v26.9.22 driver
  (`docs/sjira/v26.9.22/sa2a_loop.exs`) reads yields from here.

  Pure fold over a file: no Repo, no Ash, no network.

  ## Outcome events

  Every `agent_completed` event is one observed outcome, keyed by

    * `class` - the order class of the linked `work_order` object when a class
      map (`order-classes.json`: class => [order ids]) names it, else the
      agent's role (the label prefix: survey, sync, baseline, build, court, ...);
    * `repo`  - the linked `repo` object id without its `repo:` prefix;
    * `stage` - the linked `phase` object id without its `phase:` prefix.

  An outcome is a success iff the agent returned a result (`completed` is
  `"True"`), its reported standing token (the leading `[A-Z_]+` of the
  `standing` attribute, when present) is not one of
  #{Enum.join(@failure_standings, ", ")}, and its `verdict` (when present) is
  not one of #{Enum.join(@failure_verdicts, ", ")}. An agent without a
  result counts as a non-success: UNKNOWN is not ADMITTED.

  ## Estimator

  Hierarchical Beta-Binomial shrinkage with prior strength #{@prior} at each level:

      p_global          = (S + 1) / (N + 2)
      p(stage)          = (S_s   + 2 * p_global)        / (N_s   + 2)
      p(class, stage)   = (S_cs  + 2 * p(stage))        / (N_cs  + 2)
      p(class, repo, s) = (S_crs + 2 * p(class, stage)) / (N_crs + 2)

  A key with no observations inherits its parent's mean; every observed
  outcome moves every estimate on its path, so flipping one outcome moves the
  plan.

  ## Machinery-vs-LLM hop share (C10)

  A hop is every non-lifecycle event (every event except `agent_started` /
  `agent_completed`, which bound an agent span rather than act). A hop is an
  LLM hop iff its `actor` object has type `agent` (an LLM subagent chose it);
  every other hop - emitted by a deterministic pack, rule or script, or with no
  agent actor - is a machinery hop. The share measures who decides each hop,
  not who executes it: an LLM-issued Bash call is an LLM hop. `by_run` gives
  the per-cycle curve C10's falsifier reads.

  ## Output

  `classes` is `%{"rows" => [per-(class, repo, stage) n/successes/yield],
  "by_class" => %{class => n/successes/yield}, "machinery_share" => share}`,
  or `%{}` when the log holds no outcome event; `machinery_share` is `nil` when
  it holds no hop (undefined, never a vacuous 0).
  """

  @type mined :: map()

  @doc "Reads and decodes an OCEL JSON file; returns the log and its sha256."
  @spec load!(Path.t()) :: {map(), String.t()}
  def load!(path) do
    bytes = File.read!(path)
    {Jason.decode!(bytes), Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)}
  end

  @doc """
  Reads an order-class map (`{"class": ["ORDER-ID", ...], ...}`) into
  `%{"ORDER-ID" => "class"}`.
  """
  @spec load_classes!(Path.t()) :: %{String.t() => String.t()}
  def load_classes!(path) do
    for {class, ids} <- path |> File.read!() |> Jason.decode!(),
        id <- ids,
        into: %{},
        do: {id, class}
  end

  @doc "`load!/1` + `mine/2`, recording the file path and digest as `source`."
  @spec mine_file!(Path.t(), keyword()) :: mined()
  def mine_file!(path, opts \\ []) do
    {ocel, sha} = load!(path)
    ocel |> mine(opts) |> Map.put("source", %{"path" => path, "sha256" => sha})
  end

  @doc """
  Mines per-(class, repo, stage) outcome rates and the machinery hop share.

  Options: `:classes` - `%{order_id => class}` (see `load_classes!/1`).
  """
  @spec mine(map(), keyword()) :: mined()
  def mine(%{"objects" => objects, "events" => events}, opts \\ []) do
    classes = Keyword.get(opts, :classes, %{})
    types = Map.new(objects, &{&1["id"], &1["type"]})
    agent_run = Map.new(objects, &{&1["id"], first_rel(&1, "in_run")})
    outcomes = for %{"type" => "agent_completed"} = e <- events, do: outcome(e, classes)

    {s, n} = count(outcomes)
    p_global = (s + 1) / (n + 2)

    counts =
      outcomes
      |> Enum.group_by(&{&1.class, &1.repo, &1.stage})
      |> Enum.map(fn {{c, r, st}, os} ->
        {sk, nk} = count(os)
        %{"class" => c, "repo" => r, "stage" => st, "n" => nk, "successes" => sk}
      end)
      |> Enum.sort_by(&{&1["class"], &1["repo"], &1["stage"]})

    rows =
      Enum.map(
        counts,
        &Map.put(&1, "yield", posterior(counts, p_global, &1["class"], &1["repo"], &1["stage"]))
      )

    hops = for e <- events, e["type"] not in @lifecycle, do: hop(e, types, agent_run)

    by_class =
      outcomes
      |> Enum.group_by(& &1.class)
      |> Map.new(fn {c, os} ->
        {sc, nc} = count(os)
        {c, %{"n" => nc, "successes" => sc, "yield" => (sc + @prior * p_global) / (nc + @prior)}}
      end)

    %{
      "schema" => "xaas.sjira.yield/v1",
      "success_rule" =>
        "completed=True and standing token not in #{Enum.join(@failure_standings, "|")} " <>
          "and verdict not in #{Enum.join(@failure_verdicts, "|")}",
      "estimator" =>
        "hierarchical Beta-Binomial, prior strength #{@prior}: global -> stage -> (class,stage) -> (class,repo,stage)",
      "classes_source" => Keyword.get(opts, :classes_source),
      "global" => %{"n" => n, "successes" => s, "yield" => p_global},
      "classes" => classes_section(rows, by_class, share(hops)),
      "hop_rule" =>
        "hop = event not in #{Enum.join(@lifecycle, "|")}; llm iff actor object type is agent; else machinery",
      "hops" => hop_summary(hops),
      "machinery_share" => share(hops),
      "by_run" =>
        hops
        |> Enum.group_by(& &1.run)
        |> Enum.map(fn {run, hs} ->
          Map.put(hop_summary(hs), "run", run) |> Map.put("machinery_share", share(hs))
        end)
        |> Enum.sort_by(& &1["run"])
    }
  end

  @doc """
  Mined yield for a `(class, repo, stage)` key: the posterior mean of the
  hierarchy in the moduledoc. An unobserved key gets its nearest observed
  ancestor's mean (`(class, stage)`, else `stage`, else global).
  """
  @spec yield_for(mined(), String.t(), String.t(), String.t()) :: float()
  def yield_for(mined, class, repo, stage) do
    posterior(
      get_in(mined, ["classes", "rows"]) || [],
      mined["global"]["yield"],
      class,
      repo,
      stage
    )
  end

  @doc """
  Reads v26.9.22-style `orders.json` (`{repo_key: %{"orders" => [...]}}`) into
  flat order maps; `:repo` restricts to one repo key.
  """
  @spec orders_from_file!(Path.t(), keyword()) :: [map()]
  def orders_from_file!(path, opts \\ []) do
    only = Keyword.get(opts, :repo)

    for {repo, %{"orders" => orders}} <- path |> File.read!() |> Jason.decode!(),
        only == nil or repo == only,
        o <- orders do
      %{"id" => o["id"], "title" => o["title"], "repo" => repo, "deps" => o["deps"] || []}
    end
  end

  @doc """
  SA2A planner candidates for `orders`, with `historical_yield` taken from the
  mined log. An order's class is its own `"class"`, else `:classes`' entry, else
  `:role` (default `"build"`, the role that constructs an order); its stage is
  `:stage` (default `"Construct"`). Entropy/cost terms are the v26.9.21
  driver's (`1 + deps`, `5 + 3 * deps`).
  """
  @spec candidates(mined(), [map()], keyword()) :: [map()]
  def candidates(mined, orders, opts \\ []) do
    classes = Keyword.get(opts, :classes, %{})
    role = Keyword.get(opts, :role, "build")
    stage = Keyword.get(opts, :stage, "Construct")

    for o <- orders do
      class = o["class"] || Map.get(classes, o["id"], role)
      deps = length(o["deps"] || [])

      %{
        "item_id" => o["id"],
        "description" => o["title"] || o["id"],
        "option_entropy" => 1.0 + deps,
        "estimated_cost" => 5.0 + 3.0 * deps,
        "historical_yield" => yield_for(mined, class, o["repo"], stage),
        "yield_basis" => %{"class" => class, "repo" => o["repo"], "stage" => stage}
      }
    end
  end

  @doc """
  Orders candidates by the SA2A allocator's salience
  `option_entropy * historical_yield / max(estimated_cost, 1e-6)`, descending,
  ties by `item_id`, attaching `"salience"`.
  """
  @spec rank([map()]) :: [map()]
  def rank(cands) do
    cands
    |> Enum.map(fn c ->
      s =
        max(c["option_entropy"], 0.0) * max(c["historical_yield"], 0.0) /
          max(c["estimated_cost"], 1.0e-6)

      Map.put(c, "salience", s)
    end)
    |> Enum.sort_by(&{-&1["salience"], &1["item_id"]})
  end

  # The class dimension of the mining. Empty (%{}) when the log has no outcome
  # event, so `.classes|length>0` refuses an outcome-free log. `machinery_share` is
  # repeated here (same value as the top level) because the order's acceptance
  # `jq -e '.classes|length>0 and .machinery_share!=null'` binds as
  # `.classes | (length>0 and .machinery_share!=null)`; both readings then see it,
  # and both refuse a log with no hops (share nil).
  defp classes_section([], _by_class, _share), do: %{}

  defp classes_section(rows, by_class, share),
    do: %{"rows" => rows, "by_class" => by_class, "machinery_share" => share}

  # -- outcomes ----------------------------------------------------------

  defp outcome(e, classes) do
    attrs = Map.new(e["attributes"] || [], &{&1["name"], &1["value"]})
    wo = e |> first_rel("work_order") |> strip("wo:")

    %{
      class: Map.get(classes, wo) || attrs["role"] || "none",
      repo: e |> first_rel("repo") |> strip("repo:") || "none",
      stage: e |> first_rel("phase") |> strip("phase:") || "none",
      success: success?(attrs)
    }
  end

  defp success?(attrs) do
    attrs["completed"] == "True" and standing_token(attrs["standing"]) not in @failure_standings and
      verdict_token(attrs["verdict"]) not in @failure_verdicts
  end

  defp standing_token(nil), do: nil

  defp standing_token(s) do
    case Regex.run(~r/^\s*([A-Z_]+)/, s) do
      [_, t] -> t
      _ -> nil
    end
  end

  defp verdict_token(nil), do: nil

  defp verdict_token(v) do
    case Regex.run(~r/^\s*([A-Za-z_]+)/, v) do
      [_, t] -> String.downcase(t)
      _ -> nil
    end
  end

  defp count(os), do: {Enum.count(os, & &1.success), length(os)}

  # global -> stage -> (class, stage) -> (class, repo, stage); each level is a
  # Beta-Binomial posterior mean whose prior mean is its parent's
  defp posterior(rows, p_global, class, repo, stage) do
    p_s = shrink(rows, &(&1["stage"] == stage), p_global)
    p_cs = shrink(rows, &(&1["class"] == class and &1["stage"] == stage), p_s)
    shrink(rows, &(&1["class"] == class and &1["repo"] == repo and &1["stage"] == stage), p_cs)
  end

  defp shrink(rows, pred, prior_mean) do
    rs = Enum.filter(rows, pred)
    s = rs |> Enum.map(& &1["successes"]) |> Enum.sum()
    n = rs |> Enum.map(& &1["n"]) |> Enum.sum()
    (s + @prior * prior_mean) / (n + @prior)
  end

  # -- hops --------------------------------------------------------------

  defp hop(e, types, agent_run) do
    actor = first_rel(e, "actor")
    kind = if Map.get(types, actor) == "agent", do: :llm, else: :machinery
    tool = Enum.find_value(e["attributes"] || [], &(&1["name"] == "tool" && &1["value"]))

    %{
      kind: kind,
      actor_type: Map.get(types, actor, "none"),
      tool: tool,
      run: (first_rel(e, "in_run") || Map.get(agent_run, actor)) |> strip("run:") || "none"
    }
  end

  defp hop_summary(hops) do
    %{
      "total" => length(hops),
      "llm" => Enum.count(hops, &(&1.kind == :llm)),
      "machinery" => Enum.count(hops, &(&1.kind == :machinery)),
      "by_actor_type" => Enum.frequencies_by(hops, & &1.actor_type),
      "by_tool" => hops |> Enum.filter(& &1.tool) |> Enum.frequencies_by(& &1.tool)
    }
  end

  defp share([]), do: nil
  defp share(hops), do: Enum.count(hops, &(&1.kind == :machinery)) / length(hops)

  defp first_rel(%{"relationships" => rels}, q) when is_list(rels),
    do: Enum.find_value(rels, &(&1["qualifier"] == q && &1["objectId"]))

  defp first_rel(_, _), do: nil

  defp strip(nil, _), do: nil
  defp strip(id, prefix), do: String.replace_prefix(id, prefix, "")
end
