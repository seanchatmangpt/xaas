defmodule Xaas.Semantics.VKG.EngineHelperCourtW984krTest do
  use ExUnit.Case, async: true

  @moduledoc """
  W984kr unclaimed-family probe: direct courts for `Xaas.Test.VKGObservationEngine`.

  All six existing consumers drive the helper indirectly through `VKG.observe`,
  so the helper's own output contract (digest identity, determinism, the
  `rows_by_contract` vs. synthesized-fallback branch split, and its failure
  behavior on bad input) is uncourted. Zero mocks; the helper itself is the
  real collaborator under test.
  """

  alias Xaas.Test.VKGObservationEngine

  @stage_fields %{
    contract_id: "customer",
    source_sha256: String.duplicate("a", 64),
    mapping_sha256: String.duplicate("b", 64),
    query_sha256: String.duplicate("c", 64)
  }

  test "COVERED-elsewhere note: synthesized fallback row shape, courted directly here" do
    # Mutation rationale: a regression swapping the subject prefix or dropping
    # String.capitalize would pass every existing consumer (they never assert
    # the synthesized row's content), so the fallback branch shape is courted here.
    assert {:ok, %AshR2RML.OBDA.Observation{} = obs} =
             VKGObservationEngine.execute(@stage_fields, [])

    assert [%{"subject" => subject, "name" => name}] = obs.rows
    assert subject == "urn:xaas:test:customer:1"
    assert name == "Customer"

    assert obs.row_count == 1
    assert obs.output_bytes == byte_size(:erlang.term_to_binary(obs.rows))
  end

  test "explicit rows_by_contract branch passes rows through verbatim" do
    # Mutation rationale: if the helper silently synthesized defaults instead of
    # honoring injected rows, downstream contract-specific projections would
    # observe fabricated data. Assert passthrough byte-for-byte.
    rows = [
      %{"subject" => "urn:ex:1", "name" => "Alpha"},
      %{"subject" => "urn:ex:2", "name" => "Beta"}
    ]

    assert {:ok, %AshR2RML.OBDA.Observation{} = obs} =
             VKGObservationEngine.execute(@stage_fields, rows_by_contract: %{"customer" => rows})

    assert obs.rows == rows
    assert obs.row_count == 2
    assert obs.output_bytes == byte_size(:erlang.term_to_binary(rows))
  end

  test "digest is deterministic for identical stage inputs" do
    # Mutation rationale: if term_to_binary lost :deterministic, replay courts
    # (Replay.witness/1 identity checks) would flake across scheduler layouts.
    assert {:ok, obs1} = VKGObservationEngine.execute(@stage_fields, [])
    assert {:ok, obs2} = VKGObservationEngine.execute(@stage_fields, [])

    assert obs1.observation_sha256 == obs2.observation_sha256
    assert obs1.output_sha256 == obs2.output_sha256
    assert obs1.command_sha256 == obs2.command_sha256
  end

  test "digest distinguishes every stage input component" do
    # Mutation rationale: dropping any one of the four tuple components from the
    # digest preimage would let distinct stages collide on the same observation
    # identity. Each component is mutated and the digest must move.
    assert {:ok, base} = VKGObservationEngine.execute(@stage_fields, [])

    for {key, value} <- [
          contract_id: "supplier",
          source_sha256: String.duplicate("f", 64),
          mapping_sha256: String.duplicate("d", 64),
          query_sha256: String.duplicate("e", 64)
        ] do
      mutated = Map.put(@stage_fields, key, value)
      assert {:ok, obs} = VKGObservationEngine.execute(mutated, [])
      assert obs.observation_sha256 != base.observation_sha256,
             "digest collided when mutating #{key}"
    end
  end

  test "observation field invariants: identity digests agree and are hex-64" do
    # Mutation rationale: if command/observation/output digests ever diverge,
    # downstream replay equality (witness.result_sha256 checks) loses its
    # single-identity anchor.
    assert {:ok, %AshR2RML.OBDA.Observation{} = obs} =
             VKGObservationEngine.execute(@stage_fields, [])

    assert obs.command_sha256 == obs.observation_sha256
    assert obs.observation_sha256 == obs.output_sha256
    assert byte_size(obs.observation_sha256) == 64
    assert obs.observation_sha256 == String.downcase(obs.observation_sha256)

    assert obs.status == :PARTIAL_ALIVE
    assert obs.standing == :test_double_only
    assert obs.system == :xaas_vkg_observation_fixture
    assert obs.evidence_kind == :injected_runner
    assert obs.exit_status == 0
    assert obs.bounded? == true
    assert obs.session_sha256 == nil
    assert obs.query_sha256 == @stage_fields.query_sha256
    assert obs.mapping_sha256 == @stage_fields.mapping_sha256
  end

  test "non-binary contract_id fails with ArgumentError (no silent coercion)" do
    # Mutation rationale: if the helper ever coerced or rescued this, a malformed
    # stage would mint a fabricated observation instead of failing loudly. The
    # helper has no typed refusal path; the real behavior is the binary-
    # construction ArgumentError from `<>`.
    assert_raise ArgumentError, fn ->
      VKGObservationEngine.execute(%{@stage_fields | contract_id: :customer}, [])
    end
  end
end
