defmodule Xaas.Ultracode.CapitalCensus.ExperienceTest do
  @moduledoc """
  Chicago qualification of the machine-experience law and the
  inverse-experience index (`Xaas.Ultracode.CapitalCensus.Experience`;
  GC-26926-CENSUS). Pure functions over plain data: real collaborators
  are none -- that is the point. The boundary the court pins:
  `RepeatedFailureReasoning > 1` is STRICTLY greater than one, and
  `advance/2` removes exactly the promoted set and nothing else.
  """

  use ExUnit.Case, async: true

  alias Xaas.Ultracode.CapitalCensus.Experience

  defp exp(outcome, action, overrides \\ %{}) do
    Experience.new(
      Map.get(overrides, :state, %{branch: "feat/x", head: "da83d0e"}),
      action,
      Map.get(overrides, :observation, %{ocel_events: 3}),
      outcome,
      Map.get(overrides, :evidence, %{receipt_digest: "sha256:" <> String.duplicate("a", 64)})
    )
  end

  describe "new/5 -- the experience tuple" do
    test "builds the 5-key map (State, Action, Observation, Outcome, Evidence) and nothing else" do
      state = %{branch: "feat/census"}
      action = "mix_compile"
      observation = %{exit: 1}
      outcome = :failure
      evidence = %{receipt: "r-1"}

      tuple = Experience.new(state, action, observation, outcome, evidence)

      assert %{
               state: ^state,
               action: ^action,
               observation: ^observation,
               outcome: ^outcome,
               evidence: ^evidence
             } = tuple

      assert MapSet.new(Map.keys(tuple)) == MapSet.new([:state, :action, :observation, :outcome, :evidence])
    end
  end

  describe "failure_class/1 -- stable class keys" do
    test "the same outcome + action shape is the same class whatever the observation, evidence or state" do
      first = exp(:failure, "mix_compile")
      second = exp(:failure, "mix_compile", %{state: %{branch: "other"}, observation: %{exit: 2}, evidence: %{receipt: "r-2"}})

      assert Experience.failure_class(first) == Experience.failure_class(second)
      assert Experience.failure_class(first) == "failure:mix_compile"
    end

    test "a different outcome or a different action moves the class" do
      failure = exp(:failure, "mix_compile")

      refute Experience.failure_class(failure) == Experience.failure_class(exp(:alive, "mix_compile"))
      refute Experience.failure_class(failure) == Experience.failure_class(exp(:failure, "mix_format"))
    end

    test "atom and binary actions shape the same; structured actions are deterministic" do
      assert Experience.failure_class(exp(:failure, :mix_compile)) ==
               Experience.failure_class(exp(:failure, "mix_compile"))

      structured = {:gate, :worktree}

      assert Experience.failure_class(exp(:failure, structured)) ==
               Experience.failure_class(exp(:failure, structured))
    end
  end

  describe "system_defect?/1 -- RepeatedFailureReasoning > 1 => SystemDefect" do
    test "exactly one occurrence of a failure class is NOT a defect (the > 1 boundary)" do
      refute Experience.system_defect?([exp(:failure, "mix_compile")])

      refute Experience.system_defect?([
               exp(:failure, "mix_compile"),
               exp(:alive, "mix_compile"),
               exp(:alive, "mix_format")
             ])
    end

    test "two occurrences of the SAME failure class are a defect (the boundary flips at 2)" do
      assert Experience.system_defect?([
               exp(:failure, "mix_compile"),
               exp(:failure, "mix_compile", %{observation: %{exit: 2}})
             ])
    end

    test "two failures of DIFFERENT classes are not a defect; successes never count" do
      refute Experience.system_defect?([
               exp(:failure, "mix_compile"),
               exp(:failure, "mix_format"),
               exp(:alive, "mix_compile"),
               exp(:alive, "mix_compile")
             ])
    end

    test "the string spelling of the failure outcome counts as a reasoning failure too" do
      assert Experience.system_defect?([
               exp("failure", "gate_refusal"),
               exp("failure", "gate_refusal")
             ])
    end

    test "failure_counts/1 exposes the judged classes and their repeat counts" do
      counts =
        Experience.failure_counts([
          exp(:failure, "mix_compile"),
          exp(:failure, "mix_compile"),
          exp(:failure, "gate_refusal"),
          exp(:alive, "mix_compile")
        ])

      assert counts == %{"failure:mix_compile" => 2, "failure:gate_refusal" => 1}
      assert Experience.failure_counts([]) == %{}
    end

    test "the empty experience log is not a defect" do
      refute Experience.system_defect?([])
    end
  end

  describe "advance/2 -- IEC_{n+1} = IEC_n - Promoted(Capital_n)" do
    test "removes exactly the promoted set and nothing else (anti-vacuity)" do
      iec = ~w(route:llm plan:htn constraint:sat generate:ggen)a

      after_one = Experience.advance(iec, [:"plan:htn"])
      assert MapSet.to_list(after_one) |> Enum.sort() == ~w(constraint:sat generate:ggen route:llm)a

      after_all = Experience.advance(iec, ~w(route:llm plan:htn constraint:sat generate:ggen)a)
      assert MapSet.size(after_all) == 0
    end

    test "promoted keys absent from the index are no-ops; the rest of the index is untouched" do
      iec = ~w(plan:htn generate:ggen)a

      assert Experience.advance(iec, ~w(route:llm recipe:mix-format)a) |> MapSet.to_list() |> Enum.sort() ==
               ~w(generate:ggen plan:htn)a

      assert Experience.advance(iec, []) |> MapSet.to_list() |> Enum.sort() == ~w(generate:ggen plan:htn)a
    end

    test "accepts MapSet or list for the index and a single key for promoted" do
      from_set = Experience.advance(MapSet.new(~w(a b c)a), "b")
      from_list = Experience.advance(~w(a b c)a, ["b"])

      assert from_set == from_list
      assert MapSet.to_list(from_set) |> Enum.sort() == ~w(a c)a
    end

    test "advance twice is set difference composed: no re-additions" do
      iec_0 = ~w(a b c d)a
      iec_1 = Experience.advance(iec_0, ~w(b d)a)
      iec_2 = Experience.advance(iec_1, ~w(a)a)

      assert MapSet.to_list(iec_2) == ~w(c)a
    end
  end

  describe "deficit/1 -- the retirement metric" do
    test "the set's size, falling as capital is promoted" do
      iec_0 = ~w(a b c)a
      assert Experience.deficit(iec_0) == 3

      iec_1 = Experience.advance(iec_0, ~w(b)a)
      assert Experience.deficit(iec_1) == 2

      iec_2 = Experience.advance(iec_1, ~w(a c)a)
      assert Experience.deficit(iec_2) == 0
    end

    test "deficit after advance drops by the promoted keys ACTUALLY in the index, and only those" do
      iec = ~w(a b)a

      assert Experience.deficit(Experience.advance(iec, ~w(b not-in-index)a)) ==
               Experience.deficit(iec) - 1

      assert Experience.deficit(Experience.advance(iec, ~w(x y z)a)) == Experience.deficit(iec)
    end

    test "the empty index has deficit 0" do
      assert Experience.deficit([]) == 0
      assert Experience.deficit(MapSet.new()) == 0
    end
  end
end
