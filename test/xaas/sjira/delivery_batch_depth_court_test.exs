defmodule Xaas.Sjira.DeliveryBatchDepthCourtTest do
  @moduledoc """
  Lane W984di depth court on `Xaas.Sjira.DeliveryBatch` — the branches its alias
  coverage (test/xaas/sjira/atlassian_test.exs) does not touch.

  Census finding: every lib/xaas/sjira module is covered or alias-covered.
  `DeliveryBatch` is alias-covered (W984cj's claim verified) on the happy path
  (plan/topo/missing-dep/cycle, record accepted+retry, JSON roundtrip, resume
  retry_failed: true). This court deepens the uncovered remainder:

    1. resume/3 checkpoint-digest-mismatch typed refusal
    2. plan/2 batch-size ceiling (boundary 100 ok / 101 refused) typed refusal
    3. resume/3 retry_failed: false drops previously-failed ids (state-bearing)
    4. record/3 accepted-after-failure clears failure state + complete?/1
    5. checkpoint_from_json/1 shape-refusal variants (typed)

  Chicago discipline: real module, real data, assertions on final state;
  refusals asserted as the exact typed tuples the module actually returns.
  No mocks. Mutation rationale per test inline.
  """

  use ExUnit.Case, async: true
  alias Xaas.Sjira.DeliveryBatch

  defp item(id, deps \\ []),
    do: %{
      "identity" => id,
      "project_key" => "XAAS",
      "issue_type" => "Task",
      "summary" => "Deliver " <> id,
      "description" => "semantic work",
      "depends_on" => deps,
      "labels" => ["Semantic Jira"]
    }

  test "1. resume refuses a checkpoint whose batch_digest does not match the plan digest",
       do: (
    {:ok, plan} = DeliveryBatch.plan([item("A"), item("B")])
    forged = %{plan.checkpoint | batch_digest: "sha256:deadbeef"}
    expected_digest = plan.digest

    # Mutation rationale: a mutant that drops the digest guard in resume/3
    # (or compares against the wrong field) would return {:ok, _} here and fail
    # this exact-tuple assertion. The mismatched plan digest is echoed in the
    # error so replay can tell which subject diverged.
    assert {:error, {:checkpoint_digest_mismatch, "sha256:deadbeef", ^expected_digest}} =
             DeliveryBatch.resume(plan, forged)
  )

  test "2. plan enforces the batch-size ceiling exactly at 100/101",
       do: (
    # Mutation rationale: a mutant relaxing the guard to n > 0, or widening the
    # ceiling, is killed by the 100-ok/101-refused boundary pair; a mutant
    # rejecting all sizes is killed by the 100-ok leg.
    assert {:ok, p100} = DeliveryBatch.plan([item("A")], max_batch: 100)
    assert length(p100.batches) == 1

    assert {:error, {:invalid_batch_size, 101}} = DeliveryBatch.plan([item("A")], max_batch: 101)
    assert {:error, {:invalid_batch_size, 0}} = DeliveryBatch.plan([item("A")], max_batch: 0)

    assert {:error, {:invalid_batch_size, "50"}} =
             DeliveryBatch.plan([item("A")], max_batch: "50")
  )

  test "3. resume with retry_failed: false drops previously-failed ids; true keeps them",
       do: (
    {:ok, plan} = DeliveryBatch.plan([item("A"), item("B"), item("C")], max_batch: 3)

    cp =
      plan.checkpoint
      |> DeliveryBatch.record("A", %{disposition: :accepted})
      |> DeliveryBatch.record("B", %{disposition: :retry, error: "429"})

    {:ok, keep} = DeliveryBatch.resume(plan, cp, retry_failed: true)
    {:ok, drop} = DeliveryBatch.resume(plan, cp, retry_failed: false)

    ids = fn plan_res ->
      plan_res.batches |> Enum.flat_map(& &1.envelopes) |> Enum.map(& &1.semantic_id)
    end

    # Mutation rationale: a mutant inverting or ignoring the retry_failed flag
    # swaps the two returned sets and fails exactly one of these two assertions;
    # a mutant that forgets failed-filtering entirely makes keep == drop here.
    assert ids.(keep) == ["B", "C"]
    assert ids.(drop) == ["C"]
    assert keep.count == 2
    assert drop.count == 1
  )

  test "4. record accepted after failure clears the failure and completes the checkpoint",
       do: (
    {:ok, plan} = DeliveryBatch.plan([item("A"), item("B")])

    cp =
      plan.checkpoint
      |> DeliveryBatch.record("A", %{disposition: :retry, error: "boom"})
      |> DeliveryBatch.record("A", %{disposition: :accepted})
      |> DeliveryBatch.record("B", %{disposition: :accepted})

    # Mutation rationale: record/3's accepted clause must delete from failed
    # (not only append to completed) — a mutant keeping the stale failure entry
    # fails complete? here. Sort/uniq on completed is exercised by re-accepting
    # "A" (idempotent re-record keeps completed duplicate-free).
    cp = DeliveryBatch.record(cp, "A", %{disposition: :accepted})
    assert cp.completed == ["A", "B"]
    assert cp.failed == %{}
    assert cp.pending == []
    assert DeliveryBatch.complete?(cp)

    # Incomplete states stay incomplete: pending residue or failed residue.
    refute plan.checkpoint |> DeliveryBatch.record("A", %{disposition: :accepted}) |> Map.fetch!(:pending) |> Kernel.==([])

    failed_only =
      plan.checkpoint
      |> DeliveryBatch.record("A", %{disposition: :accepted})
      |> DeliveryBatch.record("B", %{disposition: :skip})

    refute DeliveryBatch.complete?(failed_only)
    assert failed_only.failed["B"]["disposition"] == "skip"
  )

  test "5. checkpoint_from_json refuses garbage and wrong-shape JSON with typed errors",
       do: (
    # Mutation rationale: a mutant collapsing both refusal arms to one generic
    # error, or accepting version != 1, fails the exact-tuple assertions below.
    assert {:error, {:invalid_checkpoint_json, _reason}} =
             DeliveryBatch.checkpoint_from_json(<<0xFF, 0xFE, "not json">>)

    assert {:error, :invalid_checkpoint} =
             DeliveryBatch.checkpoint_from_json(Jason.encode!(%{"version" => 2}))

    assert {:error, :invalid_checkpoint} =
             DeliveryBatch.checkpoint_from_json(
               Jason.encode!(%{
                 "version" => 1,
                 "batch_digest" => "sha256:x",
                 "completed" => [],
                 "pending" => "not-a-list",
                 "failed" => %{}
               })
             )

    # Valid shape round-trips to the exact map.
    cp = %{
      version: 1,
      batch_digest: "sha256:abc",
      completed: ["A"],
      pending: ["B"],
      failed: %{"B" => %{"disposition" => "retry"}}
    }

    assert {:ok, ^cp} = cp |> Jason.encode!() |> DeliveryBatch.checkpoint_from_json()
  )
end
