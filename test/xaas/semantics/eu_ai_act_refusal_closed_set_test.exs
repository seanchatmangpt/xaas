defmodule Xaas.Semantics.EuAiActRefusalClosedSetTest do
  @moduledoc """
  Closed-vocabulary court over Xaas.Semantics.EuAiActAdmission's typed Art.
  5(1) refusal atoms (W706 trio gap fill; ash_affidavit's closed-algorithm-set
  / typed-unsupported-refusal pattern).

  refusal_atoms/0 already has an exact-list assertion and a fuzz allowed-set
  (test/xaas/semantics/eu_ai_act_admission_test.exs,
  test/xaas/semantics/admission_fuzz_test.exs). What was missing is
  closedness from the NEGATIVE side, affidavit-style: the refusal vocabulary
  must have no out-of-set member — describe/1 is total over refusal_atoms/0,
  injective, and refuses (raises) every non-member. (W732: the malformed
  verdict atom joined the declared set — the W713 census closure repair —
  so it now has a describe/1 clause; only true non-members raise.)
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.EuAiActAdmission

  @malformed :REFUSED_EUAIA_MALFORMED_CANDIDATE

  test "refusal_atoms/0 is the 9-atom closed set, no duplicates" do
    atoms = EuAiActAdmission.refusal_atoms()
    assert length(atoms) == 9
    assert Enum.uniq(atoms) == atoms
    assert @malformed in atoms
  end

  test "describe/1 is total over refusal_atoms/0 and injective" do
    atoms = EuAiActAdmission.refusal_atoms()

    partitions =
      for atom <- atoms do
        text = EuAiActAdmission.describe(atom)
        assert text != ""
        text
      end

    assert Enum.uniq(partitions) == partitions
  end

  test "describe/1 refuses every non-member: closed from the negative side" do
    # W732: the malformed verdict atom is a declared member with its own
    # describe/1 clause (schema-shape refusal, not an Art. 5(1) partition).
    assert is_binary(EuAiActAdmission.describe(@malformed))

    for junk <- [:NOT_A_EUAIA_REFUSAL, "REFUSED_EUAIA_MANIPULATIVE", 42, nil] do
      assert_raise FunctionClauseError, fn ->
        apply(EuAiActAdmission, :describe, [junk])
      end
    end
  end

  test "a real Art. 5(1) refusal stays inside the closed set" do
    # A candidate classified under Art. 5(1)(a) manipulative techniques
    # must come back as exactly one of the eight typed atoms — never an
    # out-of-set atom.
    refusal_candidate = %{
      id: "w706-closed-set-probe",
      techniques: [:subliminal],
      purpose: :manipulation,
      data_domains: [:visual],
      provenance: :consented,
      context_joins: [],
      setting: :consumer_web,
      latency_goal: :batch,
      inferences: [],
      match_token_type: :boolean
    }

    assert {:error, atom} = EuAiActAdmission.admit(refusal_candidate)
    assert atom in EuAiActAdmission.refusal_atoms()
  end
end
