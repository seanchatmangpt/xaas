defmodule Xaas.CaseStudies.WdFaStogafReceiptTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.Stogaf.Receipt

  test "receipt is bounded, deterministic architecture evidence" do
    receipt = Receipt.build("deadbeef")

    assert receipt.schema == "STOGAF_WD_CS2_RECEIPT_V1"
    assert receipt.subject_sha == "deadbeef"
    assert receipt.current_conformance == "ST-4 CONSTRAINED"
    assert receipt.target_conformance == "ST-6 AUTONOMIC"
    assert receipt.evidence_ceiling == "REPO_LOCAL_FIXTURE"
    assert receipt.authority == "SELECT_CONSTRUCT_ONLY"
    assert receipt.human_gate == "ENGINEER_DISPOSITION_REQUIRED"
    assert receipt.requirements_mapped == 16
    assert receipt.viewpoints == 5
    assert receipt.work_orders == 10
    assert receipt.friday_do_capabilities == 0
    assert receipt.production_levels_unclaimed == 3
    refute receipt.known_path_general_llm_required
    assert receipt.standing == "REPO_LOCAL_ARCHITECTURE_RECEIPT"
  end
end
