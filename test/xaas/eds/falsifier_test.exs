defmodule Xaas.Eds.FalsifierTest do
  @moduledoc """
  Chicago-style qualification for `Xaas.Eds.Falsifier`. No mocking: real
  1-arity predicate functions, real construction refusal on degenerate
  falsifiers, real exception handling.
  """

  use ExUnit.Case, async: true

  alias Xaas.Eds.Falsifier

  describe "new/1" do
    test "constructs a real falsifier with a real predicate" do
      assert {:ok, %Falsifier{id: "f1"}} =
               Falsifier.new(%{
                 id: "f1",
                 description: "coverage(A) <= coverage(B) falsifies the claim",
                 predicate: fn %{coverage_a: a, coverage_b: b} ->
                   if a > b, do: :survived, else: :falsified
                 end
               })
    end

    test "refuses a falsifier explicitly marked vacuous" do
      assert {:error, message} =
               Falsifier.new(%{
                 id: "f2",
                 description: "always survives",
                 predicate: fn _ -> :survived end,
                 vacuous: true
               })

      assert message =~ "vacuous"
    end

    test "refuses when predicate is not a 1-arity function" do
      assert {:error, message} =
               Falsifier.new(%{
                 id: "f3",
                 description: "bad arity",
                 predicate: fn -> :survived end
               })

      assert message =~ "1-arity"
    end

    test "refuses when id or description is blank" do
      assert {:error, _} =
               Falsifier.new(%{id: "", description: "x", predicate: fn _ -> :survived end})

      assert {:error, _} =
               Falsifier.new(%{id: "f4", description: "", predicate: fn _ -> :survived end})
    end
  end

  describe "run/2" do
    setup do
      {:ok, falsifier} =
        Falsifier.new(%{
          id: "coverage-falsifier",
          description: "Method A coverage must exceed Method B",
          predicate: fn %{coverage_a: a, coverage_b: b} ->
            if a > b, do: :survived, else: :falsified
          end
        })

      %{falsifier: falsifier}
    end

    test "returns :survived when the predicate genuinely survives", %{falsifier: f} do
      assert Falsifier.run(f, %{coverage_a: 0.9, coverage_b: 0.5}) == {:ok, :survived}
    end

    test "returns :falsified when the real evidence contradicts the claim", %{falsifier: f} do
      assert Falsifier.run(f, %{coverage_a: 0.3, coverage_b: 0.7}) == {:ok, :falsified}
    end

    test "a predicate that raises is surfaced as an error, never silently treated as :survived" do
      {:ok, broken} =
        Falsifier.new(%{
          id: "broken",
          description: "raises on missing key",
          predicate: fn %{required_key: v} -> v end
        })

      assert {:error, message} = Falsifier.run(broken, %{})
      assert message =~ "raised"
    end

    test "a predicate returning a non-verdict value is surfaced as an error" do
      {:ok, malformed} =
        Falsifier.new(%{
          id: "malformed",
          description: "wrong return",
          predicate: fn _ -> :maybe end
        })

      assert {:error, message} = Falsifier.run(malformed, %{})
      assert message =~ "expected :survived or :falsified"
    end
  end
end
