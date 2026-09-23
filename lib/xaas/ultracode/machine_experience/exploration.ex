defmodule Xaas.Ultracode.MachineExperience.Exploration do
  @moduledoc """
  Bounded UNKNOWN exploration (PRD PR-016; ARD section 15 Episode 1; lane
  V23-M): the admission of one recorded exploration artifact and its budget.

  An UNKNOWN route may be resolved only through a recorded exploration
  artifact (`exploration.json`, schema
  `xaas/machine-experience-exploration/v1`). The artifact is a CANDIDATE
  (O, not O*): its producer -- for GC23-9 episode me-1 a one-time LLM
  exploration, named honestly in `producer` -- proposes capabilities, and
  nothing it says executes until the no-LLM drive runs a candidate and the
  independent court verifies it. This module never runs a model; it only
  admits or refuses the artifact and meters its budget.

  ## The budget (all five required)

    * `time_s` -- wall-clock ceiling of the whole exploration: the
      artifact's own proposal time (`finished_at - started_at`) plus every
      candidate drive;
    * `drive_runs` -- the compute budget: how many candidate drives may run;
    * `candidates` -- how many proposed candidates may be tried (the rest
      are recorded as truncated, never tried);
    * `consequence_ceiling` -- the highest authority ceiling a candidate or
      the order may carry (`OBSERVE < SELECT < CONSTRUCT < DO`);
    * `evidence_requirement` -- the evidence a candidate's drive must show
      to count as resolved, a non-empty subset of `evidence_kinds/0`.

  Budget exhaustion (no candidate resolved within `drive_runs`, `time_s`,
  `candidates`) is the receipted terminal outcome `UNKNOWN`
  (`exploration_budget_exhausted`), never success and never failure.
  """

  @schema "xaas/machine-experience-exploration/v1"
  @ceilings ~w(OBSERVE SELECT CONSTRUCT DO)
  @evidence_kinds ~w(drive_alive independent_pass revert_killed r_alive)
  @capability ~r/\A[a-z0-9][a-z0-9_.-]*:[a-z0-9][a-z0-9_.:-]*\z/

  @doc "The exploration artifact schema id."
  @spec schema() :: String.t()
  def schema, do: @schema

  @doc "The evidence kinds a budget may require."
  @spec evidence_kinds() :: [String.t()]
  def evidence_kinds, do: @evidence_kinds

  @doc """
  Admits `exploration` (the decoded artifact) for the order `row`, whose
  artifact bytes digest to `digest`. `{:ok, plan}` -- `"producer"`,
  `"producer_class"`, `"budget"`, `"proposal_elapsed_s"`, `"candidates"`
  (the admissible candidates within the candidate budget, in artifact
  order), `"rejected"` (candidate + reason), `"truncated"` (beyond the
  budget), `"digest"` -- or `{:refused, typed}` (`exploration_inadmissible`,
  broken term `mu_on_O`) naming the first failed condition.
  """
  @spec admit(map(), map(), String.t()) :: {:ok, map()} | {:refused, map()}
  def admit(exploration, row, digest) when is_map(exploration) do
    budget = exploration["budget"] || %{}

    with :ok <- check(exploration["schema"] == @schema, "schema", exploration["schema"]),
         :ok <- check(exploration["order"] == row["identity"], "order", exploration["order"]),
         :ok <-
           check(
             exploration["problem_class"] == row["failure_class"],
             "problem_class",
             exploration["problem_class"]
           ),
         :ok <- check(nonblank?(exploration["producer"]), "producer", exploration["producer"]),
         :ok <- budget(budget),
         {:ok, elapsed} <- elapsed(exploration),
         :ok <- check(elapsed <= budget["time_s"], "time_s_exceeded_by_proposal", elapsed),
         :ok <-
           check(
             rank(row["authority_ceiling"]) <= rank(budget["consequence_ceiling"]),
             "order_exceeds_consequence_ceiling",
             row["authority_ceiling"]
           ),
         candidates when is_list(candidates) and candidates != [] <- exploration["candidates"] do
      {tried, truncated} = Enum.split(candidates, budget["candidates"])

      {admissible, rejected} =
        Enum.reduce(tried, {[], []}, fn candidate, {ok, bad} ->
          case candidate_reason(candidate, budget) do
            nil -> {ok ++ [candidate], bad}
            reason -> {ok, bad ++ [%{"candidate" => candidate, "reason" => reason}]}
          end
        end)

      {:ok,
       %{
         "producer" => exploration["producer"],
         "producer_class" => exploration["producer_class"] || "unknown",
         "budget" => budget,
         "proposal_elapsed_s" => elapsed,
         "candidates" => admissible,
         "rejected" => rejected,
         "truncated" => truncated,
         "digest" => digest
       }}
    else
      {:refused, typed} -> {:refused, typed}
      _no_candidates -> inadmissible("candidates", exploration["candidates"])
    end
  end

  def admit(other, _row, _digest), do: inadmissible("not_an_object", inspect(other))

  @doc """
  The next budget verdict before a candidate drive: `:ok` when another
  drive fits (`used["drive_runs"] < drive_runs` and `used["elapsed_s"] <
  time_s`), else `{:exhausted, which}`.
  """
  @spec next(map(), map()) :: :ok | {:exhausted, String.t()}
  def next(%{"budget" => budget}, used) do
    cond do
      used["drive_runs"] >= budget["drive_runs"] -> {:exhausted, "drive_runs"}
      used["elapsed_s"] >= budget["time_s"] -> {:exhausted, "time_s"}
      true -> :ok
    end
  end

  @doc """
  The evidence kinds a finished drive showed: `drive_alive` (standing
  ALIVE), `independent_pass`, `revert_killed` (from its
  `verification.json`), `r_alive` (its R projection standing).
  """
  @spec evidence(map()) :: [String.t()]
  def evidence(%{"drive" => drive, "verification" => verification, "r" => r}) do
    [
      {"drive_alive", drive["standing"] == "ALIVE"},
      {"independent_pass", get_in(verification, ["independent", "status"]) == "pass"},
      {"revert_killed", get_in(verification, ["revert_falsifier", "verdict"]) == "killed"},
      {"r_alive", get_in(r, ["standing", "value"]) == "ALIVE"}
    ]
    |> Enum.filter(&elem(&1, 1))
    |> Enum.map(&elem(&1, 0))
  end

  def evidence(_other), do: []

  @doc "True iff `shown` evidence covers the budget's `evidence_requirement`."
  @spec resolved?(map(), [String.t()]) :: boolean()
  def resolved?(%{"budget" => %{"evidence_requirement" => required}}, shown),
    do: Enum.all?(required, &(&1 in shown))

  @doc """
  The receipted terminal UNKNOWN of an exhausted exploration: standing
  `"UNKNOWN"`, reason `exploration_budget_exhausted`, the exhausted budget
  dimension, the budget, what was used and every attempt.
  """
  @spec exhausted(map(), String.t(), map(), [map()]) :: map()
  def exhausted(plan, which, used, attempts) do
    %{
      "standing" => "UNKNOWN",
      "reason" => "exploration_budget_exhausted",
      "hop" => "explore",
      "detail" => %{
        "exhausted" => which,
        "budget" => plan["budget"],
        "used" => used,
        "attempts" => attempts,
        "rejected" => plan["rejected"],
        "truncated" => plan["truncated"],
        "exploration_digest" => plan["digest"],
        "producer" => plan["producer"]
      }
    }
  end

  # -- checks ---------------------------------------------------------------------

  defp budget(budget) do
    required = budget["evidence_requirement"]

    cond do
      not positive?(budget["time_s"]) ->
        inadmissible("budget.time_s", budget["time_s"])

      not positive?(budget["drive_runs"]) ->
        inadmissible("budget.drive_runs", budget["drive_runs"])

      not positive?(budget["candidates"]) ->
        inadmissible("budget.candidates", budget["candidates"])

      budget["consequence_ceiling"] not in @ceilings ->
        inadmissible("budget.consequence_ceiling", budget["consequence_ceiling"])

      not (is_list(required) and required != [] and Enum.all?(required, &(&1 in @evidence_kinds))) ->
        inadmissible("budget.evidence_requirement", required)

      true ->
        :ok
    end
  end

  defp elapsed(exploration) do
    with {:ok, started, 0} <- DateTime.from_iso8601(exploration["started_at"] || ""),
         {:ok, finished, 0} <- DateTime.from_iso8601(exploration["finished_at"] || ""),
         seconds when seconds >= 0 <- DateTime.diff(finished, started) do
      {:ok, seconds}
    else
      _ ->
        inadmissible("started_at/finished_at", Map.take(exploration, ~w(started_at finished_at)))
    end
  end

  defp candidate_reason(%{"capability" => capability} = candidate, budget)
       when is_binary(capability) do
    cond do
      not Regex.match?(@capability, capability) ->
        "capability_not_canonical"

      candidate["authority_ceiling"] not in @ceilings ->
        "candidate_ceiling_undeclared"

      rank(candidate["authority_ceiling"]) > rank(budget["consequence_ceiling"]) ->
        "candidate_exceeds_consequence_ceiling"

      true ->
        nil
    end
  end

  defp candidate_reason(_candidate, _budget), do: "candidate_without_capability"

  defp rank(ceiling), do: Enum.find_index(@ceilings, &(&1 == ceiling)) || length(@ceilings)

  defp positive?(value), do: is_integer(value) and value > 0

  defp nonblank?(value), do: is_binary(value) and String.trim(value) != ""

  defp check(true, _field, _value), do: :ok
  defp check(false, field, value), do: inadmissible(field, value)

  defp inadmissible(field, value) do
    {:refused,
     %{
       "standing" => "REFUSED(exploration_inadmissible)",
       "reason" => "exploration_inadmissible",
       "broken_term" => "mu_on_O",
       "hop" => "explore",
       "detail" => %{"field" => field, "value" => value}
     }}
  end
end
