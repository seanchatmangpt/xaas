defmodule Xaas.Actuation.CausalAdmissionDepthTest do
  @moduledoc """
  Chicago depth court for the uncovered branches of
  `Xaas.Actuation.Validations.CausalAdmission` (W984dw).

  Exercises the real validation through the real Ash changeset path: each case
  builds a changeset for `Xaas.Operations.ActuationIntent` carrying an
  `authority` envelope with a `causal` declaration and asserts the exact
  refusal message or the clean admission. No mocks; refusal shape is the
  real `{:error, field: :authority, message: ...}` produced by the gate.
  """

  use ExUnit.Case, async: true

  alias Xaas.Actuation.Validations.CausalAdmission

  @evidence %{
    "verifier" => "kgc-causal-verifier:v1",
    "dag_proof_hash" => "sha256:dag-proof-fixture",
    "assumptions_hash" => "sha256:assumptions-fixture",
    "placebo_result_hash" => "sha256:placebo-fixture",
    "falsifier" => "reject if the adjustment set stops d-separating"
  }

  defp validate_authority(authority) do
    changeset =
      Xaas.Operations.ActuationIntent
      |> Ash.Changeset.for_create(:admit, %{
        authority: authority
      })

    CausalAdmission.validate(changeset, [], %{})
  end

  defp refusal_message(result) do
    assert {:error, opts} = result
    assert opts[:field] == :authority
    opts[:message]
  end

  test "no causal declaration admits (deterministic domain unchanged)" do
    assert :ok == validate_authority(%{"kind" => "test_authority"})
  end

  test "causal declaration that is not a map is refused" do
    assert refusal_message(validate_authority(%{"causal" => "yes, please"})) =~
             "causal admission declaration must be a map"
  end

  test "empty causal map is refused" do
    assert refusal_message(validate_authority(%{"causal" => %{}})) =~
             "causal admission declaration must include boolean required"
  end

  test "non-boolean required is refused" do
    assert refusal_message(validate_authority(%{"causal" => %{"required" => "maybe"}})) =~
             "causal admission declaration must include boolean required"
  end

  test "required: false admits without any certificate evidence" do
    assert :ok ==
             validate_authority(%{
               "kind" => "test_authority",
               "causal" => %{"required" => false}
             })
  end

  test "required true with non-admitted status is refused" do
    causal =
      Map.merge(%{"required" => true, "status" => "draft", "strategy" => "backdoor"}, @evidence)

    assert refusal_message(validate_authority(%{"causal" => causal})) =~
             "certificate status is not admitted"
  end

  test "admitted status with missing evidence lists every missing field" do
    causal = %{
      "required" => true,
      "status" => :admitted,
      "strategy" => :iv,
      "verifier" => "  ",
      "dag_proof_hash" => "sha256:dag",
      "assumptions_hash" => "sha256:assumptions",
      "placebo_result_hash" => "sha256:placebo",
      "falsifier" => "reject on collider collapse"
    }

    message = refusal_message(validate_authority(%{"causal" => causal}))

    assert message =~ "causal admission certificate missing evidence: verifier"
  end

  test "admitted certificate without frontier bundle and without supporting hash admits" do
    causal =
      Map.merge(
        %{"required" => true, "status" => "admitted", "strategy" => "frontdoor"},
        @evidence
      )

    assert :ok == validate_authority(%{"kind" => "test_authority", "causal" => causal})
  end

  test "supporting hash without a frontier bundle is refused" do
    causal =
      Map.merge(
        %{
          "required" => true,
          "status" => "admitted",
          "strategy" => "rct",
          "supporting_evidence_hash" => "sha256:orphan"
        },
        @evidence
      )

    assert refusal_message(validate_authority(%{"causal" => causal})) =~
             "supporting evidence hash requires a frontier evidence bundle"
  end

  test "frontier bundle without an admitted bundle hash is refused" do
    causal =
      Map.merge(
        %{
          "required" => true,
          "status" => "admitted",
          "strategy" => "backdoor",
          "supporting_evidence_hash" => "sha256:support"
        },
        @evidence
      )

    authority = %{
      "causal" => causal,
      "frontier_evidence" => %{"bundle_sha256" => ""}
    }

    assert refusal_message(validate_authority(authority)) =~
             "frontier evidence bundle has no admitted bundle hash"
  end

  test "frontier bundle supplied but unbound from the certificate is refused" do
    causal =
      Map.merge(%{"required" => true, "status" => "admitted", "strategy" => "iv"}, @evidence)

    authority = %{
      "causal" => causal,
      "frontier_evidence" => %{"bundle_sha256" => "sha256:bundle-1"}
    }

    assert refusal_message(validate_authority(authority)) =~
             "must bind the supplied frontier evidence bundle"
  end

  test "supporting hash that mismatches the bundle hash is refused" do
    causal =
      Map.merge(
        %{
          "required" => true,
          "status" => "admitted",
          "strategy" => "observational_assumptions",
          "supporting_evidence_hash" => "sha256:other"
        },
        @evidence
      )

    authority = %{
      "causal" => causal,
      "frontier_evidence" => %{"bundle_sha256" => "sha256:bundle-1"}
    }

    assert refusal_message(validate_authority(authority)) =~
             "does not match frontier evidence bundle"
  end

  test "matching supporting hash binds the bundle and admits" do
    causal =
      Map.merge(
        %{
          "required" => true,
          "status" => "admitted",
          "strategy" => "backdoor",
          "supporting_evidence_hash" => "sha256:bundle-9"
        },
        @evidence
      )

    authority = %{
      "kind" => "test_authority",
      "causal" => causal,
      "frontier_evidence" => %{"bundle_sha256" => "sha256:bundle-9"}
    }

    assert :ok == validate_authority(authority)
  end

  test "non-map frontier evidence bundle is refused" do
    causal =
      Map.merge(
        %{
          "required" => true,
          "status" => "admitted",
          "strategy" => "backdoor",
          "supporting_evidence_hash" => "sha256:bundle-9"
        },
        @evidence
      )

    authority = %{
      "causal" => causal,
      "frontier_evidence" => "not-a-bundle"
    }

    assert refusal_message(validate_authority(authority)) =~
             "frontier evidence bundle must be a map"
  end
end
