defmodule Xaas.Semantics.AdmissionAttribution do
  @moduledoc """
  Exact Shapley attribution over the discrete admission check lattice
  (dissertation Ch5, Art.13, Definition 5.2).

  The lattice here is the *real* ordered admission check list — a finite
  discrete set of named checks — not a continuous black-box score, so exact
  attribution over all coalitions is computable and no sampling/estimation
  (e.g. Monte Carlo Shapley) is used or needed.

  Given a fixed candidate intent and checks `[{name, fun}]` where
  `fun.(intent) -> :pass | {:refuse, atom()}`, the characteristic function is:

      v(S) = 1  iff the intent passes every check in S (admitted under coalition S)
      v(S) = 0  otherwise

  `v(∅) = 1` vacuously (the empty coalition admits by admitting nothing).
  `v(N) = 1` iff the intent is admitted under the full check set.

  Exact Shapley value of check i:

      φ_i = Σ_{S ⊆ N\\{i}} [|S|! (n-1-|S|)! / n!] · (v(S ∪ {i}) − v(S))

  computed by enumerating **all 2^n coalitions** — deterministic, exact, no
  randomness. Cost is O(2^n · n); therefore `n` is bounded by
  `@max_checks 20` (2^20 ≈ 1.05e6 coalitions) and larger check sets get the
  typed refusal `{:error, :COALITION_LIMIT}`.

  Efficiency axiom (asserted): Σφ_i = v(N) − v(∅) within 1e-9. A violation
  raises `ArgumentError` — it is an internal-invariant impossibility, not a
  caller-recoverable condition.

  Check verdicts depend only on the intent (each `fun` sees only the intent),
  so each check is evaluated exactly once; coalition values are then exact
  combinatorics over the resulting refusal bitmask. Check `name`s must be
  unique — they are the attribution keys of the returned map.

  Returns `%{name => φ_i}` (floats) on success, `{:error, :COALITION_LIMIT}`
  when `length(checks) > 20`.
  """

  @max_checks 20
  @efficiency_epsilon 1.0e-9

  @spec shapley(term, [{term, (term -> :pass | {:refuse, atom})}]) ::
          %{optional(term) => float} | {:error, :COALITION_LIMIT}
  def shapley(intent, checks)

  def shapley(_intent, checks) when is_list(checks) and length(checks) > @max_checks do
    {:error, :COALITION_LIMIT}
  end

  def shapley(intent, checks) when is_list(checks) do
    n = length(checks)
    full_mask = :erlang.bsl(1, n) - 1

    # Evaluate each admission check exactly once against the intent.
    {names, refuse_mask} =
      checks
      |> Enum.reverse()
      |> Enum.reduce({[], 0}, fn {name, fun}, {names, mask} ->
        case fun.(intent) do
          :pass ->
            {[name | names], mask}

          {:refuse, _reason} ->
            bit = refusal_bit(checks, name)
            {[name | names], :erlang.bor(mask, bit)}

          other ->
            raise ArgumentError,
                  "admission check #{inspect(name)} returned #{inspect(other)}; " <>
                    "expected :pass | {:refuse, atom}"
        end
      end)

    weights = weights(n)

    phis =
      Enum.reduce(0..(2 ** n - 1), Map.new(0..(n - 1), &{&1, 0.0}), fn mask, acc ->
        v_mask = value(mask, refuse_mask)

        Enum.reduce(0..(n - 1), acc, fn i, acc ->
          bit = :erlang.bsl(1, i)

          if :erlang.band(mask, bit) != 0 do
            sub = :erlang.band(mask, :erlang.bnot(bit))
            marginal = v_mask - value(sub, refuse_mask)

            if marginal == 0 do
              acc
            else
              w = Enum.fetch!(weights, popcount(sub))
              Map.update!(acc, i, &(&1 + w * marginal))
            end
          else
            acc
          end
        end)
      end)

    result =
      names
      |> Enum.with_index()
      |> Map.new(fn {name, i} -> {name, Map.fetch!(phis, i)} end)

    # Efficiency axiom: Σφ_i = v(N) − v(∅) within 1e-9.
    sum = result |> Map.values() |> Enum.sum()
    diff = value(full_mask, refuse_mask) - value(0, refuse_mask)

    unless abs(sum - diff) <= @efficiency_epsilon do
      raise ArgumentError,
            "efficiency axiom violated: sum(phi)=#{sum}, v(N)-v(empty)=#{diff}"
    end

    result
  end

  defp refusal_bit(checks, name) do
    idx = Enum.find_index(checks, fn {n, _fun} -> n == name end)
    :erlang.bsl(1, idx)
  end

  defp value(mask, refuse_mask) do
    if :erlang.band(mask, refuse_mask) == 0, do: 1.0, else: 0.0
  end

  # Coalition weights |S|!(n-1-|S|)!/n! for |S| = 0..n-1, as floats.
  defp weights(0), do: []

  defp weights(n) do
    denom = factorial(n)
    Enum.map(0..(n - 1), fn s -> factorial(s) * factorial(n - 1 - s) / denom end)
  end

  defp factorial(0), do: 1
  defp factorial(k), do: Enum.reduce(1..k, 1, &*/2)

  # Kernighan: clear the lowest set bit each step.
  defp popcount(0), do: 0
  defp popcount(x), do: 1 + popcount(:erlang.band(x, x - 1))
end
