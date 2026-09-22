defmodule Xaas.Ultracode.OrderProbes do
  @moduledoc """
  Lets a Semantic Jira order declare MACHINE falsifier probes.

  An order (`docs/sjira/**/NNN-*.md`) carries an admitted JSON front matter
  (`acceptance`, `falsifiers`, ... -- the field set `GgenIgniter.SemanticJira`
  admits and this module never widens) and a free body. Falsifiers are prose
  ("materialize accepts a WorkOrder whose digest was altered"). This helper
  reads them and lets the BODY bind each one to an executable probe
  (`Xaas.Ultracode.Probes`) in a fenced block:

      ```xaas-probes
      [
        {"kind": "replace", "file": "lib/x/digest.ex",
         "pattern": "digest_matches?(", "replacement": "always_true?(",
         "falsifier": 0},
        {"id": "no-court", "kind": "delete_line", "file": "lib/x/seal.ex",
         "pattern": "require_courts!", "falsifier": "receipt seals without the required courts passing"}
      ]
      ```

  Each probe is anchored to a front-matter `falsifier` and/or `acceptance`
  entry, given as its exact text or its 0-based index; an anchor that names
  nothing is refused (`{:unanchored_probe, ...}`), so a probe cannot outlive
  the sentence it stands for. A probe with no anchor is refused too. `id`
  defaults to `<order identity>-p<N>`.

  `parse/1` never raises and never widens authority: the result is DATA the
  controller writes into the run's `{ticket}` file (`Sensing` puts it on the
  item, `Autonomic` writes it) and the fabric verifier reads back -- the
  worker never supplies it.

  ## Coverage

  `coverage` lists the falsifiers no probe stands for (`unprobed_falsifiers`);
  `require_coverage/1` turns a non-empty list into a typed refusal for callers
  that want every falsifier machine-checked.
  """

  alias Xaas.Ultracode.Probes

  @fence ~r/^```xaas-probes[ \t]*\n(.*?)\n```[ \t]*$/ms
  @front_matter ~r/\A---\n(.*?)\n---[ \t]*(?:\n|\z)/s
  @identity_re ~r/\A[A-Za-z0-9._:-]{1,60}\z/

  @type order :: %{
          identity: String.t() | nil,
          acceptance: [String.t()],
          falsifiers: [String.t()],
          probes: [map()],
          unprobed_falsifiers: [String.t()]
        }

  @doc "Reads and parses an order file."
  @spec read(Path.t()) :: {:ok, order()} | {:error, term()}
  def read(path) do
    case File.read(path) do
      {:ok, text} -> parse(text)
      {:error, reason} -> {:error, {:unreadable_order, reason}}
    end
  end

  @doc """
  Parses an order's text: `{:ok, order}` (probes may be `[]`) or
  `{:error, reason}`. Probes are returned in their JSON-safe (string-keyed)
  form with anchors resolved to the order's own text.
  """
  @spec parse(String.t()) :: {:ok, order()} | {:error, term()}
  def parse(text) when is_binary(text) do
    with {:ok, front, body} <- split(text),
         {:ok, meta} <- decode_front(front),
         {:ok, acceptance} <- string_list(meta, "acceptance"),
         {:ok, falsifiers} <- string_list(meta, "falsifiers"),
         {:ok, identity} <- identity(meta),
         {:ok, raw} <- fenced_probes(body),
         {:ok, probes} <- anchor(raw, identity, acceptance, falsifiers) do
      anchored = probes |> Enum.map(& &1["falsifier"]) |> Enum.reject(&is_nil/1)

      {:ok,
       %{
         identity: identity,
         acceptance: acceptance,
         falsifiers: falsifiers,
         probes: probes,
         unprobed_falsifiers: falsifiers -- anchored
       }}
    end
  end

  def parse(_), do: {:error, :order_must_be_text}

  @doc "`:ok` iff every falsifier of the order has at least one probe."
  @spec require_coverage(order()) :: :ok | {:error, {:unprobed_falsifiers, [String.t()]}}
  def require_coverage(%{unprobed_falsifiers: []}), do: :ok

  def require_coverage(%{unprobed_falsifiers: missing}),
    do: {:error, {:unprobed_falsifiers, missing}}

  @doc """
  The ticket/item fields for `Xaas.Ultracode.Sensing`: `%{}` when the text
  declares no probes block (and so cannot be, or need not be, parsed as an
  order), `%{"probes" => [...]}` for a valid declaration and
  `%{"probes_error" => reason}` for an invalid one -- which the verifier
  turns into a typed refusal rather than ignoring.
  """
  @spec item_fields(String.t()) :: map()
  def item_fields(text) when is_binary(text) do
    if Regex.match?(@fence, text) do
      case parse(text) do
        {:ok, %{probes: probes}} when probes != [] -> %{"probes" => probes}
        {:ok, _} -> %{}
        {:error, reason} -> %{"probes_error" => inspect(reason)}
      end
    else
      %{}
    end
  end

  # ------------------------------------------------------------------

  defp split(text) do
    case Regex.run(@front_matter, text, capture: :all_but_first, return: :index) do
      [{fs, fl}] ->
        front = binary_part(text, fs, fl)
        rest_from = fs + fl
        {:ok, front, binary_part(text, rest_from, byte_size(text) - rest_from)}

      _ ->
        {:error, :no_front_matter}
    end
  end

  defp decode_front(front) do
    case Jason.decode(front) do
      {:ok, %{} = meta} -> {:ok, meta}
      _ -> {:error, :front_matter_not_json_object}
    end
  end

  defp string_list(meta, key) do
    case Map.get(meta, key, []) do
      list when is_list(list) ->
        if Enum.all?(list, &(is_binary(&1) and &1 != "")),
          do: {:ok, list},
          else: {:error, {:bad_front_matter_field, key}}

      _ ->
        {:error, {:bad_front_matter_field, key}}
    end
  end

  defp identity(meta) do
    case Map.get(meta, "identity") do
      nil ->
        {:ok, nil}

      id when is_binary(id) ->
        if Regex.match?(@identity_re, id), do: {:ok, id}, else: {:error, :bad_identity}

      _ ->
        {:error, :bad_identity}
    end
  end

  defp fenced_probes(body) do
    @fence
    |> Regex.scan(body, capture: :all_but_first)
    |> Enum.reduce_while({:ok, []}, fn [json], {:ok, acc} ->
      case Jason.decode(json) do
        {:ok, list} when is_list(list) -> {:cont, {:ok, acc ++ list}}
        _ -> {:halt, {:error, :probes_block_not_a_json_list}}
      end
    end)
  end

  # Resolve each probe's anchors against the order's own text, default its
  # id, then let `Probes.admit/1` own every other validation.
  defp anchor(raw, identity, acceptance, falsifiers) do
    prefix = identity || "order"

    raw
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn
      {%{} = probe, n}, {:ok, acc} ->
        probe = Map.put_new(probe, "id", "#{prefix}-p#{n}")

        with {:ok, probe} <- resolve(probe, "falsifier", falsifiers),
             {:ok, probe} <- resolve(probe, "acceptance", acceptance),
             :ok <- anchored(probe) do
          {:cont, {:ok, [probe | acc]}}
        else
          {:error, reason} -> {:halt, {:error, {:invalid_order_probe, probe["id"], reason}}}
        end

      {_other, n}, _ ->
        {:halt, {:error, {:invalid_order_probe, "##{n}", :probe_must_be_a_map}}}
    end)
    |> case do
      {:ok, reversed} ->
        with {:ok, admitted} <- Probes.admit(Enum.reverse(reversed)) do
          {:ok, Enum.map(admitted, &Probes.to_map/1)}
        end

      error ->
        error
    end
  end

  defp resolve(probe, key, entries) do
    case Map.fetch(probe, key) do
      :error ->
        {:ok, probe}

      {:ok, index} when is_integer(index) ->
        case Enum.at(entries, index) do
          text when is_binary(text) and index >= 0 -> {:ok, Map.put(probe, key, text)}
          _ -> {:error, {:unanchored_probe, key, index}}
        end

      {:ok, text} when is_binary(text) ->
        if text in entries, do: {:ok, probe}, else: {:error, {:unanchored_probe, key, text}}

      {:ok, other} ->
        {:error, {:unanchored_probe, key, other}}
    end
  end

  defp anchored(probe) do
    if Map.has_key?(probe, "falsifier") or Map.has_key?(probe, "acceptance"),
      do: :ok,
      else: {:error, :probe_has_no_anchor}
  end
end
