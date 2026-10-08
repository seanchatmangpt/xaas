defmodule Xaas.ResearchRuntime.CourtW984IxTest do
  @moduledoc """
  W984ix — Chicago court for the 19 `Xaas.ResearchRuntime.*` admit-struct modules
  left uncovered by W984it's seventh re-census.

  Each entry is a real state-bearing struct with `new/1` (enforced key: nil/"" ->
  `{:error, :missing_*}`) and `admit/2` (predicate -> status flips to `:admitted`,
  refusal leaves source status untouched). Table-driven over the real modules —
  no mocks, real struct state asserted at each step.
  """
  use ExUnit.Case, async: true

  # {module, enforced key, valid value, error reason}
  @subjects [
    {Xaas.ResearchRuntime.BoundedDo, :work_order_iri, "wo-1", :missing_work_order_iri},
    {Xaas.ResearchRuntime.CommandBudget, :budget, "b-1", :missing_budget},
    {Xaas.ResearchRuntime.CommandTopology, :command_id, "ct-1", :missing_command_id},
    {Xaas.ResearchRuntime.ConsumerBoundary, :consumer_id, "cb-1", :missing_consumer_id},
    {Xaas.ResearchRuntime.EdgeSet, :edge_id, "es-1", :missing_edge_id},
    {Xaas.ResearchRuntime.FondRecovery, :edge_id, "fr-1", :missing_edge_id},
    {Xaas.ResearchRuntime.GenerationFence, :generation, "g-1", :missing_generation},
    {Xaas.ResearchRuntime.MigrationGuard, :migration_id, "mg-1", :missing_migration_id},
    {Xaas.ResearchRuntime.OsirisBoundary, :subject_sha, "sha-1", :missing_subject_sha},
    {Xaas.ResearchRuntime.PlannerBinding, :planner_id, "pb-1", :missing_planner_id},
    {Xaas.ResearchRuntime.PolyEvidence, :evidence_id, "pe-1", :missing_evidence_id},
    {Xaas.ResearchRuntime.PowlTrace, :trace_id, "pt-1", :missing_trace_id},
    {Xaas.ResearchRuntime.PromotionPolicy, :candidate_id, "pp-1", :missing_candidate_id},
    {Xaas.ResearchRuntime.QueryContract, :query_id, "qc-1", :missing_query_id},
    {Xaas.ResearchRuntime.RacapPair, :episode_id, "rp-1", :missing_episode_id},
    {Xaas.ResearchRuntime.RecoveryReceipt, :receipt_id, "rr-1", :missing_receipt_id},
    {Xaas.ResearchRuntime.SemanticPart, :part_id, "sp-1", :missing_part_id},
    {Xaas.ResearchRuntime.Steering, :context_id, "st-1", :missing_context_id},
    {Xaas.ResearchRuntime.VkgConsumer, :source_sha, "vc-1", :missing_source_sha}
  ]

  test "each subject constructs, refuses empty keys, and admits/refuses on predicate" do
    for {mod, key, valid, reason} <- @subjects do
      # new/1 with the enforced key present builds the struct in :unknown status
      assert {:ok, struct = %{^key => ^valid}} = mod.new([{key, valid}])

      assert struct.status == :unknown
      assert struct.provenance == %{}

      # nil / "" / missing key all refuse with the module's typed reason
      assert {:error, ^reason} = mod.new([{key, nil}])
      assert {:error, ^reason} = mod.new([{key, ""}])
      assert {:error, ^reason} = mod.new([])

      # admit/2 with a true predicate flips status to :admitted (real state change)
      assert {:ok, %{status: :admitted} = admitted} = mod.admit(struct, fn _ -> true end)

      assert admitted != struct

      # admit/2 with a false predicate refuses, source struct untouched
      assert {:error, :refused} = mod.admit(struct, fn _ -> false end)
      assert %{status: :unknown} = struct
    end
  end
end
