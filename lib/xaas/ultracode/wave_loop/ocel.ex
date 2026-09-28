defmodule Xaas.Ultracode.WaveLoop.Ocel do
  @moduledoc """
  OCEL 2.0 evidence for `Xaas.Ultracode.WaveLoop` ticks: every settled tick
  outcome (one `WaveLoop.finish/5` call) becomes ONE OCEL 2.0 event, written
  as one self-contained OCEL 2.0 document per line of an NDJSON sink next to
  the loop telemetry.

  ## Representation (reused, not invented)

  Each line is plain OCEL 2.0 JSON in exactly the shape
  `Xaas.Ultracode.OcelEgress` emits -- the four top-level keys
  `ocel:objectTypes` / `ocel:eventTypes` / `ocel:events` / `ocel:objects`,
  `{"name" => ...}` type declarations, `{objectId, qualifier}` relationships
  whose qualifier is the referenced object's type lowercased (the egress's
  one deterministic rule), and object ids that are the domain's own
  identifiers (row UUIDs), so a tick event joins against the derived Run
  log by `Epoch`/`Run`/`Receipt` id. Every document is validated by the
  existing court, `Xaas.Ultracode.Ocel.Validator.validate/1`, BEFORE it is
  appended; a document the court refuses is never written.

  ## Event

    * `type` = `"wave-loop:" <> outcome` (outcome as flattened in the
      telemetry line), declared in `ocel:eventTypes` (declared iff emitted).
    * `id` = `"wave-loop:tick-<n>:<step|none>:<outcome>"`.
    * `time` = the telemetry line's own `ts` (one clock read per tick).
    * `attributes`: `tick`, `step`, `outcome`, `policy_decision`
      (`Xaas.Ultracode.RecoveryPolicy.decide/2` on the outcome and the
      loop's own overload signal), `policy_digest`
      (`RecoveryPolicy.receipt().policy_digest`), `provider_overloaded`,
      `provider_breaker` (`Xaas.Ultracode.ProviderRecovery.state/1`).

  ## Objects (each related from the event; emitted only when the fact exists)

    | type       | id                              | source                                  |
    |------------|---------------------------------|-----------------------------------------|
    | `WaveStep` | `"wave-loop:step-" <> step`     | the tick's step id                      |
    | `Epoch`    | epoch UUID                      | `detail.epoch_id`                       |
    | `Run`      | run UUID                        | `Epoch.run_id` (read_unscoped)          |
    | `Receipt`  | receipt UUID(s)                 | `detail.reclaim_receipt_id` /`receipt_id`, else the epoch's sealed receipts |
    | `Provider` | provider name (`"zcode"`)       | the loop's provider                     |

  ## Failure law

  Emission NEVER changes a tick's outcome: every failure (unwritable path,
  DB read error, validator refusal) is caught, logged at `:warning`, and
  counted via `:telemetry` event `#{inspect([:xaas, :ultracode, :wave_loop, :ocel_emit])}`
  (`%{count: 1}`, metadata `%{status: :ok | :error, reason: term, path: path}`).
  Not silent, never fatal.

  ## Sink path

  `config :xaas, :ultracode_wave_loop_ocel_path` when set; otherwise derived
  from the telemetry path: `Path.rootname(telemetry_path) <> ".ocel.ndjson"`.
  """

  require Logger

  alias Xaas.Ultracode.{Epoch, ProviderRecovery, Receipt, RecoveryPolicy}
  alias Xaas.Ultracode.Ocel.Validator

  @telemetry_event [:xaas, :ultracode, :wave_loop, :ocel_emit]
  @object_type_rank %{"WaveStep" => 0, "Run" => 1, "Epoch" => 2, "Receipt" => 3, "Provider" => 4}

  @doc "The `:telemetry` event name counted on every emission attempt."
  @spec telemetry_event() :: [atom()]
  def telemetry_event, do: @telemetry_event

  @doc "The OCEL sink for a telemetry path (config override, else derived)."
  @spec ocel_path(Path.t()) :: Path.t()
  def ocel_path(telemetry_path) do
    Application.get_env(:xaas, :ultracode_wave_loop_ocel_path) ||
      Path.rootname(telemetry_path) <> ".ocel.ndjson"
  end

  @doc """
  Emits one tick event. `tick` is a map with `:tick`, `:step`, `:outcome`
  (atom or tagged tuple), `:outcome_name` (flattened string), `:time`
  (ISO8601 UTC), `:detail` (the finish detail map), `:provider`,
  `:telemetry_path`. Returns `{:ok, path}` or `{:error, reason}`; never
  raises.
  """
  @spec emit(map()) :: {:ok, Path.t()} | {:error, term()}
  def emit(%{telemetry_path: telemetry_path} = tick) do
    path = ocel_path(telemetry_path)

    result =
      try do
        document = build_document(enrich(tick))

        with {:ok, _report} <- validate(document),
             :ok <- append(path, document) do
          {:ok, path}
        end
      rescue
        error -> {:error, {:raised, Exception.message(error)}}
      catch
        kind, reason -> {:error, {kind, reason}}
      end

    report(result, path)
  end

  @doc """
  Pure core: builds the OCEL 2.0 document for one enriched tick (no IO).
  Expected keys beyond `emit/1`'s: `:run_id`, `:receipt_ids`,
  `:policy_decision`, `:policy_digest`, `:overloaded?`, `:breaker`.
  """
  @spec build_document(map()) :: map()
  def build_document(tick) do
    event_type = "wave-loop:" <> tick.outcome_name
    epoch_id = detail_value(tick.detail, :epoch_id)

    objects =
      Enum.concat([
        opt_object(tick.step && "wave-loop:step-#{tick.step}", "WaveStep", %{
          "step" => tick.step
        }),
        opt_object(tick[:run_id], "Run", %{}),
        opt_object(epoch_id, "Epoch", %{}, rels_opt(tick[:run_id], "run")),
        Enum.flat_map(tick[:receipt_ids] || [], fn id ->
          opt_object(id, "Receipt", %{}, rels_opt(epoch_id, "epoch"))
        end),
        opt_object(tick.provider, "Provider", drop_nils(%{"breaker" => atom(tick[:breaker])}))
      ])
      |> Enum.uniq_by(& &1["id"])
      |> Enum.sort_by(&{@object_type_rank[&1["type"]], &1["id"]})

    event = %{
      "id" => "wave-loop:tick-#{tick.tick}:#{tick.step || "none"}:#{tick.outcome_name}",
      "type" => event_type,
      "time" => tick.time,
      "attributes" =>
        drop_nils(%{
          "tick" => tick.tick,
          "step" => tick.step,
          "outcome" => tick.outcome_name,
          "policy_decision" => atom(tick[:policy_decision]),
          "policy_digest" => tick[:policy_digest],
          "provider_overloaded" => tick[:overloaded?],
          "provider_breaker" => atom(tick[:breaker])
        }),
      "relationships" =>
        objects
        |> Enum.map(&rel(&1["id"], String.downcase(&1["type"])))
        |> Enum.sort_by(& &1["objectId"])
    }

    %{
      "ocel:objectTypes" =>
        objects
        |> Enum.map(& &1["type"])
        |> Enum.uniq()
        |> Enum.map(&%{"name" => &1}),
      "ocel:eventTypes" => [%{"name" => event_type}],
      "ocel:events" => [event],
      "ocel:objects" => objects
    }
  end

  @doc "Validates one document with the existing OCEL 2.0 court."
  @spec validate(map()) :: {:ok, map()} | {:error, term()}
  def validate(document) do
    # The court is spec-derived over DECODED JSON; round-trip so it judges
    # exactly the bytes the sink will hold.
    case Validator.validate(JSON.decode!(JSON.encode!(document))) do
      {:ok, report} -> {:ok, report}
      {:error, violations} -> {:error, {:ocel_invalid, violations}}
    end
  end

  # ------------------------------------------------------------------
  # Enrichment: policy, breaker, run, receipts (each best-effort)
  # ------------------------------------------------------------------

  defp enrich(tick) do
    overloaded? =
      safe(fn -> Xaas.Ultracode.WaveLoop.provider_overloaded?(tick.telemetry_path, []) end, false)

    breaker = safe(fn -> ProviderRecovery.state(tick.provider) end, nil)
    epoch_id = detail_value(tick.detail, :epoch_id)
    run_id = safe(fn -> run_id_of(epoch_id) end, nil)

    Map.merge(tick, %{
      overloaded?: overloaded?,
      breaker: breaker,
      policy_decision: RecoveryPolicy.decide(tick.outcome, overloaded?),
      policy_digest: RecoveryPolicy.receipt().policy_digest,
      run_id: run_id,
      receipt_ids: receipt_ids(tick.detail, epoch_id)
    })
  end

  defp run_id_of(nil), do: nil

  defp run_id_of(epoch_id) do
    case Ash.get(Epoch, epoch_id, action: :read_unscoped, authorize?: false) do
      {:ok, %Epoch{run_id: run_id}} -> run_id
      _ -> nil
    end
  end

  # Explicit receipt ids in the finish detail win (a reclaim names its own
  # receipt); otherwise the epoch's sealed receipts are the receipt facts.
  defp receipt_ids(detail, epoch_id) do
    explicit =
      [detail_value(detail, :reclaim_receipt_id), detail_value(detail, :receipt_id)]
      |> Enum.filter(&is_binary/1)

    cond do
      explicit != [] -> Enum.uniq(explicit)
      is_binary(epoch_id) -> safe(fn -> sealed_receipt_ids(epoch_id) end, [])
      true -> []
    end
  end

  defp sealed_receipt_ids(epoch_id) do
    Receipt
    |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch_id})
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end

  defp safe(fun, default) do
    fun.()
  rescue
    _ -> default
  catch
    _, _ -> default
  end

  # ------------------------------------------------------------------
  # Sink + reporting
  # ------------------------------------------------------------------

  defp append(path, document) do
    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, JSON.encode!(document) <> "\n", [:append]) do
      :ok
    else
      {:error, reason} -> {:error, {:ocel_write, path, reason}}
    end
  end

  defp report({:ok, _} = ok, path) do
    :telemetry.execute(@telemetry_event, %{count: 1}, %{status: :ok, reason: nil, path: path})
    ok
  end

  defp report({:error, reason} = error, path) do
    Logger.warning(
      "[ultracode-wave-loop] OCEL emission failed (tick outcome unchanged): " <>
        String.slice(inspect(reason, limit: 20), 0, 500)
    )

    :telemetry.execute(@telemetry_event, %{count: 1}, %{
      status: :error,
      reason: reason,
      path: path
    })

    error
  end

  # ------------------------------------------------------------------
  # Constructors
  # ------------------------------------------------------------------

  defp opt_object(id, type, attributes, relationships \\ [])
  defp opt_object(nil, _type, _attributes, _relationships), do: []

  defp opt_object(id, type, attributes, relationships) when is_binary(id) do
    [
      %{
        "id" => id,
        "type" => type,
        "attributes" => drop_nils(attributes),
        "relationships" => relationships
      }
    ]
  end

  defp rels_opt(nil, _qualifier), do: []
  defp rels_opt(object_id, qualifier), do: [rel(object_id, qualifier)]

  defp rel(object_id, qualifier), do: %{"objectId" => object_id, "qualifier" => qualifier}

  defp detail_value(detail, key) when is_map(detail) do
    Map.get(detail, key) || Map.get(detail, Atom.to_string(key))
  end

  defp detail_value(_detail, _key), do: nil

  defp atom(nil), do: nil
  defp atom(value) when is_atom(value), do: Atom.to_string(value)
  defp atom(value) when is_binary(value), do: value
  defp atom(value), do: inspect(value)

  defp drop_nils(map), do: map |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> Map.new()
end
