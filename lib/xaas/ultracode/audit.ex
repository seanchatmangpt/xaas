defmodule Xaas.Ultracode.Audit do
  @moduledoc """
  THE ONE JUDGMENT of an ultracode campaign's validation standing
  (`docs/ultracode/eight-hour-run.md` §5, "How the whole run is judged
  validated"). Two surfaces, one law:

    * the morning-after read (`mix xaas.ultracode.audit`, which delegates
      here) prints the (a)/(b)/(c) evidence lines over a finished
      campaign; and
    * `Xaas.Ultracode.Campaign`'s `:running -> :completed` edge, whose
      terminal `standing` is now DERIVED here instead of from the wave
      receipts' own coarse report standings (the finding this extraction
      closes: campaign 50762ec9 recorded row-standing `blocked` while its
      audit said PARTIAL_ALIVE with one named gap -- two judgments of the
      same subject must be ONE law).

  READ-ONLY over campaign state: the only writes are the OCEL export
  files the (c) court owns under a throwaway tmpdir, removed before
  return.

  The judgment law, per campaign and every wave it ran:

    * (a) TERMINALITY -- the campaign row is terminal (`:completed`/
      `:abandoned`) and every wave's epochs are terminal (`:completed`/
      `:failed`/`:missed` -- none `:expected`/`:running`). The epoch census
      is taken over the wave Run rows the campaign ledger names in its
      `attempt_start` events (the per-epoch ground truth is the DB, §5).
      An attempt Run with no epoch rows is a census hole and is named.
    * (b) ALIVE EVIDENCE -- every item the wave delivered (`item_done`)
      has its recorded receipt carrying `evidence["head_verified"] == true`
      (the failover-runbook §7 finding: "done" is a completed epoch PLUS
      the court's head verification, never a bare alive receipt), and no
      sensed item was left behind by exhausted attempts (`item_blocked`):
      an item the wave could not close alive is a named gap, never a
      silent one -- a campaign that cleanly failed every item is
      PARTIAL_ALIVE, never ALIVE.
    * (c) OCEL CONFORMANCE -- every wave Run's OCEL 2.0 log passes the
      conformance court. Reuses the existing surfaces end to end:
      `Xaas.Ultracode.OcelEgress.export_run/2` into a throwaway tmpdir,
      then `Xaas.Ultracode.Ocel.Validator.validate_file/1` (the exact
      `export_ocel` -> `ocel_validate` pair of §5), then the tmpdir is
      removed.

  Standing:

    * `ALIVE` -- (a)+(b)+(c) hold for every wave.
    * `PARTIAL_ALIVE (missing: …)` -- judgeable, with every failing part
      named (the campaign row, named epochs, named items, named runs).
    * `BLOCKED (reason)` -- the audit could not judge at all (campaign row
      missing/not a campaign, malformed ledger, export or DB failure): an
      infrastructure/data error, never a verdict -- surfaced as the
      `{:error, term}` arm, never as a `:standing`.

  ## The judgment contract

      {:ok, %{
        standing: :alive | :partial_alive,   # the §5 verdict
        gaps: [String.t()],                  # every failing part, named ([] iff alive)
        per_wave: [map()],                   # per-wave judged evidence
        # -- context --
        run_id:, state:, campaign_standing:, cycle:, ledger:, ledger_present:,
        # -- the mix task's historical names for the SAME one judgment --
        waves: per_wave,                     # same list, task print name
        missing: gaps,                       # same list, task field name
        verdict: :alive | {:partial_alive, gaps}
      }} | {:error, term}

  `:alive` and `:partial_alive` are the only judged standings;
  `:blocked` is never produced here ("could not judge" is the error arm),
  but stays in the campaign-end mapper's type union for totality.

  ## `:closing` -- the campaign-end face of the same law

  `Xaas.Ultracode.Campaign` judges the campaign AT the
  `:running -> :completed` edge, an instant before the row IS terminal:
  the row's `:running` state there is the pre-image of the very
  transition this judgment informs, not an observed non-terminal
  campaign. With `closing: true` the law's campaign-row-terminality half
  therefore evaluates against the terminal state being certified
  (`:completed`) instead of naming the row a gap; EVERY other half of the
  law (epoch census, head_verified evidence, OCEL court, the
  vacuous-census guard) is byte-identical. The option lives HERE, inside
  the law, so a caller can never filter a gap it dislikes: the default
  (`closing: false`, the morning-after task's face) names a non-terminal
  row exactly as before.

  ## `:ledger`

  The campaign's ledger path. Defaults to the canonical
  `Campaign.campaign_dir/1` resolution the morning-after task reads; the
  campaign loop passes the ledger it ACTUALLY wrote (an embedder may
  point `:ledger` elsewhere), so the judgment always reads the subject's
  real artifact.
  """

  require Ash.Query

  alias Xaas.Ultracode.{Campaign, Epoch, OcelEgress, Receipt, Run}
  alias Xaas.Ultracode.Ocel.Validator

  @terminal_epoch_states [:completed, :failed, :missed]
  @terminal_campaign_states [:completed, :abandoned]

  @doc """
  Judges a campaign. With `nil`, resolves the most recent campaign row
  (the same rule `mix xaas.ultracode.status` uses). Returns
  `{:ok, judgment}` for a judged standing (`:alive` or `:partial_alive`
  with every gap named) or `{:error, reason}` when the audit cannot judge
  at all. See the module doc for `:closing`/`:ledger` and the contract.
  """
  @spec judgment(String.t() | nil, keyword()) ::
          {:ok,
           %{
             required(:standing) => :alive | :partial_alive,
             required(:gaps) => [String.t()],
             required(:per_wave) => [map()],
             optional(atom()) => term()
           }}
          | {:error, term()}
  def judgment(id_or_nil, opts \\ [])

  def judgment(nil, opts) do
    case most_recent_campaign() do
      {:ok, %Run{} = campaign} -> judgment(campaign.id, opts)
      {:error, _} = err -> err
    end
  end

  def judgment(campaign_id, opts) when is_binary(campaign_id) do
    with {:ok, campaign} <- fetch_campaign(campaign_id),
         {:ok, ledger_path, events} <- read_ledger(campaign_id, opts[:ledger]),
         {:ok, census} <- census_waves(events),
         {:ok, judged_waves} <- judge_waves(census) do
      {:ok, judge_campaign(campaign, ledger_path, census, judged_waves, opts)}
    end
  end

  defp judge_campaign(campaign, ledger_path, census, judged_waves, opts) do
    closing? = Keyword.get(opts, :closing, false)

    campaign_failures =
      []
      |> campaign_terminality(campaign, closing?)
      |> attempt_census(campaign, census)

    missing = campaign_failures ++ Enum.flat_map(judged_waves, & &1.failures)

    %{
      run_id: campaign.id,
      state: campaign.state,
      campaign_standing: campaign.standing,
      cycle: campaign.cycle,
      ledger: ledger_path,
      ledger_present: File.regular?(ledger_path),
      standing: if(missing == [], do: :alive, else: :partial_alive),
      gaps: missing,
      per_wave: judged_waves,
      # The mix task's historical names for the SAME one judgment (same
      # list, same verdict fact) -- a projection of this map, never a
      # second derivation.
      waves: judged_waves,
      missing: missing,
      verdict: if(missing == [], do: :alive, else: {:partial_alive, missing})
    }
  end

  # (a) first half: the campaign row itself is terminal. `closing?` marks
  # the campaign-end face (see the module doc): the caller is the campaign
  # loop at the :running -> :completed edge, so the terminal state being
  # certified is what this half evaluates -- a caller-supplied state other
  # than the certified one is never honored, and the default face keeps
  # naming a non-terminal row exactly as the morning-after task always has.
  defp campaign_terminality(failures, %Run{state: state}, false) do
    campaign_terminality(failures, state)
  end

  defp campaign_terminality(failures, %Run{state: state}, true) do
    campaign_terminality(failures, if(state == :running, do: :completed, else: state))
  end

  defp campaign_terminality(failures, state) do
    if state in @terminal_campaign_states do
      failures
    else
      failures ++ ["campaign row not terminal (state=#{state}; expected completed|abandoned)"]
    end
  end

  # (a) honesty guard: a campaign that executed waves but whose ledger
  # carries no attempt census cannot evidence those waves at all (a
  # stubbed/foreign runner wrote them) -- vacuous terminality is never
  # ALIVE.
  defp attempt_census(failures, %Run{cycle: cycle}, census) when cycle > 0 do
    if census_attempt_count(census) == 0 do
      failures ++
        [
          "campaign executed #{cycle} wave(s) but the ledger carries no attempt_start " <>
            "census (wave evidence absent)"
        ]
    else
      failures
    end
  end

  defp attempt_census(failures, _campaign, _census), do: failures

  defp census_attempt_count(census) do
    census.waves
    |> Map.values()
    |> Enum.map(& &1.attempt_events)
    |> Enum.sum()
  end

  # ------------------------------------------------------------------
  # One wave: (a) epoch terminality, (b) alive-item evidence, (c) OCEL court
  # ------------------------------------------------------------------

  defp judge_waves(census) do
    census.waves
    |> Enum.sort_by(fn {n, _wave} -> n end)
    |> Enum.reduce_while({:ok, []}, fn {n, wave}, {:ok, acc} ->
      case judge_wave(n, wave) do
        {:ok, judged} -> {:cont, {:ok, [judged | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, waves} -> {:ok, Enum.reverse(waves)}
      {:error, _} = err -> err
    end
  end

  defp judge_wave(n, wave) do
    epochs = epochs_for_runs(wave.run_ids)

    with {:ok, {c_failures, c_pass}} <- ocel_judgment(wave) do
      a_failures = terminality_failures(wave, epochs)
      b_failures = alive_evidence_failures(wave)

      failures =
        Enum.map(a_failures ++ b_failures ++ c_failures, fn message ->
          "wave #{n}: " <> message
        end)

      terminal = Enum.count(epochs, fn {_id, epoch} -> epoch.state in @terminal_epoch_states end)

      {:ok,
       %{
         wave: n,
         runs: MapSet.size(wave.run_ids),
         attempt_events: wave.attempt_events,
         epochs: %{total: map_size(epochs), terminal: terminal},
         items: %{done: map_size(wave.done), blocked: length(wave.blocked)},
         ocel: %{pass: c_pass, total: MapSet.size(wave.run_ids)},
         checks: %{a: flag(a_failures), b: flag(b_failures), c: flag(c_failures)},
         failures: failures
       }}
    end
  end

  defp flag([]), do: :ok
  defp flag(_failures), do: :fail

  # (a) second half: every wave epoch is terminal (completed/failed/missed);
  # every attempt Run has at least one epoch row at all.
  defp terminality_failures(wave, epochs) do
    by_run = Map.new(epochs, fn {_id, epoch} -> {epoch.run_id, true} end)

    non_terminal =
      epochs
      |> Enum.reject(fn {_id, epoch} -> epoch.state in @terminal_epoch_states end)
      |> Enum.map(fn {id, epoch} -> "#{id}(#{epoch.state})" end)
      |> Enum.sort()

    orphans =
      wave.run_ids
      |> Enum.reject(&Map.has_key?(by_run, &1))
      |> Enum.sort()
      |> Enum.map(&"run #{&1} has no epoch rows")

    case orphans ++ non_terminal do
      [] -> []
      named -> ["non-terminal epoch census: " <> Enum.join(named, ", ")]
    end
  end

  # (b): every delivered item's recorded receipt carries head_verified,
  # and no item was left behind by exhausted attempts.
  defp alive_evidence_failures(wave) do
    unverified =
      wave.done
      |> Enum.sort_by(fn {item, _receipt} -> item end)
      |> Enum.flat_map(fn {item, receipt} -> alive_evidence_failure(item, receipt) end)

    blocked =
      wave.blocked
      |> Enum.sort()
      |> Enum.map(&"item #{&1} exhausted its attempts without an alive close (blocked)")

    unverified ++ blocked
  end

  defp alive_evidence_failure(item, %{epoch_id: epoch_id, receipt_id: receipt_id}) do
    receipts =
      Receipt
      |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch_id})
      |> Ash.read!(authorize?: false)

    case Enum.find(receipts, &(&1.id == receipt_id)) do
      nil ->
        ["item #{item}: receipt #{receipt_id} not found on epoch #{epoch_id}"]

      receipt ->
        if receipt.evidence["head_verified"] == true do
          []
        else
          [
            "item #{item}: receipt #{receipt_id} carries no head_verified evidence " <>
              "(outcome #{receipt.outcome})"
          ]
        end
    end
  end

  # (c): every wave Run's OCEL 2.0 log passes the conformance court --
  # the existing export + validate pair of §5, into a throwaway tmpdir.
  # A court {:error, violations} is a judged RED (named per run); an
  # export failure is NOT a verdict, it is a refusal to judge: it
  # surfaces as {:error, _} (BLOCKED), never as a silent pass.
  defp ocel_judgment(wave) do
    run_ids = Enum.sort(Enum.to_list(wave.run_ids))

    fold =
      Enum.reduce_while(run_ids, {:ok, []}, fn
        run_id, {:ok, acc} ->
          case ocel_result(run_id) do
            :valid ->
              {:cont, {:ok, [:valid | acc]}}

            {:violations, violations} when is_list(violations) ->
              {:cont, {:ok, [{:violations, violations} | acc]}}

            {:export_failed, reason} ->
              {:halt, {:error, {:ocel_export_failed, run_id, reason}}}
          end

        _run_id, {:error, _} = halted ->
          {:halt, halted}
      end)

    case fold do
      {:error, _} = err ->
        err

      {:ok, results} ->
        results = Enum.reverse(results)

        court_failures =
          for {{:violations, violations}, run_id} <- Enum.zip(results, run_ids) do
            first =
              case violations do
                [] -> "no violations reported"
                [v | _] -> "#{v.path} #{v.reason}"
              end

            "run #{run_id} failed the OCEL conformance court: #{first} " <>
              "(#{length(violations)} violation(s))"
          end

        pass = Enum.count(results, &(&1 == :valid))
        {:ok, {court_failures, pass}}
    end
  end

  # One run's court result, tagged: `:valid` on a court pass,
  # `{:violations, violations}` on a judged red, and `{:export_failed,
  # reason}` for the refusal-to-judge path. Any unexpected court report
  # is fail-closed into a named violation, never a silent pass.
  defp ocel_result(run_id) do
    dir = audit_tmpdir()

    try do
      case OcelEgress.export_run(run_id, dir) do
        {:ok, path} ->
          case Validator.validate_file(path) do
            {:ok, %{"status" => "valid"}} ->
              :valid

            {:error, violations} when is_list(violations) ->
              {:violations, violations}

            other ->
              {:violations,
               [%{path: "$", reason: "unexpected conformance court report: #{inspect(other)}"}]}
          end

        {:error, reason} ->
          {:export_failed, reason}
      end
    after
      File.rm_rf!(dir)
    end
  end

  defp audit_tmpdir do
    Path.join(
      System.tmp_dir!(),
      "xaas-ultracode-audit-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
    )
  end

  # ------------------------------------------------------------------
  # Ledger census: walk the campaign's ndjson and attribute item/attempt
  # events to their wave. Campaign events are flat and carry "wave";
  # Autonomic events are nested under "data". A malformed census event is
  # a broken ledger, never a silently ignored line.
  # ------------------------------------------------------------------

  defp census_waves(events) do
    initial = %{waves: %{}, current: nil}

    case Enum.reduce_while(events, initial, &census_event/2) do
      {:error, _} = err -> err
      acc -> {:ok, acc}
    end
  end

  # Reducer over the ledger: `{:cont, acc}` keeps walking, `{:halt, err}`
  # stops at the first broken census fact (reduce_while's own protocol).
  defp census_event(%{"event" => "campaign_wave_start", "wave" => n}, acc)
       when is_integer(n) do
    {:cont, %{acc | current: n, waves: Map.put_new(acc.waves, n, new_wave())}}
  end

  defp census_event(%{"event" => event, "data" => data}, acc)
       when event in ~w(attempt_start item_done item_blocked) do
    case {acc.current, census_facts(event, data)} do
      {nil, _} ->
        {:halt, {:error, {:ledger_event_before_wave_start, event}}}

      {n, {:ok, facts}} ->
        wave = Map.get(acc.waves, n, new_wave())
        {:cont, %{acc | waves: Map.put(acc.waves, n, absorb(wave, event, facts))}}

      _ ->
        {:halt, {:error, {:malformed_ledger_event, event, data}}}
    end
  end

  # campaign_* and any other event shapes carry no attempt facts.
  defp census_event(_event, acc), do: {:cont, acc}

  defp census_facts("attempt_start", %{"run_id" => run_id, "item" => item})
       when is_binary(run_id) and is_binary(item),
       do: {:ok, %{run_id: run_id, item: item}}

  defp census_facts("item_done", %{
         "item" => item,
         "epoch_id" => epoch_id,
         "receipt_id" => receipt_id
       })
       when is_binary(item) and is_binary(epoch_id) and is_binary(receipt_id),
       do: {:ok, %{item: item, epoch_id: epoch_id, receipt_id: receipt_id}}

  defp census_facts("item_blocked", %{"item" => item}) when is_binary(item),
    do: {:ok, %{item: item}}

  defp census_facts(_event, _data), do: :error

  defp new_wave do
    %{
      run_ids: MapSet.new(),
      attempt_events: 0,
      # item => %{epoch_id:, receipt_id:} for delivered items
      done: %{},
      # items whose attempts were exhausted without an alive close
      blocked: []
    }
  end

  defp absorb(wave, "attempt_start", %{run_id: run_id, item: item}) do
    %{
      wave
      | run_ids: MapSet.put(wave.run_ids, run_id),
        attempt_events: wave.attempt_events + 1,
        blocked: List.delete(wave.blocked, item)
    }
  end

  defp absorb(wave, "item_done", %{item: item} = facts) do
    %{
      wave
      | done: Map.put(wave.done, item, Map.take(facts, [:epoch_id, :receipt_id])),
        blocked: List.delete(wave.blocked, item)
    }
  end

  defp absorb(wave, "item_blocked", %{item: item}) do
    # A blocked item stays named unless the item was actually delivered
    # ("delivered wins", never double-counting).
    if Map.has_key?(wave.done, item) do
      wave
    else
      %{wave | blocked: Enum.uniq(wave.blocked ++ [item])}
    end
  end

  # ------------------------------------------------------------------
  # Reads (unscoped + authorize?: false -- the internal audit path every
  # sibling internal tool in this folder uses; the audit writes nothing
  # but its own throwaway tmpdir)
  # ------------------------------------------------------------------

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

  defp most_recent_campaign do
    Run
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(like(goal, ^(Campaign.goal_marker() <> " %")))
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, [%Run{} = campaign]} -> {:ok, campaign}
      {:ok, []} -> {:error, :no_campaign_found}
      {:error, _} = err -> err
    end
  end

  defp read_ledger(campaign_id, ledger_override)

  defp read_ledger(_campaign_id, path) when is_binary(path) do
    read_ledger_file(path)
  end

  defp read_ledger(campaign_id, _nil_override) do
    read_ledger_file(Path.join(Campaign.campaign_dir(campaign_id), "ledger.ndjson"))
  end

  defp read_ledger_file(path) do
    if File.regular?(path) do
      lines = String.split(File.read!(path), "\n", trim: true)

      case decode_lines(lines, path, 1, []) do
        {:ok, events} -> {:ok, path, events}
        {:error, _} = err -> err
      end
    else
      # An absent ledger is judgeable evidence absence, not an
      # infrastructure fault: the audit proceeds with an empty census and
      # names the gap.
      {:ok, path, []}
    end
  end

  defp decode_lines([], _path, _n, acc), do: {:ok, Enum.reverse(acc)}

  defp decode_lines([line | rest], path, n, acc) do
    case Jason.decode(line) do
      {:ok, event} -> decode_lines(rest, path, n + 1, [event | acc])
      {:error, reason} -> {:error, {:malformed_ledger, path, n, reason}}
    end
  end

  defp epochs_for_runs(run_ids) do
    ids = Enum.to_list(run_ids)

    epochs =
      if ids == [] do
        []
      else
        Epoch
        |> Ash.Query.for_read(:read_unscoped)
        |> Ash.Query.filter(run_id in ^ids)
        |> Ash.read!(authorize?: false)
      end

    Map.new(epochs, fn epoch -> {epoch.id, epoch} end)
  end
end
