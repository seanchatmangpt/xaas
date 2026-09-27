defmodule Xaas.Ultracode.CapitalCensus.SelfDigestTest do
  use ExUnit.Case, async: true

  alias Xaas.Ultracode.CapitalCensus.SelfDigest

  # The G-table: recurrence class → primitive target (GC-26927-SELFDIGEST).
  describe "classify/1" do
    test "every directive class maps to its primitive target" do
      assert SelfDigest.classify(:semantic) == {:ok, :ontology}
      assert SelfDigest.classify(:structural) == {:ok, :marketplace_pack}
      assert SelfDigest.classify(:procedural) == {:ok, :hddl}
      assert SelfDigest.classify(:nondeterministic) == {:ok, :fond}
      assert SelfDigest.classify(:projection) == {:ok, :ggen}
      assert SelfDigest.classify(:routing) == {:ok, :sa2a}
      assert SelfDigest.classify(:observation) == {:ok, :beam4pm_ocel}
      assert SelfDigest.classify(:selection) == {:ok, :resolver}
      assert SelfDigest.classify(:verification) == {:ok, :court}
      assert SelfDigest.classify(:runtime) == {:ok, :otp_ash_reactor}
    end

    test "unknown classes are a typed refusal, never a guess" do
      assert {:refused, :unknown_class} = SelfDigest.classify(:vibes)
      assert {:refused, :class_must_be_atom} = SelfDigest.classify("semantic")
    end
  end

  describe "frontier_ratio/2" do
    test "computes R_t = frontier / total" do
      assert {:ok, r} = SelfDigest.frontier_ratio(3, 12)
      assert r == 0.25
      assert {:ok, 0.0} = SelfDigest.frontier_ratio(0, 12)
    end

    test "zero denominator is a typed refusal — no denominator fictions" do
      assert {:refused, :empty_denominator} = SelfDigest.frontier_ratio(0, 0)
    end

    test "malformed counts are refused" do
      assert {:refused, :invalid_counts} = SelfDigest.frontier_ratio(13, 12)
      assert {:refused, :invalid_counts} = SelfDigest.frontier_ratio(-1, 12)
      assert {:refused, :invalid_counts} = SelfDigest.frontier_ratio(1.5, 12)
    end
  end

  describe "improving?/2" do
    test "dR/dt < 0 is the improvement test; refusals never count as improvement" do
      assert SelfDigest.improving?({:ok, 0.5}, {:ok, 0.25})
      refute SelfDigest.improving?({:ok, 0.25}, {:ok, 0.25})
      refute SelfDigest.improving?({:ok, 0.25}, {:ok, 0.5})
      refute SelfDigest.improving?({:refused, :empty_denominator}, {:ok, 0.1})
    end
  end

  describe "self_work_order/1" do
    test "repeated frontier episodes emit the operator-format self-ticket" do
      episodes = [
        %{subject: "ep-1", failure_class: :runtime},
        %{subject: "ep-2", failure_class: :runtime},
        %{subject: "ep-3", failure_class: :runtime}
      ]

      assert {:ok, wo} = SelfDigest.self_work_order(episodes)
      assert wo.subject == "Xaas.Ultracode.CapitalCensus.SelfDigest"
      assert wo.observation =~ "3 frontier episodes share failure class runtime"
      assert wo.classification == :runtime
      # the candidate primitive comes from the G-table…
      assert wo.candidate_repair == {:manufacture, :otp_ash_reactor}
      # …but the missing-kind stays an open hypothesis for the replay falsifier
      assert wo.hypotheses == [:missing_capability, :missing_composition, :missing_generator, :missing_resolver_rule]
      assert wo.falsifier == {:replay, ["ep-1", "ep-2", "ep-3"]}
      assert wo.success == "1/3 episodes replay without frontier coding"
    end

    test "anti-vacuity: one episode is no recurrence" do
      assert {:refused, :no_recurrence} = SelfDigest.self_work_order([%{subject: "ep-1", failure_class: :runtime}])
      assert {:refused, :no_recurrence} = SelfDigest.self_work_order([])
    end

    test "mixed classes are a typed refusal — repetition is the evidence" do
      episodes = [
        %{subject: "ep-1", failure_class: :runtime},
        %{subject: "ep-2", failure_class: :semantic}
      ]

      assert {:refused, :classes_not_repeated} = SelfDigest.self_work_order(episodes)
    end

    test "unknown repeated class refuses typed — an unclassifiable recurrence is factory evidence" do
      episodes = [
        %{subject: "ep-1", failure_class: :vibes},
        %{subject: "ep-2", failure_class: :vibes}
      ]

      assert {:refused, :unknown_class} = SelfDigest.self_work_order(episodes)
    end

    test "malformed input refuses typed" do
      assert {:refused, :malformed_episodes} = SelfDigest.self_work_order(:not_a_list)
    end
  end
end
