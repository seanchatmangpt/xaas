defmodule Xaas.PradyotChicagoSubjectCourtTest do
  use ExUnit.Case, async: true
  alias Xaas.Planning.StalePlanGate
  alias Xaas.Sa2a.{Court, ExecutionPolicy}

  @subject "urn:chicago:agentic-payment:purchase-001"
  @policy %{classes: [%{id: "pradyot-purchase", match: {:prefix, "workorder:"}, bind_work_order: true, max_query_bytes: 512}], admitted_standings: ["KNOWN"], min_llm_avoidance_ratio: 1.0, max_compiled_rules: 64}

  defp request do
    %{"work_order_id" => @subject, "work_order_digest" => "sha256:" <> String.duplicate("1", 32),
      "query" => "workorder:#{@subject} resolve",
      "plan" => %{"plan_hash" => String.duplicate("a", 64), "candidates" => [%{"item_id" => @subject}]}}
  end

  test "exact subject reaches the existing query admission boundary" do
    assert {:ok, %{id: "pradyot-purchase"}} = ExecutionPolicy.admit_query(request()["query"], @subject, @policy)
  end

  test "cross-subject reuse is typed refusal" do
    assert {:error, {:refused, :query_not_bound_to_work_order, ^@subject}} =
      ExecutionPolicy.admit_query("workorder:urn:chicago:agentic-payment:purchase-OTHER resolve", @subject, @policy)
  end

  test "missing evidence cannot pass the existing court" do
    assert {:error, {:refused, :admit_receipt_missing, _}} = Court.admit(request(), @policy)
  end

  test "policy drift invalidates stale plan before evidence admission" do
    preimage = %{"subject" => @subject, "policy" => %{"delegation_limit" => 100}, "candidates" => [%{"item_id" => @subject}]}
    stale = request()
      |> put_in(["plan", "preimage"], preimage)
      |> put_in(["plan", "admitted_preimage_hash"], StalePlanGate.fingerprint(%{preimage | "policy" => %{"delegation_limit" => 50}}))

    assert {:error, {:refused, :stale_plan_refusal, %{admitted_preimage_hash: admitted, observed_preimage_hash: observed}}} =
      Court.admit(stale, @policy)
    refute admitted == observed
  end
end
