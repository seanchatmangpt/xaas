defmodule Xaas.Planning.StalePlanGateTest do
  @moduledoc """
  Chicago-style coverage of the stale-plan preimage fence (XA-3007): real
  SHA-256 digests over real terms, `ExUnit.Case` async, no mocks.

  `fingerprint/1` is pinned byte-for-byte to the private
  `Xaas.Actuation.Kernel.fingerprint/1` calculus (lib/xaas/actuation.ex) by
  recomputing the expected digest here with the raw `:crypto`/`:erlang` calls
  and an independently written canonicalizer.
  """

  use ExUnit.Case, async: true

  alias Xaas.Actuation.Refusal
  alias Xaas.Planning.StalePlanGate

  @digest_format Regex.compile!("^[0-9a-f]{64}$")

  describe "fingerprint/1" do
    test "matches the Xaas.Actuation.Kernel.fingerprint/1 calculus computed by hand" do
      term = %{
        "plan_id" => "xa-3007",
        "ticks" => 1000,
        "candidates" => [%{"item_id" => "SJ-1", "cost" => 5.0}, :ok]
      }

      expected =
        term
        |> kernel_canonical()
        |> :erlang.term_to_binary([:deterministic])
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)

      assert StalePlanGate.fingerprint(term) == expected
      assert StalePlanGate.fingerprint(term) =~ @digest_format
    end

    test "canonicalizes: atom and string keys, atom values, unordered maps agree" do
      assert StalePlanGate.fingerprint(%{"a" => 1, "b" => :ok}) ==
               StalePlanGate.fingerprint(%{:b => :ok, :a => 1})

      assert StalePlanGate.fingerprint(%{"b" => 1, "a" => %{"y" => 2, "x" => 3}}) ==
               StalePlanGate.fingerprint(%{"a" => %{"x" => 3, "y" => 2}, "b" => 1})
    end

    test "different preimages digest differently" do
      before = StalePlanGate.fingerprint(%{"candidates" => ["a"]})
      after_drift = StalePlanGate.fingerprint(%{"candidates" => ["a", "b"]})

      refute before == after_drift
    end
  end

  describe "check/2" do
    test "matching preimage digests admit the plan as fresh" do
      world = %{"plan_id" => "p1", "candidates" => ["a", "b"]}
      admitted = StalePlanGate.fingerprint(world)
      observed = StalePlanGate.fingerprint(world)

      assert {:ok, :fresh} = StalePlanGate.check(admitted, observed)
    end

    test "a plan whose observed preimage digest differs is refused with a typed stale_plan_refusal" do
      admitted = StalePlanGate.fingerprint(%{"candidates" => ["a"]})
      observed = StalePlanGate.fingerprint(%{"candidates" => ["a", "b"]})

      assert {:error, %Refusal{} = refusal} = StalePlanGate.check(admitted, observed)
      assert refusal.code == :stale_plan_refusal
      assert refusal.detail == %{admitted_preimage_hash: admitted, observed_preimage_hash: observed}
      assert Refusal.message(refusal) =~ ~r/stale_plan_refusal/
    end

    test "malformed digests refuse closed on either side" do
      good = StalePlanGate.fingerprint(%{})

      malformed = [
        nil,
        42,
        :not_a_hash,
        [],
        "",
        "abc",
        String.duplicate("A", 64),
        String.duplicate("g", 64),
        String.duplicate("0", 63),
        String.duplicate("0", 65)
      ]

      for bad <- malformed do
        assert {:error, %Refusal{code: :stale_plan_refusal, detail: :malformed_hash}} =
                 StalePlanGate.check(bad, good)

        assert {:error, %Refusal{code: :stale_plan_refusal, detail: :malformed_hash}} =
                 StalePlanGate.check(good, bad)

        assert {:error, %Refusal{code: :stale_plan_refusal, detail: :malformed_hash}} =
                 StalePlanGate.check(bad, bad)
      end
    end

    test "a malformed hash is refused even when both sides are equal" do
      assert {:error, %Refusal{code: :stale_plan_refusal, detail: :malformed_hash}} =
               StalePlanGate.check("drifted", "drifted")
    end
  end

  # Independent recomputation of the canonicalizer used by
  # Xaas.Actuation.Kernel.fingerprint/1 (lib/xaas/actuation.ex, `canonical_term`).
  defp kernel_canonical(%_{} = struct), do: struct |> Map.from_struct() |> kernel_canonical()

  defp kernel_canonical(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), kernel_canonical(value)} end)
    |> Enum.sort()
  end

  defp kernel_canonical(list) when is_list(list), do: Enum.map(list, &kernel_canonical/1)

  defp kernel_canonical(tuple) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> Enum.map(&kernel_canonical/1)

  defp kernel_canonical(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp kernel_canonical(other), do: other
end
