defmodule Xaas.Sa2a.ExecutionPolicyTest do
  @moduledoc """
  Pure, real-value tests of the machine admission policy and the canonical-JSON hash the
  replay check depends on. No collaborators to fake: both modules are pure functions.
  """

  use ExUnit.Case, async: true

  alias Xaas.Actuation.Refusal
  alias Xaas.Sa2a.{Canonical, ExecutionPolicy}

  @policy %{
    classes: [
      %{id: "exact", match: {:exact, ["workorder:SJ-1 resolve"]}},
      %{id: "prefixed", match: {:prefix, "workorder:"}, max_query_bytes: 40},
      %{id: "regexed", match: {:regex, "^ontology-diff:[a-z]+$"}, bind_work_order: false}
    ]
  }

  test "an empty or absent policy admits nothing (deny by default)" do
    assert {:error, {:refused, :query_not_allowlisted, "workorder:SJ-1 resolve"}} =
             ExecutionPolicy.admit_query("workorder:SJ-1 resolve", "SJ-1", %{})

    assert ExecutionPolicy.normalize([]).classes == []
  end

  test "exact, prefix and regex classes admit; the first matching class wins" do
    assert {:ok, %{id: "exact"}} =
             ExecutionPolicy.admit_query("workorder:SJ-1 resolve", "SJ-1", @policy)

    assert {:ok, %{id: "prefixed"}} =
             ExecutionPolicy.admit_query("workorder:SJ-2 other", "SJ-2", @policy)

    assert {:ok, %{id: "regexed"}} =
             ExecutionPolicy.admit_query("ontology-diff:abc", "SJ-9", @policy)
  end

  test "unknown, oversize, unbound and non-string queries are typed refusals" do
    assert {:error, {:refused, :query_not_allowlisted, "rm -rf /"}} =
             ExecutionPolicy.admit_query("rm -rf /", "SJ-1", @policy)

    assert {:error, {:refused, :query_too_long, _}} =
             ExecutionPolicy.admit_query(
               "workorder:SJ-3 " <> String.duplicate("y", 60),
               "SJ-3",
               @policy
             )

    assert {:error, {:refused, :query_not_bound_to_work_order, "SJ-4"}} =
             ExecutionPolicy.admit_query("workorder:SJ-5 resolve", "SJ-4", @policy)

    assert {:error, {:refused, :query_not_allowlisted, 42}} =
             ExecutionPolicy.admit_query(42, "SJ-1", @policy)

    assert {:error, {:refused, :query_not_allowlisted, _}} =
             ExecutionPolicy.admit_query("anything", "SJ-1", %{
               classes: [%{id: "broken", match: {:regex, "("}}]
             })
  end

  test "the shipped default policy is the sjira work-order class with the LLM-avoidance floor" do
    config = ExecutionPolicy.config()

    assert [%{id: "sjira-workorder-resolution", match: {:prefix, "workorder:"}}] = config.classes
    assert config.min_llm_avoidance_ratio == 1.0
    assert config.admitted_standings == ["KNOWN"]
  end

  test "canonical JSON hash equals Python's sort_keys/compact/ensure_ascii sha256" do
    manifest = %{
      "b" => [1, 2.5, 0.001, "q\" \\ \t\n", nil, true],
      "a" => %{"z" => "é 漢 😀", "y" => "\u007f"},
      "r" => 0.3333333333333333
    }

    assert Canonical.encode!(manifest) ==
             ~s({"a":{"y":"\\u007f","z":"\\u00e9 \\u6f22 \\ud83d\\ude00"},) <>
               ~s("b":[1,2.5,0.001,"q\\" \\\\ \\t\\n",null,true],"r":0.3333333333333333})

    # Expected digest computed independently with CPython's json + hashlib.
    assert Canonical.sha256(manifest) ==
             "4acaafdc08a70cec8677826dafc9f6445316295330b58542f1d297473d447fc8"
  end

  test "floats without an identical Python rendering and structs are refused, not mis-hashed" do
    assert_raise ArgumentError, fn -> Canonical.sha256(%{"x" => 1.0e-7}) end
    assert_raise ArgumentError, fn -> Canonical.sha256(%{"x" => 1.0e20}) end
    assert_raise ArgumentError, fn -> Canonical.sha256(%{"x" => DateTime.utc_now()}) end
  end

  test "Refusal is found through an Ash error class and is classified forbidden" do
    refusal = Refusal.new(:replay_mismatch, %{"expected" => "a"})
    assert refusal.class == :forbidden

    class = Ash.Error.to_error_class([refusal])
    assert %Refusal{code: :replay_mismatch} = Refusal.find(class)
    assert Refusal.refusal?(class)

    refute Refusal.refusal?(
             Ash.Error.to_error_class([Ash.Error.Unknown.UnknownError.exception(error: "x")])
           )
  end
end
