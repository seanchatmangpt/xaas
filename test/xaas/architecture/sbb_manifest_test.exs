defmodule Xaas.Architecture.SBBManifestTest do
  use ExUnit.Case, async: true

  alias Xaas.Architecture.SBBManifest

  defp manifest(overrides \\ %{}) do
    Map.merge(
      %{
        abb_digest: "sha256:abb",
        contract_digest: "sha256:contract",
        sbb_digest: "sha256:sbb",
        qualification_digest: "sha256:qualification",
        standing: :qualified,
        immutable_subject: true,
        authority_ceiling: :construct,
        allowed_behaviors: [:read, :prepare]
      },
      overrides
    )
  end

  test "provider substitution preserves semantic SBB identity" do
    assert {:ok, aws} =
             SBBManifest.realize(manifest(),
               provider: :aws,
               transport: :https,
               behavior: :prepare,
               authority: :construct
             )

    assert {:ok, gcp} =
             SBBManifest.realize(manifest(),
               provider: :gcp,
               transport: :grpc,
               behavior: :prepare,
               authority: :construct
             )

    assert aws.semantic_identity == gcp.semantic_identity
    assert aws.execution_authority == :none
    assert gcp.execution_authority == :none
    assert aws.brce_required_for_do
  end

  test "qualification does not grant DO" do
    assert {:error, {:refused, :brce_required}} =
             SBBManifest.realize(manifest(), authority: :do)
  end

  test "out-of-contract behavior, UNKNOWN and mutable identity fail closed" do
    assert {:error, {:refused, :contract_behavior_violation}} =
             SBBManifest.realize(manifest(), behavior: :delete)

    assert {:error, {:refused, :unknown_standing}} =
             SBBManifest.realize(manifest(%{standing: :unknown}))

    assert {:error, {:refused, :mutable_subject}} =
             SBBManifest.realize(manifest(%{immutable_subject: false}))
  end
end
