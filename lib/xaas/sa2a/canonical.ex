defmodule Xaas.Sa2a.Canonical do
  @moduledoc """
  Canonical JSON + SHA-256 identical to the autofde-lab port's `sa2a_replay` hash:
  Python `json.dumps(data, sort_keys=True, separators=(",", ":"))` (ASCII-escaped),
  then `hashlib.sha256(...).hexdigest()`.

  Computing the manifest hash here and having the port re-derive it in `sa2a_replay`
  makes the replay check a cross-implementation agreement, not the port grading itself.

  Floats are admitted only where Elixir's and Python's shortest round-trip renderings
  are byte-identical (`0.0` and `1.0e-3 <= abs(x) < 1.0e15`); anything else raises
  `ArgumentError`, which the court reports as a typed refusal instead of a silent
  hash disagreement.
  """

  @spec sha256(term()) :: String.t()
  def sha256(term) do
    :crypto.hash(:sha256, encode!(term)) |> Base.encode16(case: :lower)
  end

  @spec encode!(term()) :: binary()
  def encode!(term), do: IO.iodata_to_binary(enc(term))

  defp enc(nil), do: "null"
  defp enc(true), do: "true"
  defp enc(false), do: "false"
  defp enc(int) when is_integer(int), do: Integer.to_string(int)

  defp enc(float) when is_float(float) do
    abs = abs(float)

    if float == 0.0 or (abs >= 1.0e-3 and abs < 1.0e15) do
      Float.to_string(float)
    else
      raise ArgumentError, "float #{inspect(float)} has no canonical Python-identical rendering"
    end
  end

  defp enc(atom) when is_atom(atom), do: enc(Atom.to_string(atom))
  defp enc(bin) when is_binary(bin), do: [?", escape(bin, []), ?"]

  defp enc(list) when is_list(list),
    do: [?[, list |> Enum.map(&enc/1) |> Enum.intersperse(?,), ?]]

  defp enc(%_{} = struct),
    do: raise(ArgumentError, "structs are not canonical JSON: #{inspect(struct.__struct__)}")

  defp enc(map) when is_map(map) do
    pairs =
      map
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {k, v} -> [enc(k), ?:, enc(v)] end)
      |> Enum.intersperse(?,)

    [?{, pairs, ?}]
  end

  defp enc(other), do: raise(ArgumentError, "not canonical JSON: #{inspect(other)}")

  # Python's ensure_ascii escaper: everything outside 0x20..0x7e is escaped.
  defp escape(<<>>, acc), do: Enum.reverse(acc)
  defp escape(<<?", rest::binary>>, acc), do: escape(rest, ["\\\"" | acc])
  defp escape(<<?\\, rest::binary>>, acc), do: escape(rest, ["\\\\" | acc])
  defp escape(<<?\n, rest::binary>>, acc), do: escape(rest, ["\\n" | acc])
  defp escape(<<?\r, rest::binary>>, acc), do: escape(rest, ["\\r" | acc])
  defp escape(<<?\t, rest::binary>>, acc), do: escape(rest, ["\\t" | acc])
  defp escape(<<?\b, rest::binary>>, acc), do: escape(rest, ["\\b" | acc])
  defp escape(<<?\f, rest::binary>>, acc), do: escape(rest, ["\\f" | acc])

  defp escape(<<c, rest::binary>>, acc) when c >= 0x20 and c <= 0x7E,
    do: escape(rest, [<<c>> | acc])

  defp escape(<<c::utf8, rest::binary>>, acc) when c < 0x10000,
    do: escape(rest, [hex4(c) | acc])

  defp escape(<<c::utf8, rest::binary>>, acc) do
    v = c - 0x10000
    escape(rest, [hex4(0xDC00 + Bitwise.band(v, 0x3FF)), hex4(0xD800 + Bitwise.bsr(v, 10)) | acc])
  end

  defp escape(<<_invalid, _rest::binary>>, _acc),
    do: raise(ArgumentError, "invalid UTF-8 is not canonical JSON")

  defp hex4(c),
    do: ["\\u", c |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(4, "0")]
end
