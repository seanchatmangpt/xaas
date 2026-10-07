defmodule Xaas.Semantics.Jcs do
  @moduledoc """
  RFC 8785 (JSON Canonicalization Scheme) canonical JSON encoding for xaas.

  This is a thin facade over the `jcs` hex dependency (already a pinned
  dependency, `{:jcs, "~> 0.2"}` in mix.exs:178), which is a complete,
  pure-Elixir RFC 8785 implementation:

    - sorted keys in UTF-16 code-unit order (RFC 8785 §3.2.3);
    - no insignificant whitespace;
    - string escaping per §3.2.2.2 (control chars as lowercase `\\uhhhh`,
      `\b \\t \\n \\f \\r` shortcuts, `\\"` and `\\\\`);
    - minimal number serialization (§3.2.2.3): integers without `.0`,
      shortest round-trip floats via `:erlang.float_to_binary([:short])`
      plus the ECMA-262 NumberToString post-processing (1.0 -> 1,
      1e30 -> 1e+30, -0.0 -> 0).

  No canonicalization logic is duplicated here: this module exists so that
  xaas callers (e.g. `Xaas.Deployment.ReleaseSnapshot.portable_digest/1`,
  `Xaas.Witness.AuditChain`) reference a single in-app entry point.

  ## Supported input subset

    - `nil`, `true`, `false`
    - integers (arbitrary precision, `Integer.to_string/1`)
    - floats (IEEE-754 double, ECMA-262 NumberToString)
    - binaries (strings) — must be valid UTF-8, no unpaired surrogates
      (WTF-16 corner cases of RFC 8785 §3.2.2.2 for lone surrogates are
      out of scope; Elixir strings are valid UTF-8 only)
    - lists (JSON arrays), maps with binary/atom keys (atoms converted via
      `Atom.to_string/1`)

  Outside this subset the underlying `Jcs.encode/1` raises `ArgumentError`.

  ## Digest usage

      "sha256:" <>
        (:crypto.hash(:sha256, Xaas.Semantics.Jcs.encode(payload))
         |> Base.encode16(case: :lower))

  """

  @doc """
  Encodes a term as RFC 8785 canonical JSON.

  ## Examples

      iex> Xaas.Semantics.Jcs.encode(%{"b" => %{"d" => 2, "c" => [true, nil]}, "a" => 1})
      "{\\"a\\":1,\\"b\\":{\\"c\\":[true,null],\\"d\\":2}}"

      iex> Xaas.Semantics.Jcs.encode(9_007_199_254_740_992)
      "9007199254740992"

      iex> Xaas.Semantics.Jcs.encode(1.0e30)
      "1e+30"

      iex> Xaas.Semantics.Jcs.encode(-0.0)
      "0"

  """
  @spec encode(term()) :: String.t()
  def encode(data), do: Jcs.encode(data)
end
