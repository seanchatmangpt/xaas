defmodule Mix.Tasks.Xaas.Autonomy.Qualify do
  @shortdoc "Runs the recurrence-edge self-check (is the loop closed, machine-queryably?)"

  @moduledoc """
  The recurrence-edge self-check for one episode (`Xaas.Ultracode.Run`):
  recomputes the edge (`Xaas.Ultracode.Recurrence.recurrence_edge/1`) and
  courts it against the closure law. This is the one-command answer to "is
  the autonomic loop ACTUALLY closed for this episode" -- machine-queryable,
  receipt-grounded, provider-neutral.

      mix xaas.autonomy.qualify --run <run_id>
      mix xaas.autonomy.qualify --latest [N]     # most recent N runs (default 1)

  The checks, each a real court:

    1. EDGE RESOLVES -- the edge computes without a source failure (a
       malformed/injected frontier source that fails closed shows here).
    2. REPLAY (determinism) -- the edge derives byte-identically from the
       same rows twice (only the derivation moment may differ).
    3. COVERAGE -- every standing receipt's subject appears in the reobserve,
       and every non-satisfied frontier entry licenses exactly one n+1
       candidate.
    4. ORIGIN AUTHORITY -- every candidate carries the admitted kernel
       authority (`sj:originAuthority` law; a work order without an origin
       authority is not manufacturable).
    5. PROVIDER NEUTRALITY -- no candidate carries a provider field; provider
       identity appears only where the CONTRACT allows it (the capabilityId
       left segment).

  Standing:

    * `ALIVE` -- every check holds.
    * `PARTIAL_ALIVE (missing: ...)` -- judgeable, every failing check named.
    * `BLOCKED (reason)` -- the edge could not judge at all (run missing,
       source failure): an infrastructure error, never a verdict.

  Exit: 0 when judged (ALIVE or PARTIAL_ALIVE); non-zero only on BLOCKED
  (matching `mix xaas.ultracode.audit`'s convention).
  """

  use Mix.Task

  alias Xaas.Ultracode.{Recurrence, Run}

  @origin_authority :ultracode_reactor

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} = OptionParser.parse(args, strict: [run: :string, latest: :integer])

    Mix.Task.run("app.start")

    case resolve_runs(opts) do
      {:error, reason} ->
        Mix.shell().error("standing: BLOCKED (#{format_reason(reason)})")
        System.halt(1)

      {:ok, []} ->
        Mix.shell().error("standing: BLOCKED (no Xaas.Ultracode.Run rows exist)")
        System.halt(1)

      {:ok, runs} ->
        results = Enum.map(runs, &qualify/1)
        Enum.each(results, &print_report/1)

        if Enum.any?(results, &(&1.standing == :blocked)) do
          System.halt(1)
        end
    end
  end

  defp resolve_runs(opts) do
    cond do
      id = opts[:run] ->
        case Ash.get(Run, id, action: :read_unscoped, authorize?: false) do
          {:ok, run} -> {:ok, [run]}
          {:error, _} -> {:error, {:run_not_found, id}}
        end

      true ->
        limit = max(opts[:latest] || 1, 1)

        runs =
          Run
          |> Ash.Query.for_read(:read_unscoped)
          |> Ash.Query.sort(inserted_at: :desc)
          |> Ash.Query.limit(limit)
          |> Ash.read!()

        {:ok, runs}
    end
  end

  # ------------------------------------------------------------------
  # The law (also the library entry point tests use)
  # ------------------------------------------------------------------

  @doc false
  def qualify(%Run{} = run) do
    case Recurrence.recurrence_edge(run) do
      {:error, reason} ->
        %{run_id: run.id, standing: :blocked, reason: reason}

      {:ok, edge} ->
        failures =
          []
          |> check_replay(edge, run)
          |> check_coverage(edge)
          |> check_origin_authority(edge)
          |> check_provider_neutrality(edge)

        standing = if failures == [], do: :alive, else: {:partial_alive, failures}

        %{
          run_id: run.id,
          standing: standing,
          edge: %{
            receipts: length(edge.receipts),
            frontier: length(edge.frontier),
            next_work_orders: length(edge.next_work_orders),
            closed?: edge.closed?
          }
        }
    end
  end

  # Determinism: recompute; only the derivation moment may differ.
  defp check_replay(failures, edge, run) do
    case Recurrence.recurrence_edge(run) do
      {:ok, edge2} ->
        if %{edge | derived_at: nil} == %{edge2 | derived_at: nil} do
          failures
        else
          ["replay: edge is not deterministic across recomputation" | failures]
        end

      {:error, reason} ->
        ["replay: recompute failed: #{inspect(reason)}" | failures]
    end
  end

  defp check_coverage(failures, edge) do
    reobserved = MapSet.new(edge.reobserve, & &1.work_order)

    missing =
      edge.receipts
      |> Enum.map(& &1.subject)
      |> Enum.uniq()
      |> Enum.reject(&MapSet.member?(reobserved, &1))

    failures =
      if missing == [] do
        failures
      else
        ["coverage: receipts without a reobserve entry: #{inspect(missing)}" | failures]
      end

    licensed = length(edge.next_work_orders)
    needed = edge.frontier |> Enum.reject(&(&1.disposition == :satisfied)) |> length()

    if licensed == needed do
      failures
    else
      [
        "coverage: #{needed} frontier entries licensed #{licensed} candidates" | failures
      ]
    end
  end

  defp check_origin_authority(failures, edge) do
    bad = Enum.reject(edge.next_work_orders, &(&1.origin_authority == @origin_authority))

    if bad == [] do
      failures
    else
      ["origin_authority: #{length(bad)} candidate(s) without #{@origin_authority}" | failures]
    end
  end

  defp check_provider_neutrality(failures, edge) do
    bad =
      Enum.reject(edge.next_work_orders, fn candidate ->
        not Map.has_key?(candidate, :provider) and
          candidate.capability_id == Xaas.Ultracode.ProviderRegistry.capability_left_segment(candidate.capability_id)
      end)

    if bad == [] do
      failures
    else
      ["provider_neutrality: #{length(bad)} candidate(s) carry provider identity outside the capabilityId left segment" | failures]
    end
  end

  # ------------------------------------------------------------------
  # Printing
  # ------------------------------------------------------------------

  defp print_report(%{run_id: run_id, standing: standing} = report) do
    shell = Mix.shell()
    shell.info("run #{run_id}:")

    if Map.has_key?(report, :edge) do
      edge = report.edge

      shell.info(
        "  edge: receipts=#{edge.receipts} frontier=#{edge.frontier} " <>
          "next=#{edge.next_work_orders} closed?=#{edge.closed?}"
      )
    end

    case standing do
      :alive ->
        shell.info("  standing: ALIVE (recurrence edge closed, replayable, provider-neutral)")

      {:partial_alive, missing} ->
        shell.info("  standing: PARTIAL_ALIVE (missing: #{Enum.join(missing, "; ")})")

      :blocked ->
        shell.info("  standing: BLOCKED (#{format_reason(report.reason)})")
    end
  end

  defp format_reason({:run_not_found, id}), do: "run_not_found: #{id}"
  defp format_reason(reason), do: inspect(reason)
end
