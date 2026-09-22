defmodule Xaas.Ultracode.Learn do
  @moduledoc """
  The learning loop's core: closes the OCEL v2 circuit by turning what the
  ultracode campaigns ALREADY persisted (validated OCEL 2.0 run logs + the
  campaign ledger) into deterministic, model-free facts that shape the NEXT
  wave's agent behavior. `campaign_facts/2` is the entry the projection side
  consumes.

  ## Fail-closed OCEL gate (the law of this module)

  This module consumes ONLY validator-passing OCEL 2.0 logs. Every Run named
  by the campaign ledger's `attempt_start` events is exported through
  `Xaas.Ultracode.OcelEgress.export_run/2` into a temp dir, and EVERY export
  is adjudicated by `Xaas.Ultracode.Ocel.Validator.validate_file/1`. One
  violation anywhere, or one run that cannot be exported, and the WHOLE
  analysis is refused -- invalid logs are never analyzed, never partially
  analyzed, never repaired here. The refusal shapes are distinct:

    * `{:error, :ocel_invalid, violations}` -- a real conformance verdict
      from the court; `violations` are the validator's own
      `%{path: _, reason: _}` maps, verbatim, for the projection side to
      render;
    * `{:error, {:run_export_failed, run_id, reason}}` -- the egress could
      not produce the log at all.

  `facts.ocel_valid` is therefore ALWAYS `true` in the success shape: the
  field's absence of a `false` case is the point.

  ## THE CONTRACT (stable surface -- the projection side compiles against it)

      Learn.campaign_facts(campaign_id, opts \\\\ []) ::
        {:ok, facts} | {:error, :ocel_invalid, violations} | {:error, term()}

      facts = %{
        campaign_id: String.t(),
        generated_at: DateTime.t(),
        ocel_valid: true,                    # ALWAYS true; invalid OCEL is the error tuple
        items: [
          %{
            item_id: String.t(),
            attempts: non_neg_integer(),     # attempt_start events for this item
            final: :alive | :partial_alive | :blocked,
            court_verdicts: [atom()],        # receipt outcomes in attempt order
            failure_fingerprints: [String.t()]  # deduped, sorted, path-free
          }
        ],
        aggregate: %{
          attempts_total: non_neg_integer(),
          rate_limits: non_neg_integer(),
          reaps: non_neg_integer(),
          median_attempt_seconds: float() | nil
        },
        hints: %{item_id => hint_text}       # ONLY for non-alive items
      }

      Learn.run_facts(run_id) ::
        {:ok, facts} | {:error, :ocel_invalid, violations} | {:error, term()}

  `run_facts/1` is the same shape for ONE Run (one item): `campaign_id`
  holds the run id, `items` holds one entry whose `item_id` is parsed from
  the Run's persisted `exact_subject` (`"<alias>-autonomic:<item>#<n>:<run>"`,
  falling back to the run id), `attempts`/`attempts_total` count the valid
  log's Epoch objects, and `aggregate` keeps every key for shape parity --
  `rate_limits`/`reaps` are ledger-derived and 0 there;
  `median_attempt_seconds` comes from the log's own persisted
  epoch_started→epoch-terminal moments.

  `hints` values are DETERMINISTIC: built from that item's court diagnostics
  (normalized receipt failure / CHI-ASSERT lines, bounded size) plus its
  attempt outcome sequence. No model calls, no timestamps, no wall-clock in
  the text -- the same ledger + rows always produce byte-identical hints.
  `generated_at` is the ONLY moment in the returned map, and it never enters
  a hint.

  ## Where each fact comes from

    * the campaign ledger (`<campaign_dir>/ledger.ndjson`, dir via
      `Xaas.Ultracode.Campaign.campaign_dir/1`, overridable with the
      `:ledger` opt): item ids, attempt counts, the
      attempt_start→worker_returned duration pairs behind
      `median_attempt_seconds`, rate-limit results (the atom `:rate_limited`
      or an error text carrying the provider's own markers: `[1302]`,
      `Rate limit reached`, `rate_limit_error`), `reap` counts,
      `item_done`/`item_blocked` finals, and `attempt_failed` failure lines.
    * the VALID OCEL documents: per-attempt receipt outcomes (`receipt_closed`
      events), refusal reasons (`refused` events), epoch terminal moments.
    * the sealed Receipts whose ids the VALID OCEL witnesses (lawful
      `:for_epoch` read): `fabric_verifier.court_receipt.observation`
      failures and failed gates -- the court diagnostics behind hints.

  Fingerprints (`fingerprint/1`) normalize court failure lines: absolute
  paths and worktree prefixes are stripped, `dir/file.ext::Module.test`
  collapses to `Module.test`, and the gate id + reason class are kept. The
  deduped, sorted list is a stable identity for "the same failure again".
  An attempted item with NO terminal ledger fact (`item_done`/
  `item_blocked`) reports `final: :blocked` -- nothing was proven standing.

  ## Options (`campaign_facts/2`)

    * `:ledger` -- explicit campaign ledger path (default: the campaign dir
      under the configured ticket dir).
    * `:tmp_dir` -- where run exports are written (default: a fresh OS tmp
      subdir; removed when the call returns).
    * `:export` -- a 2-arity fault-injection seam
      `(run_id, tmp_dir -> {:ok, path} | {:error, term})`, default
      `&OcelEgress.export_run/2`. Test seam only: a corrupt "export" lets a
      test exercise the REAL fail-closed gate end-to-end. Production callers
      never pass it.

  ## Ownership note

  This module owns NO mix task and NO projection. The consumer (mix task,
  prompt/plan projection) is a sibling surface: call `campaign_facts/2` and
  render the returned map downstream. Hints are the only free text this
  module manufactures, and they are pure functions of persisted facts.
  """

  alias Xaas.Ultracode.{Campaign, Epoch, Ocel, OcelEgress, Receipt}

  require Ash.Query

  @typedoc "The facts map shape -- the stable contract the projection side compiles against."
  @type facts :: %{
          required(:campaign_id) => String.t(),
          required(:generated_at) => DateTime.t(),
          required(:ocel_valid) => true,
          required(:items) => [item()],
          required(:aggregate) => %{
            required(:attempts_total) => non_neg_integer(),
            required(:rate_limits) => non_neg_integer(),
            required(:reaps) => non_neg_integer(),
            required(:median_attempt_seconds) => float() | nil
          },
          required(:hints) => %{optional(String.t()) => String.t()}
        }

  @typedoc "One learned item fact."
  @type item :: %{
          required(:item_id) => String.t(),
          required(:attempts) => non_neg_integer(),
          required(:final) => :alive | :partial_alive | :blocked,
          required(:court_verdicts) => [atom()],
          required(:failure_fingerprints) => [String.t()]
        }

  @typedoc "One OCEL conformance violation (the validator's own shape, verbatim)."
  @type violation :: %{path: String.t(), reason: String.t()}

  # Receipt-outcome strings that count as a court verdict in OCEL
  # receipt_closed events. A :heartbeat receipt emits heartbeat_recorded
  # (never receipt_closed) in the egress, so the non-standing class can
  # never leak in here by construction. The atom values are LITERALS of this
  # module -- no dynamic-atom creation anywhere on this path.
  @verdict_atoms %{
    "alive" => :alive,
    "partial_alive" => :partial_alive,
    "blocked" => :blocked,
    "build_broken" => :build_broken,
    "unsupported" => :unsupported,
    "refused" => :refused
  }

  # worker_returned results that mean "the provider rate-limited us": either
  # the loop's own `:rate_limited` atom, or an error text carrying the
  # provider's markers. The markers, not the provider name, are the fact.
  @rate_markers [":rate_limited", "[1302]", "Rate limit reached", "rate_limit_error"]

  @hint_max_chars 600
  @hint_truncation_mark "…[truncated]"

  @default_export &OcelEgress.export_run/2

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Learns the facts of one campaign: loads its ledger, exports and validates
  the OCEL 2.0 log of EVERY attempt Run the ledger names, and derives the
  contract facts from the valid logs joined with the ledger.
  """
  @spec campaign_facts(String.t(), keyword()) ::
          {:ok, facts()} | {:error, :ocel_invalid, [violation()]} | {:error, term()}
  def campaign_facts(campaign_id, opts \\ []) when is_binary(campaign_id) and is_list(opts) do
    ledger = opts[:ledger] || default_ledger(campaign_id)
    tmp_dir = ensure_tmp_dir(opts)

    try do
      with {:ok, events} <- read_ledger(ledger),
           attempts when is_list(attempts) <- require_attempts(events),
           {:ok, docs} <- export_and_validate(run_ids(events), tmp_dir, opts) do
        {:ok, build_facts(campaign_id, events, docs)}
      end
    after
      File.rm_rf(tmp_dir)
    end
  end

  @doc """
  Learns the facts of ONE Run (same shape, one item): exports and validates
  that Run's OCEL 2.0 log, then derives the item's verdicts, fingerprints
  and -- when the log does not prove alive -- its hint, from the valid log
  and the Run's sealed Receipts alone.
  """
  @spec run_facts(String.t()) ::
          {:ok, facts()} | {:error, :ocel_invalid, [violation()]} | {:error, term()}
  def run_facts(run_id) when is_binary(run_id) do
    tmp_dir = ensure_tmp_dir([])

    try do
      with {:ok, path} <- @default_export.(run_id, tmp_dir),
           {:ok, doc} <- gate_and_decode(path) do
        {:ok, build_run_facts(run_id, digest(doc))}
      end
    after
      File.rm_rf(tmp_dir)
    end
  end

  @doc """
  Normalizes one court failure line into a fingerprint: absolute paths and
  worktree prefixes stripped, `dir/file.ext::Module.test` collapsed to
  `Module.test`, whitespace collapsed. Deterministic and path-free.
  """
  @spec fingerprint(String.t()) :: String.t()
  def fingerprint(line) when is_binary(line) do
    line
    |> String.replace(~r{\s+}, " ")
    |> String.replace(~r{(^|\s)/\S*}, " ")
    |> String.replace(~r{[\w.@/-]+\.(?:py|ex|exs|js|ts|rb)::}, "")
    |> String.replace(~r{\s+}, " ")
    |> String.trim()
  end

  # ---------------------------------------------------------------------------
  # Ledger (append-only ndjson; the campaign's durable record)
  # ---------------------------------------------------------------------------

  defp default_ledger(campaign_id),
    do: Path.join(Campaign.campaign_dir(campaign_id), "ledger.ndjson")

  defp read_ledger(ledger) do
    if File.regular?(ledger) do
      ledger
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.with_index(1)
      |> Enum.reduce_while({:ok, []}, fn {line, n}, {:ok, acc} ->
        case JSON.decode(line) do
          {:ok, event} when is_map(event) -> {:cont, {:ok, [event | acc]}}
          {:ok, other} -> {:halt, {:error, {:ledger_corrupt, n, other}}}
          {:error, _} -> {:halt, {:error, {:ledger_corrupt, n, line}}}
        end
      end)
      |> case do
        {:ok, events} -> {:ok, Enum.reverse(events)}
        {:error, _} = err -> err
      end
    else
      {:error, {:ledger_not_found, ledger}}
    end
  end

  # The event payload: attempt-life events carry a "data" wrapper; the
  # campaign-level events (campaign_start, reap, campaign_end) are flat.
  defp payload(event), do: Map.get(event, "data") || Map.drop(event, ["event", "ts"])

  defp event_ts(event) do
    case event["ts"] do
      ts when is_binary(ts) ->
        case DateTime.from_iso8601(ts) do
          {:ok, dt, 0} -> dt
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp attempts(events) do
    for event <- events,
        event["event"] == "attempt_start",
        p = payload(event),
        is_binary(p["item"]),
        is_binary(p["run_id"]),
        is_binary(p["epoch_id"]) do
      %{item: p["item"], run_id: p["run_id"], epoch_id: p["epoch_id"], ts: event_ts(event)}
    end
  end

  defp require_attempts(events) do
    case attempts(events) do
      [] -> {:error, :no_attempts}
      attempts -> attempts
    end
  end

  defp run_ids(events), do: events |> attempts() |> Enum.map(& &1.run_id) |> Enum.uniq()

  defp returns(events) do
    events
    |> Enum.filter(&(event(&1) == "worker_returned"))
    |> Enum.map(fn event ->
      p = payload(event)

      if is_binary(p["epoch_id"]) do
        {p["epoch_id"], %{result: p["result"], ts: event_ts(event)}}
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp event(event), do: Map.get(event, "event")

  # Ledger order is chronological: the LAST terminal fact per item wins.
  defp terminal_facts(events) do
    events
    |> Enum.flat_map(fn event ->
      p = payload(event)
      item = p["item"]

      case event(event) do
        "item_done" when is_binary(item) ->
          case p["accepted_via"] do
            "alive" -> [{item, :alive}]
            "partial_alive" -> [{item, :partial_alive}]
            _ -> []
          end

        "item_blocked" when is_binary(item) ->
          [{item, :blocked}]

        _ ->
          []
      end
    end)
    |> Map.new()
  end

  defp failures(events) do
    for event <- events,
        event(event) == "attempt_failed",
        p = payload(event),
        is_binary(p["item"]),
        is_binary(p["failure"]) do
      {p["item"], p["failure"]}
    end
  end

  defp rate_limited?(result) when is_binary(result),
    do: Enum.any?(@rate_markers, &String.contains?(result, &1))

  defp rate_limited?(_), do: false

  defp rate_limits(events) do
    Enum.count(events, fn event ->
      event(event) == "worker_returned" and rate_limited?(payload(event)["result"])
    end)
  end

  # ---------------------------------------------------------------------------
  # The OCEL gate: export + validate EVERY run; one violation refuses all
  # ---------------------------------------------------------------------------

  defp export_and_validate(run_ids, tmp_dir, opts) do
    export = opts[:export] || @default_export

    Enum.reduce_while(run_ids, {:ok, []}, fn run_id, {:ok, docs} ->
      case export.(run_id, tmp_dir) do
        {:ok, path} ->
          case gate_and_decode(path) do
            {:ok, doc} ->
              {:cont, {:ok, [{run_id, digest(doc)} | docs]}}

            {:error, :ocel_invalid, _} = refusal ->
              {:halt, refusal}

            # Defensive: gate_and_decode's decode cannot fail after a
            # passing validation, but the typed refusal stays honest.
            {:error, reason} ->
              {:halt, {:error, {:run_export_failed, run_id, reason}}}
          end

        {:error, reason} ->
          {:halt, {:error, {:run_export_failed, run_id, reason}}}
      end
    end)
    |> case do
      {:ok, docs} -> {:ok, Enum.reverse(docs)}
      {:error, :ocel_invalid, _} = refusal -> refusal
      {:error, _} = err -> err
    end
  end

  defp gate_and_decode(path) do
    case Ocel.Validator.validate_file(path) do
      {:ok, _report} -> JSON.decode(File.read!(path))
      {:error, violations} -> {:error, :ocel_invalid, violations}
    end
  end

  # ---------------------------------------------------------------------------
  # OCEL document digest: what a VALIDATED log says about its run
  # ---------------------------------------------------------------------------

  # Event/object ids are deterministic functions of the source row
  # ("<type>:<row-uuid>" / the row's own UUID), so the digest is a faithful
  # read of what the court just passed.
  defp digest(doc) do
    events = doc["ocel:events"] || []
    objects = doc["ocel:objects"] || []

    %{
      epoch_ids: for(o <- objects, o["type"] == "Epoch", do: o["id"]),
      receipt_epochs: receipt_epochs(objects),
      verdicts: verdicts(events),
      refusals: refusals(events),
      started: moments(events, "epoch_started"),
      terminals: terminal_moments(events)
    }
  end

  defp receipt_epochs(objects) do
    objects
    |> Enum.filter(&(&1["type"] == "Receipt"))
    |> Map.new(fn o ->
      epoch_rel =
        case Enum.find(o["relationships"] || [], &(&1["qualifier"] == "epoch")) do
          %{"objectId" => epoch_id} -> epoch_id
          _ -> nil
        end

      {o["id"], epoch_rel}
    end)
  end

  defp verdicts(events) do
    for e <- events,
        e["type"] == "receipt_closed",
        outcome = e["attributes"]["outcome"],
        verdict = Map.get(@verdict_atoms, outcome),
        {_, receipt_id} = split_event_id(e["id"]) do
      {receipt_id, verdict}
    end
  end

  defp refusals(events) do
    for e <- events,
        e["type"] == "refused",
        {_, receipt_id} = split_event_id(e["id"]),
        reason = e["attributes"]["refusal_reason"],
        is_binary(reason) do
      {receipt_id, reason}
    end
  end

  # Epoch-level event ids are "<event-type>:<epoch-uuid>"; already filtered
  # to one event type, the row part IS the epoch id.
  defp moments(events, type) do
    events
    |> Enum.filter(&(event_type(&1) == type))
    |> Map.new(fn e ->
      case row_id(e["id"]) do
        nil -> nil
        epoch_id -> {epoch_id, parse_moment(e["time"])}
      end
    end)
    |> Map.reject(fn {k, v} -> is_nil(k) or is_nil(v) end)
  end

  defp terminal_moments(events) do
    events
    |> Enum.filter(&(event_type(&1) in ["epoch_completed", "epoch_missed", "epoch_failed"]))
    |> Map.new(fn e ->
      case row_id(e["id"]) do
        nil -> nil
        epoch_id -> {epoch_id, parse_moment(e["time"])}
      end
    end)
    |> Map.reject(fn {k, v} -> is_nil(k) or is_nil(v) end)
  end

  defp event_type(event), do: Map.get(event, "type")

  # The row uuid after the (already-known) event type prefix.
  defp row_id(id) when is_binary(id) do
    case String.split(id, ":", parts: 2) do
      [_type, row_id] -> row_id
      _ -> nil
    end
  end

  defp row_id(_), do: nil

  defp parse_moment(time) when is_binary(time) do
    case DateTime.from_iso8601(time) do
      {:ok, dt, 0} -> dt
      _ -> nil
    end
  end

  defp parse_moment(_), do: nil

  defp split_event_id(id) when is_binary(id) do
    case String.split(id, ":", parts: 2) do
      [type, row_id] -> {type, row_id}
      _ -> nil
    end
  end

  defp split_event_id(_), do: nil

  # ---------------------------------------------------------------------------
  # Facts derivation (campaign)
  # ---------------------------------------------------------------------------

  defp build_facts(campaign_id, events, docs) do
    attempts = attempts(events)
    returns = returns(events)
    terminals = terminal_facts(events)
    failures = failures(events)
    docs_by_run = Map.new(docs)

    items =
      attempts
      |> Enum.map(& &1.item)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.map(fn item ->
        item_attempts = Enum.filter(attempts, &(&1.item == item))

        final = Map.get(terminals, item, :blocked)

        %{
          item_id: item,
          attempts: length(item_attempts),
          final: final,
          court_verdicts: court_verdicts(item_attempts, docs_by_run),
          failure_fingerprints:
            failure_fingerprints(item, item_attempts, docs_by_run, failures, final != :alive)
        }
      end)

    %{
      campaign_id: campaign_id,
      generated_at: DateTime.utc_now(),
      ocel_valid: true,
      items: items,
      aggregate: %{
        attempts_total: length(attempts),
        rate_limits: rate_limits(events),
        reaps: Enum.count(events, &(event(&1) == "reap")),
        median_attempt_seconds: median(attempt_seconds(attempts, returns))
      },
      hints: hints(items, attempts, returns)
    }
  end

  # One verdict list per item: every attempt's receipts (attributed via the
  # receipt object's own epoch relationship), in ledger attempt order.
  defp court_verdicts(item_attempts, docs_by_run) do
    Enum.flat_map(item_attempts, fn attempt ->
      case Map.get(docs_by_run, attempt.run_id) do
        nil ->
          []

        doc ->
          for {receipt_id, verdict} <- doc.verdicts,
              Map.get(doc.receipt_epochs, receipt_id) == attempt.epoch_id do
            verdict
          end
      end
    end)
  end

  # Fingerprints: the ledger's attempt_failed lines (normalized) plus, for
  # non-alive items, the OCEL-witnessed refusal reasons and the court
  # diagnostics of the receipts the valid log witnesses. Court-diagnostic
  # reads are capped to non-alive items: hints -- the facts that steer the
  # next wave -- are only manufactured for those.
  defp failure_fingerprints(item, item_attempts, docs_by_run, failures, with_court?) do
    ledger_fps =
      for {failed_item, failure} <- failures, failed_item == item do
        fingerprint(failure)
      end

    refusal_fps =
      if with_court? do
        Enum.flat_map(item_attempts, fn attempt ->
          case Map.get(docs_by_run, attempt.run_id) do
            nil ->
              []

            doc ->
              for {receipt_id, reason} <- doc.refusals,
                  Map.get(doc.receipt_epochs, receipt_id) == attempt.epoch_id do
                "refused #{reason}"
              end
          end
        end)
      else
        []
      end

    court_fps =
      if with_court? do
        item_attempts
        |> Enum.flat_map(fn attempt ->
          case Map.get(docs_by_run, attempt.run_id) do
            nil -> []
            doc -> [{attempt.epoch_id, witnessed_receipt_ids(doc, attempt.epoch_id)}]
          end
        end)
        |> court_diagnostics()
      else
        []
      end

    (ledger_fps ++ refusal_fps ++ court_fps)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp witnessed_receipt_ids(doc, epoch_id) do
    for {receipt_id, ^epoch_id} <- Map.to_list(doc.receipt_epochs), do: receipt_id
  end

  # The sealed receipts behind the fingerprints: loaded through the lawful
  # `:for_epoch` read, filtered to the ids the VALID OCEL witnesses.
  defp court_diagnostics(epoch_receipt_specs) do
    Enum.flat_map(epoch_receipt_specs, fn {epoch_id, receipt_ids} ->
      Receipt
      |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch_id})
      |> Ash.read()
      |> case do
        {:ok, receipts} ->
          for receipt <- receipts,
              receipt.id in receipt_ids,
              fingerprint <- receipt_failures(receipt.evidence) do
            fingerprint
          end

        {:error, _} ->
          # A receipt that cannot be read contributes NO diagnostic and NO
          # fabrication -- the ledger lines and refusal reasons above still
          # carry the item's failures.
          []
      end
    end)
  end

  # Court diagnostics from one sealed receipt's evidence: the observation's
  # failure rows and every gate the court reported as failed. Keys arrive
  # string-keyed from `Lease`; hand-sealed rows may carry atom keys, so each
  # level is normalized (never `String.to_existing_atom/1` on caller data).
  defp receipt_failures(evidence) when is_map(evidence) do
    observation =
      evidence
      |> string_keyed()
      |> Map.get("fabric_verifier")
      |> string_keyed()
      |> Map.get("court_receipt")
      |> string_keyed()
      |> Map.get("observation")
      |> string_keyed()

    failure_rows =
      case Map.get(observation, "failures", []) do
        rows when is_list(rows) ->
          for row <- rows,
              row = string_keyed(row),
              id = Map.get(row, "id"),
              is_binary(id),
              kind = Map.get(row, "kind", "fail") do
            "#{id} #{kind}"
          end

        _ ->
          []
      end

    failed_gates =
      case Map.get(observation, "gates", []) do
        gates when is_list(gates) ->
          for gate <- gates,
              gate = string_keyed(gate),
              Map.get(gate, "pass") == false,
              id = Map.get(gate, "id"),
              is_binary(id) do
            "#{id} fail"
          end

        _ ->
          []
      end

    failure_rows ++ failed_gates
  end

  defp receipt_failures(_), do: []

  defp string_keyed(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {to_string(key), value} end)

  defp string_keyed(_), do: %{}

  # ---------------------------------------------------------------------------
  # Aggregate + hints
  # ---------------------------------------------------------------------------

  defp attempt_seconds(attempts, returns) do
    for %{epoch_id: epoch_id, ts: start} <- attempts,
        start != nil,
        %{} = ret = Map.get(returns, epoch_id),
        ret.ts != nil do
      DateTime.diff(ret.ts, start, :millisecond) / 1000.0
    end
  end

  defp median([]), do: nil

  defp median(seconds) do
    sorted = Enum.sort(seconds)
    n = length(sorted)
    mid = div(n, 2)

    if rem(n, 2) == 1 do
      1.0 * Enum.at(sorted, mid)
    else
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2.0
    end
  end

  # Hints exist ONLY for non-alive items (contract law): a hint is the
  # deterministic, bounded diagnostic text the next wave's prompt can carry.
  defp hints(items, attempts, returns) do
    items
    |> Enum.reject(&(&1.final == :alive))
    |> Map.new(fn item ->
      outcome_classes =
        attempts
        |> Enum.filter(&(&1.item == item.item_id))
        |> Enum.map(&outcome_class(Map.get(returns, &1.epoch_id)))

      {item.item_id, hint(item, outcome_classes)}
    end)
  end

  defp outcome_class(%{result: result}) when is_binary(result) do
    cond do
      result == ":ok" -> "ok"
      rate_limited?(result) -> "rate_limited"
      String.starts_with?(result, "{:error") -> "error"
      true -> "returned"
    end
  end

  defp outcome_class(_), do: "no_return"

  defp hint(item, outcome_classes) do
    base =
      "item=#{item.item_id} attempts=#{item.attempts} final=#{item.final}" <>
        maybe_segment("outcomes", Enum.join(outcome_classes, "->")) <>
        maybe_segment(
          "verdicts",
          Enum.join(Enum.map(item.court_verdicts, &Atom.to_string/1), ",")
        ) <>
        maybe_segment("failures", Enum.join(item.failure_fingerprints, " | "))

    bound(base)
  end

  defp maybe_segment(_name, ""), do: ""
  defp maybe_segment(name, value), do: " #{name}=#{value}"

  defp bound(text) when byte_size(text) <= @hint_max_chars, do: text

  defp bound(text) do
    keep = @hint_max_chars - String.length(@hint_truncation_mark)
    String.slice(text, 0, keep) <> @hint_truncation_mark
  end

  # ---------------------------------------------------------------------------
  # Facts derivation (single run)
  # ---------------------------------------------------------------------------

  defp build_run_facts(run_id, doc) do
    item_id = run_item_id(run_id)

    verdicts = Enum.map(doc.verdicts, fn {_receipt_id, verdict} -> verdict end)

    final =
      case List.last(verdicts) do
        :alive -> :alive
        :partial_alive -> :partial_alive
        _ -> :blocked
      end

    refusal_fps =
      for {_receipt_id, reason} <- doc.refusals do
        "refused #{reason}"
      end

    court_fps =
      doc.epoch_ids
      |> Enum.map(&{&1, witnessed_receipt_ids(doc, &1)})
      |> court_diagnostics()

    fingerprints =
      (refusal_fps ++ court_fps) |> Enum.reject(&(&1 == "")) |> Enum.uniq() |> Enum.sort()

    item = %{
      item_id: item_id,
      attempts: length(doc.epoch_ids),
      final: final,
      court_verdicts: verdicts,
      failure_fingerprints: fingerprints
    }

    durations =
      for epoch_id <- doc.epoch_ids,
          start = Map.get(doc.started, epoch_id),
          terminal = Map.get(doc.terminals, epoch_id) do
        DateTime.diff(terminal, start, :millisecond) / 1000.0
      end

    %{
      campaign_id: run_id,
      generated_at: DateTime.utc_now(),
      ocel_valid: true,
      items: [item],
      aggregate: %{
        attempts_total: length(doc.epoch_ids),
        # Ledger-derived aggregates have no single-run input; the keys are
        # kept for shape parity with campaign_facts/2 (the contract).
        rate_limits: 0,
        reaps: 0,
        median_attempt_seconds: median(durations)
      },
      hints: if(final == :alive, do: %{}, else: %{item_id => hint(item, [])})
    }
  end

  # The item id hides in the persisted subject:
  # "<alias>-autonomic:<item>#<attempt>:<run>" -> "<item>".
  defp run_item_id(run_id) do
    Epoch
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(run_id == ^run_id)
    |> Ash.Query.sort(cycle: :asc, id: :asc)
    |> Ash.read()
    |> case do
      {:ok, epochs} ->
        Enum.find_value(epochs, run_id, fn epoch ->
          case subject_item(epoch.exact_subject) do
            nil -> nil
            item -> item
          end
        end)

      {:error, _} ->
        run_id
    end
  end

  defp subject_item(subject) when is_binary(subject) do
    case String.split(subject, ":", parts: 2) do
      [_alias_part, rest] ->
        rest |> String.split("#") |> List.first()

      _ ->
        nil
    end
  end

  defp subject_item(_), do: nil

  # ---------------------------------------------------------------------------
  # Temp dir
  # ---------------------------------------------------------------------------

  defp ensure_tmp_dir(opts) do
    case opts[:tmp_dir] do
      dir when is_binary(dir) ->
        File.mkdir_p!(dir)
        dir

      _ ->
        dir = Path.join(System.tmp_dir!(), "xaas-learn-#{System.unique_integer([:positive])}")
        File.mkdir_p!(dir)
        dir
    end
  end
end
