defmodule Xaas.Chicago.NegativeCourts.ConsequenceCourtsTest do
  @moduledoc """
  Lane L8 runtime consequence courts (wave-1 design, file 3) over the real
  `Xaas.Chicago.Court` (RESOLUTIONS.md R4), inside the REAL Postgres sandbox
  (`Xaas.DataCase` — Chicago-style: no mocking of owned collaborators):

    * CHI-CASE-005 provider unavailable BEFORE dispatch WITH an admitted
      alternative: `{:ok, :alternative_preserved}`, standing UNKNOWN — NOT a
      goal failure; authority unchanged. With NO admitted alternative left it
      IS a typed `:provider_unavailable` refusal (`authority_unchanged: true`);
    * CHI-CASE-006 unknown AFTER dispatch: `reconcile/1` returns the ORIGINAL
      consequence with original-identity replay, zero new consequence and no
      blind replay;
    * CHI-CASE-009 policy drift refuses the stale plan; matching digests
      admit (anti-vacuity pairing);
    * the full negative matrix leaves no authority residue.
  """

  use Xaas.DataCase, async: true

  Code.require_file("support/mutants.ex", __DIR__)
  alias Xaas.Chicago.Court
  alias Xaas.Chicago.NegativeCourts.Mutants, as: M

  ## CHI-CASE-005: provider unavailable before dispatch ########################

  test "CHI-CASE-005: pre-dispatch provider unavailability preserves the admitted alternative — not a goal failure" do
    ok = M.decide_provider_unavailable_alternative_preserved()

    M.assert_admitted(ok)
    assert %{outcome: :alternative_preserved, standing: "UNKNOWN"} = elem(ok, 1)
    M.assert_standing_unknown(ok)

    # authority unchanged: after the provider refusal the bounded purchase
    # still admits and the surface still cannot mint DO
    M.assert_admitted(M.decide_case("CHI-CASE-001"))
    M.assert_refusal(M.decide_case("CHI-CASE-010"), :authority_none)

    M.assert_deterministic(fn -> M.decide_provider_unavailable_alternative_preserved() end)
  end

  test "CHI-CASE-005: with no admitted alternative left, provider unavailability is a typed refusal with authority unchanged" do
    refused = M.decide_case("CHI-CASE-005")

    M.assert_refusal(refused, :provider_unavailable)
    assert %{authority_unchanged: true} = elem(refused, 2)
    M.assert_no_standing_promotion(refused)

    M.assert_deterministic(fn -> M.decide_case("CHI-CASE-005") end)
  end

  ## CHI-CASE-006: unknown after dispatch — reconcile, never blind replay ######

  test "CHI-CASE-006: unknown after dispatch reconciles the ORIGINAL consequence with zero new consequence and no blind replay" do
    refused = M.decide_case("CHI-CASE-006")
    M.assert_refusal(refused, :unknown_after_dispatch)
    M.assert_no_standing_promotion(refused)

    original = M.original_consequence()
    reconciled = M.reconcile_unknown_after_dispatch()
    M.assert_original_consequence_reconciled(reconciled, original)

    # determinism: reconciling the same unknown dispatch again reconciles the
    # SAME original consequence — never a blind replay of the dispatch
    M.assert_deterministic(fn -> M.reconcile_unknown_after_dispatch() end)
  end

  ## CHI-CASE-009: policy drift ################################################

  test "CHI-CASE-009: semantic policy drift refuses the stale plan; matching digests admit (anti-vacuity)" do
    refused = M.decide_case("CHI-CASE-009")

    M.assert_refusal(refused, :policy_drift)

    assert %{plan_digest: "stale-policy-digest", policy_digest: "policy-digest-001"} =
             elem(refused, 2)

    M.assert_no_standing_promotion(refused)

    # anti-vacuity pairing: the same case shape with FRESH (matching) digests
    # is not drifted and admits — the drift law can actually pass
    {request, policy} = M.case_request_and_policy("CHI-CASE-001")
    M.assert_admitted(Court.decide(request, policy))

    M.assert_deterministic(fn -> M.decide_case("CHI-CASE-009") end)
  end

  ## Full negative matrix leaves no residue ####################################

  test "the full negative matrix refuses every case with its contract atom and leaves no authority residue" do
    for id <- tl(M.case_identifiers()) do
      M.assert_refusal(M.decide_case(id), M.case_refusal_atom(id))
    end

    # in-memory court (R4): after nine refusals the positive control still
    # admits and the surface still cannot mint DO — no hidden state widened
    # authority and nothing promoted standing
    M.assert_admitted(M.decide_case("CHI-CASE-001"))
    M.assert_refusal(M.decide_case("CHI-CASE-010"), :authority_none)
  end
end
