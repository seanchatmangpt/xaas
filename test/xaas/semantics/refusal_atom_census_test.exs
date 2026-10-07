defmodule Xaas.Semantics.RefusalAtomCensusTest do
  @moduledoc """
  W713 — refusal-atom closure census (Chicago-style: real File.read! source
  scans + real module calls, no mocks).

  Refusal atoms are contract. For each semantics module that returns typed
  refusals, this court:

    (a) source-scans the module file (real `File.read!`) for every literal
        `:REFUSED_*` atom occurrence;
    (b) asserts every scanned atom belongs to that module's declared/closed
        set (its own `refusal_atoms/0` accessor or its `@type`/@spec
        vocabulary);
    (c) asserts cross-module AIRo mapping totality via
        `Xaas.Semantics.AiroRiskMapping.risk_concept_for/1`: every declared
        atom maps to a real (non-sentinel) risk concept.

  Any atom failing the census is a typed finding to be reported — the test
  never invents a set to make the scan pass.
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.AiroRiskMapping
  alias Xaas.Semantics.AuthorityChannel
  alias Xaas.Semantics.DatasetAdmission
  alias Xaas.Semantics.DeclaredMetrics
  alias Xaas.Semantics.EuAiActAdmission
  alias Xaas.Semantics.IncidentReport
  alias Xaas.Semantics.RobustMargin
  alias Xaas.Semantics.VulnerabilityLifecycle

  repo_root = Path.expand("../../..", __DIR__)

  # Declared (closed) refusal vocabularies, transcribed from each module's
  # own @type / @spec / accessor — NOT from the scan. Each entry names its
  # source of truth.
  @census [
    {EuAiActAdmission, "lib/xaas/semantics/eu_ai_act_admission.ex",
     [
       # via refusal_atoms/0 — the eight Art. 5(1) atoms plus the
       # REFUSED_EUAIA_MALFORMED_CANDIDATE fallback verdict (W732 closure
       # repair of the W713 typed finding; previously emitted at line 116
       # without any declared surface).
       :REFUSED_EUAIA_MANIPULATIVE,
       :REFUSED_EUAIA_VULNERABILITY_EXPLOIT,
       :REFUSED_EUAIA_SOCIAL_SCORING,
       :REFUSED_EUAIA_PREDICTIVE_POLICING,
       :REFUSED_EUAIA_FACIAL_SCRAPING,
       :REFUSED_EUAIA_EMOTION_RECOGNITION,
       :REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION,
       :REFUSED_EUAIA_REALTIME_RBI,
       :REFUSED_EUAIA_MALFORMED_CANDIDATE
     ], []},
    {DatasetAdmission, "lib/xaas/semantics/dataset_admission.ex",
     [
       # via @spec admit/2 result type (lines 55-58)
       :REFUSED_EMPTY_DATASET,
       :REFUSED_INCOMPLETE_DATASET,
       :REFUSED_BIAS_THRESHOLD,
       :REFUSED_ARITHMETIC_OVERFLOW
     ], []},
    {RobustMargin, "lib/xaas/semantics/robust_margin.ex",
     [
       # via @spec estimate_lipschitz/2 and admit/4 result types
       :REFUSED_NO_CALIBRATION_DATA,
       :REFUSED_ROBUST_MARGIN,
       :REFUSED_ARITHMETIC_OVERFLOW,
       :REFUSED_MALFORMED_MARGIN_INPUT
     ], []},
    {IncidentReport, "lib/xaas/semantics/incident_report.ex",
     [
       # via @spec build/2 result type (line 69)
       :REFUSED_NO_INCIDENT_EVIDENCE
     ],
     # IncidentReport additionally classifies receipts carrying any
     # REFUSED_EUAIA_* atom, delegated from EuAiActAdmission's closed set
     # (@euaia_refusal_strings) — allow that prefix.
     ["REFUSED_EUAIA_"]},
    {AuthorityChannel, "lib/xaas/semantics/authority_channel.ex",
     [
       # via @type refusal (lines 71-73)
       :REFUSED_UNKNOWN_CHANNEL,
       :REFUSED_NO_INCIDENT_EVIDENCE
     ], []},
    {VulnerabilityLifecycle, "lib/xaas/semantics/vulnerability_lifecycle.ex",
     [
       # via @type refusal (line 52)
       :REFUSED_LIFECYCLE_SKIP,
       :REFUSED_LIFECYCLE_EVIDENCE,
       # via @spec new/1 return type (lines 67-68); present in @spec but not
       # in @type refusal — @type/@spec divergence noted in the W713 receipt
       :REFUSED_NO_DETECTION_RECORD
     ], []},
    {DeclaredMetrics, "lib/xaas/semantics/declared_metrics.ex",
     [
       # via @typed_refusal module attribute (line 16)
       :REFUSED_METRICS_SOURCE_MISSING
     ], []}
  ]

  @refusal_atom_regex ~r/:REFUSED_[A-Z0-9_]+/

  defp repo_root, do: unquote(Macro.escape(repo_root))

  defp scan_source(path) do
    path
    |> then(&Path.join(repo_root(), &1))
    |> File.read!()
    |> then(&Regex.scan(@refusal_atom_regex, &1))
    |> Enum.map(&List.first/1)
    |> Enum.map(&String.trim_leading(&1, ":"))
    |> Enum.map(&String.to_atom/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp declared_set(module, atoms, prefixes) do
    base = MapSet.new(atoms)

    extras =
      Enum.flat_map(prefixes, fn prefix ->
        # Only atoms actually declared by the delegating source (the EUAIA
        # accessor) may satisfy a prefix, never arbitrary atoms.
        Enum.filter(EuAiActAdmission.refusal_atoms(), fn a ->
          String.starts_with?(Atom.to_string(a), prefix)
        end)
      end)

    MapSet.union(base, MapSet.new(extras))
  end

  describe "(a)+(b) per-module source census against declared sets" do
    test "every literal :REFUSED_* atom in each module belongs to its declared set" do
      violations =
        for {module, path, declared, prefixes} <- @census,
            scanned = scan_source(path),
            allowed = declared_set(module, declared, prefixes),
            undeclared = scanned -- MapSet.to_list(allowed),
            undeclared != [] do
          {module, path, undeclared}
        end

      assert violations == [],
             "modules emit literal refusal atom(s) outside their declared sets:\n" <>
               Enum.map_join(violations, "\n", fn {m, p, atoms} ->
                 "  #{inspect(m)} (#{p}): #{inspect(atoms)}" <>
                   " (typed finding: extend the @type/@spec vocabulary or the emitter)"
               end)
    end

    test "census scanner is non-vacuous — every module actually scans to atoms" do
      for {_module, path, _declared, _prefixes} <- @census do
        scanned = scan_source(path)
        assert scanned != [], "census scan of #{path} found no :REFUSED_* atoms (vacuous court)"
      end
    end

    test "declared sets equal the documented sizes" do
      assert length(EuAiActAdmission.refusal_atoms()) == 9
      assert length(@census) == 7
    end
  end

  describe "(c) AIRo risk-concept mapping totality" do
    test "every declared EUAIA atom maps to a real (non-sentinel) risk concept" do
      bogus = "REFUSED_TOTALLY_BOGUS_ATOM"

      for atom <- EuAiActAdmission.refusal_atoms() do
        concept = AiroRiskMapping.risk_concept_for(Atom.to_string(atom))

        refute concept == bogus,
               "#{inspect(atom)} maps to sentinel concept #{inspect(concept)}"

        refute concept == "",
               "#{inspect(atom)} maps to an empty/non-string concept"

        # each Art. 5(1) atom has its own dissertation-partition concept,
        # not a shared fallback
        assert concept != "UNADMITTED_TRANSITION",
               "#{inspect(atom)} falls through to the generic UNADMITTED_TRANSITION bucket"
      end
    end

    test "every scanned refusal atom across all censused modules maps to a real concept" do
      bogus = "REFUSED_TOTALLY_BOGUS_ATOM"

      for {module, path, _declared, _prefixes} <- @census do
        for atom <- scan_source(path) do
          concept = AiroRiskMapping.risk_concept_for(Atom.to_string(atom))

          refute concept == bogus,
               "#{inspect(module)}: #{inspect(atom)} maps to sentinel #{inspect(concept)}"

          refute concept == "",
               "#{inspect(module)}: #{inspect(atom)} maps to empty/non-string concept"
        end
      end
    end

    test "AIRo mapping is a deterministic total function (repeat call is stable)" do
      atoms = EuAiActAdmission.refusal_atoms()

      first = Enum.map(atoms, &AiroRiskMapping.risk_concept_for(Atom.to_string(&1)))
      second = Enum.map(atoms, &AiroRiskMapping.risk_concept_for(Atom.to_string(&1)))

      assert first == second
      assert Enum.uniq(first) |> length() == 9
    end
  end
end
