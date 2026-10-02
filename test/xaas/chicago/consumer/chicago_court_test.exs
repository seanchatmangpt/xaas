defmodule Xaas.Chicago.CourtTest do
  @moduledoc """
  The 10 Chicago case laws as anti-vacuity pairings (resolution R4 scope 3/5).

  Every verdict is paired with its mutant: flipping exactly one input flips
  the verdict. The court never promotes standing — even the positive path
  stays `"UNKNOWN"` (R8), and reconcile/1 returns the ORIGINAL consequence
  identity, never a blind replay.
  """

  use ExUnit.Case, async: true

  alias Xaas.Chicago.{Case, Court, Subject}

  @policy Court.baseline_policy()
  @refusal_atoms ~w(above_delegated_limit wrong_principal delegation_expired provider_unavailable unknown_after_dispatch missing_evidence stale_subject policy_drift authority_none)a

  describe "case law CHI-CASE-001 — bounded authorized purchase" do
    test "clean request is admitted with standing UNKNOWN" do
      request = Court.bounded_purchase()

      assert {:ok, verdict} = Court.decide(request, @policy)
      assert verdict.outcome == :bounded_authorized_purchase
      assert verdict.standing == "UNKNOWN"
      refute verdict.standing in ["ALIVE", "PARTIAL_ALIVE"]
    end

    test "over-limit amount is refused :above_delegated_limit" do
      assert {:refused, :above_delegated_limit, %{amount: 101, delegated_limit: 100}} =
               Court.decide(Court.bounded_purchase(amount: 101), @policy)
    end
  end

  describe "case law CHI-CASE-002 — delegated limit" do
    test "at-limit amount passes, over-limit fails (boundary)" do
      assert {:ok, %{outcome: :bounded_authorized_purchase}} =
               Court.decide(Court.bounded_purchase(amount: 100), @policy)

      assert {:refused, :above_delegated_limit, _} =
               Court.decide(Court.bounded_purchase(amount: 100.01), @policy)
    end
  end

  describe "case law CHI-CASE-003 — wrong principal" do
    test "matching principal is admitted, other principal is refused" do
      assert {:ok, %{}} = Court.decide(Court.bounded_purchase(), @policy)

      assert {:refused, :wrong_principal, %{expected: "principal-001", got: "principal-evil"}} =
               Court.decide(Court.bounded_purchase(principal: "principal-evil"), @policy)
    end
  end

  describe "case law CHI-CASE-004 — expired delegation" do
    test "live delegation is admitted, expired is refused (boundary at exact expiry)" do
      assert {:ok, %{}} = Court.decide(Court.bounded_purchase(), @policy)

      expired_policy = Court.baseline_policy(delegation_expires_at: ~U[2026-09-30 23:59:59Z])

      assert {:refused, :delegation_expired, _} =
               Court.decide(Court.bounded_purchase(), expired_policy)

      boundary_policy = Court.baseline_policy(delegation_expires_at: ~U[2026-10-01 00:00:00Z])

      assert {:refused, :delegation_expired, _} =
               Court.decide(Court.bounded_purchase(), boundary_policy)
    end
  end

  describe "case law CHI-CASE-005 — provider unavailable" do
    test "pre-dispatch unavailability preserves admitted alternatives (not a goal failure)" do
      request = Court.bounded_purchase(provider_available: false, dispatch: nil)

      assert {:ok, verdict} = Court.decide(request, @policy)
      assert verdict.outcome == :alternative_preserved
      assert verdict.consequence == nil
      assert verdict.standing == "UNKNOWN"
    end

    test "unavailability with no admitted alternative refuses :provider_unavailable" do
      request =
        Court.bounded_purchase(
          provider_available: false,
          dispatch: nil,
          alternative_available: false
        )

      assert {:refused, :provider_unavailable, %{authority_unchanged: true}} =
               Court.decide(request, @policy)
    end
  end

  describe "case law CHI-CASE-006 — unknown after dispatch" do
    test "refuses :unknown_after_dispatch and reconcile returns the ORIGINAL consequence identity" do
      original = %{consequence_id: "consequence-042", amount: 50}
      request = Court.bounded_purchase(dispatch: :unknown, consequence: original)

      assert {:refused, :unknown_after_dispatch, details} = Court.decide(request, @policy)
      assert {:ok, reconciled} = Court.reconcile({:refused, :unknown_after_dispatch, details})

      # never a blind replay: the SAME consequence identity comes back
      assert reconciled.consequence == original
      assert reconciled.consequence_identity == "consequence-042"
      assert reconciled.replay == :original_identity
      # never a standing promotion
      assert reconciled.standing == "UNKNOWN"
    end

    test "reconcile refuses anything that is not unknown-after-dispatch" do
      assert {:refused, :reconcile_requires_unknown_after_dispatch, _} =
               Court.reconcile({:ok, %{}})

      assert {:refused, :reconcile_requires_unknown_after_dispatch, _} =
               Court.reconcile({:refused, :missing_evidence, %{}})
    end
  end

  describe "case law CHI-CASE-007 — missing evidence" do
    test "claimed dispatch without evidence refuses :missing_evidence (no standing promotion)" do
      assert {:refused, :missing_evidence, %{missing: [:evidence]}} =
               Court.decide(Court.bounded_purchase(evidence: nil), @policy)

      assert {:refused, :missing_evidence, %{missing: [:receipt]}} =
               Court.decide(Court.bounded_purchase(receipt: nil), @policy)
    end

    test "even with evidence+receipt the court never promotes past UNKNOWN" do
      request =
        Court.bounded_purchase(evidence: %{subject: Subject.literal(), receipt_ref: "r-1"})

      assert {:ok, %{standing: "UNKNOWN"}} = Court.decide(request, @policy)
    end
  end

  describe "case law CHI-CASE-008 — stale subject" do
    test "drifted request subject refuses :stale_subject" do
      assert {:refused, :stale_subject,
              %{expected: expected, got: "urn:stale", binding: :request}} =
               Court.decide(Court.bounded_purchase(subject: "urn:stale"), @policy)

      assert expected == Subject.literal()
    end

    test "drifted evidence binding refuses :stale_subject" do
      request = Court.bounded_purchase(evidence: %{subject: "urn:other-subject"})

      assert {:refused, :stale_subject, %{binding: :evidence}} = Court.decide(request, @policy)
    end

    test "drifted receipt binding refuses :stale_subject" do
      request = Court.bounded_purchase(receipt: %{subject: "urn:other-subject"})

      assert {:refused, :stale_subject, %{binding: :receipt}} = Court.decide(request, @policy)
    end
  end

  describe "case law CHI-CASE-009 — policy drift" do
    test "stale plan digest refuses :policy_drift" do
      request = Court.bounded_purchase(plan_policy_digest: "policy-digest-stale")

      assert {:refused, :policy_drift,
              %{plan_digest: "policy-digest-stale", policy_digest: "policy-digest-001"}} =
               Court.decide(request, @policy)
    end
  end

  describe "case law CHI-CASE-010 — surface authority" do
    test "a request that mints authority refuses :authority_none" do
      assert {:refused, :authority_none, %{claim: "DO"}} =
               Court.decide(Court.bounded_purchase(authority_claim: "DO"), @policy)

      assert {:refused, :authority_none, %{claim: nil}} =
               Court.decide(Court.bounded_purchase(authority_claim: nil), @policy)
    end
  end

  describe "deterministic precedence" do
    test "earlier laws shadow later ones (subject before limit, authority before subject)" do
      request =
        Court.bounded_purchase(subject: "urn:stale", amount: 9_999, authority_claim: "NONE")

      assert {:refused, :stale_subject, _} = Court.decide(request, @policy)

      request2 = Court.bounded_purchase(authority_claim: "DO", subject: "urn:stale")
      assert {:refused, :authority_none, _} = Court.decide(request2, @policy)
    end

    test "the court is pure: deciding twice gives the identical verdict" do
      request = Court.bounded_purchase()
      assert Court.decide(request, @policy) == Court.decide(request, @policy)
    end
  end

  describe "refusal vocabulary completeness" do
    test "all 9 refusal atoms are exercised by this suite" do
      exercised =
        [
          {:above_delegated_limit, Court.decide(Court.bounded_purchase(amount: 500), @policy)},
          {:wrong_principal, Court.decide(Court.bounded_purchase(principal: "x"), @policy)},
          {:delegation_expired,
           Court.decide(
             Court.bounded_purchase(),
             Court.baseline_policy(delegation_expires_at: ~U[2020-01-01 00:00:00Z])
           )},
          {:provider_unavailable,
           Court.decide(
             Court.bounded_purchase(
               provider_available: false,
               dispatch: nil,
               alternative_available: false
             ),
             @policy
           )},
          {:unknown_after_dispatch,
           Court.decide(Court.bounded_purchase(dispatch: :unknown), @policy)},
          {:missing_evidence, Court.decide(Court.bounded_purchase(evidence: nil), @policy)},
          {:stale_subject, Court.decide(Court.bounded_purchase(subject: "urn:stale"), @policy)},
          {:policy_drift,
           Court.decide(Court.bounded_purchase(plan_policy_digest: "drift"), @policy)},
          {:authority_none, Court.decide(Court.bounded_purchase(authority_claim: "DO"), @policy)}
        ]

      for {atom, verdict} <- exercised do
        assert {:refused, ^atom, _details} = verdict,
               "expected #{inspect(atom)}, got #{inspect(verdict)}"
      end

      assert Enum.map(exercised, &elem(&1, 0)) |> Enum.sort() == Enum.sort(@refusal_atoms)
    end
  end

  describe "composition with the machine projection cases" do
    @machine_fixture Path.expand("fixtures/chicago.machine.fixture.json", __DIR__)

    test "request_from_case builds a court-ready request from CHI-CASE-001" do
      assert {:ok, machine} = Xaas.Chicago.Projection.load(:machine, @machine_fixture)
      assert {:ok, case_1} = Case.fetch(machine, "CHI-CASE-001")

      request = Case.request_from_case(case_1, Court.bounded_purchase())

      assert {:ok, %{outcome: :bounded_authorized_purchase, standing: "UNKNOWN"}} =
               Court.decide(request, @policy)

      # the mutant: same case, drifted subject — verdict flips to refusal
      drifted = Case.request_from_case(%{case_1 | "subject" => "urn:drifted"}, %{})
      assert {:refused, :stale_subject, _} = Court.decide(drifted, @policy)
    end
  end
end
