defmodule Xaas.Ultracode.CapitalCensus.SelfDigest.Run do
  @moduledoc """
  Telemetry ingest for self-gap generation (GC-26927-SELFDIGEST closure #3).

  This is the ledgered handwritten residue: reading the wave loop's NDJSON
  telemetry and mapping entries to episode topology is transport/ingest, not
  semantics (see HANDWRITTEN.md). The LAW lives in
  `Xaas.Ultracode.CapitalCensus.SelfDigest.Law`; the STATE is the generated
  `CapitalCensus.Episode` / `ExperienceCluster` / `Gap` / `WorkOrder` Ash
  resources; the VALUES come from the generated `Facts` module.

  Episode topology from telemetry (ingest rule, disclosed):
    required_closure = "wave_loop_tick"
    residual_shape   = the tick outcome (e.g. "worker_unclosed")
    context          = the telemetry step (e.g. "dispatch")
  Only shapes the ontology classifies become self-work orders; unknown
  shapes are reported, never guessed.

  ```
  Work → Resolution → Execution → OCEL → Experience → Gap → Work_self → U_{t+1}
  ```
  """

  alias Xaas.Ultracode.CapitalCensus.{Episode, Facts}
  alias Xaas.Ultracode.CapitalCensus.WorkOrder
  alias Xaas.Ultracode.CapitalCensus.SelfDigest.Law

  @doc """
  Digest a telemetry file over `:window_minutes`.

  Returns `{:ok, report}` with `:ratio` (R_t), `:improving?`, `:clusters`,
  `:work_orders` (created attrs admitted by the law) and `:unknown_shapes` —
  or a typed refusal. When `persist?: true`, episodes are recorded through
  the generated `CapitalCensus.Episode` resource (requires the repo).
  """
  def digest(%{telemetry_path: telemetry_path, out_dir: out_dir} = opts) do
    window = Map.get(opts, :window_minutes, 24 * 60)
    cutoff = DateTime.add(DateTime.utc_now(), -window * 60, :second)

    with {:ok, lines} <- read_lines(telemetry_path, cutoff),
         {:ok, episodes} <- episodes(lines) do
      frontier = Enum.filter(episodes, & &1.frontier?)
      ratio = Law.frontier_ratio(length(frontier), length(episodes))

      if opts[:persist?] do
        Enum.each(frontier, &record_episode/1)
      end

      clusters =
        Law.cluster(frontier)

      {admitted, unknown} =
        clusters
        |> Enum.filter(& &1.recurring?)
        |> Enum.map(&work_order_attrs/1)
        |> Enum.split_with(fn
          {:ok, _} -> true
          _ -> false
        end)

      unknown_count = Enum.count(unknown, &match?({:refused, :unknown_class}, &1))

      report = %{
        window_minutes: window,
        ticks: length(episodes),
        frontier_episodes: length(frontier),
        recurrence_threshold: Facts.recurrence_threshold(),
        ratio: ratio,
        improving?: improving_vs_previous?(out_dir, ratio),
        clusters: clusters,
        work_orders: Enum.map(admitted, fn {:ok, attrs} -> attrs end),
        unknown_shapes: unknown_count
      }

      _ = write_ratio_snapshot(out_dir, ratio)
      {:ok, report}
    end
  end

  @doc "Episode extraction: one entry per telemetry line with a known outcome."
  def episodes(lines) do
    episodes =
      lines
      |> Enum.flat_map(fn line ->
        with {:ok, %{"ts" => ts, "outcome" => outcome_name, "step" => step}} <- Jason.decode(line),
             {:ok, outcome} <- outcome_atom(outcome_name) do
          case DateTime.from_iso8601(ts) do
            {:ok, dt, _offset} ->
              frontier? = outcome in Facts.frontier_outcomes()

              [
                %{
                  ts: dt,
                  outcome: outcome,
                  step: step,
                  frontier?: frontier?,
                  required_closure: "wave_loop_tick",
                  residual_shape: Atom.to_string(outcome),
                  context: step || "unassigned"
                }
              ]

            _ ->
              []
          end
        else
          _ -> []
        end
      end)

    {:ok, Enum.sort_by(episodes, & &1.ts, {:asc, DateTime})}
  end

  @doc "Admit recurring clusters to the generated WorkOrder resource (real Ash create)."
  def admit_work_orders(clusters) do
    clusters
    |> Enum.filter(& &1.recurring?)
    |> Enum.flat_map(fn cluster ->
      case Law.self_work_order(Map.put(cluster, :subject, "ultracode-self-digest")) do
        {:ok, attrs} ->
          WorkOrder
          |> Ash.Changeset.for_create(:create, attrs)
          |> Ash.create()

        {:refused, reason} ->
          {:error, reason}
      end
    end)
  end

  defp work_order_attrs(cluster) do
    Law.self_work_order(Map.put(cluster, :subject, "ultracode-self-digest"))
  end

  defp record_episode(episode) do
    Episode
    |> Ash.Changeset.for_create(:create, %{
      subject: episode.step || "unassigned",
      outcome: episode.outcome,
      required_closure: "wave_loop_tick",
      residual_shape: Atom.to_string(episode.outcome),
      context: episode.context
    })
    |> Ash.create()
  end

  defp improving_vs_previous?(out_dir, ratio) do
    prev_path = Path.join(out_dir, "last-ratio.txt")

    with {:ok, body} <- File.read(prev_path),
         {prev, _} <- Float.parse(String.trim(body)) do
      Law.improving?(prev, ratio)
    else
      _ -> false
    end
  end

  defp write_ratio_snapshot(out_dir, ratio) do
    if is_float(ratio) do
      File.mkdir_p!(out_dir)
      File.write!(Path.join(out_dir, "last-ratio.txt"), Float.to_string(ratio))
    else
      :ok
    end
  end

  defp read_lines(path, cutoff) do
    case File.read(path) do
      {:ok, content} ->
        lines =
          content
          |> String.split("\n", trim: true)
          |> Enum.filter(fn line ->
            case Jason.decode(line) do
              {:ok, %{"ts" => ts}} ->
                case DateTime.from_iso8601(ts) do
                  {:ok, dt, _} -> DateTime.compare(dt, cutoff) == :gt
                  _ -> false
                end

              _ ->
                false
            end
          end)

        {:ok, lines}

      {:error, reason} ->
        {:error, {:telemetry_unreadable, path, reason}}
    end
  end

  defp outcome_atom(name) when is_binary(name) do
    atom = String.to_existing_atom(name)

    if atom in Facts.frontier_outcomes() or atom in ~w(worker_completed complete busy waiting_deps)a do
      {:ok, atom}
    else
      {:error, :unknown_outcome}
    end
  rescue
    ArgumentError -> {:error, :unknown_outcome}
  end
end
