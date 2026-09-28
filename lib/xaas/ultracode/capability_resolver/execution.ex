defmodule Xaas.Ultracode.CapabilityResolver.Execution do
  @moduledoc """
  Deterministic EXECUTION of the capability-resolution court's non-frontier
  verdicts (`Xaas.Ultracode.CapabilityResolver`). The court decides; this
  module carries the decision out without a coding worker, and never fakes
  work it cannot do:

    * `:reuse` -- BIND the prior subject the resolver's witness named (a
      completed `Run` id, a resolved census `WorkOrder`, or a witness
      receipt ref) and emit outcome `:known_replay` referencing it. No
      frontier worker is dispatched for the item. A `:reuse` whose selected
      candidate carries NO bindable prior subject is `{:unsupported,
      :no_prior_subject}` -- a replay with nothing to replay is not a replay.
    * `:compose` / `:extend` / `:generate` -- when the resolution names a
      ggen pack id (a candidate's `ggen_pack` witness field, or a
      `ggen-pack:` capability id), every named pack is run through the
      generation executor (`Xaas.Ultracode.CapabilityResolver.PackGenerator`:
      the marketplace's canonical qualification harness, real `ggen sync
      run` twice + byte-identical replay). All packs generated ->
      `{:generated, pack_ids}`; any harness refusal -> `{:refused, code}`;
      executor unavailable (no marketplace checkout / no ggen) ->
      `{:unsupported, :executor_pending}`, typed. With no pack named:
      `{:unsupported, :no_generator_named}`.
    * `:frontier` / `:unresolved` -- no execution record (a frontier item
      goes to a worker; an unresolved one is BLOCKED upstream).

  Records are appended to the SAME `capability-resolutions.ndjson` the
  resolution receipts live in (schema `xaas.capability-execution-record/1`),
  after the resolution lines, carrying subject / authority / consequence /
  replay / standing.
  """

  alias Xaas.Ultracode.CapabilityResolver.{PackGenerator, Receipt}

  @schema "xaas.capability-execution-record/1"
  @authority "capability-resolution-court:construct-ceiling (no DO; no worker lease)"

  @enforce_keys [:item_id, :class, :outcome, :executed_at]
  defstruct [
    :item_id,
    :class,
    :outcome,
    :subject,
    :authority,
    :consequence,
    :replay,
    :standing,
    :executed_at,
    pack_ids: []
  ]

  @type outcome ::
          :known_replay
          | {:generated, [String.t()]}
          | {:refused, String.t()}
          | {:unsupported, :executor_pending | :no_generator_named | :no_prior_subject}

  @type t :: %__MODULE__{
          item_id: String.t() | nil,
          class: Receipt.class(),
          outcome: outcome(),
          subject: String.t() | nil,
          authority: String.t(),
          consequence: String.t(),
          replay: map(),
          standing: String.t(),
          pack_ids: [String.t()],
          executed_at: DateTime.t()
        }

  @doc "The record schema id."
  def schema, do: @schema

  @doc """
  Executes one resolution receipt. `nil` for `:frontier`/`:unresolved`
  (no deterministic execution applies).
  """
  @spec execute(Receipt.t(), keyword()) :: t() | nil
  def execute(receipt, opts \\ [])

  def execute(%Receipt{class: class}, _opts) when class in [:frontier, :unresolved], do: nil

  def execute(%Receipt{class: :reuse} = receipt, _opts) do
    selected_id = List.first(receipt.selected_capabilities)
    candidate = Enum.find(receipt.candidate_capabilities, &(&1.capability_id == selected_id))

    case candidate && prior_subject(candidate) do
      subject when is_binary(subject) ->
        record(receipt, :known_replay,
          subject: subject,
          consequence: "no_worker_dispatched; replayed prior subject #{subject}",
          standing: "PARTIAL_ALIVE",
          replay: replay(receipt, candidate)
        )

      _ ->
        record(receipt, {:unsupported, :no_prior_subject},
          subject: nil,
          consequence: "no_worker_dispatched; no bindable prior subject on the witness",
          standing: "UNSUPPORTED",
          replay: replay(receipt, candidate)
        )
    end
  end

  def execute(%Receipt{class: class} = receipt, opts)
      when class in [:compose, :extend, :generate] do
    case pack_ids(receipt) do
      [] ->
        record(receipt, {:unsupported, :no_generator_named},
          subject: nil,
          consequence: "no_worker_dispatched; no generator named",
          standing: "UNSUPPORTED",
          replay: replay(receipt, nil)
        )

      packs ->
        generate_packs(receipt, packs, opts)
    end
  end

  # Runs every named pack through the generation executor (default
  # PackGenerator.generate/2; `opts[:generator]` supplies another real
  # function of the same shape). First refusal wins; an unavailable
  # executor is typed :executor_pending, never a fake success.
  defp generate_packs(receipt, packs, opts) do
    generator = Keyword.get(opts, :generator, &PackGenerator.generate/2)
    gen_opts = Keyword.get(opts, :generator_opts, [])

    # A pack the marketplace does not contain is a refusal of the verdict,
    # not an unavailable executor.
    results =
      Enum.map(packs, fn pack ->
        case generator.(pack, gen_opts) do
          {:error, {:unknown_pack, _}} ->
            {pack, {:refused, "REFUSED:UNKNOWN_PACK", %{"status" => "REFUSED"}}}

          other ->
            {pack, other}
        end
      end)

    evidence =
      Map.new(results, fn {pack, result} -> {pack, generation_evidence(result)} end)

    base_replay = Map.put(replay(receipt, nil), "generation", evidence)

    cond do
      Enum.all?(results, &match?({_, {:generated, _}}, &1)) ->
        record(receipt, {:generated, packs},
          subject: "ggen-packs:" <> Enum.join(packs, ","),
          consequence:
            "no_worker_dispatched; generated via marketplace qualification harness " <>
              "(ggen sync run x2, byte-identical)",
          standing: "PARTIAL_ALIVE",
          pack_ids: packs,
          replay: base_replay
        )

      refused = Enum.find(results, &match?({_, {:refused, _, _}}, &1)) ->
        {pack, {:refused, code, _}} = refused

        record(receipt, {:refused, code},
          subject: "ggen-pack:" <> pack,
          consequence: "no_worker_dispatched; generator refused #{pack}: #{code}",
          standing: "REFUSED",
          pack_ids: packs,
          replay: base_replay
        )

      true ->
        record(receipt, {:unsupported, :executor_pending},
          subject: nil,
          consequence: "no_worker_dispatched; generation executor unavailable",
          standing: "UNSUPPORTED",
          pack_ids: packs,
          replay: base_replay
        )
    end
  end

  defp generation_evidence({:generated, record}),
    do: %{"status" => record["status"], "code" => record["code"]}

  defp generation_evidence({:refused, code, record}),
    do: %{"status" => record["status"] || "REFUSED", "code" => code}

  defp generation_evidence({:error, reason}),
    do: %{"status" => "ERROR", "reason" => inspect(reason)}

  @doc "Executes every receipt, dropping the non-executable classes."
  @spec execute_all([Receipt.t()], keyword()) :: [t()]
  def execute_all(receipts, opts \\ []),
    do: receipts |> Enum.map(&execute(&1, opts)) |> Enum.reject(&is_nil/1)

  @doc "JSON-safe outcome: `\"known_replay\"` or `\"unsupported:<reason>\"`."
  @spec outcome_json(outcome() | nil) :: String.t() | nil
  def outcome_json(nil), do: nil
  def outcome_json(:known_replay), do: "known_replay"
  def outcome_json({:generated, packs}), do: "generated:" <> Enum.join(packs, ",")
  def outcome_json({:refused, code}), do: "refused:#{code}"
  def outcome_json({:unsupported, reason}), do: "unsupported:#{reason}"

  @doc "The JSON-safe projection appended as one NDJSON line."
  @spec to_json_map(t()) :: map()
  def to_json_map(%__MODULE__{} = r) do
    %{
      "schema" => @schema,
      "item_id" => r.item_id,
      "class" => Atom.to_string(r.class),
      "outcome" => outcome_json(r.outcome),
      "subject" => r.subject,
      "authority" => r.authority,
      "consequence" => r.consequence,
      "replay" => r.replay,
      "standing" => r.standing,
      "pack_ids" => r.pack_ids,
      "executed_at" => DateTime.to_iso8601(r.executed_at)
    }
  end

  @doc """
  Appends execution records to the resolution receipt file at `path`
  (after `Receipt.persist/2` wrote the resolution lines).
  """
  @spec append([t()], String.t()) :: :ok
  def append([], _path), do: :ok

  def append(records, path) when is_list(records) and is_binary(path) do
    lines = Enum.map(records, &(Jason.encode!(to_json_map(&1)) <> "\n"))
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, lines, [:append])
    :ok
  end

  # ------------------------------------------------------------------

  defp record(receipt, outcome, fields) do
    %__MODULE__{
      item_id: receipt.item_id,
      class: receipt.class,
      outcome: outcome,
      subject: Keyword.get(fields, :subject),
      authority: @authority,
      consequence: Keyword.fetch!(fields, :consequence),
      replay: Keyword.fetch!(fields, :replay),
      standing: Keyword.fetch!(fields, :standing),
      pack_ids: Keyword.get(fields, :pack_ids, []),
      executed_at: DateTime.utc_now()
    }
  end

  # The prior subject, in witness-strength order: an executed Run, then a
  # resolved census work order, then a witness receipt ref.
  defp prior_subject(candidate) do
    cond do
      present?(candidate[:run_id]) -> "run:#{candidate.run_id}"
      present?(candidate[:work_order_id]) -> "census_work_order:#{candidate.work_order_id}"
      present?(candidate[:receipt]) -> "receipt:#{candidate.receipt}"
      true -> nil
    end
  end

  defp present?(value), do: not is_nil(value) and value != ""

  defp replay(receipt, candidate) do
    %{
      "resolution_schema" => "xaas.capability-resolution-receipt/1",
      "item_id" => receipt.item_id,
      "required_capabilities" => receipt.required_capabilities,
      "selected_capabilities" => receipt.selected_capabilities,
      "source" => candidate && candidate[:source],
      "falsifier" => receipt.falsifier
    }
  end

  defp pack_ids(%Receipt{class: class} = receipt) do
    relevant =
      if class == :generate,
        do: receipt.candidate_capabilities,
        else:
          Enum.filter(
            receipt.candidate_capabilities,
            &(&1.capability_id in receipt.selected_capabilities)
          )

    relevant
    |> Enum.flat_map(fn candidate ->
      field =
        case candidate[:ggen_pack] do
          pack when is_binary(pack) and pack != "" -> [pack]
          _ -> []
        end

      named =
        case String.split(candidate.capability_id, ":", parts: 2) do
          ["ggen-pack", pack] -> [pack]
          _ -> []
        end

      field ++ named
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
