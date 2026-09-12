defmodule Xaas.FrontierEvidenceTest do
  @moduledoc """
  Chicago-style qualification for composition of bounded evidence from beam4pm,
  ash_r2rml, GitVan, and ash_pplan at the XaaS BRCE admission boundary.
  """

  use ExUnit.Case, async: true

  alias Xaas.Actuation.FrontierEvidence
  alias Xaas.Marketplace.Provider
  alias Xaas.Operations.ActuationReceipt

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp fragment(producer, ceiling, head, marker) do
    %{
      schema: "frontier-evidence/v1",
      producer: producer,
      producer_head: head,
      standing: "PARTIAL_ALIVE",
      authority_ceiling: ceiling,
      evidence: %{marker: marker},
      artifact_hash: "sha256:" <> String.duplicate(marker, 64)
    }
  end

  defp fragments do
    [
      fragment(
        "beam4pm",
        "SELECT",
        "3e7470b49f0f51a448963cdeaef05ed45576a2a9",
        "a"
      ),
      fragment(
        "ash_r2rml",
        "CONSTRUCT",
        "353ff59cabdad0d21e076bf6b935e2e218813d5d",
        "b"
      ),
      fragment(
        "gitvan",
        "OBSERVE",
        "6e5dee084ffca9738edd70181b45219129ee765d",
        "c"
      ),
      fragment(
        "ash_pplan",
        "CONSTRUCT",
        "ea2eb24fbe8417de1dfc4025137c28a2e00ad308",
        "d"
      )
    ]
  end

  defp causal_certificate do
    %{
      required: true,
      status: :admitted,
      strategy: :backdoor,
      verifier: "causal-verifier:v1",
      dag_proof_hash: "sha256:dag-proof-fixture",
      assumptions_hash: "sha256:assumptions-fixture",
      placebo_result_hash: "sha256:placebo-fixture",
      falsifier: "reject when the admitted adjustment set no longer identifies the effect"
    }
  end

  defp create_provider! do
    Xaas.Generator.create_provider!(%{name: "Frontier Provider", org_id: "org-frontier"})
  end

  test "four bounded producer fragments compose into one deterministic bundle" do
    assert {:ok, first} = FrontierEvidence.bundle(fragments())
    assert {:ok, second} = FrontierEvidence.bundle(Enum.reverse(fragments()))

    assert first["schema"] == "frontier-evidence-bundle/v1"
    assert first["bundle_sha256"] =~ ~r/^sha256:[0-9a-f]{64}$/
    assert first["bundle_sha256"] == second["bundle_sha256"]
    assert Map.keys(first["fragments"]) |> Enum.sort() ==
             ~w(ash_pplan ash_r2rml beam4pm gitvan)
    assert :ok = FrontierEvidence.validate_bundle(first)
  end

  test "missing producer and widened authority ceiling are refused" do
    incomplete = Enum.reject(fragments(), &(&1.producer == "gitvan"))

    assert {:error, {:missing_frontier_producers, ["gitvan"]}} =
             FrontierEvidence.bundle(incomplete)

    widened =
      Enum.map(fragments(), fn
        %{producer: "beam4pm"} = fragment -> %{fragment | authority_ceiling: "DO"}
        fragment -> fragment
      end)

    assert {:error, {:authority_ceiling_mismatch, "beam4pm", "DO", "SELECT"}} =
             FrontierEvidence.bundle(widened)
  end

  test "causal certificate may bind the exact supporting bundle and cross Reactor DO" do
    provider = create_provider!()
    key = "test-frontier-admitted-#{System.unique_integer([:positive])}"

    assert {:ok, authority} = FrontierEvidence.bind_causal(causal_certificate(), fragments())
    authority = Map.put(authority, "kind", "test_authority")

    assert authority["causal"]["supporting_evidence_hash"] ==
             authority["frontier_evidence"]["bundle_sha256"]

    assert {:ok, result} =
             Xaas.Actuation.run(
               Provider,
               :actuate_status,
               %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: authority
             )

    assert result.status == :succeeded
    assert result.receipt.status == :succeeded
    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) == :active

    persisted = result.intent.authority

    assert persisted["causal"]["supporting_evidence_hash"] ==
             persisted["frontier_evidence"]["bundle_sha256"]
  end

  test "mismatched causal/supporting evidence binding is refused before DO" do
    provider = create_provider!()
    key = "test-frontier-mismatch-#{System.unique_integer([:positive])}"
    receipts_before = length(Ash.read!(ActuationReceipt, authorize?: false))

    assert {:ok, authority} = FrontierEvidence.bind_causal(causal_certificate(), fragments())

    authority =
      authority
      |> put_in(["causal", "supporting_evidence_hash"], "sha256:" <> String.duplicate("f", 64))
      |> Map.put("kind", "test_authority")

    assert {:error, reason} =
             Xaas.Actuation.run(
               Provider,
               :actuate_status,
               %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: authority
             )

    assert inspect(reason) =~ "supporting evidence hash does not match"
    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) == :pending
    assert length(Ash.read!(ActuationReceipt, authorize?: false)) == receipts_before
  end
end
