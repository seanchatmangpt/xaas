defmodule Xaas.DatetimeStructuralCompareGuardTest do
  @moduledoc """
  Guard for a flake class found in `Xaas.Ultracode.EngineTest` ("fill dispatches exactly the
  free slots ..."): `Enum.max_by(rows, & &1.inserted_at)` compares `%DateTime{}` structs
  structurally. Erlang orders same-shaped maps by their values in key order, and the
  `:microsecond` key sorts before `:minute` and `:second`, so rows inserted across a second
  boundary get the wrong "latest". The fix is the `DateTime` comparator argument.

  The first test exhibits the failure mode deterministically (no clock, no database). The
  second is a source lint over `lib/` and `test/` so the same shape cannot come back.
  """
  use ExUnit.Case, async: true

  test "structural max_by picks the wrong row across a second boundary; DateTime does not" do
    first = ~U[2026-09-21 20:00:00.999000Z]
    later = ~U[2026-09-21 20:00:01.001000Z]

    assert DateTime.compare(later, first) == :gt
    assert Enum.max_by([first, later], & &1) == first
    assert Enum.max_by([first, later], & &1, DateTime) == later
  end

  test "no max_by/min_by over a timestamp field omits the DateTime comparator" do
    offenders =
      ["lib", "test"]
      |> Enum.flat_map(&Path.wildcard(Path.join(&1, "**/*.{ex,exs}")))
      |> Enum.reject(&(&1 == __ENV__.file |> Path.relative_to_cwd()))
      |> Enum.flat_map(fn path ->
        path
        |> File.stream!()
        |> Stream.with_index(1)
        |> Enum.filter(fn {line, _no} -> structural_timestamp_compare?(line) end)
        |> Enum.map(fn {line, no} -> "#{path}:#{no}: #{String.trim(line)}" end)
      end)

    assert offenders == []
  end

  # A max_by/min_by call whose key is a timestamp field but which never names `DateTime`.
  defp structural_timestamp_compare?(line) do
    Regex.match?(~r/\b(max_by|min_by)\(.*(inserted_at|updated_at|\w+_at)\b/, line) and
      not String.contains?(line, "DateTime")
  end
end
