defmodule Xaas.Semantics.Art12ChainCourtTest do
  @moduledoc """
  Art. 12(3) END-TO-END chain court (lane W658c) — the master integration
  court composing the landed W500-series surfaces over their REAL modules:

      candidate
        → EuAiActAdmission.admit/1          (W500  typed refusal, Art 5(1))
        → IncidentReport.build/2            (W538  Art 73 classification)
        → AuthorityChannel.transmit/3       (W625  internal channel RECORDED)
        → AuditChain.append + verify_chain  (W503  tamper-evidence)
        → AutomationBiasCountermeasure.briefing/2 (W539 Art 14.4.b anatomy)
        → DeclaredMetrics.declare/0         (W536  cited-source metrics)
        → martingale monotonicity over a 3-decision sequence (Thm 4.1)

    plus the positive path: lawful candidate → admitted → receipt → chain
    append → verify :ok.
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.{
    AdmissionAttribution,
    AutomationBiasCountermeasure,
    AuthorityChannel,
    Counterfactual,
    DeclaredMetrics,
    EuAiActAdmission,
    IncidentReport,
    VulnerabilityLifecycle
  }

  alias Xaas.Witness.AuditChain

  ## ------------------------------------------------------------------
  ## Shared helpers — the composed chain, once, over real modules
  ## ------------------------------------------------------------------

  # Ordered admission check list (the W505/W506 shared shape), bridging the
  # W505 contract (`:pass | {:refuse, atom}`) to the W506 contract
  # (`:ok | {:refused, atom}`) without duplicating either surface.
  @checks [
    {:scope, fn _ -> :ok end},
    {:art5_structural,
     fn candidate ->
       case EuAiActAdmission.admit(candidate) do
         {:ok, :admitted} -> :ok
         {:error, refusal} -> {:refused, refusal}
       end
     end},
    {:logging, fn _ -> :ok end}
  ]

  defp w505_checks do
    Enum.map(@checks, fn {name, fun} ->
      {name, fn input ->
         case fun.(input) do
           :ok -> :pass
           {:refused, r} -> {:refuse, r}
         end
       end}
    end)
  end

  # The full chain stage run for one candidate. Returns a map carrying every
  # stage's real result so each per-stage test asserts on composed state.
  defp run_chain(candidate) do
    # (a) W500 typed admission
    admission = EuAiActAdmission.admit(candidate)

    # W506 decision record via the real deterministic pipeline
    %{outcome: outcome, checks: check_log} = Counterfactual.run(candidate, @checks)
    {admitted?, refusal} = outcome_record(outcome)

    record = %{input: candidate, admitted?: admitted?, refusal: refusal, checks: check_log}

    # (b) W538 classification over the refusal receipt (refusals only)
    incident =
      case refusal do
        nil ->
          nil

        atom ->
          receipt = %{
            digest: payload_digest(candidate),
            refusal_atom: atom,
            status: :refused,
            observed_at: ~U[2026-10-07 00:00:00Z]
          }

          IncidentReport.build([receipt])
      end

    # (c) W625 internal-channel recording of the classified report
    channel_recorded =
      case incident do
        {:ok, report} ->
          AuthorityChannel.transmit(report, :internal_escalation_receipt_corpus)

        nil ->
          nil
      end

    # (d) W503 tamper-evident chain append of the decision receipt
    payload = payload_digest({candidate, outcome})

    {:ok, chain, head} =
      AuditChain.append([], %{
        actuation_id: {:art12_chain, System.unique_integer([:positive])},
        payload_digest: payload
      })

    verified = AuditChain.verify_chain(chain, expected_head: head)

    # (e) W539 operator briefing over the decision record
    briefing =
      AutomationBiasCountermeasure.briefing(record, AdmissionAttribution.shapley(candidate, w505_checks()))

    %{
      admission: admission,
      admitted?: admitted?,
      refusal: refusal,
      record: record,
      incident: incident,
      channel_recorded: channel_recorded,
      chain: chain,
      head: head,
      verified: verified,
      briefing: briefing
    }
  end

  defp outcome_record(:admitted), do: {true, nil}
  defp outcome_record({:refused, reason}), do: {false, reason}

  defp payload_digest(term) do
    Base.encode16(:crypto.hash(:sha256, :erlang.term_to_iovec(term)), case: :lower)
  end

  ## ------------------------------------------------------------------
  ## Per-stage courts
  ## ------------------------------------------------------------------

  @violating %{
    id: :cand_violating,
    data_domains: [:affective],
    setting: :workplace
  }

  test "(a) violating candidate → W500 typed refusal atom" do
    assert {:error, :REFUSED_EUAIA_EMOTION_RECOGNITION} = EuAiActAdmission.admit(@violating)
  end

  test "(b) refusal receipt → W538 classification INFRINGES_UNION_LAW (not MALFUNCTION)" do
    {:ok, report} =
      IncidentReport.build([
        %{
          digest: payload_digest(@violating),
          refusal_atom: :REFUSED_EUAIA_EMOTION_RECOGNITION,
          observed_at: ~U[2026-10-07 00:00:00Z]
        }
      ])

    assert report.classification == [:INFRINGES_UNION_LAW]

    # a `REFUSED_EUAIA_*` atom with status :refused must NOT also classify as
    # MALFUNCTION — the classification is derived, partition-exact.
    refute :MALFUNCTION in report.classification
  end

  test "(c) classified report → W625 internal channel RECORDED with cited paths" do
    {:ok, report} =
      IncidentReport.build([
        %{
          digest: payload_digest(@violating),
          refusal_atom: :REFUSED_EUAIA_EMOTION_RECOGNITION,
          observed_at: ~U[2026-10-07 00:00:00Z]
        }
      ])

    assert {:ok, recorded} =
             AuthorityChannel.transmit(report, :internal_escalation_receipt_corpus)

    assert recorded.status == :RECORDED
    assert recorded.channel_id == :internal_escalation_receipt_corpus
    assert recorded.incident_id == report.incident_id
    assert recorded.classification == [:INFRINGES_UNION_LAW]
    # the internal channel is EVIDENCED — cited paths verified on disk
    assert is_list(recorded.where) and recorded.where != []
  end

  test "(d) escalation → W503 chain append + verify_chain :ok, tamper detected" do
    {:ok, chain, head} =
      AuditChain.append([], %{
        actuation_id: :art12_escalation,
        payload_digest: payload_digest({:escalation, @violating})
      })

    assert AuditChain.verify_chain(chain, expected_head: head) == :ok

    # tamper-evidence is live on this exact chain
    [tampered | rest] = chain
    tampered = %{tampered | payload_digest: String.duplicate("f", 64)}
    assert AuditChain.verify_chain([tampered | rest]) == {:error, {:tampered, 0}}
  end

  test "(e) operator briefing (W539) over the composed decision record" do
    court = run_chain(@violating)

    assert {:ok, briefing} = court.briefing
    assert briefing.verdict == :refuse

    # the anatomy names the exact flipped check and its typed refusal
    assert [%{name: :art5_structural, refusal: :REFUSED_EUAIA_EMOTION_RECOGNITION}] =
             briefing.refusal_anatomy

    # every check is present with its Shapley value; attribution is exact
    assert Enum.map(briefing.per_check_causes, & &1.name) == [:scope, :art5_structural, :logging]

    assert Enum.all?(briefing.per_check_causes, &is_float(&1.shapley))

    # the art5 check carries the full causal blame; the always-green checks none
    art5 = Enum.find(briefing.per_check_causes, &(&1.name == :art5_structural))
    assert art5.shapley > 0.0
    assert Enum.find(briefing.per_check_causes, &(&1.name == :scope)).shapley == 0.0

    assert briefing.counterfactual_available
    assert briefing.interpretability =~ "Shapley"
  end

  test "(f) DeclaredMetrics.declare reads the cited sources" do
    assert {:ok, metrics} = DeclaredMetrics.declare()

    assert metrics.accuracy.metric == "pass_rate"
    assert is_integer(metrics.accuracy.passed) and metrics.accuracy.passed > 0
    assert is_integer(metrics.accuracy.population) and metrics.accuracy.population > 0
    assert metrics.accuracy.source == "docs/sjira/v26.10.6/plans/w316-tokened-full-suite.md"

    assert metrics.robustness.metric == "mutant_kill_rate"
    assert is_integer(metrics.robustness.kills) and metrics.robustness.kills > 0
    assert is_integer(metrics.robustness.runs) and metrics.robustness.runs > 0
    assert is_binary(metrics.refusal_coverage) and metrics.refusal_coverage =~ "/"

    assert metrics.conformance =~ ~r/^\d+\/\d+ in-repo court$/
  end

  test "(g) martingale monotonicity across a 3-decision sequence" do
    candidates = [
      @violating,
      %{id: :cand_social, data_domains: [:social_behavior], context_joins: [:unrelated_context_join]},
      %{id: :cand_lawful, purpose: :assist}
    ]

    # Three decisions, one chain: every decision receipt appended in order.
    {chain, _head} =
      Enum.reduce(candidates, {[], nil}, fn candidate, {chain, _prev_head} ->
        {:ok, chain, head} =
          AuditChain.append(chain, %{
            actuation_id: candidate.id,
            payload_digest: payload_digest({candidate.id, EuAiActAdmission.admit(candidate)})
          })

        {chain, head}
      end)

    assert length(chain) == 3
    assert AuditChain.verify_chain(chain, expected_length: 3) == :ok
    assert AuditChain.martingale(chain) == [1, 1, 1]

    # monotone non-increasing under tamper: from the first tampered receipt
    # onward M_k latches to 0 and never recovers
    [r0, r1, r2] = chain
    tampered = %{r1 | payload_digest: String.duplicate("a", 64)}
    m = AuditChain.martingale([r0, tampered, r2])
    assert m == [1, 0, 0]

    # per-decision single-link chains: each stage's own chain verifies clean
    # against its own head (independent escalation runs)
    for candidate <- candidates do
      {:ok, c, h} =
        AuditChain.append([], %{
          actuation_id: candidate.id,
          payload_digest: payload_digest({candidate, :single})
        })

      assert AuditChain.verify_chain(c, expected_head: h) == :ok
      assert AuditChain.martingale(c) == [1]
    end
  end

  ## ------------------------------------------------------------------
  ## Positive path — the factual baseline
  ## ------------------------------------------------------------------

  test "positive path: lawful candidate → admitted → receipt → chain → verify :ok" do
    lawful = %{id: :cand_positive, purpose: :summarize, data_domains: [:text], setting: :office}

    # admission
    assert {:ok, :admitted} = EuAiActAdmission.admit(lawful)

    # no incident evidence from a lawful candidate
    full = run_chain(lawful)
    assert full.admitted?
    assert is_nil(full.refusal)
    assert is_nil(full.incident)
    assert is_nil(full.channel_recorded)

    # decision record is a faithful admit witness
    assert full.record.admitted? and is_nil(full.record.refusal)

    # operator briefing: admit anatomy — zero-blame, no refusal anatomy
    assert {:ok, briefing} = full.briefing
    assert briefing.verdict == :admit
    assert briefing.refusal_anatomy == []
    assert length(briefing.per_check_causes) == 3

    # actuation-ready receipt appended to the chain, verified with its head
    {:ok, chain, head} =
      AuditChain.append([], %{
        actuation_id: {:art12_positive, lawful.id},
        payload_digest: payload_digest({lawful, :admitted})
      })

    assert AuditChain.verify_chain(chain, expected_head: head) == :ok
    assert AuditChain.martingale(chain) == [1]
  end

  ## ------------------------------------------------------------------
  ## VulnerabilityLifecycle (W540) — the chain's defect ledger discipline
  ## ------------------------------------------------------------------

  test "lifecycle: chain defect DETECTED → TRIAGED → RESPONDED → RESOLVED forward-only" do
    assert {:ok, lc} =
             VulnerabilityLifecycle.new(%{
               detector: "Art12ChainCourt/w503-tamper-probe",
               finding: "verify_chain returned {:error, {:tampered, 0}} on a mutated payload digest"
             })

    assert {:ok, lc} =
             VulnerabilityLifecycle.triage(lc, %{
               analysis: "tamper probe mutates payload_digest of link 0; successor-consistency check (b) fails"
             })

    assert {:ok, lc} =
             VulnerabilityLifecycle.respond(lc, %{
               receipt: "court (d) tamper assertion exercises the guard on the real chain"
             })

    assert {:ok, _lc} =
             VulnerabilityLifecycle.resolve(lc, %{
               green: true,
               run: "mix test test/xaas/semantics/art12_chain_court_test.exs"
             })

    # skip is refused: DETECTED → RESPONDED is not a legal edge
    {:ok, lc2} = VulnerabilityLifecycle.new(%{detector: "x", finding: "y"})
    assert {:error, :REFUSED_LIFECYCLE_SKIP} = VulnerabilityLifecycle.resolve(lc2, %{green: true, run: "skip"})
  end
end
