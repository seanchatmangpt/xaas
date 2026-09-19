defmodule Xaas.Gall.SemanticReceiptTest do
  use ExUnit.Case, async: true

  alias Xaas.Gall.SemanticReceipt

  @base_sha "6d5fca8cff223eb30ef19e237574d54f21cbfc15"
  @candidate_sha "0123456789abcdef0123456789abcdef01234567"
  @checkpoint_digest String.duplicate("ab", 32)
  @started "2026-09-18T10:00:00Z"
  @finished "2026-09-18T10:05:00Z"

  @valid_fields [
    receipt_id: "rcpt-001",
    checkpoint_iri: "urn:gall:checkpoint:xaas:semantic-worker-001",
    checkpoint_digest: @checkpoint_digest,
    repository: "urn:repo:seanchatmangpt:xaas",
    base_sha: @base_sha,
    candidate_sha: @candidate_sha,
    run_id: "run-42",
    epoch_id: "epoch-7",
    lease_fingerprint: "lease-fp-9f2c",
    provider: "xaas-fabric",
    worker_id: "worker-01",
    runtime_version: "OTP 27.2 / Elixir 1.18.1",
    model_identity: "builtin:test-model",
    started_at: @started,
    finished_at: @finished,
    admitted_capabilities: [:Read, :Edit, :Commit],
    observed_tool_classes: ["mix_test", "git_commit"],
    claimed_outcome: "alive",
    verified_outcome: "alive",
    verifier_id: "https://semantic-a2a.dev/gall#XaasChicagoCourt",
    verifier_result: "pass",
    standing: :ALIVE,
    replay_identity: "replay:run-42:epoch-7:#{@candidate_sha}"
  ]

  defp valid_fields(overrides) do
    @valid_fields |> Keyword.merge(overrides) |> Map.new()
  end

  describe "new/1 (sealing the receipt shape)" do
    test "builds a receipt from the PRD section 17 minimum field set" do
      assert {:ok, receipt} = SemanticReceipt.new(valid_fields([]))

      assert receipt.receipt_id == "rcpt-001"
      assert receipt.checkpoint_iri == "urn:gall:checkpoint:xaas:semantic-worker-001"
      assert receipt.checkpoint_digest == @checkpoint_digest
      assert receipt.base_sha == @base_sha
      assert receipt.candidate_sha == @candidate_sha
      assert receipt.standing == :ALIVE
      assert receipt.admitted_capabilities == [:Read, :Edit, :Commit]
      assert receipt.replay_identity == "replay:run-42:epoch-7:#{@candidate_sha}"
    end

    test "parses ISO8601 timestamps into DateTimes and accepts DateTime values" do
      assert {:ok, receipt} = SemanticReceipt.new(valid_fields([]))
      assert %DateTime{} = receipt.started_at
      assert %DateTime{} = receipt.finished_at
      assert DateTime.compare(receipt.finished_at, receipt.started_at) == :gt

      assert {:ok, receipt} =
               SemanticReceipt.new(
                 valid_fields(
                   started_at: DateTime.utc_now(),
                   finished_at: DateTime.utc_now()
                 )
               )

      assert %DateTime{} = receipt.finished_at
    end

    test "refuses ANY missing required field with :refused_authority (never raises)" do
      for key <- [:receipt_id, :checkpoint_digest, :run_id, :lease_fingerprint, :replay_identity] do
        fields = valid_fields([]) |> Map.delete(key)
        assert SemanticReceipt.new(fields) == {:refused, :refused_authority}
      end
    end

    test "refuses malformed checkpoint identity with :refused_subject_mismatch" do
      assert SemanticReceipt.new(valid_fields(checkpoint_iri: "urn:repo:not-a-checkpoint")) ==
               {:refused, :refused_subject_mismatch}
    end

    test "refuses malformed repository with :refused_subject_mismatch" do
      assert SemanticReceipt.new(valid_fields(repository: "repo:xaas")) ==
               {:refused, :refused_subject_mismatch}
    end

    test "refuses non-40-hex SHAs and non-64-hex digest with :refused_subject_mismatch" do
      assert SemanticReceipt.new(valid_fields(base_sha: "deadbeef")) ==
               {:refused, :refused_subject_mismatch}

      assert SemanticReceipt.new(valid_fields(candidate_sha: String.duplicate("f", 41))) ==
               {:refused, :refused_subject_mismatch}

      assert SemanticReceipt.new(valid_fields(checkpoint_digest: String.duplicate("f", 63))) ==
               {:refused, :refused_subject_mismatch}
    end

    test "refuses out-of-vocabulary capabilities with :refused_capability" do
      assert SemanticReceipt.new(valid_fields(admitted_capabilities: [:Read, :Teleport])) ==
               {:refused, :refused_capability}
    end

    test "refuses out-of-vocabulary standing with :refused_authority" do
      assert SemanticReceipt.new(valid_fields(standing: "SUPER_ALIVE")) ==
               {:refused, :refused_authority}
    end

    test "refuses unparseable timestamps with :refused_authority" do
      assert SemanticReceipt.new(valid_fields(started_at: "yesterday-ish")) ==
               {:refused, :refused_authority}
    end

    test "refuses a non-chronological interval with :refused_authority" do
      assert SemanticReceipt.new(valid_fields(started_at: @finished, finished_at: @started)) ==
               {:refused, :refused_authority}
    end

    test "refuses non-map input with :refused_authority" do
      assert SemanticReceipt.new(42) == {:refused, :refused_authority}
    end
  end

  describe "JSON projection" do
    test "the receipt round-trips through Jason" do
      {:ok, receipt} = SemanticReceipt.new(valid_fields([]))
      json = Jason.encode!(Map.from_struct(receipt))
      decoded = Jason.decode!(json)

      assert decoded["receipt_id"] == "rcpt-001"
      assert decoded["standing"] == "ALIVE"
      assert decoded["admitted_capabilities"] == ["Read", "Edit", "Commit"]
      assert decoded["candidate_sha"] == @candidate_sha
      assert decoded["finished_at"] == "2026-09-18T10:05:00Z"
    end
  end
end
