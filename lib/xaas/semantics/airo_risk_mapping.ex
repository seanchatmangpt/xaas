defmodule Xaas.Semantics.AiroRiskMapping do
  @moduledoc """
  Maps the fleet's typed refusal surfaces (the refusal ledger) onto the
  AIRo (AI Risk Ontology, https://w3id.org/airo) risk vocabulary.

  `risk_graph/0` emits deterministic, sorted Turtle describing:
  - one `airo:RiskSource` + `airo:Hazard` node per ledger refusal variant,
  - one `airo:RiskControl` per enforcing module (the w532-verified seams),
    with `airo:detectsRiskConcept` / `airo:mitigatesRiskConcept` edges,
  - the `airo:AISystem` node with `airo:hasRisk` edges, and the
    `airo:AIDeployer` node.

  Source of truth:
    docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json
  """

  @ledger_relpath "docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json"

  # EUAIA family (W657): Art. 5 prohibited-practice atoms and their
  # dissertation-partition risk concepts. Mirrors the EUAIA clauses of
  # `risk_concept_for/1`.
  @euaia_atoms [
    {"REFUSED_EUAIA_MANIPULATIVE", "RISK_TO_INFORMED_CHOICE"},
    {"REFUSED_EUAIA_VULNERABILITY_EXPLOIT", "RISK_TO_VULNERABLE_PERSONS"},
    {"REFUSED_EUAIA_SOCIAL_SCORING", "CROSS_CONTEXT_RISK"},
    {"REFUSED_EUAIA_PREDICTIVE_POLICING", "DUE_PROCESS_RISK"},
    {"REFUSED_EUAIA_FACIAL_SCRAPING", "PRIVACY_RISK"},
    {"REFUSED_EUAIA_EMOTION_RECOGNITION", "MENTAL_PRIVACY_RISK"},
    {"REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION", "DISCRIMINATION_RISK"},
    {"REFUSED_EUAIA_REALTIME_RBI", "SURVEILLANCE_RISK"}
  ]

  @airo "https://w3id.org/airo#"
  @ex "https://xaas.example/ontology/v26.10.6#"

  @doc "Absolute path of the source refusal ledger."
  @spec ledger_path() :: String.t()
  def ledger_path do
    repo_root = Path.expand("../../..", __DIR__)
    Path.join(repo_root, @ledger_relpath)
  end

  @doc "Load and JSON-parse the refusal ledger (real file, real parse)."
  @spec load_ledger() :: map()
  def load_ledger do
    ledger_path()
    |> File.read!()
    |> Jason.decode!()
  end

  @doc """
  Ledger refusal variants, sorted by variant name.
  Each element: %{variant:, sites:, fixture:, refused?:}
  """
  @spec variants() :: [map()]
  def variants do
    ledger = load_ledger()

    ledger["variants"]
    |> Enum.map(fn v ->
      %{
        variant: v["variant"] || "UNKNOWN_VARIANT",
        sites: v["sites"] || [],
        fixture: v["fixture"],
        refused?: String.starts_with?(v["variant"] || "", "REFUSED_")
      }
    end)
    |> Enum.sort_by(& &1.variant)
  end

  @doc """
  Enforcing modules (w532-verified seams) as RiskControl descriptors.
  Each: %{module:, path:, detects:, mitigates:, scope:}
  """
  @spec risk_controls() :: [map()]
  def risk_controls do
    [
      %{
        module: "Xaas.Semantics.EuAiActAdmission",
        path: "lib/xaas/semantics/eu_ai_act_admission.ex",
        detects: ["UNADMITTED_SEMANTIC_ADMISSION"],
        mitigates: ["UNADMITTED_SEMANTIC_ADMISSION"],
        scope: "EU AI Act admission kernel (zero-unrepresentability refusal engine)"
      },
      %{
        module: "Xaas.Semantics.DatasetAdmission",
        path: "lib/xaas/semantics/dataset_admission.ex",
        detects: ["TRAINING_DATA_QUALITY_DRIFT", "BIASED_OR_UNREPRESENTATIVE_DATA"],
        mitigates: ["TRAINING_DATA_QUALITY_DRIFT", "BIASED_OR_UNREPRESENTATIVE_DATA"],
        scope: "dataset admission gates (Art. 10 data governance)"
      },
      %{
        module: "Xaas.Semantics.RobustMargin",
        path: "lib/xaas/semantics/robust_margin.ex",
        detects: ["ROBUSTNESS_MARGIN_EXHAUSTION"],
        mitigates: ["ROBUSTNESS_MARGIN_EXHAUSTION"],
        scope: "robustness margin gates (Art. 15 accuracy/robustness)"
      },
      %{
        module: "Xaas.Witness.AuditChain",
        path: "lib/xaas/witness/audit_chain.ex",
        detects: ["AUDIT_TRAIL_BREAK", "RECEIPT_REPLAY_FAILURE"],
        mitigates: ["AUDIT_TRAIL_BREAK"],
        scope: "certified-receipt audit chain (Art. 12 logging)"
      },
      %{
        module: "Xaas.Actuation.QuiescentStop",
        path: "lib/xaas/actuation/quiescent_stop.ex",
        detects: ["UNCONTROLLED_ACTUATION"],
        mitigates: ["UNCONTROLLED_ACTUATION"],
        scope: "quiescent stop fallback (Art. 14 human oversight stop button)"
      },
      %{
        module: "Xaas.Semantics.VulnerabilityLifecycle",
        path: "lib/xaas/semantics/vulnerability_lifecycle.ex",
        detects: ["UNPATCHED_VULNERABILITY", "CYBERATTACK_EXPOSURE"],
        mitigates: ["UNPATCHED_VULNERABILITY"],
        scope: "vulnerability lifecycle (Art. 15 cybersecurity)"
      },
      %{
        module: "Xaas.Castle",
        path: "lib/xaas/castle.ex",
        detects: ["UNRECEIPTED_ACTUATION", "CASTLE_AUTHORITY_ESCAPE"],
        mitigates: ["UNRECEIPTED_ACTUATION", "CASTLE_AUTHORITY_ESCAPE"],
        scope: "castle gates: admission/kernel/receipt authority boundary"
      },
      %{
        module: "XaasWeb.Plugs.RequireInternalApiToken",
        path: "lib/xaas_web/plugs/require_internal_api_token.ex",
        detects: ["UNAUTHENTICATED_API_ACCESS"],
        mitigates: ["UNAUTHENTICATED_API_ACCESS"],
        scope: "API token floor (fail-closed auth floor before content negotiation)"
      },
      %{
        module: "Xaas.Marketplace.Changes.ApplyProviderStatusChange",
        path: "lib/xaas/marketplace/changes/apply_provider_status_change.ex",
        detects: ["UNRECEIPTED_PROVIDER_STATUS_TRANSITION"],
        mitigates: ["UNRECEIPTED_PROVIDER_STATUS_TRANSITION"],
        scope:
          "provider lifecycle maker-checker bridge (approved status changes route through receipted Xaas.Actuation.run/4)"
      },
      %{
        module: "Xaas.Library.Changes.EnforceBorrowCap",
        path: "lib/xaas/library/changes/enforce_borrow_cap.ex",
        detects: ["UNRECEIPTED_OVER_CAP_LENDING"],
        mitigates: ["UNRECEIPTED_OVER_CAP_LENDING"],
        scope:
          "library circulation borrow cap (typed refusal when a patron exceeds the open-checkout limit; guards both the borrow path and the hold-fulfillment hand-off)"
      }
    ]
    |> Enum.sort_by(& &1.module)
  end

  @doc """
  Family -> AIRo risk-concept mapping for one refusal variant name.
  Deterministic function of the variant string.
  """
  @spec risk_concept_for(String.t()) :: String.t()
  def risk_concept_for(variant) do
    cond do
      # EUAIA family (W657): Art. 5 prohibited-practice atoms, each mapped to
      # its own dissertation-partition risk concept.
      String.contains?(variant, "EUAIA_MANIPULATIVE") ->
        "RISK_TO_INFORMED_CHOICE"

      String.contains?(variant, "EUAIA_VULNERABILITY_EXPLOIT") ->
        "RISK_TO_VULNERABLE_PERSONS"

      String.contains?(variant, "EUAIA_SOCIAL_SCORING") ->
        "CROSS_CONTEXT_RISK"

      String.contains?(variant, "EUAIA_PREDICTIVE_POLICING") ->
        "DUE_PROCESS_RISK"

      String.contains?(variant, "EUAIA_FACIAL_SCRAPING") ->
        "PRIVACY_RISK"

      String.contains?(variant, "EUAIA_EMOTION_RECOGNITION") ->
        "MENTAL_PRIVACY_RISK"

      String.contains?(variant, "EUAIA_BIOMETRIC_CATEGORIZATION") ->
        "DISCRIMINATION_RISK"

      String.contains?(variant, "EUAIA_REALTIME_RBI") ->
        "SURVEILLANCE_RISK"

      String.contains?(variant, "MALFORMED") ->
        "MALFORMED_INPUT_CANDIDATE"

      String.contains?(variant, "AUTHORITY") or String.contains?(variant, "AMBIENT") ->
        "AUTHORITY_ESCAPE"

      String.contains?(variant, "CASTLE") and String.contains?(variant, "IDENTITY") ->
        "IDENTITY_SPOOFING"

      String.contains?(variant, "DIGEST") or String.contains?(variant, "HASH") ->
        "RECEIPT_DIGEST_MISMATCH"

      String.contains?(variant, "RECEIPT") or String.contains?(variant, "AUDIT") ->
        "RECEIPT_INTEGRITY_FAILURE"

      String.contains?(variant, "PROJECTION") or String.contains?(variant, "SEMANTIC") ->
        "SEMANTIC_PROJECTION_DRIFT"

      String.contains?(variant, "VKG") ->
        "KNOWLEDGE_GRAPH_SURFACE_EXPOSURE"

      String.contains?(variant, "CHECKPOINT") ->
        "CHECKPOINT_STATE_CORRUPTION"

      String.contains?(variant, "EVIDENCE") ->
        "EVIDENCE_INTEGRITY_FAILURE"

      String.contains?(variant, "ADAPTER") or String.contains?(variant, "PROFILE") ->
        "ADAPTER_PROFILE_DRIFT"

      String.contains?(variant, "TOKEN") or String.contains?(variant, "IDEMPOTENCY") ->
        "REPLAY_OR_IDEMPOTENCY_FAILURE"

      String.contains?(variant, "BUDGET") or String.contains?(variant, "CAPACITY") ->
        "RESOURCE_EXHAUSTION"

      String.contains?(variant, "CHICAGO") or String.contains?(variant, "JSON") ->
        "PROTOCOL_SHAPE_MISMATCH"

      String.contains?(variant, "EXECUTION") or String.contains?(variant, "INTENT") ->
        "UNADMITTED_EXECUTION_INTENT"

      true ->
        "UNADMITTED_TRANSITION"
    end
  end

  @doc "Full deterministic AIRo risk graph as Turtle text."
  @spec risk_graph() :: String.t()
  def risk_graph do
    vs = variants()
    controls = risk_controls()

    header = [
      "@prefix airo: <#{@airo}> .\n",
      "@prefix ex: <#{@ex}> .\n",
      "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .\n",
      "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n",
      "\n"
    ]

    risk_nodes =
      vs
      |> Enum.map(fn v ->
        concept = risk_concept_for(v.variant)
        local = safe_local(v.variant)

        [
          "ex:riskSource-#{local} a airo:RiskSource, airo:Hazard ;\n",
          "  rdfs:label \"#{v.variant}\" ;\n",
          "  airo:isRiskSourceFor ex:xaas-system ;\n",
          "  ex:enforcingModule \"#{module_for_variant(v.sites)}\"^^xsd:string ;\n",
          "  ex:refusalVariant \"#{v.variant}\"^^xsd:string ;\n",
          "  ex:refusedType \"#{if v.refused?, do: "REFUSED", else: "BLOCKED"}\"^^xsd:string ;\n",
          "  ex:mapsToRiskConcept ex:#{concept} .\n\n"
        ]
      end)

    # Dedupe by RDF subject (W984ce, fixing the W984bj pinned defect): a
    # EUAIA atom that is also a ledger variant would otherwise emit a second
    # riskSource node + hasRisk edge under the same subject. The ledger
    # emission is the superset (it carries `ex:enforcingModule`); the atom
    # emission is merged by skipping it when the ledger already covered that
    # subject, so each RDF subject appears exactly once.
    ledger_locals = MapSet.new(vs, &safe_local(&1.variant))

    euaia_nodes =
      @euaia_atoms
      |> Enum.reject(fn {atom_string, _concept} ->
        MapSet.member?(ledger_locals, safe_local(atom_string))
      end)
      |> Enum.map(fn {atom_string, concept} ->
        local = safe_local(atom_string)

        [
          "ex:riskSource-#{local} a airo:RiskSource, airo:Hazard ;\n",
          "  rdfs:label \"#{atom_string}\" ;\n",
          "  airo:isRiskSourceFor ex:xaas-system ;\n",
          "  ex:refusalVariant \"#{atom_string}\"^^xsd:string ;\n",
          "  ex:refusedType \"REFUSED\"^^xsd:string ;\n",
          "  ex:mapsToRiskConcept ex:#{concept} .\n\n"
        ]
      end)

    control_nodes =
      controls
      |> Enum.map(fn c ->
        detects = Enum.map(c.detects, &"ex:#{&1}")
        mitigates = Enum.map(c.mitigates, &"ex:#{&1}")

        [
          "ex:riskControl-#{safe_local(c.module)} a airo:RiskControl ;\n",
          "  rdfs:label \"#{c.module}\" ;\n",
          "  ex:modulePath \"#{c.path}\" ;\n",
          "  ex:scope \"#{c.scope}\" ;\n",
          "  airo:detectsRiskConcept #{Enum.join(detects, ", ")} ;\n",
          "  airo:mitigatesRiskConcept #{Enum.join(mitigates, ", ")} ;\n",
          "  airo:isRiskControlFor ex:xaas-system .\n\n"
        ]
      end)

    risk_edges =
      (Enum.map(vs, &{:variant, &1.variant}) ++
         Enum.map(@euaia_atoms, &{:euaia, elem(&1, 0)}))
      |> Enum.reject(fn
        # dedupe by subject: ledger variant already emitted this edge
        {:euaia, atom_string} ->
          MapSet.member?(ledger_locals, safe_local(atom_string))

        _ ->
          false
      end)
      |> Enum.map(fn
        {:euaia, atom_string} ->
          "ex:xaas-system airo:hasRisk ex:riskSource-#{safe_local(atom_string)} .\n"

        {_, variant} ->
          "ex:xaas-system airo:hasRisk ex:riskSource-#{safe_local(variant)} .\n"
      end)

    system_block = [
      "ex:xaas-system a airo:AISystem ;\n",
      "  rdfs:label \"Xaas semantic actuation platform\" ;\n",
      "  airo:isDeployedBy ex:xaas-deployer ;\n",
      "  airo:hasRiskControl ",
      controls |> Enum.map(&"ex:riskControl-#{safe_local(&1.module)}") |> Enum.join(", "),
      " .\n\n",
      "ex:xaas-deployer a airo:AIDeployer ;\n",
      "  rdfs:label \"Xaas platform deployer\" .\n"
    ]

    IO.iodata_to_binary([header, risk_nodes, euaia_nodes, control_nodes, risk_edges, system_block])
  end

  defp module_for_variant(sites) do
    case sites do
      [site | _] -> site
      [] -> "unknown"
    end
  end

  defp safe_local(name) do
    name
    |> String.replace(~r/[^A-Za-z0-9_.-]/, "_")
    |> String.replace_prefix("", "")
  end
end
