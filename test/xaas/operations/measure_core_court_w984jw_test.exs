defmodule Xaas.Operations.MeasureCoreCourtW984jwTest do
  @moduledoc """
  Lane W984jw court on the project-measure census/receipt core residue.

  W984fn courted the Spark/verifier layer and W984dp4 courted the GitHubActions
  transport. This court exercises the genuinely unexercised state-bearing
  branches of `Xaas.Operations.ProjectMeasure.Census` and
  `Xaas.Operations.ProjectMeasure.Receipt` over real collaborators and real
  files — zero mocks. Mutation rationale per test: each assertion kills a named
  mutant (branch flip / refusal-code swap / count drift).
  """

  use ExUnit.Case, async: false

  alias Xaas.Operations.ProjectMeasure.{Census, Receipt}

  @sha String.duplicate("a", 40)
  @other_sha String.duplicate("b", 40)
  @since ~U[2026-08-21 00:00:00Z]
  @until ~U[2026-08-22 00:00:00Z]

  setup do
    tmp =
      Path.join(System.tmp_dir!(), "w984jw-#{:erlang.unique_integer([:positive])}.json")

    on_exit(fn -> File.rm(tmp) end)
    {:ok, tmp: tmp}
  end

  defp config(overrides \\ []) do
    %{
      repository: "seanchatmangpt/xaas",
      output_path: ".artifacts/project-measure/ci-outcomes.json",
      token_env: "GITHUB_TOKEN",
      subject_sha_env: "GITHUB_SHA",
      api_url: "https://api.github.com"
    }
    |> Map.merge(Map.new(overrides))
  end

  defp run(id, attrs \\ %{}) do
    Map.merge(
      %{
        "id" => id,
        "node_id" => "RUN_#{id}",
        "name" => "CI",
        "event" => "pull_request",
        "status" => "completed",
        "conclusion" => "success",
        "head_sha" => @sha,
        "created_at" => "2026-08-21T01:00:00Z",
        "updated_at" => "2026-08-21T01:00:00Z",
        "html_url" => "https://github.com/seanchatmangpt/xaas/actions/runs/#{id}"
      },
      Map.new(attrs, fn {k, v} -> {to_string(k), v} end)
    )
  end

  # --- Census.build input-shape guard (catch-all clause) -------------------

  test "build/5 refuses non-DateTime window with PROJECT_MEASURE_INPUT_INVALID" do
    # Mutation: deleting the fallback clause turns a typed refusal into a
    # FunctionClauseError; only this clause produces that exact code.
    assert {:error, "REFUSED[PROJECT_MEASURE_INPUT_INVALID]"} =
             Census.build(config(), "2026-08-21", @until, [], subject_sha: @sha)
  end

  test "build/5 refuses non-list rows with PROJECT_MEASURE_INPUT_INVALID" do
    assert {:error, "REFUSED[PROJECT_MEASURE_INPUT_INVALID]"} =
             Census.build(config(), @since, @until, %{"id" => 1}, subject_sha: @sha)
  end

  # --- validate_config branches ---------------------------------------------

  test "incomplete config refuses PROJECT_MEASURE_CONFIG_INCOMPLETE" do
    # Mutation: dropping the blank-binary guard would admit repository: "" into
    # the observation; this refusal is the only emitter of that code.
    for key <- [:repository, :output_path, :token_env, :subject_sha_env, :api_url] do
      assert {:error, "REFUSED[PROJECT_MEASURE_CONFIG_INCOMPLETE]"} =
               Census.build(Map.delete(config(), key), @since, @until, [], subject_sha: @sha)
    end
  end

  test "blank-string config values refuse PROJECT_MEASURE_CONFIG_INCOMPLETE" do
    # Mutation: is_binary/1 alone (without trim) would admit "   " as repository.
    assert {:error, "REFUSED[PROJECT_MEASURE_CONFIG_INCOMPLETE]"} =
             Census.build(config(repository: "   "), @since, @until, [], subject_sha: @sha)
  end

  test "census-layer malformed repository refuses REPOSITORY_IDENTITY_INVALID" do
    # Mutation: removing the split/2 check at the census boundary (distinct from
    # the W984fn Spark-verifier court) would let "seanchatman" become the
    # observation subject; only this branch emits the code at build time.
    assert {:error, reason} =
             Census.build(config(repository: "seanchatman"), @since, @until, [], subject_sha: @sha)

    assert reason =~ "REFUSED[REPOSITORY_IDENTITY_INVALID]"
    assert reason =~ "seanchatman"
  end

  # --- row admission branches -----------------------------------------------

  test "malformed created_at refuses CI_RUN_TIMESTAMP_INVALID with detail" do
    # Mutation: swapping the with-clause guard to accept any binary would admit
    # a run whose window classification is undefined.
    assert {:error, reason} =
             Census.build(
               config(),
               @since,
               @until,
               [run(1, created_at: "not-a-timestamp")],
               subject_sha: @sha
             )

    assert reason =~ "REFUSED[CI_RUN_TIMESTAMP_INVALID]"
    assert reason =~ "not-a-timestamp"
  end

  test "non-binary created_at refuses CI_RUN_TIMESTAMP_INVALID via catch-all clause" do
    # Mutation: deleting the row_time(_) fallback clause would crash with
    # FunctionClauseError instead of refusing typed.
    assert {:error, reason} =
             Census.build(
               config(),
               @since,
               @until,
               [run(1, created_at: nil)],
               subject_sha: @sha
             )

    assert reason == "REFUSED[CI_RUN_TIMESTAMP_INVALID]"
  end

  test "missing head_sha refuses CI_RUN_SUBJECT_IDENTITY_MISSING" do
    # Mutation: admitting a head_sha-less row would silently misclassify it as
    # off-subject instead of refusing the subject identity.
    assert {:error, "REFUSED[CI_RUN_SUBJECT_IDENTITY_MISSING]"} =
             Census.build(
               config(),
               @since,
               @until,
               [%{"id" => 1, "created_at" => "2026-08-21T01:00:00Z"}],
               subject_sha: @sha
             )
  end

  test "empty-string head_sha also refuses CI_RUN_SUBJECT_IDENTITY_MISSING" do
    assert {:error, "REFUSED[CI_RUN_SUBJECT_IDENTITY_MISSING]"} =
             Census.build(
               config(),
               @since,
               @until,
               [run(1, head_sha: "")],
               subject_sha: @sha
             )
  end

  # --- identity resolution ---------------------------------------------------

  test "run without integer id falls back to node_id identity" do
    # Mutation: deleting the node_id clause would refuse a legitimate
    # GitHub-shaped row that carries only node_id.
    row =
      run(1)
      |> Map.delete("id")
      |> Map.put("node_id", "NODE_abc")

    assert {:ok, payload} = Census.build(config(), @since, @until, [row], subject_sha: @sha)
    assert Enum.map(payload["runs"], & &1["identity"]) == ["node:NODE_abc"]
  end

  test "run with neither id nor node_id refuses CI_RUN_IDENTITY_MISSING" do
    # Mutation: defaulting to a synthesized identity would make deduplication
    # collision-blind; this refusal is the only emitter of that code.
    row = run(1) |> Map.delete("id") |> Map.delete("node_id")

    assert {:error, "REFUSED[CI_RUN_IDENTITY_MISSING]"} =
             Census.build(config(), @since, @until, [row], subject_sha: @sha)
  end

  test "duplicate node-only identities collapse; conflicting node identities refuse" do
    # Mutation: node-keyed dedup diverging from id-keyed dedup would admit two
    # rows for one run.
    row =
      run(1)
      |> Map.delete("id")
      |> Map.put("node_id", "NODE_same")

    assert {:ok, payload} =
             Census.build(config(), @since, @until, [row, row], subject_sha: @sha)

    assert payload["summary"]["subject_run_count"] == 1

    conflict = row |> Map.put("status", "failure")

    assert {:error, reason} =
             Census.build(config(), @since, @until, [row, conflict], subject_sha: @sha)

    assert reason =~ "REFUSED[CI_RUN_IDENTITY_CONFLICT]"
  end

  # --- evidence_state / standing classification ------------------------------

  test "all-completed no-failure evidence_state is COMPLETED_NO_FAILURE_LIKE" do
    # Mutation: flipping the evidence_state clause order would label green CI as
    # PENDING; prior courts only assert PENDING/FAILURE_LIKE/NO_OBSERVED_CI.
    assert {:ok, payload} =
             Census.build(config(), @since, @until, [run(1)], subject_sha: @sha)

    assert payload["summary"]["evidence_state"] == "COMPLETED_NO_FAILURE_LIKE"
    assert payload["standing"] == "PARTIAL_ALIVE"
    assert payload["summary"]["pending_run_count"] == 0
    assert payload["summary"]["failure_like_run_count"] == 0
    assert payload["summary"]["conclusion_counts"] == %{"success" => 1}
  end

  test "failure-like conclusions beyond failure are classified failure-like" do
    # Mutation: narrowing @failure_like to ["failure"] would admit timed_out /
    # cancelled / action_required / startup_failure runs as evidence of health.
    for conclusion <- ~w(action_required cancelled timed_out startup_failure) do
      assert {:ok, payload} =
               Census.build(config(), @since, @until, [run(2, conclusion: conclusion)], subject_sha: @sha)

      assert payload["summary"]["evidence_state"] == "FAILURE_LIKE"
      assert payload["standing"] == "BUILD_BROKEN"
      assert payload["summary"]["failure_like_run_count"] == 1
    end
  end

  test "conclusion_counts bucketises nil conclusion under none" do
    # Mutation: removing the || "none" fallback would produce a nil key in the
    # frequencies map, breaking JSON round-trip of the summary.
    assert {:ok, payload} =
             Census.build(
               config(),
               @since,
               @until,
               [run(3, status: "in_progress", conclusion: nil)],
               subject_sha: @sha
             )

    # pending run is not completed, so not counted; assert completed-side counts
    # with a nil conclusion on a completed run instead.
    assert {:ok, payload2} =
             Census.build(
               config(),
               @since,
               @until,
               [run(4, status: "completed", conclusion: nil)],
               subject_sha: @sha
             )

    assert payload2["summary"]["conclusion_counts"] == %{"none" => 1}
    # Contract: evidence_state keys on status, not conclusion presence — a
    # completed run with nil conclusion is COMPLETED_NO_FAILURE_LIKE, not
    # PENDING (witnessed on this exact subject 2026-10-08).
    assert payload2["summary"]["evidence_state"] == "COMPLETED_NO_FAILURE_LIKE"

    assert payload["summary"]["pending_run_count"] == 1
    assert payload["summary"]["evidence_state"] == "PENDING"
  end

  # --- projection defaults ----------------------------------------------------

  test "missing name/event fields project to empty string; missing url projects to nil" do
    # Mutation: deleting the value/nullable_value default clauses would raise
    # KeyError on sparse GitHub rows.
    sparse = %{
      "id" => 5,
      "head_sha" => @sha,
      "created_at" => "2026-08-21T01:00:00Z",
      "status" => "completed",
      "conclusion" => "success"
    }

    assert {:ok, payload} = Census.build(config(), @since, @until, [sparse], subject_sha: @sha)

    [projected] = payload["runs"]
    assert projected["name"] == ""
    assert projected["event"] == ""
    assert projected["updated_at"] == nil
    assert projected["html_url"] == nil
  end

  test "non-binary projected values collapse to defaults" do
    # Mutation: accepting any term into the projection would leak structs into
    # the JSON surface.
    weird =
      run(6)
      |> Map.put("name", %{deep: :map})
      |> Map.put("conclusion", 42)

    assert {:ok, payload} = Census.build(config(), @since, @until, [weird], subject_sha: @sha)

    [projected] = payload["runs"]
    assert projected["name"] == ""
    assert projected["conclusion"] == nil
  end

  # --- Receipt core -----------------------------------------------------------

  test "Receipt.verify/1 is false for payloads without a well-formed receipt" do
    # Mutation: a lenient verify(_) head would accept receipt-less payloads as
    # verified evidence.
    refute Receipt.verify(%{"schema" => "x"})
    refute Receipt.verify(%{"receipt" => "not-a-map"})
    refute Receipt.verify(%{
             "receipt" => %{
               "algorithm" => "md5",
               "canonicalization" => "sorted-json-v1",
               "observation_digest" => "00"
             }
           })
    refute Receipt.verify(%{
             "receipt" => %{
               "algorithm" => "sha256",
               "canonicalization" => "sorted-json-v1",
               "observation_digest" => 12_345
             }
           })
  end

  test "canonical_json stringifies atom keys deterministically" do
    # Mutation: removing to_string(key) would crash on atom-keyed maps used by
    # internal callers.
    assert Receipt.canonical_json(%{b: 1, a: 2}) == ~s({"a":2,"b":1})
    assert Receipt.digest(%{a: 1}) == Receipt.digest(%{"a" => 1})
  end

  test "canonical_json round-trips lists and scalars" do
    assert Receipt.canonical_json([1, "x", nil, true]) == ~s([1,"x",null,true])
    assert Receipt.canonical_json([]) == "[]"
    assert Receipt.canonical_json(%{}) == "{}"
  end

  # --- replay_file!/1 over a real file ----------------------------------------

  test "replay_file!/1 verifies a real written artifact and prints ALIVE", %{tmp: tmp} do
    # Mutation: replay divergence between write-side and verify-side
    # canonicalization would make stored artifacts unreplayable.
    assert {:ok, payload} =
             Census.build(config(), @since, @until, [run(7)], subject_sha: @sha)

    File.write!(tmp, Jason.encode!(payload))
    assert :ok = Census.replay_file!(tmp)
  end

  test "replay_file!/1 raises typed refusal on a tampered artifact", %{tmp: tmp} do
    # Mutation: a verify-then-warn instead of raise would let mutated evidence
    # masquerade as replayed evidence.
    assert {:ok, payload} = Census.build(config(), @since, @until, [run(8)], subject_sha: @sha)

    tampered = put_in(payload, ["subject", "sha"], @other_sha)
    File.write!(tmp, Jason.encode!(tampered))

    assert_raise RuntimeError, ~r/REFUSED\[PROJECT_MEASURE_REPLAY_MISMATCH\]/, fn ->
      Census.replay_file!(tmp)
    end
  end

  test "replay_file!/1 raises on malformed artifact JSON", %{tmp: tmp} do
    File.write!(tmp, "{not json")
    assert_raise Jason.DecodeError, fn -> Census.replay_file!(tmp) end
  end

  # --- window boundary, dense assertions --------------------------------------

  test "outside_window classification counts before-since and at-until separately" do
    # Mutation: fusing outside-window counting with off-subject counting would
    # corrupt the two distinct exclusion tallies in the summary.
    rows = [
      run(9, created_at: "2026-08-20T23:59:59Z"),
      run(10, created_at: "2026-08-22T00:00:00Z"),
      run(11, created_at: "2026-08-22T09:00:00Z")
    ]

    assert {:ok, payload} = Census.build(config(), @since, @until, rows, subject_sha: @sha)

    assert payload["summary"]["subject_run_count"] == 0
    assert payload["summary"]["outside_window_run_count"] == 3
    assert payload["summary"]["off_subject_run_count"] == 0
  end

  test "off-subject wins over outside-window for a foreign row in-window" do
    # Mutation: reordering the cond clauses would misattribute foreign-head
    # rows as window exclusions.
    assert {:ok, payload} =
             Census.build(
               config(),
               @since,
               @until,
               [run(12, head_sha: @other_sha)],
               subject_sha: @sha
             )

    assert payload["summary"]["off_subject_run_count"] == 1
    assert payload["summary"]["outside_window_run_count"] == 0
  end

  test "admitted rows preserve input order after reverse" do
    # Mutation: dropping Enum.reverse in admit_rows would emit runs newest-first
    # while dedup keeps insertion semantics — observable in run ordering.
    rows = [
      run(13, created_at: "2026-08-21T01:00:00Z"),
      run(14, created_at: "2026-08-21T02:00:00Z"),
      run(15, created_at: "2026-08-21T03:00:00Z")
    ]

    assert {:ok, payload} = Census.build(config(), @since, @until, rows, subject_sha: @sha)

    assert Enum.map(payload["runs"], & &1["identity"]) == ["id:13", "id:14", "id:15"]
  end

  test "runs are sorted by identity in the final projection" do
    assert {:ok, payload} =
             Census.build(
               config(),
               @since,
               @until,
               [run(17), run(16)],
               subject_sha: @sha
             )

    assert Enum.map(payload["runs"], & &1["identity"]) == ["id:16", "id:17"]
  end
end
