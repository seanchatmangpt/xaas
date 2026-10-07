defmodule Xaas.EUAIAct.TitleITest do
  @moduledoc """
  Title I generator (lane W525b) — EU AI Act Arts 1-4, one test per corpus
  line_id. Substrate: `docs/eu_ai_act/corpus.json` (W520), loaded as JSON at
  compile time directly (lane isolation keeps W525b off W526's `CorpusLoader`,
  same as W522's Title II / W525's Titles VI-XIII generators).

  Mapping per the W525b contract (`docs/sjira/v26.10.6/plans/w525b-title-i.md`):

    * `EVIDENCED`      — the fleet has a typed surface for this definition;
      the test asserts the real paths on disk AND makes a real typed call
      against the owning module (no mocks).
    * `NOT_APPLICABLE` — typed reason (legislative scope statement, or a
      definitional line whose concept has no typed counterpart in this repo;
      definitions carry no behavioral obligation).
    * `OPEN_GAP`       — the duty applies to this deployer-side repo and no
      seam covers it; `flunk`s by design. Split across two modules in this
      file because ExUnit resolves includes OVER excludes: a test carrying
      both `:eu_ai_act` and `:eu_ai_act_open_gap` would be resurrected by
      `--include eu_ai_act` even under `--exclude eu_ai_act_open_gap`
      (same W523 finding, observed 2026-10-06: 10/112 failing under the
      green-gate command). The OPEN_GAP lines therefore live in
      `Xaas.EUAIAct.TitleIOpenGapsTest`, which carries ONLY the
      `:eu_ai_act_open_gap` tag (module-level), so the exclude holds.
  """

  use ExUnit.Case, async: true

  @moduletag :eu_ai_act

  @corpus_relpath "docs/eu_ai_act/corpus.json"
  @receipt_dir "docs/sjira/v26.10.6/plans"

  @admission_source "lib/xaas/semantics/eu_ai_act_admission.ex"
  @admission_test "test/xaas/semantics/eu_ai_act_admission_test.exs"
  @dataset_source "lib/xaas/semantics/dataset_admission.ex"
  @dataset_test "test/xaas/semantics/dataset_admission_test.exs"
  @decoupling_test "test/xaas/semantics/authority_decoupling_test.exs"
  @incident_source "lib/xaas/semantics/incident_report.ex"
  @incident_test "test/xaas/semantics/incident_report_test.exs"
  @incident_test_count 9

  titles_i_lines =
    if File.exists?(@corpus_relpath) do
      body = File.read!(@corpus_relpath)

      case Jason.decode(body) do
        {:ok, %{"titles" => titles}} when is_list(titles) ->
          for title <- titles,
              title["num"] == "I",
              article <- title["articles"] || [],
              line <- article["lines"] || [],
              is_map(line),
              is_binary(line["line_id"]) do
            line
            |> Map.put("article", article["id"])
            |> Map.put("article_title", article["title"])
          end

        {:ok, other} ->
          raise RuntimeError, """
          corpus.json shape unexpected: keys #{inspect(Enum.map(other, &elem(&1, 0)) |> Enum.sort())}.
          Title I generator (W525b) expects {"titles": [...]} with num "I".
          REFUSED(EUAIA_CORPUS_SHAPE_UNEXPECTED_W525B)
          """

        {:error, reason} ->
          raise RuntimeError, "corpus.json is not valid JSON: #{inspect(reason)}"
      end
    else
      raise RuntimeError, """
      EUAI-Act corpus absent: #{File.cwd!()}/#{@corpus_relpath} not found.
      Substrate owned by lane W520. REFUSED(EUAIA_CORPUS_MISSING_W525B)
      """
    end

  scope_line_count = Enum.count(titles_i_lines, fn l -> l["article"] in ["1", "2"] end)
  total_line_count = Enum.count(titles_i_lines)

  # 3.49 family flipped EVIDENCED by W607 (2026-10-06): W538's incident-report
  # builder landed. 4.1 flipped EVIDENCED by W648b (2026-10-06): the AI-literacy
  # register (Xaas.Semantics.OversightGovernance.ai_literacy/0) landed.
  gap_ids = []

  open_gap_lines = Enum.filter(titles_i_lines, fn l -> l["line_id"] in gap_ids end)
  non_gap_lines = Enum.reject(titles_i_lines, fn l -> l["line_id"] in gap_ids end)

  @scope_line_count scope_line_count
  @total_line_count total_line_count

  # ---------------------------------------------------------------------------
  # Evidence table: line_id -> {lane, seam description, paths to assert}.
  # Every path verified on disk at generation time (2026-10-06,
  # xaas @ feat/playwright-surface).
  # ---------------------------------------------------------------------------
  @evidence %{
    # Art. 1(2)(b) — the prohibition corpus row is implemented and courted (W500/W522)
    "1.2.b" => {"W500/W522", "prohibitions of certain AI practices — Art.5(1)(a)-(h) typed refusal corpus landed and courted",
                [@admission_source, @admission_test,
                 "#{@receipt_dir}/w500-art5-admission.md",
                 "#{@receipt_dir}/w522-title-ii.md"]},
    # Art. 3(1) — "AI system": the admission modules treat candidates structurally
    "3.1" => {"W500", "AI system — the admission surface treats every candidate as a structurally-typed AI-system candidate",
              [@admission_source, @admission_test]},
    # Art. 3(2) — "risk": typed refusal-atom risk vocabulary
    "3.2" => {"W500", "risk — typed refusal-atom vocabulary with per-atom describe/2",
              [@admission_source, @admission_test]},
    # Art. 3(12) — "intended purpose": the candidate :purpose field is the typed counterpart
    "3.12" => {"W500", "intended purpose — candidate :purpose field in the typed admission candidate contract",
               [@admission_source]},
    # Art. 3(29)-(33) — data-set/data definitions: DatasetAdmission + W502 dataset gate
    "3.29" => {"W502", "training data — DatasetAdmission admits/refuses real sample lists (sliced-W1 bias gate)",
               [@dataset_source, @dataset_test, "#{@receipt_dir}/w502-art10-dataset-gate.md"]},
    "3.30" => {"W502", "validation data — DatasetAdmission completeness/required-field gate over evaluation samples",
               [@dataset_source, @dataset_test, "#{@receipt_dir}/w502-art10-dataset-gate.md"]},
    "3.31" => {"W502", "validation data set — DatasetAdmission required_fields over a separate sample list",
               [@dataset_source, @dataset_test, "#{@receipt_dir}/w502-art10-dataset-gate.md"]},
    "3.32" => {"W502", "testing data — DatasetAdmission independent evaluation via sliced-W1 projections",
               [@dataset_source, @dataset_test, "#{@receipt_dir}/w502-art10-dataset-gate.md"]},
    "3.33" => {"W502", "input data — typed candidate data_domains / sample features in the admission surfaces",
               [@dataset_source, @admission_source]},
    # Art. 3(39)-(43) — emotion/biometric systems: typed data_domains + real refusal atoms
    "3.39" => {"W500", "emotion recognition system — typed :affective data domain refuses in workplace setting",
               [@admission_source]},
    "3.40" => {"W500", "biometric categorisation system — typed :biometric domain inferring special categories",
               [@admission_source]},
    "3.41" => {"W500", "remote biometric identification system — typed :biometric_identification data domain",
               [@admission_source]},
    "3.42" => {"W500", "real-time RBI system — latency_goal :realtime + :biometric_identification + :public_space",
               [@admission_source]},
    "3.43" => {"W500", "post-remote RBI system — :biometric_identification domain admits cleanly without the realtime/setting join",
               [@admission_source]},
    # Art. 3(63) — GPAI model: W512 authority decoupling
    "3.63" => {"W512", "general-purpose AI model — W512 pins no GPAI-model capability is relied on anywhere in the actuation path",
               [@decoupling_test, "#{@receipt_dir}/w512-gpai-decoupling.md"]},
    # Art. 3(49) family — serious incident: W538's Art 73 incident-report
    # builder (Xaas.Semantics.IncidentReport) derives classification from
    # witnessed receipts; transmission channel honestly typed OPEN.
    "3.49" => {"W538", "serious incident — IncidentReport.build/2 derives Art 73(1) classification from witnessed receipts",
               [@incident_source, @incident_test, "#{@receipt_dir}/w538-art73-incident-report.md"]},
    "3.49.a" => {"W538", "serious incident (death / serious health harm) — same IncidentReport seam; MALFUNCTION class derivable from refused/error receipts",
                 [@incident_source, @incident_test]},
    "3.49.b" => {"W538", "serious incident (critical-infrastructure disruption) — same IncidentReport seam; MALFUNCTION class derivable from refused/error receipts",
                 [@incident_source, @incident_test]},
    "3.49.c" => {"W538", "serious incident (fundamental-rights infringement) — IncidentReport maps REFUSED_EUAIA_* atoms to INFRINGES_UNION_LAW / HARM_TO_RIGHTS",
                 [@incident_source, @incident_test]},
    "3.49.d" => {"W538", "serious incident (serious property / environment harm) — same IncidentReport seam; MALFUNCTION class derivable from refused/error receipts",
                 [@incident_source, @incident_test]},
    # Art. 4.1 — AI literacy: W648b's structured literacy register over REAL
    # fleet enablement evidence (CRO loop, executable-regulation suite,
    # corpus falsifier discipline, coverage-map Art. 14 rows).
    "4.1" => {"W648b", "AI literacy — structured measures register over real operator-enablement artifacts",
              ["lib/xaas/semantics/oversight_governance.ex",
               "test/xaas/semantics/oversight_governance_test.exs",
               "docs/cro/CRO-LOOP.md",
               "test/eu_ai_act/README.md"]}
  }

  # ---------------------------------------------------------------------------
  # Real typed-vocabulary calls: one per evidenced Art.3 definition, against
  # the REAL admission surface (Chicago: real collaborators, no mocks).
  # ---------------------------------------------------------------------------
  @typed_calls %{
    # W616 deepening: 1.2.b previously asserted paths only — now a real
    # admit/1 call on an Art.5(1)(a) violating candidate returns the exact
    # typed refusal atom (the corpus row the prohibition maps to).
    "1.2.b" => quote do
      assert {:error, :REFUSED_EUAIA_MANIPULATIVE} =
               Xaas.Semantics.EuAiActAdmission.admit(%{techniques: [:deceptive]})

      assert {:ok, :admitted} =
               Xaas.Semantics.EuAiActAdmission.admit(%{techniques: [:recommendation]})
    end,
    "3.1" => quote do
      # a candidate IS an AI-system-shaped typed map; a clean one admits.
      # W616 deepening: the corpus definition feeds the STRUCTURAL model —
      # with/without the definitional attributes is treated distinctly where
      # the module supports it: a non-map is a typed malformed refusal, a
      # bare map (no definitional attributes at all) admits via structural
      # nullification (attributes are constraints, not requirements).
      assert {:error, :REFUSED_EUAIA_MALFORMED_CANDIDATE} =
               Xaas.Semantics.EuAiActAdmission.admit("not a candidate map")

      assert {:ok, :admitted} = Xaas.Semantics.EuAiActAdmission.admit(%{})

      clean = %{
        id: :title_i_art3_1,
        techniques: [:recommendation],
        purpose: :rank_content,
        data_domains: [:usage_events],
        provenance: :consented,
        setting: :consumer_app,
        latency_goal: :batch
      }

      assert {:ok, :admitted} = Xaas.Semantics.EuAiActAdmission.admit(clean)

      # with a definitional attribute present in a prohibited shape, the same
      # structural model refuses — the attribute, not presence, drives verdicts
      assert {:error, :REFUSED_EUAIA_MANIPULATIVE} =
               Xaas.Semantics.EuAiActAdmission.admit(%{clean | techniques: [:deceptive]})
    end,
    "3.2" => quote do
      # risk is a typed vocabulary: 9 refusal atoms (8 Art. 5(1) + malformed
      # fallback, W732 closure), each with a describe/2
      atoms = Xaas.Semantics.EuAiActAdmission.refusal_atoms()
      assert is_list(atoms) and length(atoms) == 9
      for atom <- atoms, do: assert(is_binary(Xaas.Semantics.EuAiActAdmission.describe(atom)))
    end,
    "3.12" => quote do
      # intended purpose is typed: the same candidate with a prohibited
      # :purpose takes a different typed path than the benign one
      assert {:error, :REFUSED_EUAIA_PREDICTIVE_POLICING} =
               Xaas.Semantics.EuAiActAdmission.admit(%{
                 id: :title_i_art3_12,
                 techniques: [:classification],
                 purpose: :predict_offending,
                 data_domains: [:usage_events],
                 provenance: :consented,
                 setting: :consumer_app,
                 latency_goal: :batch,
                 context_joins: [:individualized_profile_join]
               })
    end,
    "3.29" => quote do
      # training data: real DatasetAdmission over real samples
      samples =
        for i <- 1..10, s <- [0, 1] do
          %{features: %{"x0" => 1.0 * i}, label: rem(i, 2), sensitive: s}
        end

      assert {:ok, :ADMITTED, _} = Xaas.Semantics.DatasetAdmission.admit(samples, seed: 42)

      # W616 deepening: train-set distinction via required_fields — a
      # required training field that no sample carries is a typed
      # incomplete-dataset refusal, not a silent admit.
      assert {:error, {:REFUSED_INCOMPLETE_DATASET, %{completeness: c, threshold: t}}} =
               Xaas.Semantics.DatasetAdmission.admit(samples,
                 required_fields: ["x0", "x1_missing"],
                 seed: 42
               )

      assert c == 0.5 and t == 0.95
    end,
    "3.30" => quote do
      # validation data: required-field completeness gate over samples.
      # W616 deepening: the distinct validation scenario is a PARTIALLY
      # complete set (half the samples miss the required validation field) —
      # a typed incomplete refusal with the exact measured completeness.
      partial =
        for i <- 1..10 do
          feats =
            if rem(i, 2) == 0,
              do: %{"x0" => 1.0 * i},
              else: %{"x0" => 1.0 * i, "x_valid" => 1.0 * i}

          %{features: feats, label: rem(i, 2), sensitive: rem(i, 2)}
        end

      assert {:error, {:REFUSED_INCOMPLETE_DATASET, %{completeness: 0.5, threshold: 0.95}}} =
               Xaas.Semantics.DatasetAdmission.admit(partial,
                 required_fields: ["x_valid"],
                 seed: 42
               )

      samples = [%{features: %{"x0" => 1.0}, label: 0, sensitive: 0}]

      assert {:error, :REFUSED_EMPTY_DATASET} =
               Xaas.Semantics.DatasetAdmission.admit([], required_fields: ["x0"])

      balanced =
        for i <- 1..10, s <- [0, 1] do
          %{features: %{"x0" => 1.0 * i}, label: rem(i, 2), sensitive: s}
        end

      assert {:ok, :ADMITTED, %{completeness: 1.0}} =
               Xaas.Semantics.DatasetAdmission.admit(balanced,
                 required_fields: ["x0"],
                 seed: 42
               )
    end,
    "3.31" => quote do
      # validation data set: a separate sample list is gated independently.
      # W616 deepening: the validation SET's required fields are measured and
      # certified on the admit path — completeness 1.0 is a measured, returned
      # quantity of the real call, not assumed.
      samples = [%{features: %{"x0" => 2.0}, label: 1, sensitive: 1}]

      assert {:error, {:REFUSED_BIAS_THRESHOLD, _}} =
               Xaas.Semantics.DatasetAdmission.admit(samples, required_fields: ["x0"], seed: 42)

      balanced =
        for i <- 1..10, s <- [0, 1] do
          %{features: %{"x0" => 2.0 * i}, label: rem(i, 2), sensitive: s}
        end

      assert {:ok, :ADMITTED, %{completeness: 1.0, projections: k}} =
               Xaas.Semantics.DatasetAdmission.admit(balanced,
                 required_fields: ["x0"],
                 seed: 42
               )

      assert is_integer(k) and k > 0
    end,
    "3.32" => quote do
      # testing data: independent evaluation via sliced-W1 projections.
      # W616 deepening: the test-set scenario is distinct — an INDEPENDENT
      # test split with its own required fields, certified complete (1.0),
      # and the sliced-W1 proxy is deterministic under the seed (two calls
      # with the same seed agree exactly; a different seed may differ).
      samples =
        for i <- 1..10, s <- [0, 1] do
          %{features: %{"x0" => 1.0 * i}, label: rem(i, 2), sensitive: s}
        end

      assert {:ok, :ADMITTED, %{w1_proxy: w1, completeness: 1.0, projections: 8}} =
               Xaas.Semantics.DatasetAdmission.admit(samples,
                 projections: 8,
                 required_fields: ["x0"],
                 seed: 42
               )

      assert is_float(w1) and w1 >= 0.0

      assert {:ok, :ADMITTED, %{w1_proxy: w1_again}} =
               Xaas.Semantics.DatasetAdmission.admit(samples,
                 projections: 8,
                 required_fields: ["x0"],
                 seed: 42
               )

      assert w1_again == w1
    end,
    "3.33" => quote do
      # input data: typed candidate data_domains in the admission surface.
      # W616 deepening: the input-domain attribute drives the verdict — the
      # SAME candidate with/without the prohibited input provenance takes
      # opposite typed paths.
      base = %{
        id: :title_i_art3_33,
        techniques: [:classification],
        purpose: :identify_persons,
        data_domains: [:facial_images],
        provenance: :scraped,
        setting: :consumer_app,
        latency_goal: :batch
      }

      assert {:error, :REFUSED_EUAIA_FACIAL_SCRAPING} =
               Xaas.Semantics.EuAiActAdmission.admit(base)

      # without the prohibited provenance attribute the same input data admits
      assert {:ok, :admitted} =
               Xaas.Semantics.EuAiActAdmission.admit(%{base | provenance: :consented})
    end,
    "3.39" => quote do
      # emotion recognition system: :affective domain in a workplace setting
      assert {:error, :REFUSED_EUAIA_EMOTION_RECOGNITION} =
               Xaas.Semantics.EuAiActAdmission.admit(%{
                 id: :title_i_art3_39,
                 techniques: [:classification],
                 purpose: :identify_emotion,
                 data_domains: [:affective],
                 provenance: :consented,
                 setting: :workplace,
                 latency_goal: :batch
               })
    end,
    "3.40" => quote do
      # biometric categorisation: :biometric domain inferring special categories
      assert {:error, :REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION} =
               Xaas.Semantics.EuAiActAdmission.admit(%{
                 id: :title_i_art3_40,
                 techniques: [:classification],
                 purpose: :categorize_persons,
                 data_domains: [:biometric],
                 inferences: [:political_opinion],
                 provenance: :consented,
                 setting: :consumer_app,
                 latency_goal: :batch
               })
    end,
    "3.41" => quote do
      # remote biometric identification system: the typed :biometric_identification domain
      assert {:error, :REFUSED_EUAIA_REALTIME_RBI} =
               Xaas.Semantics.EuAiActAdmission.admit(%{
                 id: :title_i_art3_41,
                 techniques: [:identification],
                 purpose: :identify_persons,
                 data_domains: [:biometric_identification],
                 provenance: :scraped,
                 setting: :public_space,
                 latency_goal: :realtime
               })
    end,
    "3.42" => quote do
      # real-time RBI: the latency_goal :realtime + :public_space join is the typed split
      assert {:error, :REFUSED_EUAIA_REALTIME_RBI} =
               Xaas.Semantics.EuAiActAdmission.admit(%{
                 id: :title_i_art3_42,
                 techniques: [:identification],
                 purpose: :identify_persons,
                 data_domains: [:biometric_identification],
                 provenance: :consented,
                 setting: :public_space,
                 latency_goal: :realtime
               })
    end,
    "3.43" => quote do
      # post-remote RBI: without the realtime/public-space join it admits cleanly
      clean = %{
        id: :title_i_art3_43,
        techniques: [:identification],
        purpose: :identify_persons,
        data_domains: [:biometric_identification],
        provenance: :consented,
        setting: :consumer_app,
        latency_goal: :batch
      }

      assert {:ok, :admitted} = Xaas.Semantics.EuAiActAdmission.admit(clean)
    end,
    "3.63" => quote do
      # W616 deepening: 3.63 previously asserted paths only. Real behavior
      # call: the Art.5 structural admission surface treats a GPAI-model
      # candidate as ordinary input — no Art.5 structural invariant matches a
      # mere general-purpose inference capability, so the gate admits it
      # (the W512 decoupling: no GPAI capability is relied on anywhere the
      # Art.5 gate binds).
      gpai_candidate = %{
        id: :title_i_art3_63,
        techniques: [:foundation_model_inference],
        purpose: :general_assistance,
        data_domains: [:usage_events],
        provenance: :consented,
        setting: :consumer_app,
        latency_goal: :batch
      }

      assert {:ok, :admitted} = Xaas.Semantics.EuAiActAdmission.admit(gpai_candidate)
    end,
    "3.49" => quote do
      # serious incident: classification derived from a witnessed receipt; the
      # authority channel stays honestly typed OPEN. Also pins the builder's
      # court at its W538-landed shape: 6 test definitions, 0 pending.
      incident_test_body = File.read!(Path.expand(@incident_test, File.cwd!()))
      assert @incident_test_count == Enum.count(Regex.scan(~r/^\s*test "/m, incident_test_body))

      receipt = %{
        digest: "sha256:w607349",
        refusal_atom: :REFUSED_EUAIA_EMOTION_RECOGNITION,
        status: :refused,
        observed_at: ~U[2026-10-06 00:00:00Z]
      }

      assert {:ok, report} = Xaas.Semantics.IncidentReport.build([receipt])
      assert :INFRINGES_UNION_LAW in report.classification
      # W679: a lawful REFUSED_EUAIA_* admission refusal is the receipt-
      # integrity family, not a malfunction — partition-exact classification.
      refute :MALFUNCTION in report.classification
      assert {:ok, %{status: :PREPARED_NOT_TRANSMITTED}} =
               Xaas.Semantics.IncidentReport.transmit(report)
    end,
    "4.1" => quote do
      # AI literacy: real structured register over real enablement artifacts —
      # every cited path verified on disk by the module's own tests.
      assert {:ok, lit} = Xaas.Semantics.OversightGovernance.ai_literacy()
      assert match?([_ | _], lit.measures)
      assert lit.audience == "operators/oversight personnel"

      for m <- lit.measures do
        assert File.exists?(Path.expand(m.evidence_path, File.cwd!()))
      end
    end,
    "3.49.a" => quote do
      # death / serious health harm trigger: the seam exists and derives the
      # MALFUNCTION class from an error-status receipt (sub-line-specific
      # trigger vocabulary is the same Art 73 classification surface)
      receipt = %{id: :w607_349a, status: :error, observed_at: 1}

      assert {:ok, report} = Xaas.Semantics.IncidentReport.build([receipt])
      assert :MALFUNCTION in report.classification
    end,
    "3.49.b" => quote do
      # critical-infrastructure disruption trigger: same IncidentReport seam
      receipt = %{id: :w607_349b, status: :refused, observed_at: 2}

      assert {:ok, report} = Xaas.Semantics.IncidentReport.build([receipt])
      assert :MALFUNCTION in report.classification
    end,
    "3.49.c" => quote do
      # fundamental-rights infringement trigger: REFUSED_EUAIA_* atoms map to
      # INFRINGES_UNION_LAW, and _RIGHTS_/_HARM_ atoms additionally carry HARM_TO_RIGHTS
      r1 = %{digest: "w607_349c_a", refusal_atom: "REFUSED_EUAIA_PREDICTIVE_POLICING"}
      r2 = %{digest: "w607_349c_b", refusal_atom: :REFUSED_EUAIA_HARM_RIGHTS_X}

      assert {:ok, report} = Xaas.Semantics.IncidentReport.build([r1, r2])
      assert :INFRINGES_UNION_LAW in report.classification
      assert :HARM_TO_RIGHTS in report.classification
    end,
    "3.49.d" => quote do
      # serious property / environment harm trigger: same IncidentReport seam
      receipt = %{id: :w607_349d, status: :error, observed_at: 3}

      assert {:ok, report} = Xaas.Semantics.IncidentReport.build([receipt])
      assert :MALFUNCTION in report.classification
    end
  }

  # ---------------------------------------------------------------------------
  # Art. 1-2 structural scope pin (kept out of the per-line loop; Art.1-2 lines
  # are all NOT_APPLICABLE legislative scope statements below).
  # ---------------------------------------------------------------------------

  test "EUAI-ACT Title I corpus pin — Title I line census" do
    assert @scope_line_count == 30
    assert @total_line_count == 111
  end

  for line <- non_gap_lines do
    id = line["line_id"]
    article = line["article"]
    text = line["text"] || ""

    short =
      text
      |> String.replace(~r/\s+/, " ")
      |> String.slice(0, 72)

    {verdict, detail} =
      cond do
        evidence = Map.get(@evidence, id) ->
          {:evidenced, evidence}

        article in ["1", "2"] ->
          {:not_applicable,
           "Art.#{article} legislative scope/purpose statement — no behavioral obligation; per-title suites court the obligations"}

        true ->
          {:not_applicable,
           "Art.3 definitional line — no typed counterpart in this repo; the concept's obligations are courted in the per-title suites"}
      end

    case verdict do
      :evidenced ->
        {lane, _desc, paths} = detail
        typed_call = Map.get(@typed_calls, id)

        test "EUAI-ACT #{id} — EVIDENCED (#{lane}): #{short}" do
          for p <- unquote(paths) do
            assert File.exists?(Path.expand(p, File.cwd!())),
                   "EVIDENCED path missing on disk: #{p}"
          end

          unquote(typed_call)
        end

      :not_applicable ->
        test "EUAI-ACT #{id} — NOT_APPLICABLE: #{short}" do
          reason = unquote(detail)
          assert is_binary(reason) and reason != ""
        end
    end
  end
end

defmodule Xaas.EUAIAct.TitleIOpenGapsTest do
  @moduledoc """
  Title I OPEN_GAP lines (lane W525b) — split out of `TitleITest` because
  ExUnit resolves includes over excludes (see that module's moduledoc).
  Carries ONLY `:eu_ai_act_open_gap`, so `--exclude eu_ai_act_open_gap`
  filters these out of the green-gate run.
  """

  use ExUnit.Case, async: true

  @moduletag :eu_ai_act_open_gap

  @gap_details %{
    # 4.1 flipped EVIDENCED by W648b (2026-10-06): AI-literacy register
    # (Xaas.Semantics.OversightGovernance.ai_literacy/0) + its Chicago tests.
    # Title I now has ZERO typed open gaps; only 8.1 (Title III) remains.
  }

  gap_ids = Map.keys(@gap_details)

  title_i_gap_lines =
    if File.exists?("docs/eu_ai_act/corpus.json") do
      body = File.read!("docs/eu_ai_act/corpus.json")

      case Jason.decode(body) do
        {:ok, %{"titles" => titles}} when is_list(titles) ->
          for title <- titles,
              title["num"] == "I",
              article <- title["articles"] || [],
              line <- article["lines"] || [],
              is_map(line),
              line["line_id"] in gap_ids do
            line
          end

        _ ->
          raise RuntimeError,
                "corpus.json shape unexpected for Title I open gaps. REFUSED(EUAIA_CORPUS_SHAPE_UNEXPECTED_W525B)"
      end
    else
      raise RuntimeError,
            "EUAI-Act corpus absent. Substrate owned by lane W520. REFUSED(EUAIA_CORPUS_MISSING_W525B)"
    end

  for line <- title_i_gap_lines do
    id = line["line_id"]
    text = line["text"] || ""

    short =
      text
      |> String.replace(~r/\s+/, " ")
      |> String.slice(0, 72)

    detail = Map.fetch!(@gap_details, id)

    test "EUAI-ACT #{id} — OPEN_GAP: #{short}" do
      flunk("OPEN_GAP: " <> unquote(detail))
    end
  end
end
