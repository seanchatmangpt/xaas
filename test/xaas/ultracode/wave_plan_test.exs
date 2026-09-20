defmodule Xaas.Ultracode.WavePlanTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Qualification of the wave planning law (`Xaas.Ultracode.WavePlan`): the
  pure core of multi-repo wave planning. No DB, no git, no subprocess --
  these are laws, so they are tested exhaustively and cheaply:

    * determinism: the same registry/sensed state ALWAYS yields the same
      plan (sorted aliases, round-robin draw, no clocks or randomness);
    * no starvation: while a repo has ready items it contributes at least
      one item per wave -- the first N items of a plan cover N repos;
    * per-repo caps bound one repo's draw without touching the rotation
      order of the others;
    * repo tags: every planned item carries its `"repo"` alias;
    * typed refusals for bad specs, unknown aliases, bad caps.
  """

  alias Xaas.Ultracode.WavePlan

  @registry %{"alpha" => "/r/alpha", "beta" => "/r/beta", "gamma" => "/r/gamma"}

  defp items(prefix, ids), do: Enum.map(ids, &%{"id" => "#{prefix}-#{&1}", "goal" => "do #{&1}"})

  # ------------------------------------------------------------------
  # parse_spec/1 (shape only -- admission-time validation)
  # ------------------------------------------------------------------

  describe "parse_spec/1" do
    test "one alias" do
      assert WavePlan.parse_spec("aps") == {:ok, ["aps"]}
    end

    test "a list is trimmed, deduped, and sorted" do
      assert WavePlan.parse_spec(" gamma,beta , alpha,gamma") ==
               {:ok, ["alpha", "beta", "gamma"]}
    end

    test "all is the sentinel" do
      assert WavePlan.parse_spec("all") == {:ok, :all}
    end

    test "bad shapes are typed refusals" do
      assert WavePlan.parse_spec("") == {:error, {:bad_repo_spec, ""}}
      assert WavePlan.parse_spec("a,,b") == {:error, {:bad_repo_spec, "a,,b"}}
      assert WavePlan.parse_spec("  ") == {:error, {:bad_repo_spec, "  "}}
      assert WavePlan.parse_spec(nil) == {:error, {:bad_repo_spec, nil}}
      assert WavePlan.parse_spec(:all) == {:error, {:bad_repo_spec, :all}}
    end
  end

  # ------------------------------------------------------------------
  # resolve/2 (spec + registry)
  # ------------------------------------------------------------------

  describe "resolve/2" do
    test "one alias resolves to itself" do
      assert WavePlan.resolve("beta", @registry) == {:ok, ["beta"]}
    end

    test "a list resolves in sorted order regardless of spelling" do
      assert WavePlan.resolve("gamma,beta,alpha", @registry) == {:ok, ["alpha", "beta", "gamma"]}
      assert WavePlan.resolve("alpha,beta", @registry) == {:ok, ["alpha", "beta"]}
    end

    test "all resolves to every registered alias, sorted" do
      assert WavePlan.resolve("all", @registry) == {:ok, ["alpha", "beta", "gamma"]}
    end

    test "all over an empty registry is a typed refusal" do
      assert WavePlan.resolve("all", %{}) == {:error, :no_registered_repos}
    end

    test "an unknown alias is a typed refusal naming it" do
      assert WavePlan.resolve("ghost", @registry) == {:error, {:unknown_repo_alias, "ghost"}}

      assert WavePlan.resolve("alpha,ghost", @registry) ==
               {:error, {:unknown_repo_alias, "ghost"}}
    end
  end

  # ------------------------------------------------------------------
  # validate_caps/1
  # ------------------------------------------------------------------

  describe "validate_caps/1" do
    test "nil and empty are uncapped" do
      assert WavePlan.validate_caps(nil) == {:ok, %{}}
      assert WavePlan.validate_caps(%{}) == {:ok, %{}}
    end

    test "alias -> non-negative integers pass through" do
      assert WavePlan.validate_caps(%{"alpha" => 2, "beta" => 0}) ==
               {:ok, %{"alpha" => 2, "beta" => 0}}
    end

    test "any other shape is a typed refusal" do
      assert WavePlan.validate_caps(%{"alpha" => -1}) ==
               {:error, {:bad_repo_caps, %{"alpha" => -1}}}

      assert WavePlan.validate_caps(%{"alpha" => "many"}) ==
               {:error, {:bad_repo_caps, %{"alpha" => "many"}}}

      assert WavePlan.validate_caps("3") == {:error, {:bad_repo_caps, "3"}}
    end
  end

  # ------------------------------------------------------------------
  # rotate/2 (the draw)
  # ------------------------------------------------------------------

  describe "rotate/2" do
    test "draws round-robin over sorted aliases; the first N items cover N repos" do
      sensed = %{
        "alpha" => items("a", ["1", "2", "3"]),
        "beta" => items("b", ["1", "2"]),
        "gamma" => items("g", ["1"])
      }

      plan = WavePlan.rotate(sensed, nil)

      assert Enum.map(plan, & &1["id"]) == ["a-1", "b-1", "g-1", "a-2", "b-2", "a-3"]

      # No starvation: each repo appears in the first |repos| items.
      first_round = plan |> Enum.take(3) |> Enum.map(& &1["repo"]) |> Enum.uniq()
      assert first_round == ["alpha", "beta", "gamma"]
    end

    test "every planned item is tagged with its repo" do
      plan = WavePlan.rotate(%{"beta" => items("b", ["1"]), "alpha" => items("a", ["1"])}, nil)
      assert Enum.all?(plan, &is_binary(&1["repo"]))
      assert Enum.map(plan, &{&1["repo"], &1["id"]}) == [{"alpha", "a-1"}, {"beta", "b-1"}]
    end

    test "a per-repo cap bounds that repo's draw; others rotate untouched" do
      sensed = %{
        "alpha" => items("a", ["1", "2", "3", "4"]),
        "beta" => items("b", ["1", "2"])
      }

      plan = WavePlan.rotate(sensed, %{"alpha" => 1})

      assert Enum.map(plan, &{&1["repo"], &1["id"]}) == [
               {"alpha", "a-1"},
               {"beta", "b-1"},
               {"beta", "b-2"}
             ]
    end

    test "a cap of zero silences a repo for this wave" do
      plan =
        WavePlan.rotate(%{"alpha" => items("a", ["1"]), "beta" => items("b", ["1"])}, %{
          "alpha" => 0
        })

      assert Enum.map(plan, & &1["repo"]) == ["beta"]
    end

    test "a cap for an unselected repo is inert" do
      plan =
        WavePlan.rotate(%{"alpha" => items("a", ["1", "2"])}, %{"ghost" => 1})

      assert Enum.map(plan, & &1["id"]) == ["a-1", "a-2"]
    end

    test "repos with no ready items are skipped without disturbing the order" do
      sensed = %{"alpha" => [], "beta" => items("b", ["1", "2"]), "gamma" => items("g", ["1"])}
      plan = WavePlan.rotate(sensed, nil)

      assert Enum.map(plan, &{&1["repo"], &1["id"]}) == [
               {"beta", "b-1"},
               {"gamma", "g-1"},
               {"beta", "b-2"}
             ]
    end

    test "an all-empty backlog plans an empty wave" do
      assert WavePlan.rotate(%{"alpha" => []}, nil) == []
      assert WavePlan.rotate(%{}, nil) == []
    end

    test "determinism: the same state always yields the byte-identical plan" do
      sensed = %{
        "gamma" => items("g", ["1", "2"]),
        "alpha" => items("a", ["1", "2"]),
        "beta" => items("b", ["1"])
      }

      caps = %{"alpha" => 2}

      plan1 = WavePlan.rotate(sensed, caps)
      plan2 = WavePlan.rotate(sensed, caps)
      plan3 = WavePlan.rotate(sensed, caps)

      assert plan1 == plan2
      assert plan2 == plan3

      assert plan1 ==
               WavePlan.rotate(
                 %{
                   "alpha" => items("a", ["1", "2"]),
                   "beta" => items("b", ["1"]),
                   "gamma" => items("g", ["1", "2"])
                 },
                 caps
               )
    end
  end
end
