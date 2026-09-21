defmodule Xaas.Ultracode.CourtReceiptTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Qualification of the fabric court-receipt producer
  (`Xaas.Ultracode.CourtReceipt`) against the ggen consumer contract
  (`GgenIgniter.SemanticJira.promote/3`'s acceptance/falsifiers/courts
  checks): admission of the court map, per-test extraction from REAL
  pytest -v / mix test --trace output shapes, the IRI-keyed verdict
  vocabulary, and the fail-closed law (no observed verdict = typed
  refusal, never a defaulted row).

  The IRIs below are CROWN2-001's minted IRIs from
  ggen_igniter priv/ggen/semantic-jira-pack/ontology.ttl (branch
  ultracode/w7-crown2) -- the real consumer's real shape.
  """

  alias Xaas.Ultracode.{CourtReceipt, SemanticWork, TargetSuites}

  @sj "https://ggen-igniter.dev/ontology/semantic-jira"
  @acceptance_delta @sj <> "#obs-275a1f5e4de7-acceptance-delta"
  @acceptance_guard @sj <> "#obs-275a1f5e4de7-acceptance-guard"
  @falsifier_delta @sj <> "#obs-275a1f5e4de7-falsifier-delta"
  @court @sj <> "#exact-head-projection-court"

  @delta_test "tests/test_w7_crown_seed.py::test_dedup_labels_normalizes_before_comparing"
  @guard_test "tests/test_w7_crown_seed.py::test_dedup_labels_preserves_first_occurrence_order"

  @head String.duplicate("a", 40)
  @argv_sha String.duplicate("b", 64)

  defp court_map do
    %{
      "acceptance" => %{
        @acceptance_delta => %{"test" => @delta_test},
        @acceptance_guard => %{"test" => @guard_test}
      },
      "falsifiers" => %{@falsifier_delta => %{"test" => @delta_test}},
      "courts" => [@court]
    }
  end

  defp produce(court_map, output, opts \\ []) do
    suite = %{
      result_format: Keyword.get(opts, :result_format, "pytest_v")
    }

    step = %{
      "id" => "test",
      "status" => Keyword.get(opts, :status, "pass"),
      "output_tail" => output
    }

    CourtReceipt.produce(court_map, "eds-dod", suite, step, @head, @argv_sha)
  end

  # -- admission ---------------------------------------------------------

  describe "admit/1" do
    test "nil is a valid no-court contract" do
      assert {:ok, nil} = CourtReceipt.admit(nil)
    end

    test "a well-formed court map round-trips" do
      assert {:ok, admitted} = CourtReceipt.admit(court_map())
      assert admitted["acceptance"][@acceptance_delta] == %{"test" => @delta_test}
      assert admitted["courts"] == [@court]
    end

    test "an empty court map is refused: it declares no contract" do
      assert {:error, {:refused_court_map, :empty}} = CourtReceipt.admit(%{})
    end

    test "unknown keys are refused, never silently ignored" do
      assert {:error, {:refused_court_map, {:unknown_keys, ["commands"]}}} =
               CourtReceipt.admit(Map.put(court_map(), "commands", %{}))
    end

    test "a non-IRI key is refused" do
      bad = %{"acceptance" => %{"not-an-iri" => %{"test" => "t"}}}

      assert {:error, {:refused_court_map, {:invalid_iri, "acceptance", "not-an-iri"}}} =
               CourtReceipt.admit(bad)
    end

    test "an unsupported predicate kind is refused, not ignored" do
      bad = %{"acceptance" => %{@acceptance_delta => %{"command" => ["true"]}}}

      assert {:error, {:refused_court_map, {:unknown_predicate, _}}} = CourtReceipt.admit(bad)
    end

    test "a blank test id and a non-map predicate are refused" do
      assert {:error, {:refused_court_map, {:invalid_predicate, _}}} =
               CourtReceipt.admit(%{"acceptance" => %{@acceptance_delta => %{"test" => ""}}})

      assert {:error, {:refused_court_map, {:invalid_predicate, "x"}}} =
               CourtReceipt.admit(%{"acceptance" => %{@acceptance_delta => "x"}})
    end

    test "a non-list courts value is refused" do
      assert {:error, {:refused_court_map, {:invalid_courts, "x"}}} =
               CourtReceipt.admit(%{"courts" => "x"})
    end
  end

  # -- extraction + verdict vocabulary ------------------------------------

  describe "produce/6 with real pytest -v output shapes" do
    test "GREEN: acceptance true, falsifier survived, court bound to the passing step" do
      output = """
      ============================= test session starts ==============================
      collected 61 items

      tests/test_w7_crown_seed.py::test_dedup_labels_normalizes_before_comparing PASSED [  1%]
      tests/test_w7_crown_seed.py::test_dedup_labels_preserves_first_occurrence_order PASSED [  3%]
      tests/test_cli.py::test_cli_runs PASSED [  4%]

      ========================= 61 passed in 0.42s =========================
      """

      assert {:ok, receipt} = produce(court_map(), output)

      assert receipt["acceptance_results"] == %{
               @acceptance_delta => true,
               @acceptance_guard => true
             }

      assert receipt["falsifier_results"] == %{@falsifier_delta => "survived"}

      assert receipt["court_results"][@court]["passed"] == true
      assert receipt["court_results"][@court]["suite"] == "eds-dod"
      assert receipt["court_results"][@court]["step_id"] == "test"
      assert receipt["court_results"][@court]["head"] == @head
      assert receipt["court_results"][@court]["argv_sha256"] == @argv_sha

      assert receipt["binding"] == %{
               "suite" => "eds-dod",
               "step_id" => "test",
               "head" => @head,
               "argv_sha256" => @argv_sha
             }
    end

    test "RED: a failing predicate makes acceptance false and the falsifier fire" do
      output = """
      tests/test_w7_crown_seed.py::test_dedup_labels_normalizes_before_comparing FAILED [  1%]
      tests/test_w7_crown_seed.py::test_dedup_labels_preserves_first_occurrence_order PASSED [  3%]

      ========================= 1 failed, 60 passed in 0.42s =========================
      """

      assert {:ok, receipt} = produce(court_map(), output, status: "fail")

      assert receipt["acceptance_results"][@acceptance_delta] == false
      assert receipt["acceptance_results"][@acceptance_guard] == true

      # A reproduction falsifies the repair: "failed", exactly the
      # consumer's non-surviving verdict.
      assert receipt["falsifier_results"][@falsifier_delta] == "failed"

      # The step did not pass, so the declared court did not pass either.
      assert receipt["court_results"][@court]["passed"] == false
    end

    test "ERROR and SKIPPED verdicts are not passes" do
      output = """
      tests/test_w7_crown_seed.py::test_dedup_labels_normalizes_before_comparing ERROR [  1%]
      tests/test_w7_crown_seed.py::test_dedup_labels_preserves_first_occurrence_order SKIPPED [  3%]
      """

      assert {:ok, receipt} = produce(court_map(), output, status: "fail")

      assert receipt["acceptance_results"] == %{
               @acceptance_delta => false,
               @acceptance_guard => false
             }

      assert receipt["falsifier_results"][@falsifier_delta] == "failed"
    end

    test "a mapped test with no observed verdict is a typed refusal, never a defaulted row" do
      output = """
      tests/test_cli.py::test_cli_runs PASSED [100%]
      """

      assert {:error, {:refused_court_receipt, {:missing_verdict, :acceptance, iri, @delta_test}}} =
               produce(court_map(), output)

      assert iri == @acceptance_delta
    end

    test "a partially observed output refuses the WHOLE receipt (no partial receipt)" do
      output = """
      tests/test_w7_crown_seed.py::test_dedup_labels_normalizes_before_comparing PASSED [  1%]
      """

      assert {:error, {:refused_court_receipt, {:missing_verdict, :acceptance, iri, @guard_test}}} =
               produce(court_map(), output)

      assert iri == @acceptance_guard
    end
  end

  describe "produce/6 with real mix test --trace output shapes" do
    test "pass and failure re-listings become survived/failed" do
      output = """
        * test dedup normalizes (0.01ms)
        * test dedup preserves first occurrence (200.5ms)

      1) test dedup preserves first occurrence (test/x.ex:12)
         Assertion failed
      """

      court_map = %{
        "acceptance" => %{@acceptance_delta => %{"test" => "test dedup normalizes"}},
        "falsifiers" => %{
          @falsifier_delta => %{"test" => "test dedup preserves first occurrence"}
        }
      }

      assert {:ok, receipt} =
               produce(court_map, output, result_format: "mix_trace", status: "fail")

      assert receipt["acceptance_results"][@acceptance_delta] == true
      assert receipt["falsifier_results"][@falsifier_delta] == "failed"
    end
  end

  describe "produce/6 guard rails" do
    test "an undeclared result_format is a refusal" do
      assert {:error, {:refused_court_receipt, :result_format_undeclared}} =
               produce(court_map(), "x", result_format: nil)
    end

    test "an unknown result_format is a refusal" do
      assert {:error, {:refused_court_receipt, {:unknown_result_format, "junit"}}} =
               produce(court_map(), "x", result_format: "junit")
    end

    test "an omitted courts list yields empty court_results (the consumer refuses, honestly)" do
      output = """
      tests/test_w7_crown_seed.py::test_dedup_labels_normalizes_before_comparing PASSED [  1%]
      tests/test_w7_crown_seed.py::test_dedup_labels_preserves_first_occurrence_order PASSED [  3%]
      """

      court_map = Map.delete(court_map(), "courts")

      assert {:ok, receipt} = produce(court_map, output)
      assert receipt["court_results"] == %{}
    end
  end

  describe "suite declaration admission (TargetSuites.validate/1)" do
    test "the code-declared suites (eds-dod receipt-flagged) stay admissible" do
      assert :ok = TargetSuites.validate(TargetSuites.devs())
      eds = TargetSuites.devs()["eds-dod"]
      assert eds.result_format == "pytest_v"
      assert [%{receipt: true, receipt_argv: receipt_argv, argv: argv}] = eds.steps
      assert receipt_argv != argv
      assert "-v" in receipt_argv
    end

    test "a non-boolean receipt flag is refused" do
      suite = %{steps: [%{id: "s", timeout_ms: 1, argv: ["true"], receipt: "yes"}]}

      assert {:error, problems} = TargetSuites.validate(%{"s" => suite})
      assert Enum.any?(problems, &(&1 =~ "receipt must be a boolean"))
    end

    test "a malformed receipt_argv is refused" do
      suite = %{steps: [%{id: "s", timeout_ms: 1, argv: ["true"], receipt_argv: ["x{tmpdir}"]}]}

      assert {:error, problems} = TargetSuites.validate(%{"s" => suite})
      assert Enum.any?(problems, &(&1 =~ "receipt_argv"))
    end

    test "an unknown result_format is refused" do
      suite = %{result_format: "junit", steps: [%{id: "s", timeout_ms: 1, argv: ["true"]}]}

      assert {:error, problems} = TargetSuites.validate(%{"s" => suite})
      assert Enum.any?(problems, &(&1 =~ "unknown result_format"))
    end
  end

  describe "descriptor threading (SemanticWork.admit/1)" do
    @descriptor %{
      work_order_iri: @sj <> "#obs-275a1f5e4de7",
      checkpoint_iri: @sj <> "#obs-275a1f5e4de7-checkpoint",
      graph_digest: "sha256:" <> String.duplicate("0", 64),
      repository_identity: "local/eds",
      execution_repo_alias: "eds",
      base_sha: String.duplicate("9", 40),
      goal: "Repair observed failing condition",
      provider: "zcode",
      verifier_suite: "eds-dod",
      execution_policy: :autonomic_wave_attempt,
      dependencies: []
    }

    test "a valid court_map is admitted onto the descriptor" do
      assert {:ok, descriptor} = SemanticWork.admit(Map.put(@descriptor, :court_map, court_map()))
      assert descriptor.court_map["courts"] == [@court]
    end

    test "a string-keyed court_map normalizes onto the descriptor" do
      raw = %{@descriptor | execution_policy: "autonomic_wave_attempt"}

      assert {:ok, descriptor} =
               SemanticWork.admit(Map.put(raw, "court_map", %{"courts" => [@court]}))

      assert descriptor.court_map["courts"] == [@court]
    end

    test "a malformed court_map is a typed refusal" do
      assert {:error, {:refused_court_map, {:unknown_keys, _}}} =
               SemanticWork.admit(Map.put(@descriptor, :court_map, %{"bogus" => %{}}))
    end
  end
end
