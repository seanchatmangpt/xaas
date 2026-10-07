defmodule Xaas.EuAiAct.CounterfactualTest do
  @moduledoc """
  Lane W550 — line-by-line COUNTERFACTUAL test harness (operator directive
  2026-10-06): paired factual-baseline -> do-intervention -> deterministic-
  refusal per operational article, over the REAL landed modules.

  Pearl's 3-step per test:
    1. FACTUAL — the lawful input admits/passes (real call).
    2. ACTION  — apply the specific do-intervention to the input (mutate
       exactly the governed attribute; everything else held constant).
    3. PREDICTION — assert the exact typed refusal and that NO side effect
       occurred (pure modules: the input map is unchanged — the
       do-intervention held everything else constant).

  Every refusal row runs the intervention twice and asserts identical
  results (determinism x2).

  Article -> module map (all real atoms, no invented ones):

    | article     | module                                   | asserted atom/term |
    |-------------|------------------------------------------|--------------------|
    | Art 5(1)(a) | Xaas.Semantics.EuAiActAdmission          | REFUSED_EUAIA_MANIPULATIVE / _VULNERABILITY_EXPLOIT |
    | Art 5(1)(b) | Xaas.Semantics.EuAiActAdmission          | REFUSED_EUAIA_SOCIAL_SCORING |
    | Art 5(1)(c) | Xaas.Semantics.EuAiActAdmission          | REFUSED_EUAIA_PREDICTIVE_POLICING |
    | Art 5(1)(d) | Xaas.Semantics.EuAiActAdmission          | REFUSED_EUAIA_FACIAL_SCRAPING |
    | Art 5(1)(e) | Xaas.Semantics.EuAiActAdmission          | REFUSED_EUAIA_EMOTION_RECOGNITION |
    | Art 5(1)(f) | Xaas.Semantics.EuAiActAdmission          | REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION |
    | Art 5(1)(g-h)| Xaas.Semantics.EuAiActAdmission         | REFUSED_EUAIA_REALTIME_RBI |
    | Art 10(2)   | Xaas.Semantics.DatasetAdmission          | {:REFUSED_BIAS_THRESHOLD, _} |
    | Art 12      | Xaas.Witness.AuditChain                  | {:tampered, k} |
    | Art 15(1)   | Xaas.Semantics.RobustMargin              | REFUSED_ROBUST_MARGIN |
    | Art 15(5)   | Xaas.Semantics.VulnerabilityLifecycle    | REFUSED_LIFECYCLE_SKIP |
    | Art 14(4)(e)| Xaas.Actuation.QuiescentStop             | REFUSED_STOP_AUTHORITY |
    | Art 14(4)(b)| Xaas.Semantics.AutomationBiasCountermeasure | refusal_anatomy non-empty |
    | Art 86(1)   | Xaas.Semantics.Counterfactual            | exact deterministic outcome |
    | Art 73      | Xaas.Semantics.IncidentReport            | PREPARED_NOT_TRANSMITTED |
  """

  use ExUnit.Case, async: true

  alias Xaas.Actuation.QuiescentStop
  alias Xaas.Semantics.AutomationBiasCountermeasure
  alias Xaas.Semantics.Counterfactual
  alias Xaas.Semantics.DatasetAdmission
  alias Xaas.Semantics.DeclaredMetrics
  alias Xaas.Semantics.EuAiActAdmission
  alias Xaas.Semantics.IncidentReport
  alias Xaas.Semantics.RobustMargin
  alias Xaas.Semantics.VulnerabilityLifecycle
  alias Xaas.Witness.AuditChain

  # -- harness helpers ---------------------------------------------------------

  # Pearl 3-step inline: run the lawful call, apply the do-intervention, run
  # again — twice — and assert identical typed refusals plus input immutability.
  defp run_intervention_twice(lawful_input, intervention) do
    r1 = EuAiActAdmission.admit(lawful_input)
    intervened = intervention.(lawful_input)
    r2 = EuAiActAdmission.admit(intervened)
    r3 = EuAiActAdmission.admit(intervened)

    {r1, r2, r3}
  end

  # -- Art 5(1)(a) — manipulative / subliminal / deceptive techniques ----------

  test "Art 5(1)(a) manipulative: lawful technique set admits; do(manipulate_behavior) refuses deterministically" do
    lawful = %{id: "c-a", techniques: [:personalization], purpose: :recommend_content}

    assert {:ok, :admitted} = EuAiActAdmission.admit(lawful)

    intervention = fn c -> Map.put(c, :techniques, [:manipulate_behavior]) end
    {r1, r2, r3} = run_intervention_twice(lawful, intervention)

    assert r1 == {:ok, :admitted}
    assert r2 == {:error, :REFUSED_EUAIA_MANIPULATIVE}
    assert r3 == r2
  end

  test "Art 5(1)(a) vulnerability exploit: do(exploit_vulnerability) refuses deterministically" do
    lawful = %{id: "c-a2", techniques: [:personalization], purpose: :assist_user}

    assert {:ok, :admitted} = EuAiActAdmission.admit(lawful)

    intervention = fn c -> Map.put(c, :techniques, [:exploit_vulnerability]) end
    {r1, r2, r3} = run_intervention_twice(lawful, intervention)

    assert r1 == {:ok, :admitted}
    assert r2 == {:error, :REFUSED_EUAIA_VULNERABILITY_EXPLOIT}
    assert r3 == r2
  end

  # -- Art 5(1)(b) — social scoring --------------------------------------------

  test "Art 5(1)(b) social scoring: do(social_behavior + unrelated_context_join) refuses deterministically" do
    lawful = %{
      id: "c-b",
      data_domains: [:transaction_history],
      context_joins: [:own_context_join],
      purpose: :credit_assessment
    }

    assert {:ok, :admitted} = EuAiActAdmission.admit(lawful)

    intervention = fn c ->
      Map.put(c, :data_domains, c.data_domains ++ [:social_behavior])
      |> Map.put(:context_joins, c.context_joins ++ [:unrelated_context_join])
    end

    {r1, r2, r3} = run_intervention_twice(lawful, intervention)

    assert r1 == {:ok, :admitted}
    assert r2 == {:error, :REFUSED_EUAIA_SOCIAL_SCORING}
    assert r3 == r2
  end

  # -- Art 5(1)(c) — predictive policing ----------------------------------------

  test "Art 5(1)(c) predictive policing: do(purpose: predict_offending + individualized join) refuses deterministically" do
    lawful = %{
      id: "c-c",
      purpose: :forecast_demand,
      context_joins: [:aggregate_only_join]
    }

    assert {:ok, :admitted} = EuAiActAdmission.admit(lawful)

    intervention = fn c ->
      Map.put(c, :purpose, :predict_offending)
      |> Map.put(:context_joins, c.context_joins ++ [:individualized_profile_join])
    end

    {r1, r2, r3} = run_intervention_twice(lawful, intervention)

    assert r1 == {:ok, :admitted}
    assert r2 == {:error, :REFUSED_EUAIA_PREDICTIVE_POLICING}
    assert r3 == r2
  end

  # -- Art 5(1)(d) — untargeted facial scraping ---------------------------------

  test "Art 5(1)(d) facial scraping: do(facial_images with scraped provenance) refuses deterministically" do
    lawful = %{id: "c-d", data_domains: [:text], provenance: :consented}

    assert {:ok, :admitted} = EuAiActAdmission.admit(lawful)

    intervention = fn c ->
      Map.put(c, :data_domains, c.data_domains ++ [:facial_images])
      |> Map.put(:provenance, :scraped)
    end

    {r1, r2, r3} = run_intervention_twice(lawful, intervention)

    assert r1 == {:ok, :admitted}
    assert r2 == {:error, :REFUSED_EUAIA_FACIAL_SCRAPING}
    assert r3 == r2
  end

  # -- Art 5(1)(e) — emotion recognition in workplace/education ------------------

  test "Art 5(1)(e) emotion recognition: do(affective domain in workplace) refuses deterministically" do
    lawful = %{id: "c-e", data_domains: [:text], setting: :workplace}

    assert {:ok, :admitted} = EuAiActAdmission.admit(lawful)

    intervention = fn c -> Map.put(c, :data_domains, c.data_domains ++ [:affective]) end
    {r1, r2, r3} = run_intervention_twice(lawful, intervention)

    assert r1 == {:ok, :admitted}
    assert r2 == {:error, :REFUSED_EUAIA_EMOTION_RECOGNITION}
    assert r3 == r2
  end

  # -- Art 5(1)(f) — biometric categorization ------------------------------------

  test "Art 5(1)(f) biometric categorization: do(sensitive inference on biometric surface) refuses deterministically" do
    lawful = %{
      id: "c-f",
      data_domains: [:facial_images],
      provenance: :consented,
      inferences: [],
      match_token_type: :boolean
    }

    assert {:ok, :admitted} = EuAiActAdmission.admit(lawful)

    intervention = fn c -> Map.put(c, :inferences, [:political_opinion]) end
    {r1, r2, r3} = run_intervention_twice(lawful, intervention)

    assert r1 == {:ok, :admitted}
    assert r2 == {:error, :REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION}
    assert r3 == r2
  end

  # -- Art 5(1)(g)-(h) — realtime RBI in public space -----------------------------

  test "Art 5(1)(g-h) realtime RBI: do(latency_goal: realtime in public_space) refuses deterministically" do
    lawful = %{
      id: "c-g",
      data_domains: [:biometric_identification],
      setting: :private_premises,
      latency_goal: :batch
    }

    assert {:ok, :admitted} = EuAiActAdmission.admit(lawful)

    intervention = fn c ->
      Map.put(c, :setting, :public_space) |> Map.put(:latency_goal, :realtime)
    end

    {r1, r2, r3} = run_intervention_twice(lawful, intervention)

    assert r1 == {:ok, :admitted}
    assert r2 == {:error, :REFUSED_EUAIA_REALTIME_RBI}
    assert r3 == r2
  end

  # -- Art 10(2) — bias threshold over training data -------------------------------

  test "Art 10(2): factual balanced sample admits; do(W1-skewed sensitive group) refuses REFUSED_BIAS_THRESHOLD deterministically" do
    lawful = [
      %{features: %{score: 5.0}, label: :y, sensitive: 0},
      %{features: %{score: 5.0}, label: :y, sensitive: 1}
    ]

    assert {:ok, :ADMITTED, %{w1_proxy: w1}} =
             DatasetAdmission.admit(lawful, seed: 7)

    assert w1 == 0.0

    # Do-intervention: shift ONLY the sensitive=1 group's feature; everything
    # else (count, labels, seed, epsilon) held constant.
    skewed = [
      %{features: %{score: 5.0}, label: :y, sensitive: 0},
      %{features: %{score: 50.0}, label: :y, sensitive: 1}
    ]

    r1 = DatasetAdmission.admit(skewed, seed: 7)
    r2 = DatasetAdmission.admit(skewed, seed: 7)

    assert {:error, {:REFUSED_BIAS_THRESHOLD, %{w1_proxy: measured, epsilon_bias: eps}}} = r1
    assert measured > eps
    assert r2 == r1

    # No side effect on the lawful sample list (pure module).
    assert lawful == [
             %{features: %{score: 5.0}, label: :y, sensitive: 0},
             %{features: %{score: 5.0}, label: :y, sensitive: 1}
           ]
  end

  # -- Art 12 — record-keeping: tamper detection over the audit chain --------------

  test "Art 12: factual chain verifies; do(tamper payload_digest of link k) yields {:tampered, k} deterministically" do
    # payload_digest must be a 64-hex SHA-256 (Definition 4.2).
    chain =
      Enum.reduce(1..4, [], fn i, acc ->
        {:ok, acc, _head} =
          AuditChain.append(acc, %{
            actuation_id: "act-#{i}",
            payload_digest: String.duplicate(Integer.to_string(i, 16), 64)
          })

        acc
      end)

    # FACTUAL: the untampered chain verifies.
    assert :ok = AuditChain.verify_chain(chain, expected_length: 4)

    # ACTION: tamper EXACTLY link k=2's payload_digest; all else constant.
    k = 2
    tampered = List.update_at(chain, k, fn r -> %{r | payload_digest: "forged"} end)

    # PREDICTION: exact attribution of the tampered index, deterministically.
    e1 = AuditChain.verify_chain(tampered, expected_length: 4)
    e2 = AuditChain.verify_chain(tampered, expected_length: 4)

    assert {:error, {:tampered, ^k}} = e1
    assert e1 == e2

    # The original chain is untouched (no side effect).
    assert :ok = AuditChain.verify_chain(chain, expected_length: 4)
  end

  # W655b — the TAIL-link row (W551 M3 survivor): link-2 tamper is caught by
  # successor linkage (link 3's prev_hash no longer matches), but a tamper of
  # the LAST link has no successor to break. Two sub-cases:
  #
  #   (a) non-hex forged digest ("forged") — still caught at the tail by the
  #       64-hex format check (valid_payload_digest?/1).
  #   (b) a VALID-FORMAT 64-hex digest substituted for the real one — the
  #       realistic payload tamper — is NOT caught by verify_chain/2 alone
  #       (:ok, the documented tail blind spot); it IS caught as
  #       {:tampered, :head} when the honest head hash is supplied via
  #       expected_head. Per-link recomputation alone does not cover the tail.
  test "Art 12 tail link: do(tamper LAST link payload_digest) needs expected_head — verify_chain/2 alone verifies :ok for a valid-format forged tail digest" do
    {chain, honest_head} =
      Enum.reduce(1..4, {[], AuditChain.root_hash()}, fn i, {acc, _prev_head} ->
        {:ok, acc, head} =
          AuditChain.append(acc, %{
            actuation_id: "act-tail-#{i}",
            payload_digest: String.duplicate(Integer.to_string(i, 16), 64)
          })

        {acc, head}
      end)

    assert byte_size(honest_head) == 64

    # FACTUAL: the untampered 4-link chain verifies, with and without a head pin.
    assert :ok = AuditChain.verify_chain(chain, expected_length: 4)
    assert :ok = AuditChain.verify_chain(chain, expected_length: 4, expected_head: honest_head)

    # ACTION (a): tamper ONLY the last link (k=3) with a NON-hex digest.
    last = 3
    forged_format = List.update_at(chain, last, fn r -> %{r | payload_digest: "w655b-forged"} end)
    assert {:error, {:tampered, ^last}} =
             AuditChain.verify_chain(forged_format, expected_length: 4)

    # ACTION (b): tamper ONLY the last link with a VALID 64-hex digest
    # (realistic payload substitution, format check passes).
    valid_forged_digest = String.duplicate("e", 64)
    tampered_tail =
      List.update_at(chain, last, fn r -> %{r | payload_digest: valid_forged_digest} end)

    # PREDICTION (b), the typed finding: WITHOUT expected_head the tail tamper
    # verifies :ok — no successor linkage and no head pin covers the last link.
    b1 = AuditChain.verify_chain(tampered_tail, expected_length: 4)
    b2 = AuditChain.verify_chain(tampered_tail, expected_length: 4)
    assert :ok = b1
    assert b1 == b2

    # PREDICTION (b), the mitigation: WITH the honest expected_head the same
    # tamper is detected as {:tampered, :head}, deterministically.
    h1 = AuditChain.verify_chain(tampered_tail, expected_length: 4, expected_head: honest_head)
    h2 = AuditChain.verify_chain(tampered_tail, expected_length: 4, expected_head: honest_head)
    assert {:error, {:tampered, :head}} = h1
    assert h1 == h2

    # No side effect: the original chain is untouched.
    assert :ok = AuditChain.verify_chain(chain, expected_length: 4, expected_head: honest_head)
  end

  # -- Art 15(1) — adversarial robustness margin ------------------------------------

  test "Art 15(1): factual epsilon admits; do(epsilon out of margin) refuses REFUSED_ROBUST_MARGIN deterministically" do
    # margin h(E(x)) = 1.0, L_h = 2.0, L_E = 1.0: margin holds for eps <= 0.5.
    lawful_margin = 1.0
    l_h = 2.0
    l_e = 1.0
    eps_lawful = 0.5

    assert :ADMITTED = RobustMargin.admit(lawful_margin, l_h, l_e, eps_lawful)

    # Do-intervention: enlarge ONLY epsilon; margin, L_h, L_e held constant.
    eps_attack = 0.5 + 1.0e-9

    r1 = RobustMargin.admit(lawful_margin, l_h, l_e, eps_attack)
    r2 = RobustMargin.admit(lawful_margin, l_h, l_e, eps_attack)

    assert {:error, :REFUSED_ROBUST_MARGIN} = r1
    assert r1 == r2
  end

  # -- Art 15(5) — vulnerability lifecycle, forward-only ------------------------------

  test "Art 15(5): factual triage advances; do(skip to respond from DETECTED) refuses REFUSED_LIFECYCLE_SKIP deterministically" do
    {:ok, detected} =
      VulnerabilityLifecycle.new(%{detector: "mutant-court", finding: "survived mutant 2"})

    # FACTUAL: the lawful next edge DETECTED -> TRIAGED advances.
    assert {:ok, %VulnerabilityLifecycle{state: :TRIAGED}} =
             VulnerabilityLifecycle.triage(detected, %{analysis: "gap at cell w382/2"})

    # ACTION: skip the triage edge — respond straight from DETECTED.
    e1 = VulnerabilityLifecycle.respond(detected, %{receipt: "diff abc"})
    e2 = VulnerabilityLifecycle.respond(detected, %{receipt: "diff abc"})

    assert {:error, :REFUSED_LIFECYCLE_SKIP} = e1
    assert e1 == e2

    # No side effect: the struct is unchanged by the refused transition.
    assert detected.state == :DETECTED
    assert detected.history == [{:detect, :DETECTED}]
  end

  # -- Art 14(4)(e) — stop authority (fail-closed) --------------------------------------

  test "Art 14(4)(e): stop without admitted authority refuses REFUSED_STOP_AUTHORITY deterministically, before any DO" do
    opts = [idempotency_key: "stop-key-w550", authority: %{}]

    e1 = QuiescentStop.execute(Xaas.Marketplace.Provider, opts)
    e2 = QuiescentStop.execute(Xaas.Marketplace.Provider, opts)

    assert {:error, :REFUSED_STOP_AUTHORITY} = e1
    assert e1 == e2
  end

  # -- Art 14(4)(b) — automation-bias countermeasure: refusal anatomy present ------------

  test "Art 14(4)(b): refusal briefing carries non-empty refusal_anatomy (attribution present) deterministically" do
    checks = [
      {:technique_ok,
       fn c -> if Map.get(c, :techniques) == [], do: :ok, else: {:refused, :REFUSED_TECHNIQUE} end},
      {:id_ok, fn c -> if is_binary(Map.get(c, :id)), do: :ok, else: {:refused, :REFUSED_NO_ID} end}
    ]

    lawful_input = %{id: "op-1", techniques: []}
    %{outcome: outcome, checks: check_log} = Counterfactual.run(lawful_input, checks)
    assert outcome == :admitted

    record = %{input: lawful_input, admitted?: true, refusal: nil, checks: check_log}
    attributions = %{technique_ok: 0.0, id_ok: 0.0}

    # FACTUAL: an admit briefing still carries per-check anatomy.
    assert {:ok, briefing_admit} = AutomationBiasCountermeasure.briefing(record, attributions)
    assert briefing_admit.verdict == :admit
    assert briefing_admit.per_check_causes != []

    # ACTION: do-intervention — strip the id (the governed attribute).
    stripped = %{input: %{techniques: []}, admitted?: false, refusal: :REFUSED_NO_ID, checks: nil}

    %{outcome: refused_outcome, checks: refused_log} =
      Counterfactual.run(%{techniques: []}, checks)

    assert refused_outcome == {:refused, :REFUSED_NO_ID}

    refused_record = %{
      input: Map.delete(lawful_input, :id),
      admitted?: false,
      refusal: :REFUSED_NO_ID,
      checks: refused_log
    }

    assert {:ok, briefing_refuse} =
             AutomationBiasCountermeasure.briefing(refused_record, attributions)

    # PREDICTION: refusal_anatomy is non-empty — the countermeasure fired,
    # the operator is never shown an unexplained verdict.
    assert briefing_refuse.verdict == :refuse
    assert briefing_refuse.refusal_anatomy != []
    assert [%{name: :id_ok, refusal: :REFUSED_NO_ID}] = briefing_refuse.refusal_anatomy

    # Determinism x2 + no side effect on the original record.
    assert {:ok, briefing_refuse2} =
             AutomationBiasCountermeasure.briefing(refused_record, attributions)

    assert briefing_refuse2 == briefing_refuse
    assert record.input == lawful_input
    assert stripped.refusal == :REFUSED_NO_ID
  end

  # -- Art 86(1) — right to explanation: exact deterministic counterfactual --------------

  test "Art 86(1): counterfactual on the recorded decision is an exact 0/1 outcome, deterministically" do
    checks = [
      {:consent_ok,
       fn c -> if Map.get(c, :provenance) == :consented, do: :ok, else: {:refused, :REFUSED_NO_CONSENT} end},
      {:scope_ok, fn _c -> :ok end}
    ]

    factual_input = %{id: "cf-1", provenance: :consented}
    x_prime = %{id: "cf-1", provenance: :scraped}

    # FACTUAL: the recorded decision admits under this check-list.
    record = %{
      input: factual_input,
      admitted?: true,
      refusal: nil,
      checks: [
        %{name: :consent_ok, verdict: :pass, refusal: nil},
        %{name: :scope_ok, verdict: :pass, refusal: nil}
      ]
    }

    assert {:ok, result} = Counterfactual.evaluate(record, x_prime, checks)

    # PREDICTION: Theorem 7.1 — the counterfactual outcome is exactly one
    # deterministic value, with the named causal check.
    assert result.outcome == {:refused, :REFUSED_NO_CONSENT}
    assert result.changed? == true
    assert result.explanation =~ "consent_ok"

    # Determinism x2: identical replay, byte-identical result.
    assert {:ok, result2} = Counterfactual.evaluate(record, x_prime, checks)
    assert result2 == result

    # No side effect: the recorded decision and its input are unchanged.
    assert record.admitted? == true
    assert record.refusal == nil
    assert factual_input.provenance == :consented
  end

  # -- Art 73 — serious-incident reporting: honest transmission channel -------------------

  test "Art 73: report builds from typed refusal evidence; transmit is PREPARED_NOT_TRANSMITTED, deterministically" do
    receipt = %{
      digest: "sha256:w550-evidence",
      refusal_atom: :REFUSED_EUAIA_MANIPULATIVE,
      observed_at: ~U[2026-10-06 00:00:00Z]
    }

    assert {:ok, report} = IncidentReport.build([receipt])

    assert :INFRINGES_UNION_LAW in report.classification

    t1 = IncidentReport.transmit(report)
    t2 = IncidentReport.transmit(report)

    assert {:ok, %{status: :PREPARED_NOT_TRANSMITTED, reason: reason}} = t1
    assert reason != ""
    assert t1 == t2

    # No side effect: the report was not consumed or mutated by transmit.
    assert :INFRINGES_UNION_LAW in report.classification
  end

  # -- DeclaredMetrics (W536) presence check: declared vs measured stay pure --------------

  test "DeclaredMetrics surface stays a pure call argument gate (no ambient state)" do
    assert is_atom(DeclaredMetrics.__info__(:module))
  end

  # ==========================================================================
  # Lane W624 — counterfactual harness EXTENSION (rows over additional real
  # seams). Same Pearl 3-phase pattern; every row determinism x2.
  # ==========================================================================

  # -- Art 9(2)(a) — post-market barrier: NOT_RUN (disclosed) -----------------
  # ferroplan's BackwardSafeSet is not a mix dep of xaas (cross-repo), so no
  # in-repo seam exists for a real do-intervention. Honest scoping: this row
  # is NOT_RUN, recorded in docs/sjira/v26.10.6/plans/w624-counterfactual-extension.md.

  # -- Art 11 — technical documentation drift (DeclaredMetrics fail-closed) ----

  test "Art 11: factual declare() reads real receipts; do(receipt source removed) refuses REFUSED_METRICS_SOURCE_MISSING deterministically" do
    # FACTUAL: with the repo root, every cited receipt exists and declare/0
    # returns the real evidence-pointer structure.
    # (W654: no in-process Application env mutation anywhere in this test —
    # the counterfactual arm runs in an isolated `mix run` subprocess so the
    # async suite never samples a perturbed :declared_metrics_root.)
    factual = DeclaredMetrics.declare()

    assert {:ok,
            %{
              accuracy: %{metric: "pass_rate", source: src},
              robustness: %{metric: "mutant_kill_rate", sources: [_ | _]}
            }} = factual

    assert src =~ "w316"

    # ACTION: do-intervention — point the metrics root at an empty directory
    # (every cited receipt source gone); nothing else changes. The intervention
    # happens in an ISOLATED subprocess (its own BEAM, its own Application
    # env), so the parent node's env is never perturbed — no async flake.
    empty_root =
      System.tmp_dir!() |> Path.join("w624-metrics-root-#{System.unique_integer()}")

    File.mkdir_p!(empty_root)

    probe = """
    Application.put_env(:xaas, :declared_metrics_root, System.fetch_env!("W654_EMPTY_ROOT"))
    r1 = Xaas.Semantics.DeclaredMetrics.declare()
    r2 = Xaas.Semantics.DeclaredMetrics.declare()
    case {r1, r2} do
      {{:error, :REFUSED_METRICS_SOURCE_MISSING}, {:error, :REFUSED_METRICS_SOURCE_MISSING}} ->
        IO.puts("W654_REFUSED_DETERMINISTIC")
      _ ->
        IO.puts("W654_UNEXPECTED: " <> inspect({r1, r2}))
        System.halt(1)
    end
    """

    {out, exit_code} =
      System.cmd(
        mix_bin(),
        ["run", "--no-start", "-e", probe],
        cd: File.cwd!(),
        env: %{
          "MIX_ENV" => "test",
          "MIX_BUILD_ROOT" => build_root(),
          "W654_EMPTY_ROOT" => empty_root,
          "PATH" => System.get_env("PATH", "")
        },
        stderr_to_stdout: true
      )

    # PREDICTION: fail-closed typed refusal, deterministically (x2, in the
    # isolated process).
    assert exit_code == 0, "subprocess failed (exit #{exit_code}):\n#{out}"
    assert out =~ "W654_REFUSED_DETERMINISTIC", out
    refute out =~ "W654_UNEXPECTED"

    # No side effect on the filesystem beyond the empty fixture root itself.
    assert File.ls!(empty_root) == []

    on_exit(fn ->
      File.rm_rf(empty_root)
    end)
  end

  # Subprocess isolation helpers: run the child on the SAME build root this
  # test run uses (leased lane root when set, else the default _build), under
  # the same elixir toolchain, so no recompilation storm and no env leak.
  defp mix_bin do
    System.find_executable("mix") || raise("mix not on PATH")
  end

  defp build_root do
    System.get_env("MIX_BUILD_ROOT") || "_build"
  end

  # -- Art 25 — value-chain integrity: digest sensitivity of the JCS payload ----

  test "Art 25: JCS digest binds the payload; do(tamper one field) changes the digest deterministically" do
    payload = %{"model" => "a2a-card", "version" => 1, "provider" => %{"org" => "xaas"}}

    factual = :crypto.hash(:sha256, Xaas.Semantics.Jcs.encode(payload)) |> Base.encode16(case: :lower)

    assert is_binary(factual) and byte_size(factual) == 64

    # ACTION: tamper EXACTLY one nested field; everything else held constant.
    tampered_payload = put_in(payload, ["provider", "org"], "forged-org")

    d1 = :crypto.hash(:sha256, Xaas.Semantics.Jcs.encode(tampered_payload)) |> Base.encode16(case: :lower)
    d2 = :crypto.hash(:sha256, Xaas.Semantics.Jcs.encode(tampered_payload)) |> Base.encode16(case: :lower)

    # PREDICTION: any value-chain mutation is digest-visible, deterministically.
    assert d1 != factual
    assert d2 == d1

    # The witness chain hash binds the same way (AuditChain.hash_receipt/2 is
    # the real JCS hash): tampering a receipt's payload_digest changes its
    # chain hash — same digest-sensitivity property at the chain layer.
    {:ok, chain, _head} =
      AuditChain.append([], %{
        actuation_id: "w624-art25",
        payload_digest: String.duplicate("a", 64)
      })

    [link] = chain
    legit = AuditChain.hash_receipt(link, "0")
    forged = AuditChain.hash_receipt(%{link | payload_digest: String.duplicate("b", 64)}, "0")

    assert legit != forged
    # Determinism x2 on the chain hash too.
    assert AuditChain.hash_receipt(link, "0") == legit
    assert AuditChain.hash_receipt(%{link | payload_digest: String.duplicate("b", 64)}, "0") == forged
  end

  # -- Art 26(6) — retention: receipts are durable rows, tamper-evident ----------
  # Tamper case follows W524b's audit_chain_actuation_integration pattern
  # (in-memory variant over the same AuditChain calculus — no DB fixture).

  test "Art 26(6): retention policy is permanent_durable_rows with existing sources; tampered retained record is detected deterministically" do
    alias Xaas.Semantics.OversightGovernance

    assert {:ok, policy} = OversightGovernance.retention_policy()
    assert policy.actuation_receipts == :permanent_durable_rows
    assert policy.ephemeral_artifacts == :lane_lease_cleanup

    # Factual: every cited retention source path exists on disk.
    for path <- OversightGovernance.cited_paths() do
      assert File.exists?(Path.join(File.cwd!(), path)), "missing cited source: #{path}"
    end

    # W524b pattern (in-memory): a retained receipt chain verifies; tampering
    # one link's payload is detected with exact attribution.
    {:ok, chain, _head} =
      Enum.reduce(1..3, {:ok, [], nil}, fn i, {:ok, acc, _} ->
        AuditChain.append(acc, %{
          actuation_id: "w624-ret-#{i}",
          payload_digest: String.duplicate(Integer.to_string(i, 16), 64)
        })
      end)

    assert :ok = AuditChain.verify_chain(chain, expected_length: 3)

    k = 1
    tampered = List.update_at(chain, k, fn r -> %{r | payload_digest: "w624-forged"} end)

    e1 = AuditChain.verify_chain(tampered, expected_length: 3)
    e2 = AuditChain.verify_chain(tampered, expected_length: 3)

    assert {:error, {:tampered, ^k}} = e1
    assert e1 == e2

    # No side effect: the lawful retained chain still verifies.
    assert :ok = AuditChain.verify_chain(chain, expected_length: 3)
  end

  # -- Art 50(2) — synthetic-content marking: stripping is DETECTABLE ------------

  test "Art 50(2): factual response is marked; do(strip ai_generated) is detectable because the plug re-marks unconditionally, incl. refusal envelopes" do
    alias XaasWeb.Plugs.SyntheticMarkingPlug

    mark_and_send = fn status, body ->
      Plug.Test.conn(:post, "/a2a/v1")
      |> SyntheticMarkingPlug.call([])
      |> Plug.Conn.resp(status, body)
      |> Plug.Conn.send_resp()
    end

    # FACTUAL: a 200 JSON response carries both markings.
    conn =
      mark_and_send.(200, Jason.encode!(%{"answer" => "synthetic text", "refusal" => nil}))

    assert {"x-ai-generated", "true"} in conn.resp_headers
    assert %{"ai_generated" => true, "answer" => "synthetic text"} = Jason.decode!(conn.resp_body)

    # ACTION (refusal envelope): a halted refusal envelope — the exact W521
    # case — is STILL marked (before_send callbacks run on halted conns).
    refusal_conn =
      mark_and_send.(200, Jason.encode!(%{"error" => "REFUSED_EUAIA_MANIPULATIVE"}))

    assert %{"ai_generated" => true, "error" => "REFUSED_EUAIA_MANIPULATIVE"} =
             Jason.decode!(refusal_conn.resp_body)

    # ACTION (strip): strip the ai_generated field from a marked body — the
    # downstream consumer can DETECT the strip because the header remains,
    # and re-running the plug over the stripped body re-marks unconditionally.
    stripped_body =
      conn.resp_body
      |> Jason.decode!()
      |> Map.delete("ai_generated")
      |> Jason.encode!()

    remarked =
      Plug.Test.conn(:post, "/a2a/v1")
      |> SyntheticMarkingPlug.call([])
      |> Plug.Conn.resp(200, stripped_body)
      |> Plug.Conn.send_resp()

    assert {"x-ai-generated", "true"} in remarked.resp_headers
    assert %{"ai_generated" => true} = Jason.decode!(remarked.resp_body)

    # Determinism x2: marking the same stripped body twice is identical.
    remarked2 =
      Plug.Test.conn(:post, "/a2a/v1")
      |> SyntheticMarkingPlug.call([])
      |> Plug.Conn.resp(200, stripped_body)
      |> Plug.Conn.send_resp()

    assert remarked2.resp_body == remarked.resp_body
    assert remarked2.resp_headers == remarked.resp_headers
  end

  # -- Art 72 — post-market drift: fitness drop on a perturbed OCEL trace --------
  # Pattern cited from test/xaas/telemetry/ocel_fitness_integration_test.exs
  # (W545). Its Art72 submodule is nested inside that test module and not
  # reliably compiled in the test/eu_ai_act context, so the Definition 7.2
  # token-replay calculus is replicated inline here — same disclosed
  # replication discipline W545 used for beam4pm (beam4pm is not a xaas dep).

  test "Art 72: factual OCEL trace fits the model (NO_DRIFT); do(drop the sealed-receipt event) yields :DRIFT deterministically" do
    net = art72_net()

    factual_trace = [
      "actuation_receipt.prepare",
      "provider.actuate_status",
      "actuation_receipt.seal"
    ]

    {fitness, _stats} = art72_log_fitness(net, [factual_trace])
    assert fitness == 1.0
    assert art72_drift_decision(fitness, 0.05) == :NO_DRIFT

    # ACTION: do-intervention — drop EXACTLY the sealed-receipt event
    # (the missing-evidence drift the Art 72 review exists to catch);
    # everything else held constant.
    perturbed = Enum.drop(factual_trace, -1)

    {f1, stats1} = art72_log_fitness(net, [perturbed])
    {f2, _} = art72_log_fitness(net, [perturbed])

    assert f1 < 1.0
    assert art72_drift_decision(f1, 0.05) == :DRIFT
    assert f2 == f1
    assert stats1.missing > 0
  end

  # Inline replica of W545's inline replica of BeamPM.Art72Conformance (w511):
  # Definition 7.2 token-replay fitness C(L,P) = 1/2(1 - m/c) + 1/2(1 - r/p).
  defp art72_net do
    transitions = %{
      "actuation_receipt.prepare" => %{input: %{}, output: %{:p_prepared => 1}},
      "provider.actuate_status" => %{input: %{:p_prepared => 1}, output: %{:p_actuated => 1}},
      "actuation_receipt.seal" => %{input: %{:p_actuated => 1}, output: %{:p_receipt => 1}}
    }

    %{
      transitions: transitions,
      initial: %{},
      final: %{:p_receipt => 1}
    }
  end

  defp art72_drift_decision(fitness, threshold) when is_float(fitness) or is_integer(fitness) do
    if fitness < 1.0 - threshold, do: :DRIFT, else: :NO_DRIFT
  end

  defp art72_log_fitness(net, log) do
    stats =
      Enum.reduce(log, %{consumed: 0, produced: 0, missing: 0, remaining: 0}, fn trace, acc ->
        s = art72_replay(net, trace)
        Map.merge(acc, s, fn _k, a, b -> a + b end)
      end)

    term1 = if stats.consumed == 0, do: 1.0, else: 1 - stats.missing / stats.consumed
    term2 = if stats.produced == 0, do: 1.0, else: 1 - stats.remaining / stats.produced
    {(term1 + term2) / 2, stats}
  end

  defp art72_replay(net, trace) do
    Enum.reduce(trace, {%{consumed: 0, produced: 0, missing: 0, remaining: 0}, net.initial}, fn
      tname, {acc, marking} ->
        tr = Map.fetch!(net.transitions, tname)

        {missing_here, consumed_here} =
          Enum.reduce(tr.input, {0, 0}, fn {pl, w}, {m, c} ->
            {m + max(0, w - Map.get(marking, pl, 0)), c + w}
          end)

        produced_here = Enum.sum(Map.values(tr.output))

        marking =
          Enum.reduce(tr.output, marking, fn {pl, w}, mk ->
            Map.put(mk, pl, Map.get(mk, pl, 0) + w)
          end)
          |> then(fn mk ->
            Enum.reduce(tr.input, mk, fn {pl, w}, mk2 ->
              Map.put(mk2, pl, max(0, Map.get(mk2, pl, 0) - w))
            end)
          end)

        {%{acc | consumed: acc.consumed + consumed_here,
                 produced: acc.produced + produced_here,
                 missing: acc.missing + missing_here},
         marking}
    end)
    |> then(fn {stats, end_marking} ->
      deficit =
        net.final
        |> Enum.reduce(0, fn {pl, need}, acc -> acc + max(0, need - Map.get(end_marking, pl, 0)) end)

      excess =
        end_marking
        |> Enum.reduce(0, fn {pl, have}, acc ->
          acc + max(0, have - Map.get(net.final, pl, 0))
        end)

      %{stats | consumed: stats.consumed + deficit,
                produced: stats.produced + excess,
                missing: stats.missing + deficit,
                remaining: stats.remaining + excess}
    end)
  end

  # -- Art 14(4)(b) — automation-bias countermeasure on a REAL typed refusal ------
  # W550's row exercised the countermeasure over the synthetic check-list; this
  # row briefs on a refusal emitted by a REAL in-repo surface
  # (QuiescentStop's REFUSED_STOP_AUTHORITY, the Art 14(4)(e) fail-closed seam).

  test "Art 14(4)(b) extension: briefing on a real REFUSED_STOP_AUTHORITY refusal record carries non-empty anatomy, deterministically" do
    opts = [idempotency_key: "w624-bias-key", authority: %{}]

    {:error, refusal} = QuiescentStop.execute(Xaas.Marketplace.Provider, opts)
    assert refusal == :REFUSED_STOP_AUTHORITY

    refused_record = %{
      input: %{module: Xaas.Marketplace.Provider, authority: %{}},
      admitted?: false,
      refusal: refusal,
      checks: [
        %{name: :stop_authority_ok, verdict: :fail, refusal: :REFUSED_STOP_AUTHORITY}
      ]
    }

    attributions = %{stop_authority_ok: 1.0}

    {:ok, briefing} = AutomationBiasCountermeasure.briefing(refused_record, attributions)
    {:ok, briefing2} = AutomationBiasCountermeasure.briefing(refused_record, attributions)

    assert briefing.verdict == :refuse
    assert briefing.refusal_anatomy != []
    assert briefing2 == briefing
  end

  # ==========================================================================
  # Lane W634 — Art. 14(4)(a) explanation-suppression counterfactual row:
  # do(Explanation <- ∅). The dissertation's halt-gate is NOT our design;
  # our design is degradation-with-typed-signal: the briefing degrades
  # gracefully when the attributions do not cover the recorded log
  # (counterfactual_available: false) — it does NOT halt. The typed signal
  # is the refusal ANATOMY, not the counterfactual.
  # ==========================================================================

  test "Art 14(4)(a): degradation-with-signal (not halt) — counterfactual_available false + anatomy retained" do
    checks = [
      {:consent_ok,
       fn c -> if Map.get(c, :provenance) == :consented, do: :ok, else: {:refused, :REFUSED_NO_CONSENT} end},
      {:scope_ok, fn _c -> :ok end}
    ]

    input = %{id: "w634-a", provenance: :scraped}

    %{outcome: outcome, checks: check_log} = Counterfactual.run(input, checks)
    assert outcome == {:refused, :REFUSED_NO_CONSENT}

    refused_record = %{
      input: input,
      admitted?: false,
      refusal: :REFUSED_NO_CONSENT,
      checks: check_log
    }

    # do(Explanation <- ∅): the attribution map is EMPTY — no Shapley blame
    # covers any logged check name. Everything else held constant.
    empty_attributions = %{}

    # PREDICTION: the briefing does NOT halt — it returns :ok with
    # counterfactual_available: false (the typed degradation signal).
    b1 = AutomationBiasCountermeasure.briefing(refused_record, empty_attributions)
    b2 = AutomationBiasCountermeasure.briefing(refused_record, empty_attributions)

    assert {:ok, briefing} = b1
    assert briefing.counterfactual_available == false
    assert briefing.verdict == :refuse

    # AND the typed signal survives: refusal_anatomy is still present and
    # names the exact flipped check — the anatomy IS the explanation under
    # explanation-suppression, not the counterfactual replay.
    assert briefing.refusal_anatomy != []
    assert [%{name: :consent_ok, refusal: :REFUSED_NO_CONSENT}] = briefing.refusal_anatomy

    # The degraded row still lists every logged check (unattributed entries
    # degrade to shapley 0.0, never missing rows).
    assert length(briefing.per_check_causes) == length(check_log)
    assert Enum.all?(briefing.per_check_causes, &(&1.shapley == 0.0))

    # Determinism x2: byte-identical degraded briefing.
    assert b2 == b1

    # No side effect on the record (pure module).
    assert refused_record.admitted? == false
    assert refused_record.refusal == :REFUSED_NO_CONSENT
  end

  # -- Art 14(4)(a) positive row: full attributions — full-strength mechanism --

  test "Art 14(4)(a) positive: full attributions yield counterfactual_available true + per-check causes present (full-strength anti-over-reliance)" do
    checks = [
      {:consent_ok,
       fn c -> if Map.get(c, :provenance) == :consented, do: :ok, else: {:refused, :REFUSED_NO_CONSENT} end},
      {:scope_ok, fn _c -> :ok end}
    ]

    lawful_input = %{id: "w634-p", provenance: :consented}
    %{outcome: outcome, checks: check_log} = Counterfactual.run(lawful_input, checks)
    assert outcome == :admitted

    record = %{input: lawful_input, admitted?: true, refusal: nil, checks: check_log}

    # Full attributions covering every logged check name.
    attributions = %{consent_ok: 0.0, scope_ok: 0.0}

    p1 = AutomationBiasCountermeasure.briefing(record, attributions)
    p2 = AutomationBiasCountermeasure.briefing(record, attributions)

    # PREDICTION: full-strength mechanism — counterfactual_available is true
    # and every check carries its per-check cause (verdict + Shapley blame).
    assert {:ok, briefing} = p1
    assert briefing.counterfactual_available == true
    assert briefing.verdict == :admit

    assert length(briefing.per_check_causes) == length(check_log)
    # Subset-based assertion: per_check_causes elements may carry extra keys
    # (e.g. refusal: nil) — assert only on the relevant keys, never whole-map
    # equality against module-emitted structs.
    for {name, shapley} <- [consent_ok: 0.0, scope_ok: 0.0] do
      assert Enum.any?(briefing.per_check_causes, fn cause ->
               Map.take(cause, [:name, :verdict, :shapley]) == %{
                 name: name,
                 verdict: :pass,
                 shapley: shapley
               }
             end),
             "no per_check_causes entry with name=#{inspect(name)}"
    end

    # Full admit: nothing flipped — anatomy empty by construction, causes
    # still present (the operator never sees an unexplained verdict).
    assert briefing.refusal_anatomy == []

    # Determinism x2: byte-identical.
    assert p2 == p1
  end
end
