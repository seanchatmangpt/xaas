defmodule Xaas.EuAiAct.Art86RightsDeepeningTest do
  @moduledoc """
  Lane W710 — Art 86 right-to-explanation deepening court (composed, real
  module composition, no mocks).

  W648b dispositioned the title_vi_xiii 86.x rows as "compliance obligations,
  no gap" on the 86.1 seam (Counterfactual, W506). This court composes the
  seam end-to-end over the REAL modules:

    (a) 86.1 — an individual decision: a real `EuAiActAdmission.admit/1`
        refusal becomes a decision record; `Counterfactual.run/2` +
        `Counterfactual.evaluate/3` produce the refusal anatomy (named
        article, refusal atom, φ attribution) that constitutes the
        explanation.
    (b) 86.1 (access) — the same explanation is deterministically
        reproducible x3: right of access implies reproducibility.
    (c) 86.2 — complaint/escalation shape: `IncidentReport.build/2` over an
        alleged-infringement receipt derived from the same refusal atom,
        plus `AuthorityChannel` transmission with the honest
        `PREPARED_NOT_TRANSMITTED` caveat (authority-side determination).
    (d) 86.3/non-existent-decision — the modules have no decision-id
        registry surface; the honest typed gap is asserted (no invented
        surface): a fabricated record reference is refused via the real
        `{:error, {:record_outcome_mismatch, _}}` typed refusal, and the
        absence of any id-lookup function is witnessed.
  """

  use ExUnit.Case, async: true

  @moduletag :eu_ai_act

  alias Xaas.Semantics.AuthorityChannel
  alias Xaas.Semantics.Counterfactual
  alias Xaas.Semantics.EuAiActAdmission
  alias Xaas.Semantics.IncidentReport

  # Module attributes cannot hold anonymous functions (cannot escape), so the
  # check-list lives in a defp — same fix shape as W641 art12_chain_court.
  defp checks do
    [
      {:lawful_practice, fn input ->
        if input[:techniques] == [],
          do: :ok,
          else: {:refused, :REFUSED_EUAIA_MANIPULATIVE}
      end}
    ]
  end

  defp individual_input, do: %{techniques: [:deceptive], purpose: :persuade}

  # -- (a) 86.1: individual decision -> refusal anatomy (the explanation) ----

  describe "86.1 individual decision explanation" do
    test "real admission refusal composes into a decision record whose anatomy is human-legible" do
      input = individual_input()

      # The individual decision: the REAL admission kernel refuses.
      assert {:error, refusal_atom} = EuAiActAdmission.admit(input)
      assert refusal_atom in EuAiActAdmission.refusal_atoms()

      # Named article: every refusal atom carries a real human-legible
      # description naming the prohibited practice (the "named article").
      description = EuAiActAdmission.describe(refusal_atom)
      assert is_binary(description)
      assert description != ""
      assert description =~ ~r/^Art\. \d/

      # Decision record with the full ordered per-check verdict log (the
      # recovered structural recourse variables U).
      %{outcome: outcome, checks: check_log} = Counterfactual.run(input, checks())
      assert outcome == {:refused, :REFUSED_EUAIA_MANIPULATIVE}
      assert [%{name: :lawful_practice, verdict: :fail, refusal: :REFUSED_EUAIA_MANIPULATIVE}] =
               check_log

      record = %{input: input, admitted?: false, refusal: refusal_atom, checks: check_log}

      # phi attribution: the counterfactual names the exact check whose
      # verdict flip would change the decision (the causal delta).
      assert {:ok, cf} =
               Counterfactual.evaluate(record, %{input | techniques: []}, checks())

      assert cf.outcome == :admitted
      assert cf.changed? == true
      assert cf.explanation =~ "`lawful_practice`"
      assert cf.explanation =~ "refused (:REFUSED_EUAIA_MANIPULATIVE)" or
               cf.explanation =~ "admitted"
    end
  end

  # -- (b) 86.1: right of access => deterministic reproducibility x3 ---------

  describe "86.1 explanation reproducibility" do
    test "the same explanation is derivable deterministically across 3 replays" do
      input = individual_input()
      {:error, refusal_atom} = EuAiActAdmission.admit(input)

      record =
        Counterfactual.run(input, checks())
        |> then(&%{input: input, admitted?: false, refusal: refusal_atom, checks: &1.checks})

      replays =
        for _ <- 1..3 do
          assert {:ok, cf} = Counterfactual.evaluate(record, input, checks())
          assert cf.changed? == false
          assert cf.outcome == {:refused, refusal_atom}
          cf
        end

      # Identical anatomy every time (binary-equal explanation + check log).
      assert [first, second, third] = replays
      assert first.explanation == second.explanation
      assert second.explanation == third.explanation
      assert first.checks == second.checks
      assert second.checks == third.checks
    end
  end

  # -- (c) 86.2: complaint path (incident build + authority escalation) ------

  describe "86.2 complaint escalation shape" do
    test "alleged-infringement receipt builds an incident and prepares (never transmits) to authority" do
      input = individual_input()
      {:error, refusal_atom} = EuAiActAdmission.admit(input)

      # The complaint receipt: a witnessed record of the alleged infringement,
      # carrying the same typed refusal atom as its evidence.
      receipt = %{
        digest: "w710-art86-complaint",
        refusal_atom: refusal_atom,
        rights_harm: true,
        observed_at: ~U[2026-10-07 00:00:00Z]
      }

      assert {:ok, report} = IncidentReport.build([receipt])

      assert :INFRINGES_UNION_LAW in report.classification
      assert :HARM_TO_RIGHTS in report.classification
      assert report.originating_receipt_digests == ["w710-art86-complaint"]
      assert report.temporal.first_observed == ~U[2026-10-07 00:00:00Z]

      # 86.2 escalation: transmission to an authority channel is honestly
      # PREPARED_NOT_TRANSMITTED (authority-side determination, typed OPEN).
      assert {:ok, tx} = AuthorityChannel.transmit(report, %{kind: :authority, id: :market_surveillance, endpoint: nil})

      assert tx.status == :PREPARED_NOT_TRANSMITTED
      assert tx.incident_id == report.incident_id
      assert tx.classification == report.classification
      assert tx.reason =~ "typed OPEN"
    end
  end

  # -- (d) non-existent decision id: honest typed gap -------------------------

  describe "non-existent decision reference" do
    test "typed refusal for a fabricated record; no invented id-lookup surface" do
      # The modules have no decision-id registry: the only lawful way to
      # reference a decision is a full decision record. A fabricated record
      # whose recorded outcome does not match the pipeline replay is refused
      # by the real typed refusal — this is the honest gap, not a lookup.
      input = individual_input()
      {:error, refusal_atom} = EuAiActAdmission.admit(input)

      bogus_record = %{
        input: input,
        admitted?: false,
        refusal: :REFUSED_EUAIA_NEVER_ISSUED,
        checks: [%{name: :lawful_practice, verdict: :fail, refusal: :REFUSED_EUAIA_NEVER_ISSUED}]
      }

      assert {:error, {:record_outcome_mismatch, detail}} =
               Counterfactual.evaluate(bogus_record, input, checks())

      assert detail == {:expected, {false, :REFUSED_EUAIA_NEVER_ISSUED}, :got, {:refused, refusal_atom}}

      # Honest typed gap: no id-based decision lookup exists on any of the
      # composed modules — asserted against the real exports.
      refute function_exported?(Counterfactual, :fetch, 1)
      refute function_exported?(Counterfactual, :lookup, 1)
      refute function_exported?(EuAiActAdmission, :decision, 1)
      refute function_exported?(EuAiActAdmission, :by_id, 1)
    end
  end
end
