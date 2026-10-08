defmodule Xaas.Compat.Otp29MapUpdate do
  @moduledoc """
  OS-20 typed guard for the OTP-29 `Map.update/4` absent-key deviation.

  Probe (w525d, Elixir 1.20.4-otp-29): the 4-arity `Map.update` on an
  absent key
  on an absent key stores `default` WITHOUT calling `fun`; on the pinned
  otp-28 runtime the same call also stores `default` without calling `fun`
  (Elixir's documented behavior: `fun` is only applied to a PRESENT key's
  value). A future OTP/Elixir where the absent-key path applies `fun` to the
  default would corrupt every accumulator built on the absent-key arm.

  This module makes that deviation irrelevant at new call sites: identical
  results on both behaviors, by construction — the `fun` is applied only in
  an explicit present-key arm.

  Use `update/4` for new accumulator code instead of raw `Map.update/4`.

  Court: `test/xaas/compat/otp29_map_update_court_test.exs` (semantics pins
  on both baselines + lib/ re-introduction census).
  """

  @spec update(map(), term(), term(), (term() -> term())) :: map()
  def update(map, key, default, fun) when is_map(map) and is_function(fun, 1) do
    case map do
      %{^key => value} -> Map.put(map, key, fun.(value))
      _ -> Map.put(map, key, default)
    end
  end

  @doc """
  Absent-key-reliant accumulator append (the dominant OS-20 site class):
  absent key seeds `[value]`, present key appends. Dual-safe by the same
  explicit-arm construction as `update/4`.
  """
  @spec append(map(), term(), term()) :: map()
  def append(map, key, value) when is_map(map) do
    case map do
      %{^key => list} when is_list(list) -> Map.put(map, key, [value | list])
      %{^key => _} -> Map.put(map, key, [value])
      _ -> Map.put(map, key, [value])
    end
  end

  @doc """
  Absent-key-reliant counter: absent key seeds 1, present key increments.
  """
  @spec increment(map(), term()) :: map()
  def increment(map, key) when is_map(map) do
    update(map, key, 1, &(&1 + 1))
  end
end
