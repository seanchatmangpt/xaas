defmodule Xaas.Ultracode.OcelConformance do
  @moduledoc """
  Batch OCEL 2.0 conformance court for a whole Ultracode campaign: the
  standing-capability form of the run-by-run validation path. The
  mandate is that EVERY capability be validated against OCEL 2.0 not as
  a one-off (`mix xaas.ultracode.export_ocel <run> && mix
  xaas.ultracode.ocel_validate <file>`) but as a property of the
  campaign: this module exports and adjudicates EVERY Run the campaign
  ledger names -- each `attempt_start` run, plus the campaign row
  itself -- through the exact production pair,
  `Xaas.Ultracode.OcelEgress.export_run/2` then
  `Xaas.Ultracode.Ocel.Validator.validate_file/1` (the same surfaces
  `mix xaas.ultracode.audit`'s (c) check and `Xaas.Ultracode.Learn`'s
  fail-closed gate use).

  Court discipline (inherited from the siblings, kept identical here):

    * A validator RED (`{:error, violations}`) is a JUDGED result: it
      lands in the report as a per-run `:violations` entry -- never as
      an exception, never silently.
    * An EXPORT failure (run missing, DB error) is NOT a verdict: it is
      a refusal to judge that fails the WHOLE call closed -- the same
      `{:error, {:run_export_failed, run_id, reason}}` shape `Learn`
      uses. A campaign judged "3/3 valid" while two runs could not be
      exported would be a fabricated ratio.
    * An unexpected validator report is fail-closed into one named
      violation, never a silent pass (audit's rule).
    * An absent or malformed ledger refuses the whole judgment
      (`Learn`'s rule -- the ledger is the enumeration source; without
      it the batch claim is vacuous, and a small "N/N valid" would
      read as success).

  Bounded resources: exports are streamed through a per-run subdirectory
  of one throwaway tmpdir -- at most ONE export exists on disk at any
  moment, and each is removed before the next run is judged (the same
  hygiene `mix xaas.ultracode.audit` uses per run). The tmpdir is
  removed when the call returns. `:max_runs` bounds the JUDGED set
  deterministically: ledger order (first occurrence), campaign row
  last -- so a bounded run always judges a prefix, and the report's
  `:named` vs `:total` exposes exactly how much was not judged.

  ## Options (`campaign/2`)

    * `:ledger` -- explicit campaign ledger path (default: the campaign
      dir under the configured ticket dir, `Campaign.campaign_dir/1`).
    * `:max_runs` -- positive integer bound on judged runs (deterministic
      prefix order above). Default: no bound.
    * `:tmp_dir` -- where exports are streamed (default: a fresh OS tmp
      subdir; removed when the call returns, the documented `Learn`
      semantics).
    * `:export` -- a 2-arity fault-injection seam
      `(run_id, tmp_dir -> {:ok, path} | {:error, term})`, default
      `&OcelEgress.export_run/2`. Test seam only (the exact seam shape
      `Learn.campaign_facts/2` documents): it routes around nothing --
      the REAL validator still adjudicates whatever the seam hands over.

  ## Ownership

  This module owns one mix task (`mix xaas.ultracode.ocel_conformance`)
  and its tests. It mutates nothing: campaign rows, ledgers and exports
  are read-only inputs; the only writes are its own throwaway tmpdirs.
  """

  alias Xaas.Ultracode.{Campaign, Ocel, OcelEgress, Run}

  @default_export &OcelEgress.export_run/2

  @typedoc "One validator violation (the court's own shape)."
  @type violation :: Ocel.Validator.violation()

  @typedoc """
  One run's judged result: `:valid` with the validator's counts, or
  `:violations` with the named list.
  """
  @type run_result :: %{
          required(:run_id) => String.t(),
          required(:status) => :valid | :violations,
          optional(:events) => non_neg_integer(),
          optional(:objects) => non_neg_integer(),
          optional(:violations) => [violation()]
        }

  @typedoc """
  The campaign report. `:named` is how many distinct runs the campaign
  names (ledger runs + the campaign row); `:total` is how many were
  actually judged (equal unless `:max_runs` bound the run). `:status` is
  `:conformant` only when at least one run was judged and EVERY judged
  run is valid.
  """
  @type report :: %{
          required(:campaign_id) => String.t(),
          required(:ledger) => String.t(),
          required(:ledger_present) => boolean(),
          required(:named) => pos_integer(),
          required(:runs) => [run_result()],
          required(:valid) => non_neg_integer(),
          required(:total) => non_neg_integer(),
          required(:status) => :conformant | :violations
        }

  @doc """
  Judges one whole campaign: exports + validates the OCEL 2.0 log of
  EVERY run the campaign ledger names (each `attempt_start` run in
  ledger order, plus the campaign row itself). Returns
  `{:ok, report}` -- including when runs FAIL conformance (that is the
  report's job to name) -- or `{:error, reason}` when the court could
  not judge at all.
  """
  @spec campaign(String.t(), keyword()) :: {:ok, report()} | {:error, term()}
  def campaign(campaign_id, opts \\ [])

  def campaign(campaign_id, opts) when is_binary(campaign_id) and is_list(opts) do
    ledger = opts[:ledger] || default_ledger(campaign_id)
    export = opts[:export] || @default_export

    with :ok <- check_opts(opts),
         {:ok, campaign} <- fetch_campaign(campaign_id),
         {:ok, ledger_present, events} <- read_ledger(ledger),
         {:ok, named_run_ids} <- attempt_run_ids(events),
         named = Enum.uniq(named_run_ids ++ [campaign.id]),
         targets = bounded(named, opts[:max_runs]),
         {:ok, results} <- judge(targets, export, opts) do
      {:ok, build_report(campaign.id, ledger, ledger_present, named, results)}
    end
  end

  @doc """
  Single-run mode (`--run <run-id>`): the same per-run court,
  campaign-independent (no campaign-row marker check). Same result
  discipline: a validator RED is a judged `{:ok, run_result}`; an export
  failure is a `{:error, ...}` refusal to judge.
  """
  @spec run(String.t(), keyword()) :: {:ok, run_result()} | {:error, term()}
  def run(run_id, opts \\ []) when is_binary(run_id) and is_list(opts) do
    export = opts[:export] || @default_export
    judge_run(run_id, 1, ensure_tmp_dir(opts), export)
  end

  # ------------------------------------------------------------------
  # The per-run court (bounded tmpdir: one export on disk at a time)
  # ------------------------------------------------------------------

  defp judge(targets, export, opts) do
    parent = ensure_tmp_dir(opts)

    try do
      targets
      |> Enum.with_index(1)
      |> Enum.reduce_while({:ok, []}, fn {run_id, index}, {:ok, acc} ->
        case judge_run(run_id, index, parent, export) do
          {:ok, result} -> {:cont, {:ok, [result | acc]}}
          {:error, _} = refusal -> {:halt, refusal}
        end
      end)
      |> case do
        {:ok, results} -> {:ok, Enum.reverse(results)}
        {:error, _} = refusal -> refusal
      end
    after
      File.rm_rf(parent)
    end
  end

  # One run: export into its own subdir, hand the file to the REAL
  # validator, remove the subdir. Any unexpected court report is
  # fail-closed into a named violation (audit's rule) -- never a pass.
  @spec judge_run(String.t(), pos_integer(), Path.t(), (String.t(), Path.t() -> term())) ::
          {:ok, run_result()} | {:error, {:run_export_failed, String.t(), term()}}
  defp judge_run(run_id, index, parent, export) do
    dir = Path.join(parent, "run-#{index}")

    try do
      case export.(run_id, dir) do
        {:ok, path} ->
          judge_export(run_id, path)

        {:error, reason} ->
          {:error, {:run_export_failed, run_id, reason}}
      end
    after
      File.rm_rf(dir)
    end
  end

  defp judge_export(run_id, path) do
    case Ocel.Validator.validate_file(path) do
      {:ok, counts} ->
        {:ok,
         %{
           run_id: run_id,
           status: :valid,
           events: counts["event_count"],
           objects: counts["object_count"]
         }}

      {:error, violations} when is_list(violations) ->
        {:ok, %{run_id: run_id, status: :violations, violations: violations}}

      other ->
        {:ok,
         %{
           run_id: run_id,
           status: :violations,
           violations: [
             %{path: "$", reason: "unexpected conformance court report: #{inspect(other)}"}
           ]
         }}
    end
  end

  # ------------------------------------------------------------------
  # Report
  # ------------------------------------------------------------------

  defp build_report(campaign_id, ledger, ledger_present, named, results) do
    valid = Enum.count(results, &(&1.status == :valid))
    total = length(results)

    %{
      campaign_id: campaign_id,
      ledger: ledger,
      ledger_present: ledger_present,
      named: length(named),
      runs: results,
      valid: valid,
      total: total,
      status: if(total > 0 and valid == total, do: :conformant, else: :violations)
    }
  end

  # ------------------------------------------------------------------
  # Options / campaign row / ledger (the enumeration source)
  # ------------------------------------------------------------------

  defp check_opts(opts) do
    case Keyword.get(opts, :max_runs) do
      nil -> :ok
      max when is_integer(max) and max >= 1 -> :ok
      other -> {:error, {:bad_opt, :max_runs, other}}
    end
  end

  defp bounded(targets, nil), do: targets
  defp bounded(targets, max) when is_integer(max) and max >= 1, do: Enum.take(targets, max)

  # The same campaign-row rule `mix xaas.ultracode.audit` uses: the id
  # must resolve AND name a campaign row (goal marker) -- a mistyped run
  # id is not silently judged as a campaign.
  defp fetch_campaign(campaign_id) do
    case Ash.get(Run, campaign_id, action: :read_unscoped, authorize?: false) do
      {:ok, %Run{} = campaign} ->
        if String.starts_with?(campaign.goal || "", Campaign.goal_marker()) do
          {:ok, campaign}
        else
          {:error, {:not_a_campaign, campaign_id}}
        end

      _ ->
        {:error, :campaign_not_found}
    end
  end

  # Ledger walk: attempt_start run_ids in ledger order. Fail-closed on an
  # absent ledger (no enumeration source -> no batch claim, `Learn`'s
  # rule), a corrupt line (audit's located error) and an attempt_start
  # whose run_id is not a string (a broken census fact, never skipped).
  defp read_ledger(path) do
    if File.regular?(path) do
      path |> File.read!() |> String.split("\n", trim: true) |> decode_lines(path, 1, [])
    else
      {:error, {:ledger_not_found, path}}
    end
  end

  defp decode_lines([], _path, _line_no, acc), do: {:ok, true, Enum.reverse(acc)}

  defp decode_lines([line | rest], path, line_no, acc) do
    case Jason.decode(line) do
      {:ok, event} -> decode_lines(rest, path, line_no + 1, [event | acc])
      {:error, reason} -> {:error, {:malformed_ledger, path, line_no, reason}}
    end
  end

  defp attempt_run_ids(events) do
    events
    |> Enum.reduce_while({:ok, []}, fn event, {:ok, acc} ->
      case attempt_run_id(event) do
        {:ok, nil} -> {:cont, {:ok, acc}}
        {:ok, run_id} -> {:cont, {:ok, [run_id | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, ids} -> {:ok, Enum.reverse(ids)}
      {:error, _} = err -> err
    end
  end

  # Attempt-life facts are nested under "data" in the production ledger
  # shape; the flat fallback (`Map.drop`) is `Learn.payload/1`'s tolerance.
  defp attempt_run_id(%{"event" => "attempt_start"} = event) do
    payload = Map.get(event, "data") || Map.drop(event, ["event", "ts"])

    case payload do
      %{"run_id" => run_id} when is_binary(run_id) -> {:ok, run_id}
      _ -> {:error, {:malformed_ledger_event, "attempt_start", payload}}
    end
  end

  defp attempt_run_id(_event), do: {:ok, nil}

  defp default_ledger(campaign_id),
    do: Path.join(Campaign.campaign_dir(campaign_id), "ledger.ndjson")

  # `Learn`'s tmpdir semantics: a caller-provided `:tmp_dir` is used (and
  # removed when the call returns); the default is a fresh OS tmp subdir.
  defp ensure_tmp_dir(opts) do
    case opts[:tmp_dir] do
      dir when is_binary(dir) ->
        File.mkdir_p!(dir)
        dir

      _ ->
        Path.join(
          System.tmp_dir!(),
          "xaas-ocel-conformance-#{System.unique_integer([:positive])}"
        )
    end
  end
end
