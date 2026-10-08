defmodule Xaas.Actuation.ValidationsCourtW984gwTest do
  @moduledoc """
  W984gw unclaimed-family probe court for the actuation validation family not
  owned by W984dw (CausalAdmission depth) or W984ey (quiescent stop).

  Real changesets against `Xaas.Operations.ActuationIntent`, real bundle
  composition, zero mocks. Each test names the mutation it kills: a removed or
  mutated branch below must turn its test red.
  """

  use ExUnit.Case, async: true

  alias Xaas.Actuation.FrontierEvidence
  alias Xaas.Actuation.Refusal
  alias Xaas.Actuation.Validations.CausalAdmission
  alias Xaas.Actuation.Validations.FrontierEvidence, as: FrontierEvidenceValidation
  alias Xaas.Actuation.Validations.ReactorContext

  @evidence %{
    "verifier" => "kgc-causal-verifier:v1",
    "dag_proof_hash" => "sha256:dag-proof-fixture",
    "assumptions_hash" => "sha256:assumptions-fixture",
    "placebo_result_hash" => "sha256:placebo-fixture",
    "falsifier" => "reject if the adjustment set stops d-separating"
  }

  defp fragment(producer, ceiling, head, marker) do
    %{
      schema: "frontier-evidence/v1",
      producer: producer,
      producer_head: producer_head(producer, head),
      standing: "PARTIAL_ALIVE",
      authority_ceiling: ceiling,
      evidence: %{marker: marker},
      artifact_hash: "sha256:" <> String.duplicate(marker, 64)
    }
  end

  defp producer_head("gitvan", head), do: head
  defp producer_head(_, head), do: head

  defp fragments do
    [
      fragment("beam4pm", "SELECT", "3e7470b49f0f51a448963cdeaef05ed45576a2a9", "a"),
      fragment("ash_r2rml", "CONSTRUCT", "353ff59cabdad0d21e076bf6b935e2e218813d5d", "b"),
      fragment("gitvan", "OBSERVE", "6e5dee084ffca9738edd70181b45219129ee765d", "c"),
      fragment("ash_pplan", "CONSTRUCT", "ea2eb24fbe8417de1dfc4025137c28a2e00ad308", "d")
    ]
  end

  defp valid_bundle do
    {:ok, bundle} = FrontierEvidence.bundle(fragments())
    bundle
  end

  defp validate_authority(authority, validation \\ CausalAdmission) do
    changeset =
      Xaas.Operations.ActuationIntent
      |> Ash.Changeset.for_create(:admit, %{authority: authority})

    validation.validate(changeset, [], %{})
  end

  defp refusal_message(result) do
    assert {:error, opts} = result
    assert opts[:field] == :authority
    opts[:message]
  end

  # ------------------------------------------------------------------
  # Xaas.Actuation.FrontierEvidence — composition refusals (uncovered)
  # ------------------------------------------------------------------

  test "fragments that are neither list nor map are refused" do
    # Kills mutation: deleting the index_fragments/1 catch-all clause.
    assert {:error, :frontier_fragments_must_be_list_or_map} =
             FrontierEvidence.bundle("beam4pm-dump")
  end

  test "duplicate fragment producer is refused" do
    # Kills mutation: dropping Map.has_key?(acc, producer) duplicate check.
    duplicated = fragments() ++ [fragments() |> hd() |> Map.put("wrapped", true)]

    assert {:error, {:duplicate_fragment_producer, "beam4pm"}} =
             FrontierEvidence.bundle(duplicated)
  end

  test "map-form fragments with mismatched producer key are refused" do
    # Kills mutation: deleting the declared != producer comparison in the
    # map-mode index_fragments/1 clause.
    by_producer =
      fragments()
      |> Map.new(fn f -> {f.producer, f} end)
      |> Map.update!("beam4pm", fn f -> %{f | producer: "gitvan"} end)

    assert {:error, {:producer_key_mismatch, "beam4pm", "gitvan"}} =
             FrontierEvidence.bundle(by_producer)
  end

  test "unsupported extra frontier producers are refused" do
    # Kills mutation: deleting the extras check in validate_fragments/1.
    rogue = fragment("wild_repo", "DO", "deadbeef", "e")

    assert {:error, {:unsupported_frontier_producers, ["wild_repo"]}} =
             FrontierEvidence.bundle(fragments() ++ [rogue])
  end

  test "fragment missing producer_head is refused" do
    # Kills mutation: deleting the producer_head_required guard.
    headless =
      Enum.map(fragments(), fn
        %{producer: "beam4pm"} = f -> Map.delete(f, :producer_head)
        f -> f
      end)

    assert {:error, {:producer_head_required, "beam4pm"}} = FrontierEvidence.bundle(headless)
  end

  test "fragment with blank artifact hash is refused" do
    # Kills mutation: deleting the artifact_hash_required guard.
    unhashed =
      Enum.map(fragments(), fn
        %{producer: "ash_r2rml"} = f -> %{f | artifact_hash: "not-a-hash"}
        f -> f
      end)

    assert {:error, {:artifact_hash_required, "ash_r2rml"}} = FrontierEvidence.bundle(unhashed)
  end

  test "fragment without evidence map is refused" do
    # Kills mutation: deleting the fragment_evidence_required guard.
    evidence_free =
      Enum.map(fragments(), fn
        %{producer: "ash_pplan"} = f -> %{f | evidence: nil}
        f -> f
      end)

    assert {:error, {:fragment_evidence_required, "ash_pplan"}} =
             FrontierEvidence.bundle(evidence_free)
  end

  test "validate_bundle refuses non-map input" do
    # Kills mutation: deleting the non-map validate_bundle/1 clause.
    assert {:error, :frontier_evidence_bundle_must_be_map} =
             FrontierEvidence.validate_bundle("looks-like-a-bundle")
  end

  test "validate_bundle refuses an unsupported bundle schema" do
    # Kills mutation: dropping the schema == @schema check.
    tampered = Map.put(valid_bundle(), "schema", "frontier-evidence-bundle/v0")

    assert {:error, :unsupported_bundle_schema} = FrontierEvidence.validate_bundle(tampered)
  end

  test "validate_bundle requires fragments" do
    # Kills mutation: dropping the fragments presence step in the with-chain.
    assert {:error, :fragments_required} =
             FrontierEvidence.validate_bundle(%{"schema" => "frontier-evidence-bundle/v1"})
  end

  test "validate_bundle detects a tampered bundle hash" do
    # Kills mutation: dropping the supplied_hash == expected fingerprint step.
    tampered = Map.put(valid_bundle(), "bundle_sha256", "sha256:" <> String.duplicate("0", 64))

    assert {:error, {:bundle_hash_mismatch, supplied, expected}} =
             FrontierEvidence.validate_bundle(tampered)

    assert supplied =~ ~r/^sha256:0+$/
    assert expected == valid_bundle()["bundle_sha256"]
  end

  test "bind_causal refuses a non-map causal certificate" do
    # Kills mutation: deleting the non-map bind_causal/2 clause.
    assert {:error, :causal_certificate_must_be_map} =
             FrontierEvidence.bind_causal("trust me", fragments())
  end

  test "bind_causal binds the exact bundle hash as supporting evidence" do
    # Kills mutation: removing the supporting_evidence_hash injection (the
    # causal/frontier binding seam consumed by CausalAdmission).
    causal = %{"required" => true, "status" => "admitted", "strategy" => "backdoor"}

    assert {:ok, %{"causal" => bound, "frontier_evidence" => bundle}} =
             FrontierEvidence.bind_causal(causal, fragments())

    assert bound["supporting_evidence_hash"] == bundle["bundle_sha256"]
    assert :ok = FrontierEvidence.validate_bundle(bundle)
  end

  # ------------------------------------------------------------------
  # CausalAdmission — atom-key authority envelopes (rescue path)
  # ------------------------------------------------------------------

  test "atom-key causal declaration is read through the atom-key fetch" do
    # Kills mutation: deleting fetch_atom_key/2 (string-only fetch would then
    # read every atom-keyed envelope as "no causal declaration" and admit).
    causal = %{
      required: true,
      status: :admitted,
      strategy: :backdoor,
      verifier: "kgc-causal-verifier:v1",
      dag_proof_hash: "sha256:dag-proof-fixture",
      assumptions_hash: "sha256:assumptions-fixture",
      placebo_result_hash: "sha256:placebo-fixture",
      falsifier: "reject if the adjustment set stops d-separating"
    }

    assert :ok == validate_authority(%{kind: "test_authority", causal: causal})
  end

  test "atom-key envelope with missing evidence still lists the missing fields" do
    # Kills mutation: making the ArgumentError rescue a silent nil-return that
    # hides evidence (fetch_atom_key rescue path exercised with atoms present).
    causal = %{
      required: true,
      status: :admitted,
      strategy: :backdoor,
      verifier: "  "
    }

    assert refusal_message(validate_authority(%{causal: causal})) =~
             "causal admission certificate missing evidence: verifier"
  end

  test "unknown keys in the envelope fall through to nil without raising" do
    # Kills mutation: removing the rescue ArgumentError -> nil clause (an atom
    # that does not exist would raise instead of being treated as absent).
    assert refusal_message(validate_authority(%{"never_defined_atom_xyz" => 1, "causal" => %{}})) =~
             "must include boolean required"
  end

  test "whitespace-only falsifier counts as missing evidence" do
    # Kills mutation: replacing non_empty_string?/1 with is_binary/1 (trim
    # semantics lost, blank evidence admitted).
    causal =
      Map.merge(
        %{"required" => true, "status" => "admitted", "strategy" => "frontdoor"},
        Map.put(@evidence, "falsifier", "   ")
      )

    assert refusal_message(validate_authority(%{"causal" => causal})) =~
             "causal admission certificate missing evidence: falsifier"
  end

  # ------------------------------------------------------------------
  # Validations.FrontierEvidence — changeset-level gate
  # ------------------------------------------------------------------

  test "frontier gate admits when no bundle is supplied" do
    # Kills mutation: inverting the nil -> :ok clause into a refusal.
    assert :ok == validate_authority(%{"kind" => "test_authority"}, FrontierEvidenceValidation)
  end

  test "frontier gate refuses a non-map bundle at the changeset boundary" do
    # Kills mutation: deleting the catch-all refusal clause in the validation
    # (a string bundle would then crash validate_bundle or pass silently).
    assert refusal_message(
             validate_authority(
               %{"kind" => "x", "frontier_evidence" => "blob"},
               FrontierEvidenceValidation
             )
           ) =~ "frontier evidence bundle must be a map"
  end

  test "frontier gate refuses a malformed map bundle" do
    # Kills mutation: making validate_bundle failure a pass-through (:ok).
    assert refusal_message(
             validate_authority(
               %{"kind" => "x", "frontier_evidence" => %{"schema" => "bogus"}},
               FrontierEvidenceValidation
             )
           ) =~ "frontier evidence refused"
  end

  test "frontier gate admits a real composed bundle via atom-key authority" do
    # Kills mutation: deleting the atom-key fallback in the validation's
    # fetch/2 (atom-keyed authority envelopes would silently lose the bundle).
    assert :ok ==
             validate_authority(
               %{kind: "test_authority", frontier_evidence: valid_bundle()},
               FrontierEvidenceValidation
             )
  end

  # ------------------------------------------------------------------
  # ReactorContext — direct changeset-level branches
  # ------------------------------------------------------------------

  defp reactor_changeset(context) do
    changeset =
      Xaas.Operations.ActuationIntent
      |> Ash.Changeset.for_create(:admit, %{authority: %{"kind" => "test_authority"}})

    Ash.Changeset.set_context(changeset, %{xaas_actuation: context})
  end

  test "reactor context without any xaas_actuation map is refused" do
    # Kills mutation: deleting the else-refusal (a missing context would
    # fall through as :ok, opening the direct-Ash-write bypass).
    assert {:error, opts} = ReactorContext.validate(reactor_changeset(nil), [], %{})
    assert opts[:message] =~ "requires an admitted Ash.Reactor intent"
  end

  test "reactor context missing the receipt id is refused" do
    # Kills mutation: dropping the receipt_id is_binary step in the with-chain.
    context = %{intent_id: "i-1", ontology_projection_hash: "h", receipt_id: nil}

    assert {:error, opts} = ReactorContext.validate(reactor_changeset(context), [], %{})
    assert opts[:message] =~ "requires an admitted Ash.Reactor intent"
  end

  test "reactor context with a stale projection hash is refused" do
    # Kills mutation: dropping the projection-hash equality step.
    context = %{
      receipt_id: "r-1",
      intent_id: "i-1",
      ontology_projection_hash: "stale-hash"
    }

    assert {:error, opts} = ReactorContext.validate(reactor_changeset(context), [], %{})
    assert opts[:message] =~ "requires an admitted Ash.Reactor intent"
  end

  test "reactor context with matching admitted identifiers is admitted" do
    # Kills mutation: inverting the :ok arm (admitted intents would be refused
    # and no DO could ever flow).
    context = %{
      receipt_id: "r-1",
      intent_id: "i-1",
      ontology_projection_hash: Xaas.Operations.ActuationIntent.ontology_projection_hash()
    }

    assert :ok = ReactorContext.validate(reactor_changeset(context), [], %{})
  end

  # ------------------------------------------------------------------
  # Xaas.Actuation.Refusal — typed refusal plumbing
  # ------------------------------------------------------------------

  test "refusal message renders code and detail" do
    # Kills mutation: deleting message/1 (rendered refusal text becomes the
    # default struct inspect instead of the typed format).
    refusal = Refusal.new(:court_denied, %{reason: "x"})

    assert message = Refusal.message(refusal)
    assert message =~ "actuation refused (court_denied)"
    assert message =~ "%{reason: \"x\"}"
  end

  test "find returns nil for bare non-refusal errors and refusal? agrees" do
    # Kills mutation: removing the find(_other) catch-all or the Enum.find_value
    # nil fall-through (error classes without a refusal would crash or lie).
    refute Refusal.refusal?(%RuntimeError{message: "boom"})
    refute Refusal.refusal?(%{errors: [%Ash.Error.Changes.InvalidArgument{message: "other"}]})
    assert Refusal.refusal?(Refusal.new(:nope))
  end
end
