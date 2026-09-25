defmodule Xaas.Tunnel.Receipt do
  @moduledoc """
  Canonical JSON and sha256 digests for the bounded runtime fabric, byte-identical
  to Python `canonical_json` in chatgpt-cloud-elixir `scripts/xaas-runtime.py`
  and to `ChatGPTCloud.Xaas.Receipt`:

      json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()

  Rules (pinned by `test/fixtures/tunnel/receipt_golden.json` + `.sha256`, the
  same two files committed in chatgpt-cloud-elixir `xaas-runtime/elixir/test/fixtures/`):

    * object keys sorted by Unicode code point (UTF-8 byte order is identical);
    * separators `,` and `:` with no whitespace;
    * strings are raw UTF-8; only `"`, `\\` and C0 controls are escaped, using
      `\\b \\f \\n \\r \\t` and lowercase `\\u00xx` for the rest (`/` and DEL are raw);
    * floats, invalid UTF-8 and duplicate keys are refused (ArgumentError).

  `from_ultracode/1` projects a sealed `Xaas.Ultracode.Receipt` into the wire map
  the fabric serves; `json_safe/1` makes any evidence term canonical-encodable
  (floats become their shortest decimal string, since the canonical form refuses
  floats and a receipt digest must survive a JSON round trip exactly).

  HANDWRITTEN.md: UNSUPPORTED(generator-capability) -- no admitted pack renders a
  canonical-JSON encoder or the fabric receipt projection.
  """

  @schema "xaas.fabric-sealed-receipt/1"

  @doc "Schema id of the sealed receipt the fabric serves."
  def schema, do: @schema

  @doc "Canonical JSON bytes (Python canonical_json parity)."
  @spec canonical(term()) :: binary()
  def canonical(value), do: value |> encode() |> IO.iodata_to_binary()

  @doc "Lowercase hex sha256 of the canonical bytes."
  @spec digest(term()) :: String.t()
  def digest(value), do: :crypto.hash(:sha256, canonical(value)) |> Base.encode16(case: :lower)

  @doc "Replay: the recomputed digest of `sealed` must equal the declared digest."
  @spec verify_replay(term(), term()) :: :ok | {:refused, :replay_digest_mismatch}
  def verify_replay(sealed, declared) when is_map(sealed) and is_binary(declared) do
    if digest(sealed) == declared, do: :ok, else: {:refused, :replay_digest_mismatch}
  end

  def verify_replay(_sealed, _declared), do: {:refused, :replay_digest_mismatch}

  @doc """
  Wire projection of a sealed `Xaas.Ultracode.Receipt` (the same fields the
  execution receipts endpoint formats), plus the fabric schema, authority and
  standing derived from the outcome. The result is canonical-encodable.
  """
  @spec from_ultracode(struct()) :: map()
  def from_ultracode(%{__struct__: Xaas.Ultracode.Receipt} = receipt) do
    outcome = to_string(receipt.outcome)

    json_safe(%{
      "schema" => @schema,
      "id" => receipt.id,
      "epoch_id" => receipt.epoch_id,
      "subject" => receipt.subject,
      "outcome" => outcome,
      "evidence" => receipt.evidence || %{},
      "sealed_at" => receipt.sealed_at,
      "authority" => "CONSTRUCT",
      "standing" => standing(outcome)
    })
  end

  @doc "Standing vocabulary for an Ultracode receipt outcome."
  @spec standing(String.t()) :: String.t()
  def standing("alive"), do: "ALIVE"
  def standing("partial_alive"), do: "PARTIAL_ALIVE"
  def standing("build_broken"), do: "BUILD_BROKEN"
  def standing("refused"), do: "REFUSED"
  def standing("blocked"), do: "BLOCKED"
  def standing("unsupported"), do: "UNSUPPORTED"
  def standing(other), do: "UNKNOWN:" <> other

  @doc """
  A server-side step receipt carrying the BRCE fields: identity, authority
  (`CONSTRUCT`), consequence, replay and standing, plus `receipt_sha256` over
  every other field.
  """
  @spec tunnel_receipt(String.t(), map()) :: map()
  def tunnel_receipt(step, facts) when is_binary(step) and is_map(facts) do
    body =
      json_safe(%{
        "schema" => "xaas.fabric-step-receipt/1",
        "step" => step,
        "identity" => Map.get(facts, :identity, %{}),
        "authority" => "CONSTRUCT",
        "consequence" => Map.get(facts, :consequence, %{}),
        "replay" => Map.get(facts, :replay),
        "standing" => Map.get(facts, :standing, "UNKNOWN")
      })

    Map.put(body, "receipt_sha256", digest(body))
  end

  @doc "Normalize a term into the canonical-encodable subset."
  @spec json_safe(term()) :: term()
  def json_safe(nil), do: nil
  def json_safe(v) when is_boolean(v), do: v
  def json_safe(v) when is_integer(v), do: v
  def json_safe(v) when is_float(v), do: Float.to_string(v)
  def json_safe(v) when is_binary(v), do: v
  def json_safe(v) when is_atom(v), do: Atom.to_string(v)
  def json_safe(%DateTime{} = v), do: DateTime.to_iso8601(v)
  def json_safe(%NaiveDateTime{} = v), do: NaiveDateTime.to_iso8601(v)
  def json_safe(%Date{} = v), do: Date.to_iso8601(v)
  def json_safe(%_{} = v), do: inspect(v)
  def json_safe(v) when is_list(v), do: Enum.map(v, &json_safe/1)
  def json_safe(v) when is_tuple(v), do: v |> Tuple.to_list() |> json_safe()

  def json_safe(v) when is_map(v),
    do: Map.new(v, fn {k, val} -> {json_key(k), json_safe(val)} end)

  def json_safe(v), do: inspect(v)

  defp json_key(k) when is_binary(k), do: k
  defp json_key(k) when is_atom(k), do: Atom.to_string(k)
  defp json_key(k), do: to_string(k)

  # --- encoder -------------------------------------------------------------

  defp encode(nil), do: "null"
  defp encode(true), do: "true"
  defp encode(false), do: "false"
  defp encode(v) when is_integer(v), do: Integer.to_string(v)

  defp encode(v) when is_float(v),
    do: raise(ArgumentError, "canonical receipts refuse floats: #{inspect(v)}")

  defp encode(v) when is_atom(v), do: encode_string(Atom.to_string(v))
  defp encode(v) when is_binary(v), do: encode_string(v)

  defp encode(v) when is_list(v),
    do: ["[", v |> Enum.map(&encode/1) |> Enum.intersperse(","), "]"]

  defp encode(%_{} = v), do: raise(ArgumentError, "canonical receipts refuse #{inspect(v)}")

  defp encode(v) when is_map(v) do
    pairs =
      v
      |> Enum.map(fn {k, val} -> {key(k), val} end)
      |> Enum.sort_by(fn {k, _} -> k end)

    if length(pairs) != length(Enum.uniq_by(pairs, &elem(&1, 0))),
      do: raise(ArgumentError, "canonical receipts refuse duplicate keys")

    body =
      pairs
      |> Enum.map(fn {k, val} -> [encode_string(k), ":", encode(val)] end)
      |> Enum.intersperse(",")

    ["{", body, "}"]
  end

  defp encode(v), do: raise(ArgumentError, "canonical receipts refuse #{inspect(v)}")

  defp key(k) when is_binary(k), do: k
  defp key(k) when is_atom(k) and k not in [nil, true, false], do: Atom.to_string(k)
  defp key(k), do: raise(ArgumentError, "canonical receipts refuse key #{inspect(k)}")

  defp encode_string(s) do
    unless String.valid?(s), do: raise(ArgumentError, "canonical receipts refuse invalid UTF-8")
    [?", escape(s, []), ?"]
  end

  defp escape(<<>>, acc), do: Enum.reverse(acc)
  defp escape(<<?", rest::binary>>, acc), do: escape(rest, ["\\\"" | acc])
  defp escape(<<?\\, rest::binary>>, acc), do: escape(rest, ["\\\\" | acc])
  defp escape(<<?\b, rest::binary>>, acc), do: escape(rest, ["\\b" | acc])
  defp escape(<<?\f, rest::binary>>, acc), do: escape(rest, ["\\f" | acc])
  defp escape(<<?\n, rest::binary>>, acc), do: escape(rest, ["\\n" | acc])
  defp escape(<<?\r, rest::binary>>, acc), do: escape(rest, ["\\r" | acc])
  defp escape(<<?\t, rest::binary>>, acc), do: escape(rest, ["\\t" | acc])

  defp escape(<<c, rest::binary>>, acc) when c < 0x20 do
    hex = c |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(4, "0")
    escape(rest, ["\\u" <> hex | acc])
  end

  defp escape(<<c, rest::binary>>, acc), do: escape(rest, [c | acc])
end
