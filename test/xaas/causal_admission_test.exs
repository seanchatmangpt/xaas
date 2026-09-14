defmodule Xaas.CausalAdmissionTest do
  @moduledoc """
  Chicago-style qualification for the causal proof-obligation gate.

  These tests use the real Ash resources, Reactor actuation path, and sandboxed
  Postgres data layer. They prove that an intervention marked as requiring
  causal identification cannot reach DO without an admitted evidence
  certificate, while a structurally admitted certificate is durably bound to
  the resulting ActuationIntent authority evidence.
  """

  use ExUnit.Case, async: true

  alias Xaas.Marketplace.Provider
  alias Xaas.Operations.ActuationReceipt

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_provider! do
    Xaas.Generator.create_provider!(%{name: "Causal Provider", org_id: "org-causal"})
  end

  defp certificate(overrides \\ %{}) do
    Map.merge(
      %{
        required: true,
        status: :admitted,
        strategy: :backdoor,
        verifier: "kgc-causal-verifier:v1",
        dag_proof_hash: "sha256:dag-proof-fixture",
        assumptions_hash: "sha256:assumptions-fixture",
        placebo_result_hash: "sha256:placebo-fixture",
        falsifier: "reject if the admitted adjustment set no longer d-separates treatment and outcome"
      },
      overrides
    )
  end

  test "required causal intervention without an admitted certificate cannot reach DO" do
    provider = create_provider!()
    key = "test-causal-refusal-#{System.unique_integer([:positive])}"
    receipts_before = length(Ash.read!(ActuationReceipt, authorize?: false))

    assert {:error, reason} =
             Xaas.Actuation.run(
               Provider,
               :actuate_status,
               %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{
                 kind: "test_authority",
                 causal: %{required: true}
               }
             )

    assert inspect(reason) =~ "causal admission"
    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) == :pending
    assert length(Ash.read!(ActuationReceipt, authorize?: false)) == receipts_before
  end

  test "admitted causal certificate crosses admission and is persisted with the intent" do
    provider = create_provider!()
    key = "test-causal-admitted-#{System.unique_integer([:positive])}"

    assert {:ok, result} =
             Xaas.Actuation.run(
               Provider,
               :actuate_status,
               %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{
                 kind: "test_authority",
                 causal: certificate()
               }
             )

    assert result.status == :succeeded
    assert result.receipt.status == :succeeded
    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) == :active

    causal = result.intent.authority["causal"]
    assert causal["required"] == true
    assert causal["status"] == "admitted"
    assert causal["strategy"] == "backdoor"
    assert causal["verifier"] == "kgc-causal-verifier:v1"
    assert causal["dag_proof_hash"] == "sha256:dag-proof-fixture"
    assert causal["placebo_result_hash"] == "sha256:placebo-fixture"
  end

  test "unsupported causal identification strategy is refused before DO" do
    provider = create_provider!()
    key = "test-causal-strategy-#{System.unique_integer([:positive])}"

    assert {:error, reason} =
             Xaas.Actuation.run(
               Provider,
               :actuate_status,
               %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{
                 kind: "test_authority",
                 causal: certificate(%{strategy: :magic})
               }
             )

    assert inspect(reason) =~ "unsupported causal identification strategy"
    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) == :pending
  end
end
