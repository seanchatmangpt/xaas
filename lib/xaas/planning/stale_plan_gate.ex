# Ported from beam4pm's BeamPM.StalePlanGate (lib/beam4pm_stale_plan_gate.ex;
# XA-3007). Given the preimage digest a plan was admitted against and the
# digest of the preimage actually observed, refuses stale execution with a
# typed Xaas.Actuation.Refusal instead of letting drift pass.
defmodule Xaas.Planning.StalePlanGate do
  @moduledoc """
  Stale-plan refusal gate over preimage digests.

  A plan may be fenced by the preimage digest it was admitted against.
  `fingerprint/1` digests the observed preimage with the same calculus as
  `Xaas.Actuation.Kernel.fingerprint/1` (lib/xaas/actuation.ex -- the kernel's
  version is private, so the calculus is mirrored here and pinned
  byte-for-byte by `test/xaas/planning/stale_plan_gate_test.exs`):
  canonical term -> deterministic `term_to_binary` -> SHA-256 -> lowercase hex.

  `check/2` compares the `admitted_preimage_hash` a plan was admitted against
  with the `observed_preimage_hash` of the preimage actually observed:

    * equal (both well-formed 64-char lowercase hex) -> `{:ok, :fresh}`
    * unequal -> `{:error, %Xaas.Actuation.Refusal{}` with
      `code: :stale_plan_refusal` and `detail:` carrying both hashes as
      refusal evidence (the gate is the decision; the caller decides what to
      persist and whether to actuate)
    * any non-binary, wrong-length, or non-lowercase-hex input ->
      `{:error, %Xaas.Actuation.Refusal{}` with `detail: :malformed_hash` --
      a malformed hash can never be evidence of freshness, so the gate
      refuses closed.

  No authority semantics: this gate only refuses or passes; it never actuates.
  """

  alias Xaas.Actuation.Refusal

  @hash_format Regex.compile!("^[0-9a-f]{64}$")

  @doc "Digests a preimage term exactly as Xaas.Actuation.Kernel.fingerprint/1 does."
  @spec fingerprint(term()) :: String.t()
  def fingerprint(term) do
    term
    |> canonical_term()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @spec check(term(), term()) :: {:ok, :fresh} | {:error, Refusal.t()}
  def check(admitted_preimage_hash, observed_preimage_hash) do
    cond do
      not well_formed?(admitted_preimage_hash) or not well_formed?(observed_preimage_hash) ->
        {:error, Refusal.new(:stale_plan_refusal, :malformed_hash)}

      admitted_preimage_hash == observed_preimage_hash ->
        {:ok, :fresh}

      true ->
        {:error,
         Refusal.new(:stale_plan_refusal, %{
           admitted_preimage_hash: admitted_preimage_hash,
           observed_preimage_hash: observed_preimage_hash
         })}
    end
  end

  defp well_formed?(hash) when is_binary(hash), do: Regex.match?(@hash_format, hash)
  defp well_formed?(_other), do: false

  # -- byte-identical mirror of Xaas.Actuation.Kernel.fingerprint/1 --------------------

  defp canonical_term(%_{} = struct), do: struct |> Map.from_struct() |> canonical_term()

  defp canonical_term(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), canonical_term(value)} end)
    |> Enum.sort()
  end

  defp canonical_term(list) when is_list(list), do: Enum.map(list, &canonical_term/1)

  defp canonical_term(tuple) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> Enum.map(&canonical_term/1)

  defp canonical_term(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp canonical_term(other), do: other
end
