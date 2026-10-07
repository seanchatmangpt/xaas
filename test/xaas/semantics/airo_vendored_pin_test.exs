defmodule Xaas.Semantics.AiroVendoredPinTest do
  @moduledoc """
  W621b — pins the vendored AIRo vocabulary (W600's verified vendor) that all
  AIRo consumers cite, plus W601's risk-graph projection over it.

  Chicago-style: real files, real sha256, real risk_graph/0 execution.
  """

  use ExUnit.Case, async: false

  @airo_relpath "priv/semantic/airo/airo.ttl"
  @airo_readme_relpath "priv/semantic/airo/README.md"

  # W600's verified vendor pin.
  @expected_sha256 "6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469"

  @repo_root Path.expand("../../..", __DIR__)

  @airo_path Path.join(@repo_root, @airo_relpath)
  @airo_readme_path Path.join(@repo_root, @airo_readme_relpath)

  @key_classes ~w(AISystem Risk RiskSource RiskControl Vulnerability)
  @key_properties ~w(hasRisk mitigatesRiskConcept detectsRiskConcept)

  describe "vendored AIRo vocabulary pin" do
    test "airo.ttl exists" do
      assert File.exists?(@airo_path), "missing #{airo_relpath()}"
    end

    test "airo.ttl sha256 matches the W600 verified vendor pin" do
      assert File.exists?(@airo_path), "missing #{airo_relpath()}"

      actual =
        @airo_path
        |> File.read!()
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)

      assert actual == @expected_sha256,
             "airo.ttl drift: expected #{@expected_sha256}, got #{actual}"
    end

    test "README exists" do
      assert File.exists?(@airo_readme_path), "missing #{@airo_readme_relpath}"
    end

    test "key AIRo classes appear in airo.ttl content" do
      content = File.read!(@airo_path)

      for cls <- @key_classes do
        assert String.contains?(content, cls), "airo.ttl missing class #{cls}"
      end
    end

    test "key AIRo properties appear in airo.ttl content" do
      content = File.read!(@airo_path)

      for prop <- @key_properties do
        assert String.contains?(content, prop), "airo.ttl missing property #{prop}"
      end
    end
  end

  describe "W601 risk_graph/0 over the vendored vocabulary" do
    test "emits deterministically with the airo: prefix" do
      graph1 = Xaas.Semantics.AiroRiskMapping.risk_graph()
      graph2 = Xaas.Semantics.AiroRiskMapping.risk_graph()

      assert is_binary(graph1)
      assert graph1 == graph2, "risk_graph/0 is not deterministic"
      assert String.contains?(graph1, "airo:"), "risk_graph/0 output lacks the airo: prefix"
    end
  end

  defp airo_relpath, do: @airo_relpath
end
