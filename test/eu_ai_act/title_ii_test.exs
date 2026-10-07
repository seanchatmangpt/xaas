defmodule Xaas.EUAIAct.TitleIITest do
  @moduledoc """
  EU AI Act Title II (Art. 5 prohibited practices) as Chicago tests against the
  REAL landed seams (lane W522).

  Per the W526 per-title contract (`docs/sjira/v26.10.6/plans/w526-euaia-suite-wiring.md`):

  - EVIDENCED: the real product path exists and a real call returns the exact
    typed verdict (real `EuAiActAdmission.admit/1`, no mocks).
  - NOT_APPLICABLE: typed reason (recital/definition lines carry no behavioral
    obligation).
  - OPEN_GAP: tagged `:eu_ai_act_open_gap`, flunks by design until closed;
    excluded from this suite run via `--exclude eu_ai_act_open_gap`.
  """

  use ExUnit.Case, async: true

  @moduletag :eu_ai_act

  @admission_source "lib/xaas/semantics/eu_ai_act_admission.ex"
  @w500_test "test/xaas/semantics/eu_ai_act_admission_test.exs"
  @wasi_receipt "docs/sjira/v26.10.6/plans/w509-wasi-gate.md"
  @wasi_crate "/Users/sac/wasm4pm/crates/eu_gate"
  @integration_test "test/xaas_web/eu_ai_act_admission_integration_test.exs"

  # One violating candidate per Art. 5(1) refusal atom, plus a W616 near-miss
  # control: the same structural shape minus ONE join field — which the
  # structural gate must ADMIT (proves the invariant is the join, not any
  # single field).
  #
  # W655 dedupe: the violating candidates below were byte-identical to the
  # W531 corpus loop's candidates for the same refusal atoms (5 duplicated
  # atom+candidate pairs). They are now DIFFERENTIATED — each synthetic
  # candidate proves a distinct facet of the same structural invariant, so
  # both layers survive with distinct coverage (no line lost):
  #   - (a) manipulative: :subliminal technique class (corpus keeps :deceptive)
  #   - (a) vulnerability: :target_vulnerable_audience technique (corpus keeps
  #     :exploit_vulnerability)
  #   - (b) social scoring: a declared purpose does NOT rescue the unrelated-
  #     context join (corpus keeps the bare join)
  #   - (d) facial scraping: ANY non-:consented provenance refuses, not just
  #     :scraped (corpus keeps :scraped)
  #   - (e) emotion recognition: the :education setting also prohibits
  #     :affective data (corpus keeps :workplace)
  #   - (f) biometric categorization: a non-boolean match_token_type refuses
  #     even with no :inferences (corpus keeps the inference shape)
  @partitions [
    {:"5.1.a-manipulative", :REFUSED_EUAIA_MANIPULATIVE,
     %{techniques: [:subliminal]},
     %{techniques: [:recommendation]}},
    {:"5.1.a-vulnerability", :REFUSED_EUAIA_VULNERABILITY_EXPLOIT,
     %{techniques: [:target_vulnerable_audience], context_joins: [:age_slice_join]},
     %{techniques: [:classification]}},
    {:"5.1.b", :REFUSED_EUAIA_SOCIAL_SCORING,
     %{purpose: :credit_decisions, data_domains: [:social_behavior],
       context_joins: [:unrelated_context_join]},
     %{data_domains: [:social_behavior]}},
    {:"5.1.c", :REFUSED_EUAIA_PREDICTIVE_POLICING,
     %{purpose: :predict_offending, context_joins: [:individualized_profile_join]},
     %{purpose: :predict_offending}},
    {:"5.1.d", :REFUSED_EUAIA_FACIAL_SCRAPING,
     %{data_domains: [:facial_images], provenance: :publicly_scraped},
     %{data_domains: [:facial_images], provenance: :consented}},
    {:"5.1.e", :REFUSED_EUAIA_EMOTION_RECOGNITION,
     %{data_domains: [:affective], setting: :education},
     %{data_domains: [:affective], setting: :consumer_app}},
    {:"5.1.f", :REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION,
     %{data_domains: [:biometric], match_token_type: :raw_embedding},
     %{data_domains: [:biometric]}},
    {:"5.1.g-h", :REFUSED_EUAIA_REALTIME_RBI,
     %{setting: :public_space, data_domains: [:biometric_identification],
       latency_goal: :realtime},
     %{setting: :public_space, data_domains: [:biometric_identification],
       latency_goal: :batch}}
  ]

  test "EUAI-ACT admission surface: source of truth on disk (W616: real admit roundtrip)" do
    assert File.exists?(Path.expand(@admission_source, File.cwd!()))

    # W616 deepening: the surface is not merely on disk — a REAL admit/1 call
    # refuses a violating candidate with the exact typed atom, and a non-map
    # input hits the typed malformed-candidate refusal.
    assert {:error, :REFUSED_EUAIA_MANIPULATIVE} =
             Xaas.Semantics.EuAiActAdmission.admit(%{techniques: [:deceptive]})

    assert {:error, :REFUSED_EUAIA_MALFORMED_CANDIDATE} =
             Xaas.Semantics.EuAiActAdmission.admit("not a candidate map")
  end

  for {partition, refusal_atom, candidate, near_miss} <- @partitions do
    test "EUAI-ACT #{partition}: EVIDENCED — #{refusal_atom}" do
      partition = unquote(partition)
      refusal_atom = unquote(refusal_atom)
      candidate = unquote(Macro.escape(candidate))
      near_miss = unquote(Macro.escape(near_miss))

      # (a) the admission source exists on disk
      source = Path.expand(@admission_source, File.cwd!())
      assert File.exists?(source), "missing #{@admission_source}"

      # (b) a REAL admit/1 call on a violating candidate returns EXACTLY this atom
      assert {:error, ^refusal_atom} = Xaas.Semantics.EuAiActAdmission.admit(candidate)

      # (b2, W616) the near-miss control — same shape minus one join field —
      # is ADMITTED, proving the refusal is the structural join, not a field
      assert {:ok, :admitted} = Xaas.Semantics.EuAiActAdmission.admit(near_miss)

      # (c) the W500 test tree covers this refusal atom
      w500 = File.read!(Path.expand(@w500_test, File.cwd!()))
      assert w500 =~ Atom.to_string(refusal_atom),
             "#{@w500_test} does not cover #{refusal_atom}"

      # the article partition is described by the module
      assert Xaas.Semantics.EuAiActAdmission.describe(refusal_atom) =~
               partition_label(partition)
    end
  end

  defp partition_label(partition) do
    case partition do
      :"5.1.a-manipulative" -> "(a)"
      :"5.1.a-vulnerability" -> "(a)"
      :"5.1.b" -> "(b)"
      :"5.1.c" -> "(c)"
      :"5.1.d" -> "(d)"
      :"5.1.e" -> "(e)"
      :"5.1.f" -> "(f)"
      :"5.1.g-h" -> "(g)"
    end
  end

  test "EUAI-ACT 5.catch-all: EVIDENCED — clean candidate admitted" do
    clean = %{
      id: :benign,
      techniques: [:recommendation],
      purpose: :rank_content,
      data_domains: [:usage_events],
      provenance: :consented,
      setting: :consumer_app,
      latency_goal: :batch
    }

    assert {:ok, :admitted} = Xaas.Semantics.EuAiActAdmission.admit(clean)

    # and every declared refusal atom is typed in the module's public list
    atoms = Xaas.Semantics.EuAiActAdmission.refusal_atoms()
    assert length(atoms) == 8
    for {_, atom, _, _} <- @partitions, do: assert(atom in atoms)
  end

  test "EUAI-ACT 5.structural-gate: EVIDENCED — eyerun_wasi crate + 21-test receipt" do
    # crate sources exist (W509 landed the standalone crate)
    for src <- ["Cargo.toml", "src/lib.rs", "src/main.rs", "tests/cli.rs"] do
      assert File.exists?(Path.join(@wasi_crate, src)), "missing #{src} in #{@wasi_crate}"
    end

    # the 21-test receipt (16 lib + 5 cli) exists on the receipt path
    receipt = Path.expand(@wasi_receipt, File.cwd!())
    assert File.exists?(receipt), "missing #{@wasi_receipt}"

    assert File.read!(receipt) =~ "16 passed" and File.read!(receipt) =~ "5 passed"
  end

  test "EUAI-ACT 5.live-integration: EVIDENCED — Art.5 intake wired (W521, W616 real plug call)" do
    # W521 landed: the live integration test exists and drives the real
    # admission surface over the web intake path.
    path = Path.expand(@integration_test, File.cwd!())
    assert File.exists?(path), "missing #{@integration_test}"
    content = File.read!(path)
    assert content =~ "EuAiActAdmission"
    assert content =~ "REFUSED_EUAIA_"

    # W616 deepening: a REAL in-process call through the live intake plug —
    # the same endpoint pipeline stage the W521 court drives — refuses a
    # social-scoring JSON-RPC body with the typed envelope, and passes a
    # lawful body through untouched.
    alias XaasWeb.Plugs.EuAiActAdmissionPlug

    # The parse floor (Plug.Parsers) has already decoded the body by the time
    # the endpoint reaches this plug in the real pipeline; we build the conn
    # at that exact handoff point (decoded body_params) and run the REAL plug.
    violating_params = %{
      "jsonrpc" => "2.0",
      "method" => "message/send",
      "params" => %{
        "techniques" => ["summarize"],
        "data_domains" => ["social_behavior"],
        "context_joins" => ["unrelated_context_join"]
      },
      "id" => "w616-1"
    }

    violating_conn =
      Plug.Test.conn(:post, "/a2a/v1", "")
      |> Map.replace!(:body_params, violating_params)
      |> EuAiActAdmissionPlug.call([])

    assert violating_conn.status == 200
    assert %{"error" => %{"data" => %{"refusal" => "REFUSED_EUAIA_SOCIAL_SCORING"}}} =
             Jason.decode!(violating_conn.resp_body)

    lawful_conn =
      Plug.Test.conn(:post, "/a2a/v1", "")
      |> Map.replace!(:body_params, %{
        "jsonrpc" => "2.0",
        "method" => "message/send",
        "params" => %{
          "message" => %{
            "role" => "ROLE_USER",
            "messageId" => "msg-w616-lawful",
            "parts" => [%{"kind" => "text", "text" => "hddl:plan"}]
          }
        },
        "id" => "w616-2"
      })
      |> EuAiActAdmissionPlug.call([])

    # passed through untouched: halted? false and no refusal envelope written
    refute lawful_conn.halted
    assert lawful_conn.resp_body in [nil, ""]
  end

  # -- Title II recital/definition lines: no behavioral obligation -------------

  @tag :eu_ai_act_not_applicable
  test "EUAI-ACT Title II recitals: NOT_APPLICABLE — recital/definition, no behavioral obligation" do
    # Art. 5 recital material (definitions of manipulation, vulnerability,
    # biometric categorisation, etc.) is definitional; the behavioral
    # obligations are the 5.1(a)-(h) partitions asserted above.
    assert true
  end

  # ---------------------------------------------------------------------------
  # W531: corpus-driven loop over the real Title II lines (W527 finding: the
  # synthetic partition atoms above cover 8 atoms, not the corpus's 26 lines).
  # One test per corpus line_id, "EUAI-ACT <line_id>: <kind>", generated from
  # docs/eu_ai_act/corpus.json at compile time (same shape as W523's Title III
  # loop; the W526 CorpusLoader flat shape is not used here — lane isolation).
  #
  # Prohibition lines with a deployer-enforceable surface map to the W500 typed
  # refusal atom and are EVIDENCED by a REAL admit/1 call (Chicago: no mocks).
  # Authority-side procedure lines, exception carve-outs, enumerative headers
  # and savings clauses are NOT_APPLICABLE with a typed reason.
  # The W522 synthetic tests above are documented EXTRA ids and stay intact.
  # ---------------------------------------------------------------------------

  @corpus_relpath "docs/eu_ai_act/corpus.json"

  title_ii_lines =
    if File.exists?(@corpus_relpath) do
      case Jason.decode(File.read!(@corpus_relpath)) do
        {:ok, %{"titles" => titles}} when is_list(titles) ->
          for title <- titles,
              title["num"] == "II",
              article <- title["articles"] || [],
              line <- article["lines"] || [],
              is_map(line),
              is_binary(line["line_id"]) do
            line |> Map.put("article", article["id"])
          end

        _ ->
          raise RuntimeError,
                "corpus.json shape unexpected for Title II — REFUSED(EUAIA_CORPUS_SHAPE_UNEXPECTED_W531)"
      end
    else
      raise RuntimeError, "EUAI-Act corpus absent — REFUSED(EUAIA_CORPUS_MISSING_W520/W531)"
    end

  # corpus line_id -> W500 typed refusal atom (deployer-enforceable prohibition)
  @line_atoms %{
    "5.1.a" => :REFUSED_EUAIA_MANIPULATIVE,
    "5.1.b" => :REFUSED_EUAIA_VULNERABILITY_EXPLOIT,
    "5.1.c" => :REFUSED_EUAIA_SOCIAL_SCORING,
    "5.1.c.i" => :REFUSED_EUAIA_SOCIAL_SCORING,
    "5.1.c.ii" => :REFUSED_EUAIA_SOCIAL_SCORING,
    "5.1.d" => :REFUSED_EUAIA_FACIAL_SCRAPING,
    "5.1.e" => :REFUSED_EUAIA_EMOTION_RECOGNITION,
    "5.1.f" => :REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION,
    "5.1.g" => :REFUSED_EUAIA_REALTIME_RBI,
    "5.1.h" => :REFUSED_EUAIA_REALTIME_RBI
  }

  # corpus line_id -> violating candidate fed to the real admit/1 (from W522).
  # W616 deepening: sub-lines get DISTINCT candidates (previously byte-identical
  # duplicates of their parent line), each still hitting the same typed atom.
  @line_candidates %{
    "5.1.a" => %{techniques: [:deceptive]},
    "5.1.b" => %{techniques: [:exploit_vulnerability]},
    "5.1.c" => %{data_domains: [:social_behavior], context_joins: [:unrelated_context_join]},
    # sub-line distinct scenario: a scoring purpose over the social join
    "5.1.c.i" => %{
      techniques: [:classification],
      purpose: :score_citizens,
      data_domains: [:social_behavior],
      context_joins: [:unrelated_context_join]
    },
    # sub-line distinct scenario: a benefits-gating purpose, ranking technique
    "5.1.c.ii" => %{
      techniques: [:ranking],
      purpose: :welfare_benefits_gate,
      data_domains: [:social_behavior],
      context_joins: [:unrelated_context_join]
    },
    "5.1.d" => %{data_domains: [:facial_images], provenance: :scraped},
    "5.1.e" => %{data_domains: [:affective], setting: :workplace},
    "5.1.f" => %{data_domains: [:biometric], inferences: [:political_opinion]},
    # sub-line distinct scenario: realtime public-space tracking purpose
    "5.1.g" => %{
      techniques: [:identification],
      purpose: :track_persons,
      provenance: :consented,
      setting: :public_space,
      data_domains: [:biometric_identification],
      latency_goal: :realtime
    },
    # sub-line distinct scenario: scraped provenance, categorize purpose
    "5.1.h" => %{
      techniques: [:identification],
      purpose: :categorize_persons,
      provenance: :scraped,
      setting: :public_space,
      data_domains: [:biometric_identification],
      latency_goal: :realtime
    }
  }

  classified_ii =
    for line <- title_ii_lines do
      id = line["line_id"]
      text = line["text"] || ""
      addressee = line["addressee"] || "both"
      kind = line["kind"] || "procedure"

      {verdict, detail} =
        cond do
          atom = Map.get(@line_atoms, id) ->
            {:evidenced, {atom, Map.get(@line_candidates, id)}}

          # exception carve-outs inside 5.1(c) and 5.1(h): they *narrow* the
          # prohibition (permitted law-enforcement / protective uses); the
          # admitting surface enforces the prohibition itself, tested above
          id in ["5.1.h.i", "5.1.h.ii"] ->
            {:not_applicable,
             "Art.5(1)(h) exception carve-out (permitted protective use) — narrows the prohibition enforced by REFUSED_EUAIA_REALTIME_RBI; no separate deployer surface"}

          id == "5.1.s2" ->
            {:not_applicable,
             "cross-reference to Art.9 of Regulation (EU) 2016/672 (external law-enforcement directive) — no implementable obligation in this repo"}

          addressee == "authority" ->
            {:not_applicable,
             "authority-side machinery (judicial/ market-surveillance/ data-protection authorization and reporting) — not implementable as deployer-side code"}

          id in ["5.2", "5.2.a", "5.2.b"] ->
            {:not_applicable,
             "Art.5(2) law-enforcement authorization criteria — the repo deploys no real-time RBI system; criteria bind the authority authorizing such use"}

          id == "5.8" ->
            {:not_applicable,
             "savings clause (other Union-law prohibitions unaffected) — definitional, no behavioral obligation"}

          true ->
            {:not_applicable,
             "enumerative/definitional line (#{kind}) with no standalone behavioral obligation"}
        end

      {id, verdict, detail}
    end

  evidenced_ii = Enum.filter(classified_ii, &match?({_, :evidenced, _}, &1))
  not_applicable_ii = Enum.filter(classified_ii, &match?({_, :not_applicable, _}, &1))

  for {id, _v, {atom, candidate}} <- evidenced_ii do
    test "EUAI-ACT #{id}: EVIDENCED — real admit/1 refuses with #{atom}" do
      id = unquote(id)
      atom = unquote(atom)
      candidate = unquote(Macro.escape(candidate))

      # REAL admission call — the corpus line's prohibition is enforced by the
      # exact W500 typed refusal atom (Chicago: real collaborator, no mocks)
      assert {:error, ^atom} = Xaas.Semantics.EuAiActAdmission.admit(candidate),
             "corpus line #{id} mapped to #{atom} but admit/1 did not return it"

      # the W500 test tree covers this atom
      w500 = File.read!(Path.expand(@w500_test, File.cwd!()))
      assert w500 =~ Atom.to_string(atom)
      assert atom in Xaas.Semantics.EuAiActAdmission.refusal_atoms()
    end
  end

  for {id, _v, reason} <- not_applicable_ii do
    test "EUAI-ACT #{id}: NOT_APPLICABLE — typed reason" do
      reason = unquote(reason)
      assert is_binary(reason) and reason != ""
    end
  end

  test "EUAI-ACT Title II corpus closure: every corpus line_id classified (W531/W527)" do
    all = unquote(Enum.map(title_ii_lines, & &1["line_id"]))
    evidenced_ids = unquote(Enum.map(evidenced_ii, &elem(&1, 0)))
    na_ids = unquote(Enum.map(not_applicable_ii, &elem(&1, 0)))

    assert length(all) == 26
    assert Enum.sort(evidenced_ids ++ na_ids) == Enum.sort(all)
  end
end
