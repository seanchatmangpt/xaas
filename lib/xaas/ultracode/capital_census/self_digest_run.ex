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
    residual_shape   = the line's explicit `residual_shape` when present,
                       else the tick outcome (e.g. "worker_unclosed")
    context          = the telemetry step (e.g. "dispatch")
  Only shapes the ontology classifies become self-work orders; unknown
  shapes are reported as receipted CANDIDATES (`:candidates`), never guessed.

  Provenance (the law's admission precondition) is minted here from the
  exact window: `derived_from_receipt = "self-digest:sha256:<digest of the
  windowed telemetry lines>@<path>"` and a replay falsifier naming the same
  window. With `admit?: true` every admitted order is persisted through the
  generated chain ExperienceCluster -> Gap(:hypothesis) -> WorkOrder(:open)
  with subject `self_subject/0` (UltraCode itself), deduplicated against an
  existing OPEN order for the same subject + topology.

  ```
  Work → Resolution → Execution → OCEL → Experience → Gap → Work_self → U_{t+1}
  ```
  """

  require Ash.Query

  alias Xaas.Ultracode.CapitalCensus.{Episode, ExperienceCluster, Facts, Gap}
  alias Xaas.Ultracode.CapitalCensus.WorkOrder
  alias Xaas.Ultracode.CapitalCensus.SelfDigest.Law

  @self_subject "ultracode-self-digest"

  @doc "The self-work subject: UltraCode itself (the Law's default subject)."
  def self_subject, do: @self_subject

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
      provenance = provenance(telemetry_path, lines, window)

      frontier = Enum.filter(episodes, & &1.frontier?)
      ratio = Law.frontier_ratio(length(frontier), length(episodes))

      if opts[:persist?] do
        Enum.each(frontier, &record_episode/1)
      end

      clusters =
        Law.cluster(frontier)

      verdicts =
        clusters
        |> Enum.filter(& &1.recurring?)
        |> Enum.map(&{&1, work_order_attrs(&1, provenance)})

      admitted = for {cluster, {:ok, attrs}} <- verdicts, do: {cluster, attrs}
      refused = for {cluster, {:refused, reason}} <- verdicts, do: {cluster, reason}

      unknown_count = Enum.count(refused, &match?({_, :unknown_class}, &1))

      created =
        if opts[:admit?] do
          persist_orders(admitted)
        else
          {:ok, []}
        end

      report = %{
        window_minutes: window,
        ticks: length(episodes),
        frontier_episodes: length(frontier),
        recurrence_threshold: Facts.recurrence_threshold(),
        ratio: ratio,
        improving?: improving_vs_previous?(out_dir, ratio),
        clusters: clusters,
        work_orders: Enum.map(admitted, fn {_cluster, attrs} -> attrs end),
        unknown_shapes: unknown_count,
        # Recurring clusters the law REFUSED: receipted candidates only,
        # never persisted as orders (unknown never guesses).
        candidates:
          Enum.map(refused, fn {cluster, reason} ->
            %{topology: cluster.topology, count: cluster.count, refused: reason}
          end),
        provenance: provenance
      }

      _ = write_ratio_snapshot(out_dir, ratio)

      case created do
        {:ok, rows} ->
          {:ok, Map.put(report, :created_work_orders, rows)}

        {:error, reason} ->
          {:error, {:self_work_order_admission_failed, reason}}
      end
    end
  end

  @doc """
  JSON-safe summary of a digest report (what `mix xaas.self_digest` prints
  and `SelfDigestWorker` writes as its receipt).
  """
  def summary(report) do
    %{
      "schema" => "xaas.self-digest-receipt/1",
      "subject" => @self_subject,
      "window_minutes" => report.window_minutes,
      "ticks" => report.ticks,
      "frontier_episodes" => report.frontier_episodes,
      "ratio" => report.ratio,
      "improving" => report.improving?,
      "recurring_clusters" =>
        report.clusters
        |> Enum.filter(& &1.recurring?)
        |> Enum.map(&%{"topology" => Tuple.to_list(&1.topology), "count" => &1.count}),
      "admitted_work_orders" => Enum.map(report.work_orders, & &1.ticket_id),
      "created_work_orders" =>
        Enum.map(Map.get(report, :created_work_orders, []), fn
          {:created, order} ->
            %{"id" => order.id, "ticket_id" => order.ticket_id, "created" => true}

          {:existing, order} ->
            %{"id" => order.id, "ticket_id" => order.ticket_id, "created" => false}
        end),
      "candidates" =>
        Enum.map(report.candidates, fn c ->
          %{
            "topology" => Tuple.to_list(c.topology),
            "count" => c.count,
            "refused" => Atom.to_string(c.refused)
          }
        end),
      "unknown_shapes" => report.unknown_shapes,
      "provenance" => report.provenance
    }
  end

  @doc "Episode extraction: one entry per telemetry line with a known outcome."
  def episodes(lines) do
    episodes =
      lines
      |> Enum.flat_map(fn line ->
        with {:ok, %{"ts" => ts, "outcome" => outcome_name, "step" => step} = decoded} <-
               Jason.decode(line),
             {:ok, outcome} <- outcome_atom(outcome_name) do
          shape =
            case decoded["residual_shape"] do
              explicit when is_binary(explicit) and explicit != "" -> explicit
              _ -> Atom.to_string(outcome)
            end

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
                  residual_shape: shape,
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

  @doc """
  Admit recurring clusters (with `provenance`, as minted by `digest/1`) to
  the generated chain ExperienceCluster -> Gap -> WorkOrder. Returns
  `{:ok, [{:created | :existing, order}]}` or `{:error, reason}`; refused
  clusters (law refusal) are skipped -- they are `digest/1`'s candidates.
  """
  def admit_work_orders(clusters, provenance) do
    clusters
    |> Enum.filter(& &1.recurring?)
    |> Enum.flat_map(fn cluster ->
      case work_order_attrs(cluster, provenance) do
        {:ok, attrs} -> [{cluster, attrs}]
        {:refused, _} -> []
      end
    end)
    |> persist_orders()
  end

  defp work_order_attrs(cluster, provenance) do
    cluster
    |> Map.merge(%{
      subject: @self_subject,
      falsifier: provenance["falsifier"],
      derived_from_receipt: provenance["derived_from_receipt"]
    })
    |> Law.self_work_order()
  end

  defp provenance(telemetry_path, lines, window) do
    digest = :crypto.hash(:sha256, Enum.join(lines, "\n")) |> Base.encode16(case: :lower)

    %{
      "telemetry_path" => telemetry_path,
      "window_minutes" => window,
      "window_lines" => length(lines),
      "window_sha256" => digest,
      "derived_from_receipt" => "self-digest:sha256:#{digest}@#{telemetry_path}",
      "falsifier" =>
        "replay the #{window}-minute window of #{telemetry_path} (sha256 #{digest}) " <>
          "through `mix xaas.self_digest`; the topology must not recur after the repair lands"
    }
  end

  # One transaction for the whole batch: a partially-admitted self-work set
  # never persists (fail-closed).
  defp persist_orders([]), do: {:ok, []}

  defp persist_orders(admitted) do
    Xaas.Repo.transaction(fn ->
      Enum.map(admitted, fn {cluster, attrs} ->
        case persist_order(cluster, attrs) do
          {:ok, result} -> result
          {:error, reason} -> Xaas.Repo.rollback(reason)
        end
      end)
    end)
  end

  defp persist_order(%{topology: {closure, shape, context}} = cluster, attrs) do
    case existing_open_order(closure, shape, context) do
      %WorkOrder{} = order ->
        {:ok, {:existing, order}}

      nil ->
        {:hypothesis, class, primitive} = Law.classify(%{residual_shape: shape})

        with {:ok, cluster_row} <-
               ExperienceCluster
               |> Ash.Changeset.for_create(:create, %{
                 required_closure: closure,
                 residual_shape: shape,
                 context: context,
                 episode_count: cluster.count
               })
               |> Ash.create(authorize?: false),
             {:ok, gap} <-
               Gap
               |> Ash.Changeset.for_create(:create, %{
                 experience_cluster_id: cluster_row.id,
                 required_closure: closure,
                 residual_shape: shape,
                 context: context,
                 recurrence_class: class,
                 primitive_target: primitive,
                 episode_count: cluster.count,
                 falsifier: attrs.falsifier,
                 status: :hypothesis
               })
               |> Ash.create(authorize?: false),
             {:ok, order} <-
               WorkOrder
               |> Ash.Changeset.for_create(:create, Map.put(attrs, :gap_id, gap.id))
               |> Ash.create(authorize?: false) do
          {:ok, {:created, order}}
        end
    end
  end

  # Dedup: an OPEN self-work order already owns this topology.
  defp existing_open_order(closure, shape, context) do
    gap_ids =
      Gap
      |> Ash.Query.filter(
        required_closure == ^closure and residual_shape == ^shape and context == ^context
      )
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    case gap_ids do
      [] ->
        nil

      ids ->
        WorkOrder
        |> Ash.Query.filter(gap_id in ^ids and status == :open and subject == ^@self_subject)
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.read!(authorize?: false)
        |> List.first()
    end
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

    if atom in Facts.frontier_outcomes() or
         atom in ~w(worker_completed complete busy waiting_deps)a do
      {:ok, atom}
    else
      {:error, :unknown_outcome}
    end
  rescue
    ArgumentError -> {:error, :unknown_outcome}
  end
end
