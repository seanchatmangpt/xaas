defmodule Xaas.Ultracode.Learn.Projection do
  # Attributes BEFORE the moduledoc: the moduledoc interpolates @max_chars.
  @max_chars 400
  @facts_ttl_ms 300_000
  @context_header "\n\nLEARNED CONTEXT (prior campaign attempts, advisory):\n"

  @moduledoc """
  Projects OCEL-derived campaign learning into worker behavior.

  The facts come from `Xaas.Ultracode.Learn.campaign_facts/1` (contract:
  `{:ok, %{campaign_id, generated_at, ocel_valid: true, items, aggregate,
  hints}}` -- `hints` carries text ONLY for non-alive items, derived
  deterministically from court diagnostics). This module turns those facts
  into the three behavioral surfaces:

    * `repair_context/2` -- a deterministic, bounded (<= #{@max_chars}
      chars) block appended to a repair attempt's Run goal. The loop's own
      "PREVIOUS ATTEMPT(S) WERE REJECTED BY THE INDEPENDENT COURT" text
      keeps its position; the learned block rides after it.
    * `ticket_section/2` + `stamp_ticket/3` -- the ticket JSON's `"learn"`
      section (hints + failure fingerprints + court verdicts), stamped on
      attempt >= 2 only.
    * `digest/2` -- the `mix xaas.ultracode.learn` per-item + aggregate
      digest, printed by the task and appended verbatim as the campaign
      ledger's one `learn` event.

  ## Fail-open law

  Learning is ADVISORY. The repair loop must make progress with Learn
  absent, erroring, or empty: every failure collapses to `nil` facts and
  therefore an empty context / no ticket section -- never a raise, never a
  blocked attempt, nothing loud. Only callers that must REPORT failures
  honestly (`mix xaas.ultracode.learn`, via `resolve_facts/1`) see the raw
  `{:error, term}`.

  ## Campaign identity

  The loop's ctx knows its campaign only through the ledger path
  (`<ticket_dir>/campaign-<8-hex>/ledger.ndjson`, the exact shape
  `Xaas.Ultracode.Campaign` hands every wave). `campaign_id/1` extracts
  that token and resolves it to the FULL campaign Run id through the real
  rows (goal-marker filtered); when the DB is unavailable or the row is
  gone, the 8-char token itself is passed -- `Campaign.campaign_dir/1`
  re-slices either form onto the same directory, so both identify the same
  facts source.

  A standalone `Autonomic.run` (no campaign row; an `autonomic-<nonce>`
  output dir) has NO campaign identity: `campaign_id/1` returns nil and
  the loop runs hint-free -- by design, not by failure.

  ## Resolver seam

  `campaign_facts/1` calls through `config :xaas, :ultracode_learn_facts`
  (default `{Xaas.Ultracode.Learn, :campaign_facts}`), the same `{module,
  fun}` seam shape as `:ultracode_wave_runner`: tests inject real fact
  FIXTURES (never interaction mocks), and the E3/E4 wave reconciliation
  retargets one tuple -- never a call site.
  """

  require Ash.Query

  alias Xaas.Ultracode.{Campaign, Run}

  # ------------------------------------------------------------------
  # Entry point the Autonomic repair-goal/ticket assembly calls
  # ------------------------------------------------------------------

  @doc """
  Everything the wave loop needs for one item's learning projection, in one
  fail-open call: `context` (append to the repair goal; `""` when nothing
  was learned) and `ticket` (the `"learn"` section; nil when nothing was
  learned). Never raises -- the loop must not depend on Learn to progress.

  Memoized on the ctx's LEDGER PATH (stable for a whole wave), so BOTH the
  campaign-id resolution (one DB read) and the Learn facts fetch happen at
  most once per TTL window -- never once per attempt.
  """
  @spec item_learning(map(), term()) :: %{context: String.t(), ticket: map() | nil}
  def item_learning(ctx, item_id) when is_map(ctx) do
    facts = facts_for_ledger(Map.get(ctx, :ledger))

    %{context: repair_context(facts, item_id), ticket: ticket_section(facts, item_id)}
  rescue
    _ -> %{context: "", ticket: nil}
  end

  def item_learning(_ctx, _item_id), do: %{context: "", ticket: nil}

  defp facts_for_ledger(ledger) when is_binary(ledger) do
    key = {:xaas_ultracode_learn_projection_ledger, ledger}

    case :persistent_term.get(key, :miss) do
      {expires_at, facts} when is_integer(expires_at) ->
        if System.monotonic_time(:millisecond) < expires_at do
          facts
        else
          fetch_ledger_facts(ledger, key)
        end

      _ ->
        fetch_ledger_facts(ledger, key)
    end
  end

  defp facts_for_ledger(_ledger), do: nil

  defp fetch_ledger_facts(ledger, key) do
    facts = campaign_facts(campaign_id(%{ledger: ledger}))
    :persistent_term.put(key, {System.monotonic_time(:millisecond) + @facts_ttl_ms, facts})
    facts
  end

  # ------------------------------------------------------------------
  # Repair-goal block (surface 1)
  # ------------------------------------------------------------------

  @doc """
  The deterministic, bounded (<= #{@max_chars} chars) learning block for
  one item's repair goal: prior attempts, final-so-far, court verdicts,
  and the item's hint. Empty string when there are no facts or no hint for
  the item (per the Learn contract, hints exist only for non-alive items),
  so a repair is never blocked -- and never decorated -- by an unavailable
  or empty Learn.
  """
  @spec repair_context(term(), term()) :: String.t()
  def repair_context(facts, item_id)

  def repair_context(facts, item_id) when is_map(facts) and is_binary(item_id) do
    hint = hint_text(facts, item_id)

    if hint == "" do
      ""
    else
      item = item_facts(facts, item_id)

      block =
        [prior_line(item), verdicts_line(item), "hint: " <> hint]
        |> Enum.reject(&is_nil/1)
        |> Enum.join("\n")

      String.slice(@context_header <> block, 0, @max_chars)
    end
  end

  def repair_context(_facts, _item_id), do: ""

  defp prior_line(item) do
    with attempts when is_integer(attempts) <- get_field(item, :attempts),
         final when final != nil <- get_field(item, :final) do
      "prior attempts: #{attempts}, final standing: #{fmt_scalar(final)}"
    else
      _ -> nil
    end
  end

  defp verdicts_line(item) do
    case get_field(item, :court_verdicts) do
      verdicts when is_list(verdicts) and verdicts != [] ->
        "court verdicts: " <> Enum.map_join(verdicts, "; ", &fmt_scalar/1)

      _ ->
        nil
    end
  end

  # ------------------------------------------------------------------
  # Ticket section (surface 2)
  # ------------------------------------------------------------------

  @doc """
  The ticket JSON's `"learn"` section for `item_id` (hint, failure
  fingerprints, court verdicts, attempts/final), or nil when there is
  nothing learned -- the same fail-open law as `repair_context/2`.
  Deterministic: identical facts produce an identical section (the ticket
  file is rewritten whole per attempt, so re-stamping is idempotent by
  construction).
  """
  @spec ticket_section(term(), term()) :: map() | nil
  def ticket_section(facts, item_id) when is_map(facts) and is_binary(item_id) do
    hint = hint_text(facts, item_id)

    if hint == "" do
      nil
    else
      item = item_facts(facts, item_id)

      %{"hint" => hint}
      |> put_present("attempts", int_or_nil(item, :attempts))
      |> put_present("final", scalar_or_nil(item, :final))
      |> put_present("court_verdicts", list_or_nil(item, :court_verdicts))
      |> put_present("failure_fingerprints", list_or_nil(item, :failure_fingerprints))
    end
  end

  def ticket_section(_facts, _item_id), do: nil

  @doc """
  Stamps a ticket map with the item's `"learn"` section -- on attempt >= 2
  only (the repair-attempt law; attempt 1 of a later wave still receives
  the hint through the repair goal, but a fresh attempt's ticket carries no
  same-worktree learn section). No section, or a non-integer attempt,
  returns the ticket unchanged.
  """
  @spec stamp_ticket(map(), term(), term()) :: map()
  def stamp_ticket(ticket, attempt, learn) when is_map(ticket) and is_integer(attempt) do
    section = if is_map(learn), do: Map.get(learn, :ticket), else: nil

    if attempt >= 2 and is_map(section) do
      Map.put(ticket, :learn, section)
    else
      ticket
    end
  end

  def stamp_ticket(ticket, _attempt, _learn) when is_map(ticket), do: ticket

  # ------------------------------------------------------------------
  # Digest (surface 3: mix xaas.ultracode.learn)
  # ------------------------------------------------------------------

  @doc """
  The `mix xaas.ultracode.learn` digest: one deterministic entry per item
  (sorted by item id; hint presence, not text -- the full hint text lives
  in the ticket) plus the aggregate. Printed by the task and appended
  verbatim as the campaign ledger's one `learn` event data.
  """
  @spec digest(map(), String.t()) :: map()
  def digest(facts, campaign_id) when is_map(facts) and is_binary(campaign_id) do
    hints = get_field(facts, :hints)

    items =
      facts
      |> get_field(:items)
      |> List.wrap()
      |> Enum.filter(&is_map/1)
      |> Enum.map(&item_digest(&1, hints))
      |> Enum.sort_by(& &1["item_id"])

    %{
      "campaign_id" => campaign_id,
      "ocel_valid" => get_field(facts, :ocel_valid) == true,
      "items" => items,
      "aggregate" => aggregate_digest(get_field(facts, :aggregate))
    }
  end

  def digest(_facts, campaign_id) when is_binary(campaign_id) do
    %{
      "campaign_id" => campaign_id,
      "ocel_valid" => false,
      "items" => [],
      "aggregate" => aggregate_digest(nil)
    }
  end

  defp item_digest(item, hints) do
    %{
      "item_id" => fmt_scalar(get_field(item, :item_id)),
      "attempts" => int_or_nil(item, :attempts),
      "final" => scalar_or_nil(item, :final),
      "court_verdicts" => count_of(get_field(item, :court_verdicts)),
      "failure_fingerprints" => get_field(item, :failure_fingerprints) || [],
      "hint" => hint_present?(hints, get_field(item, :item_id))
    }
  end

  defp hint_present?(hints, item_id) when is_map(hints) and is_binary(item_id) do
    case get_field(hints, item_id) do
      h when is_binary(h) and h != "" -> true
      _ -> false
    end
  end

  defp hint_present?(_, _), do: false

  defp aggregate_digest(agg) when is_map(agg) do
    %{
      "attempts_total" => get_field(agg, :attempts_total),
      "rate_limits" => get_field(agg, :rate_limits),
      "reaps" => get_field(agg, :reaps),
      "median_attempt_seconds" => get_field(agg, :median_attempt_seconds)
    }
  end

  defp aggregate_digest(_),
    do: %{
      "attempts_total" => nil,
      "rate_limits" => nil,
      "reaps" => nil,
      "median_attempt_seconds" => nil
    }

  # ------------------------------------------------------------------
  # Fail-open facts seam (memoized per campaign; TTL-bounded)
  # ------------------------------------------------------------------

  @doc """
  The campaign facts, fetched through the resolver seam at most once per
  #{@facts_ttl_ms} ms per campaign (`:persistent_term` memoization -- a
  wave fetches once, not once per attempt). Returns the facts map, or nil
  on ANY failure (`{:error, _}`, a raise -- including Learn not being
  loaded yet, a non-map payload). The fail-open law: nil facts mean "no
  hints", never "stop the loop".
  """
  @spec campaign_facts(String.t() | nil) :: map() | nil
  def campaign_facts(nil), do: nil

  def campaign_facts(campaign_id) when is_binary(campaign_id) do
    key = cache_key(campaign_id)

    case :persistent_term.get(key, :miss) do
      {expires_at, facts} when is_integer(expires_at) ->
        if System.monotonic_time(:millisecond) < expires_at do
          facts
        else
          fetch_facts(campaign_id, key)
        end

      _ ->
        fetch_facts(campaign_id, key)
    end
  end

  defp fetch_facts(campaign_id, key) do
    facts =
      try do
        case resolver().(campaign_id) do
          {:ok, facts} when is_map(facts) -> facts
          _ -> nil
        end
      rescue
        _ -> nil
      end

    :persistent_term.put(key, {System.monotonic_time(:millisecond) + @facts_ttl_ms, facts})
    facts
  end

  @doc """
  The RAW resolver result for callers that must report failures honestly
  (the `mix xaas.ultracode.learn` task) rather than fail open: exactly
  what the configured resolver returns, no rescue.
  """
  @spec resolve_facts(String.t()) :: {:ok, map()} | {:error, term()}
  def resolve_facts(campaign_id) when is_binary(campaign_id), do: resolver().(campaign_id)

  @doc false
  def clear_cache(campaign_id), do: :persistent_term.erase(cache_key(campaign_id))

  defp resolver do
    case Application.get_env(
           :xaas,
           :ultracode_learn_facts,
           {Xaas.Ultracode.Learn, :campaign_facts}
         ) do
      {mod, fun} when is_atom(mod) and is_atom(fun) -> &:erlang.apply(mod, fun, [&1])
      fun when is_function(fun, 1) -> fun
      _ -> fn _ -> {:error, :bad_learn_facts_config} end
    end
  end

  defp cache_key(campaign_id), do: {:xaas_ultracode_learn_projection, campaign_id}

  # ------------------------------------------------------------------
  # Campaign identity from the loop's ctx
  # ------------------------------------------------------------------

  @doc """
  The campaign id a wave-loop ctx belongs to: the `campaign-<8-hex>` token
  of its ledger path (the shape `Xaas.Ultracode.Campaign` hands every
  wave), resolved to the FULL campaign Run id when exactly one campaign row
  matches; the bare token when the DB cannot resolve it (read-only, and ANY
  failure falls back -- this function never raises). Standalone autonomic
  runs (an `autonomic-<nonce>` ledger) have no campaign: nil.
  """
  @spec campaign_id(map()) :: String.t() | nil
  def campaign_id(ctx) when is_map(ctx) do
    with ledger when is_binary(ledger) <- Map.get(ctx, :ledger),
         [_line, token] <- Regex.run(~r|/campaign-([0-9a-f]{8})/ledger\.ndjson$|, ledger) do
      full_campaign_id(token)
    else
      _ -> nil
    end
  end

  def campaign_id(_ctx), do: nil

  defp full_campaign_id(token) do
    case Run
         |> Ash.Query.for_read(:read_unscoped)
         |> Ash.Query.filter(like(goal, ^(Campaign.goal_marker() <> " %")))
         |> Ash.read(authorize?: false) do
      {:ok, rows} ->
        case Enum.filter(rows, &(is_binary(&1.id) and String.starts_with?(&1.id, token))) do
          [%Run{id: id}] -> id
          _ -> token
        end

      _ ->
        token
    end
  rescue
    _ -> token
  end

  # ------------------------------------------------------------------
  # Shape-tolerant accessors (atom keys per the Learn contract, string
  # keys accepted for JSON-round-tripped facts; anything else -> nil)
  # ------------------------------------------------------------------

  defp get_field(nil, _key), do: nil

  defp get_field(map, key) when is_map(map) do
    cond do
      is_map_key(map, key) ->
        Map.fetch!(map, key)

      is_atom(key) and is_map_key(map, Atom.to_string(key)) ->
        Map.fetch!(map, Atom.to_string(key))

      true ->
        nil
    end
  end

  defp get_field(_other, _key), do: nil

  defp item_facts(facts, item_id) do
    facts
    |> get_field(:items)
    |> List.wrap()
    |> Enum.find(nil, fn
      item when is_map(item) -> get_field(item, :item_id) == item_id
      _ -> false
    end)
  end

  defp hint_text(facts, item_id) do
    case get_field(get_field(facts, :hints), item_id) do
      hint when is_binary(hint) -> String.slice(hint, 0, @max_chars)
      _ -> ""
    end
  end

  defp int_or_nil(item, key) do
    case get_field(item, key) do
      v when is_integer(v) -> v
      _ -> nil
    end
  end

  # `final` is an atom in the Learn contract (:alive | :partial_alive |
  # :blocked) and a binary in JSON-round-tripped facts -- stringify either.
  defp scalar_or_nil(item, key) do
    case get_field(item, key) do
      nil -> nil
      v -> fmt_scalar(v)
    end
  end

  defp list_or_nil(item, key) do
    case get_field(item, key) do
      v when is_list(v) -> v
      _ -> nil
    end
  end

  defp count_of(v) when is_list(v), do: length(v)
  defp count_of(_), do: 0

  defp put_present(map, _key, nil), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)

  defp fmt_scalar(v) when is_binary(v), do: v
  defp fmt_scalar(v) when is_atom(v) and not is_boolean(v), do: Atom.to_string(v)
  defp fmt_scalar(v), do: inspect(v)
end
