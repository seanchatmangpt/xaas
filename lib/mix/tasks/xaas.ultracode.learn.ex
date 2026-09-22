defmodule Mix.Tasks.Xaas.Ultracode.Learn do
  @shortdoc "Prints a campaign's OCEL-derived learning digest and appends one learn ledger event"

  @moduledoc """
  The learning projection's operator surface for an overnight
  `Xaas.Ultracode.Campaign`: it prints the campaign's OCEL-derived facts
  digest (one line per backlog item -- attempts, final standing, court
  verdict count, failure fingerprints, hint presence -- plus the wave
  aggregate) and appends exactly ONE `learn` event to the campaign ledger
  (`{"ts", "event": "learn", "data": <digest>}` -- the same event shape
  every Autonomic ledger line uses).

      mix xaas.ultracode.learn              # most recent campaign row
      mix xaas.ultracode.learn --run <campaign-run-id>

  READ-ONLY on the database: the campaign row is fetched unscoped, facts
  come through `Xaas.Ultracode.Learn.campaign_facts/1` (itself read-only),
  and the ONLY write this task performs is the one ledger append.

  Unlike the wave loop (which fails open -- see
  `Xaas.Ultracode.Learn.Projection`'s fail-open law), the task REPORTS
  failures honestly: an unresolvable campaign or unavailable facts print
  `BLOCKED (<reason>)` and exit non-zero -- an unjudgeable learning digest
  is never printed as an empty one.
  """

  use Mix.Task

  require Ash.Query

  alias Xaas.Ultracode.{Campaign, Run}
  alias Xaas.Ultracode.Learn.Projection

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} = OptionParser.parse(args, strict: [run: :string])
    Mix.Task.run("app.start")

    case digest(opts[:run]) do
      {:ok, digest, ledger_path} ->
        print_digest(digest)
        :ok = append_learn_event(ledger_path, digest)
        Mix.shell().info("ledger:     learn event appended to #{ledger_path}")

      {:error, reason} ->
        Mix.shell().error("learn: BLOCKED (#{format_reason(reason)})")
        System.halt(1)
    end
  end

  # ------------------------------------------------------------------
  # Digest + append (public so the Chicago tests exercise the real logic)
  # ------------------------------------------------------------------

  @doc """
  Builds the learning digest for a campaign. With `nil`, resolves the most
  recent campaign row (the same rule `mix xaas.ultracode.audit` and
  `mix xaas.ultracode.status` use). Returns `{:ok, digest, ledger_path}`
  -- the ledger path the one `learn` event belongs to -- or
  `{:error, reason}` when the campaign cannot be judged or the facts are
  unavailable. Reads only: the digest mutates nothing.
  """
  def digest(nil) do
    case most_recent_campaign() do
      {:ok, %Run{} = campaign} -> digest(campaign.id)
      {:error, _} = err -> err
    end
  end

  def digest(campaign_id) when is_binary(campaign_id) do
    with {:ok, _campaign} <- fetch_campaign(campaign_id),
         {:ok, facts} <- facts(campaign_id) do
      {:ok, Projection.digest(facts, campaign_id), ledger_path(campaign_id)}
    end
  end

  @doc """
  Appends exactly one `learn` event line (`{"ts", "event": "learn",
  "data": <digest>}`) to the campaign ledger -- this task's ONLY write.
  """
  @spec append_learn_event(String.t(), map()) :: :ok
  def append_learn_event(ledger_path, digest) when is_binary(ledger_path) and is_map(digest) do
    line =
      Jason.encode!(%{
        ts: DateTime.to_iso8601(DateTime.utc_now()),
        event: "learn",
        data: digest
      }) <> "\n"

    File.mkdir_p!(Path.dirname(ledger_path))
    File.write!(ledger_path, line, [:append])
    :ok
  end

  defp facts(campaign_id) do
    case Projection.resolve_facts(campaign_id) do
      {:ok, facts} when is_map(facts) ->
        {:ok, facts}

      # The Learn contract's fail-closed OCEL gate: name the violations,
      # never print a digest that the conformance court did not witness.
      {:error, :ocel_invalid, violations} ->
        {:error, {:ocel_invalid, campaign_id, violations}}

      {:error, reason} ->
        {:error, {:facts_unavailable, campaign_id, reason}}

      other ->
        {:error, {:bad_facts, campaign_id, other}}
    end
  end

  defp ledger_path(campaign_id),
    do: Path.join(Campaign.campaign_dir(campaign_id), "ledger.ndjson")

  defp print_digest(digest) do
    shell = Mix.shell()

    shell.info("campaign:   #{digest["campaign_id"]} (ocel_valid: #{digest["ocel_valid"]})")

    Enum.each(digest["items"], fn item ->
      shell.info(
        "  item #{item["item_id"]}: attempts=#{item["attempts"]} final=#{item["final"]} " <>
          "court_verdicts=#{item["court_verdicts"]} " <>
          "fingerprints=#{length(item["failure_fingerprints"])} hint=#{item["hint"]}"
      )
    end)

    agg = digest["aggregate"]

    shell.info(
      "aggregate:  attempts_total=#{agg["attempts_total"]} rate_limits=#{agg["rate_limits"]} " <>
        "reaps=#{agg["reaps"]} median_attempt_seconds=#{agg["median_attempt_seconds"]}"
    )
  end

  # ------------------------------------------------------------------
  # Campaign row reads (unscoped + authorize?: false -- the same internal
  # audit path every sibling internal tool in this folder uses)
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

  defp format_reason({:facts_unavailable, campaign_id, reason}),
    do: "learning facts unavailable for campaign #{campaign_id}: #{inspect(reason)}"

  defp format_reason({:ocel_invalid, campaign_id, violations}) do
    first =
      case violations do
        [] -> "no violations reported"
        [v | _] -> "#{violation_field(v, :path)} #{violation_field(v, :reason)}"
      end

    "campaign #{campaign_id} failed the OCEL conformance court (#{length(violations)} " <>
      "violation(s)); first: #{first}"
  end

  defp format_reason({:bad_facts, campaign_id, other}),
    do: "campaign #{campaign_id} returned malformed facts: #{inspect(other)}"

  defp format_reason({:not_a_campaign, id}), do: "run #{id} is not a campaign row"
  defp format_reason(:campaign_not_found), do: "campaign_not_found"
  defp format_reason(:no_campaign_found), do: "no campaign row exists"

  defp format_reason(reason), do: inspect(reason)

  defp violation_field(v, key) when is_map(v) do
    to_string(Map.get(v, key) || Map.get(v, Atom.to_string(key)) || "?")
  end

  defp violation_field(v, _key), do: to_string(v)
end
