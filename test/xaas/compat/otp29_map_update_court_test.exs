defmodule Xaas.Compat.Otp29MapUpdateCourtTest do
  @moduledoc """
  W984ee / OS-20 court: typed guard `Xaas.Compat.Otp29MapUpdate` semantics
  pinned on the pinned runtime, PLUS a real-File.read! census that fails if
  any raw `Map.update/4` call site re-enters lib/ (the w705 hardcoded site
  list can drift silently; this census cannot).
  """

  use ExUnit.Case, async: true

  describe "guard semantics (real maps, real funs, zero mocks)" do
    test "update/4 absent key seeds default WITHOUT applying fun (otp-28 semantics)" do
      alias Xaas.Compat.Otp29MapUpdate

      assert Otp29MapUpdate.update(%{}, :k, 7, fn _ -> flunk("fun must not run on absent key") end) ==
               %{k: 7}

      assert Otp29MapUpdate.update(%{k: 5}, :k, 0, &(&1 + 1)) == %{k: 6}
      assert Otp29MapUpdate.update(%{}, "s", nil, &(&1 || :x)) == %{"s" => nil}
    end

    test "update/4 agrees with Map.update/4 on BOTH baselines on this runtime" do
      alias Xaas.Compat.Otp29MapUpdate

      for {m, k, d} <- [{%{}, :k, 1}, {%{k: 9}, :k, 1}, {%{"a" => 1}, "a", 0}] do
        assert Otp29MapUpdate.update(m, k, d, &(&1 + 1)) == Map.update(m, k, d, &(&1 + 1))
      end
    end

    test "append/3: absent key seeds [v], present key prepends" do
      alias Xaas.Compat.Otp29MapUpdate

      assert Otp29MapUpdate.append(%{}, :k, :a) == %{k: [:a]}
      assert Otp29MapUpdate.append(%{k: [:a]}, :k, :b) == %{k: [:b, :a]}
      assert Otp29MapUpdate.append(%{k: :not_a_list}, :k, :a) == %{k: [:a]}
    end

    test "increment/2: absent key seeds 1, present key increments" do
      alias Xaas.Compat.Otp29MapUpdate

      assert Otp29MapUpdate.increment(%{}, :c) == %{c: 1}
      assert Otp29MapUpdate.increment(%{c: 1}, :c) == %{c: 2}
      assert Otp29MapUpdate.increment(%{c: 41}, :c) == %{c: 42}
    end

    test "helpers are runtime-observation canaries: they match otp-28 Map.update semantics" do
      alias Xaas.Compat.Otp29MapUpdate

      # If a future runtime flips absent-key semantics, raw Map.update would
      # diverge from the guard — the guard stays correct either way, and this
      # pin documents the equivalence contract on the current runtime.
      assert Otp29MapUpdate.increment(%{}, :c) == Map.update(%{}, :c, 1, &(&1 + 1))
      assert Otp29MapUpdate.increment(%{c: 2}, :c) == Map.update(%{c: 2}, :c, 1, &(&1 + 1))
    end
  end

  describe "lib/ re-introduction census (real File.read! scan)" do
    @describetag :os20_census

    test "zero raw Map.update/4 call sites in lib/**.ex" do
      ex_files = Path.wildcard("lib/**/*.ex")

      assert length(ex_files) > 400, "census sanity: lib/ source tree present"

      offenders =
        Enum.flat_map(ex_files, fn path ->
          path
          |> File.read!()
          |> String.split("\n")
          |> Enum.with_index(1)
          |> Enum.flat_map(fn {line, i} ->
            # match Map.update/4 calls; Map.update!/3 is present-key-only and exempt
            if Regex.match?(~r/Map\.update\(/, line) do
              [{path, i, String.trim(line)}]
            else
              []
            end
          end)
        end)

      assert offenders == [],
             "raw Map.update/4 call sites re-introduced in lib/ (OS-20 regression): #{inspect(offenders, pretty: true)}"
    end

    test "census guard itself is the only sanctioned escape hatch surface" do
      assert Code.ensure_loaded?(Xaas.Compat.Otp29MapUpdate)
      assert function_exported?(Xaas.Compat.Otp29MapUpdate, :update, 4)
      assert function_exported?(Xaas.Compat.Otp29MapUpdate, :append, 3)
      assert function_exported?(Xaas.Compat.Otp29MapUpdate, :increment, 2)
    end
  end
end
