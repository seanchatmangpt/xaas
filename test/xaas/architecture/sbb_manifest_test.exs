defmodule Xaas.Architecture.SBBManifestTest do
  use ExUnit.Case, async: true

  alias Xaas.Architecture.SBBManifest

  defp manifest(overrides \\ %{}) do
    Map.merge(
      %{
        abb_digest: "sha256:" <> String.duplicate("a", 64),
        contract_digest: "sha256:" <> String.duplicate("c", 64),
        sbb_digest: "sha256:" <> String.duplicate("b", 64),
        qualification_digest: "sha256:" <> String.duplicate("d", 64),
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

  describe "hardening (adversarial, v26.9.26)" do
    test "placeholder or malformed digests are refused per field" do
      assert {:error, {:refused, {:malformed_digest, :abb_digest}}} =
               SBBManifest.realize(manifest(%{abb_digest: "sha256:abb"}))

      assert {:error, {:refused, {:malformed_digest, :contract_digest}}} =
               SBBManifest.realize(
                 manifest(%{contract_digest: "sha256:" <> String.duplicate("C", 64)})
               )

      assert {:error, {:refused, {:malformed_digest, :sbb_digest}}} =
               SBBManifest.realize(manifest(%{sbb_digest: nil}))

      assert {:error, {:refused, {:malformed_digest, :qualification_digest}}} =
               SBBManifest.realize(manifest(%{qualification_digest: String.duplicate("d", 64)}))
    end

    test "missing required field is refused, not a crash" do
      assert {:error, {:refused, {:missing_field, :sbb_digest}}} =
               SBBManifest.realize(Map.delete(manifest(), :sbb_digest))
    end

    test "non-map manifest and non-list opts are typed refusals" do
      assert {:error, {:refused, :malformed_manifest}} = SBBManifest.realize(:junk)
      assert {:error, {:refused, :malformed_manifest}} = SBBManifest.realize(manifest(), :junk)
    end

    test "malformed allowed_behaviors fail closed even with no requested behavior" do
      assert {:error, {:refused, :malformed_contract_behaviors}} =
               SBBManifest.realize(manifest(%{allowed_behaviors: :all}), behavior: :read)

      assert {:error, {:refused, :malformed_contract_behaviors}} =
               SBBManifest.realize(manifest(%{allowed_behaviors: ["read"]}))
    end

    test "a DO ceiling on a qualified manifest is refused even for a lower request" do
      assert {:error, {:refused, :do_ceiling_laundering}} =
               SBBManifest.realize(manifest(%{authority_ceiling: :do}), authority: :observe)
    end

    test "authority above ceiling and unknown authority are refused" do
      assert {:error, {:refused, :authority_ceiling_exceeded}} =
               SBBManifest.realize(manifest(%{authority_ceiling: :select}), authority: :construct)

      assert {:error, {:refused, :invalid_authority}} =
               SBBManifest.realize(manifest(), authority: :root)
    end

    test "any digest change moves semantic identity; provider/transport do not" do
      base = SBBManifest.semantic_identity(manifest())

      for field <- [:abb_digest, :contract_digest, :sbb_digest, :qualification_digest] do
        mutated = manifest(%{field => "sha256:" <> String.duplicate("e", 64)})
        refute SBBManifest.semantic_identity(mutated) == base
      end

      {:ok, r1} = SBBManifest.realize(manifest(), provider: :aws, transport: :https)
      {:ok, r2} = SBBManifest.realize(manifest(), provider: :aws, transport: :https)
      {:ok, r3} = SBBManifest.realize(manifest(), provider: :gcp, transport: :https)
      assert r1 == r2
      assert r1.semantic_identity == r3.semantic_identity
      refute r1.receipt_identity == r3.receipt_identity
    end
  end
end
