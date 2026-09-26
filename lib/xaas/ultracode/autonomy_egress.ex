defmodule Xaas.Ultracode.AutonomyEgress do
  @moduledoc """
  The EPISODE-level OCEL 2.0 ndjson egress: derives one episode (a
  `Xaas.Ultracode.Run` and its Epochs/Receipts) into the CONTRACT's
  object/event vocabulary -- the `aloop-episode-ontology-pack` names, which
  are exactly the CONTRACT's `ExecutionRequest`/`ExecutionReceipt` world:

    * object types: `Episode Objective Requirement WorkOrder Authority
      Repository Subject Provider Worker WorkerRun Plan Capability Candidate
      Consequence Evidence Receipt Failure Benchmark Release` (declared in
      full; emitted iff the episode carries the fact -- the court requires
      emitted types to be declared, never the converse);
    * event classes: `provider.select worker.claim execution.crash
      receipt.persist falsifier.run provider.replace reobserve
      goal.satisfied episode.terminal` (the CONTRACT list's episode-scoped
      members);
    * qualifiers: the CONTRACT's own (`subject originAuthority provider
      worker input output evidence consequence receipt parentEpisode
      predecessor`, plus the egress's deterministic fallback: the referenced
      object's type, lowercased).

  Line format is the proven `Xaas.Telemetry.OcelAshEmitter` reshape: each
  ndjson line is a COMPLETE, individually-conformant OCEL 2.0 document
  carrying exactly one event and the objects that event's relationships
  reference, so `Xaas.Telemetry.OcelNdjson` aggregates and the real court
  (`Xaas.Ultracode.Ocel.Validator`) adjudicates the whole log.

  ## The RECONSTRUCTED law (honesty about derived events)

  An event carries `"reconstructed": true` in its attributes iff it is a
  DERIVED INFERENCE -- the named activity never occurred as a discrete,
  recorded action at that moment. Row-backed lifecycle events (a claim's
  `claimed_at`, a receipt's `sealed_at`, a terminal transition's
  `terminal_at`) are NOT reconstructed: their moments are persisted facts.
  Currently reconstructed:

    * `provider.select` -- selection was implicit in the Run row's provider
      column (pre-registry); the event is pinned to `Run.inserted_at`, the
      earliest persisted fact consistent with the selection;
    * `reobserve` -- the frontier re-derivation
      (`Xaas.Ultracode.Recurrence`) happens at export time; the event is
      pinned to the moment it re-observes (the latest standing receipt's
      `sealed_at`), never wall-clock, so the log stays byte-stable across
      exports (same rows -> same log).

  `provider.replace` is DECLARED but not yet emitted: a single-Run episode
  carries exactly one provider (the Run's own column); the registry-failover
  across runs of one work order needs the cross-Run join this module
  deliberately does not guess at. An honest gap, named here so it is not
  silently empty.
  """

  require Ash.Query

  alias Xaas.Ultracode.{Epoch, ProviderRegistry, Receipt, Recurrence, Run}

  @object_types ~w(Episode Objective Requirement WorkOrder Authority Repository Subject Provider
                   Worker WorkerRun Plan Capability Candidate Consequence Evidence Receipt Failure
                   Benchmark Release)

  @origin_authority :ultracode_reactor

  @doc "The default output dir (the `priv/ocel/` convention, `autonomy` subdir)."
  def default_out_dir, do: Path.join([Application.app_dir(:xaas), "priv", "ocel", "autonomy"])

  @doc """
  Derives the episode's event lines (one complete OCEL 2.0 document per
  event), chronological, deterministic.
  """
  @spec derive_episode_lines(Run.t() | String.t()) :: {:ok, [map()]} | {:error, :run_not_found}
  def derive_episode_lines(%Run{} = run) do
    {:ok, epochs} =
      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.Query.sort(cycle: :asc)
      |> Ash.Query.load(:run)
      |> Ash.read()

    receipts =
      Enum.flat_map(epochs, fn epoch ->
        case Receipt.for_epoch(epoch.id) do
          {:ok, rs} -> Enum.map(rs, &{epoch, &1})
          {:error, _} -> []
        end
      end)

    ctx = build_context(run, epochs, receipts)

    events =
      build_events(run, epochs, receipts, ctx)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(fn e -> {DateTime.to_unix(e.time), e.type} end)

    {:ok, Enum.map(events, &line(&1, ctx))}
  end

  def derive_episode_lines(run_id) when is_binary(run_id) do
    case Ash.get(Run, run_id, action: :read_unscoped, authorize?: false) do
      {:ok, run} -> derive_episode_lines(run)
      {:error, _} -> {:error, :run_not_found}
    end
  end

  @doc """
  Derives + writes `<out_dir>/<run_id>.ocel.ndjson` (one event per line).
  Returns `{:ok, path}`.
  """
  @spec export_episode(Run.t() | String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def export_episode(run_or_id, out_dir \\ default_out_dir()) do
    run_id = if is_struct(run_or_id), do: run_or_id.id, else: run_or_id

    with {:ok, lines} <- derive_episode_lines(run_or_id) do
      path = Path.join(out_dir, "#{run_id}.ocel.ndjson")
      File.mkdir_p!(Path.dirname(path))

      body =
        lines
        |> Enum.map(&Jason.encode!/1)
        |> Enum.join("\n")
        |> Kernel.<>("\n")

      case File.write(path, body) do
        :ok -> {:ok, path}
        {:error, reason} -> {:error, {:write_failed, path, reason}}
      end
    end
  end

  # ------------------------------------------------------------------
  # Objects this episode actually carries
  # ------------------------------------------------------------------

  defp build_context(run, epochs, receipts) do
    subjects = epochs |> Enum.map(& &1.exact_subject) |> Enum.uniq()

    workers =
      epochs |> Enum.map(& &1.leased_to) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    left_segment =
      (is_binary(run.capability_id) && ProviderRegistry.capability_left_segment(run.capability_id)) ||
        nil

    objects =
      Enum.reject(
        [
          object("Episode", run.id, %{"goal" => run.goal, "state" => to_string(run.state)}),
          obj_if(run.goal, "Objective", "objective:#{run.id}", %{}),
          obj_if(run.verifier_suite, "Requirement", "requirement:#{run.id}:#{run.verifier_suite}", %{
            "suite" => run.verifier_suite
          }),
          obj_if(run.work_order_iri, "WorkOrder", run.work_order_iri, %{
            "capability_left_segment" => left_segment,
            "base_sha" => run.base_sha,
            "graph_digest" => run.graph_digest
          }),
          object("Authority", "authority:#{@origin_authority}", %{}),
          obj_if(
            run.execution_repo_alias || run.repository_identity,
            "Repository",
            run.execution_repo_alias || run.repository_identity,
            %{}
          ),
          obj_if(
            run.execution_policy && to_string(run.execution_policy),
            "Plan",
            "plan:#{run.id}:#{run.execution_policy}",
            %{}
          ),
          obj_if(run.capability_id, "Capability", run.capability_id, %{}),
          object("Provider", run.provider, %{})
        ],
        &is_nil/1
      ) ++
        Enum.map(subjects, &object("Subject", "subject:" <> &1, %{"subject" => &1})) ++
        Enum.map(workers, &object("Worker", "worker:" <> &1, %{"worker" => &1})) ++
        Enum.map(epochs, fn e ->
          object("WorkerRun", e.id, %{"cycle" => e.cycle, "subject" => e.exact_subject})
        end) ++
        Enum.map(receipts, fn {_e, r} ->
          object("Receipt", r.id, %{"outcome" => to_string(r.outcome)})
        end) ++
        Enum.map(receipts, fn {_e, r} ->
          object("Consequence", "consequence:" <> r.id, %{"outcome" => to_string(r.outcome)})
        end) ++
        Enum.map(receipts, fn {_e, r} ->
          object("Evidence", "evidence:" <> r.id, %{
            "head_verified" => Map.get(r.evidence, "head_verified", false)
          })
        end) ++
        Enum.map(
          Enum.filter(epochs, &(&1.state == :failed)),
          &object("Failure", "failure:" <> &1.id, %{})
        )

    # id -> object index: relationship resolution is total (every
    # relationship id comes from this same context).
    Map.new(objects, fn o -> {o["id"], o} end)
  end

  defp object(type, id, attrs), do: %{"id" => id, "type" => type, "attributes" => attrs}

  defp obj_if(nil, _type, _id, _attrs), do: nil
  defp obj_if(false, _type, _id, _attrs), do: nil
  defp obj_if(_value, type, id, attrs), do: object(type, id, attrs)

  # ------------------------------------------------------------------
  # Events
  # ------------------------------------------------------------------

  defp build_events(run, epochs, receipts, ctx) do
    epoch_events =
      Enum.flat_map(epochs, fn epoch ->
        [provider_select(run, epoch, ctx), worker_claim(epoch, ctx), execution_crash(epoch, ctx)]
      end)

    receipt_events =
      Enum.flat_map(receipts, fn {epoch, receipt} ->
        [
          receipt_persist(epoch, receipt, ctx),
          falsifier_run(epoch, receipt, ctx),
          goal_satisfied(epoch, receipt, ctx)
        ]
      end)

    [
      epoch_events,
      receipt_events,
      [reobserve(run, receipts, ctx), episode_terminal(run, ctx)]
    ]
    |> List.flatten()
  end

  # RECONSTRUCTED: see moduledoc. One per epoch attempt (the selection that
  # put THIS attempt's work on the provider).
  defp provider_select(run, epoch, ctx) do
    rels =
      [
        {ctx[run.id], "episode"},
        {ctx[run.provider], "provider"},
        {ctx[run.work_order_iri], "input"},
        {ctx["authority:#{@origin_authority}"], "originAuthority"}
      ]
      |> rels()

    event("provider.select", run.inserted_at, %{
      "reconstructed" => true,
      "provider" => run.provider,
      "epoch_id" => epoch.id
    }, rels)
  end

  defp worker_claim(%Epoch{claimed_at: nil}, _ctx), do: nil

  defp worker_claim(epoch, ctx) do
    rels =
      [
        {ctx[epoch.run_id], "episode"},
        {ctx["worker:" <> epoch.leased_to], "worker"},
        {ctx[epoch.id], "output"},
        {ctx["subject:" <> epoch.exact_subject], "subject"},
        {ctx[run_provider_id(epoch)], "provider"}
      ]
      |> rels()

    event("worker.claim", epoch.claimed_at, %{"worker" => epoch.leased_to}, rels)
  end

  # A failed epoch is a crash iff it was NOT a cancellation (a cancellation
  # seals its own :blocked receipt with cancelled_by evidence; the crash
  # event would misname it -- it never happened as a crash).
  defp execution_crash(epoch, ctx) do
    with true <- epoch.state == :failed,
         {:ok, rs} <- Receipt.for_epoch(epoch.id),
         false <- Enum.any?(rs, &Map.has_key?(&1.evidence, "cancelled_by")) do
      rels =
        [
          {ctx[epoch.run_id], "episode"},
          {ctx[epoch.id], "workerRun"},
          {ctx["subject:" <> epoch.exact_subject], "subject"},
          {ctx["failure:" <> epoch.id], "consequence"}
        ]
        |> rels()

      event("execution.crash", terminal_moment(epoch), %{"epoch_id" => epoch.id}, rels)
    else
      _ -> nil
    end
  end

  defp receipt_persist(epoch, receipt, ctx) do
    rels =
      [
        {ctx[epoch.run_id], "episode"},
        {ctx[epoch.id], "workerRun"},
        {ctx[receipt.id], "receipt"},
        {ctx["consequence:" <> receipt.id], "consequence"},
        {ctx["evidence:" <> receipt.id], "evidence"}
      ]
      |> rels()

    event(
      "receipt.persist",
      receipt.sealed_at,
      %{"outcome" => to_string(receipt.outcome), "epoch_id" => epoch.id},
      rels
    )
  end

  defp falsifier_run(epoch, %Receipt{evidence: %{"fabric_verifier" => %{"status" => status}}} = receipt, ctx)
       when is_binary(status) do
    rels =
      [
        {ctx[epoch.run_id], "episode"},
        {ctx[epoch.id], "workerRun"},
        {ctx["evidence:" <> receipt.id], "evidence"}
      ]
      |> rels()

    event("falsifier.run", receipt.sealed_at, %{"verdict" => status}, rels)
  end

  defp falsifier_run(_epoch, _receipt, _ctx), do: nil

  defp goal_satisfied(epoch, %Receipt{outcome: :alive} = receipt, ctx) do
    rels =
      [
        {ctx[epoch.run_id], "episode"},
        {ctx[receipt.id], "receipt"},
        {ctx["objective:" <> epoch.run_id], "output"}
      ]
      |> rels()

    event("goal.satisfied", receipt.sealed_at, %{"receipt_id" => receipt.id}, rels)
  end

  defp goal_satisfied(_epoch, _receipt, _ctx), do: nil

  # RECONSTRUCTED: see moduledoc.
  defp reobserve(run, receipts, ctx) do
    standing = Enum.reject(receipts, fn {_e, r} -> r.outcome == :heartbeat end)

    case standing do
      [] ->
        nil

      standing ->
        {last_epoch, last_receipt} =
          Enum.max_by(standing, fn {e, r} ->
            {DateTime.to_unix(r.sealed_at), e.cycle}
          end)

        reobserved = Recurrence.reobserve(run)

        rels =
          [
            {ctx[run.id], "episode"},
            {ctx["subject:" <> last_epoch.exact_subject], "input"}
          ]
          |> rels()

        event(
          "reobserve",
          last_receipt.sealed_at,
          %{
            "reconstructed" => true,
            "reobserved" => length(reobserved),
            "dispositions" => Enum.map(reobserved, &to_string(&1.disposition))
          },
          rels
        )
    end
  end

  defp episode_terminal(run, ctx) do
    if run.state in [:completed, :failed, :abandoned] and run.terminal_at do
      rels =
        [
          {ctx[run.id], "episode"},
          {ctx["authority:#{@origin_authority}"], "originAuthority"},
          {ctx["objective:" <> run.id], "output"}
        ]
      |> rels()

      event("episode.terminal", run.terminal_at, %{"state" => to_string(run.state)}, rels)
    else
      nil
    end
  end

  # -- construction helpers ---------------------------------------------------

  defp rels(pairs) do
    pairs
    |> Enum.reject(fn {object, _qualifier} -> is_nil(object) end)
    |> Enum.map(fn {object, qualifier} -> %{"objectId" => object["id"], "qualifier" => qualifier} end)
  end

  defp event(type, time, attrs, rels) do
    %{
      type: type,
      time: time,
      attributes: attrs,
      relationships: rels,
      id: "ev-" <> event_digest(type, time, rels, attrs)
    }
  end

  defp event_digest(type, time, rels, attrs) do
    :crypto.hash(:sha256, "#{type}|#{DateTime.to_iso8601(time)}|#{inspect(rels)}|#{inspect(attrs)}")
    |> Base.encode16(case: :lower)
    |> binary_part(0, 32)
  end

  defp terminal_moment(%Epoch{terminal_at: t}) when not is_nil(t), do: t
  defp terminal_moment(%Epoch{completed_at: t}) when not is_nil(t), do: t
  defp terminal_moment(%Epoch{inserted_at: t}), do: t

  # One provider per Run by construction; the epoch's run (loaded) carries it.
  defp run_provider_id(epoch), do: epoch.run.provider

  # ------------------------------------------------------------------
  # The OCEL 2.0 line (one complete document per event)
  # ------------------------------------------------------------------

  defp line(event, ctx) do
    referenced =
      event.relationships
      |> Enum.map(& &1["objectId"])
      |> Enum.uniq()
      |> Enum.map(&Map.fetch!(ctx, &1))

    %{
      "ocel:objectTypes" =>
        referenced
        |> Enum.map(& &1["type"])
        |> Enum.uniq()
        |> Enum.sort()
        |> Enum.map(&%{"name" => &1}),
      "ocel:eventTypes" => [%{"name" => event.type}],
      "ocel:events" => [
        %{
          "id" => event.id,
          "type" => event.type,
          "time" => DateTime.to_iso8601(event.time),
          "attributes" => event.attributes,
          "relationships" => event.relationships
        }
      ],
      "ocel:objects" => referenced
    }
  end

  @doc "The full CONTRACT object-type declaration list."
  def object_types, do: @object_types
end
