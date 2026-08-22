defmodule Xaas.Operations.ProjectMeasureTest do
  @moduledoc """
  Chicago-style measurement tests over the real production extension modules.

  These tests do not mock an owned collaborator. They feed literal GitHub-shaped
  observations into the production admission/census path so subject identity,
  windowing, deduplication, classification, and receipt replay are exercised
  without granting network or mutation authority to the test process.
  """

  use ExUnit.Case, async: true

  alias Xaas.Operations.ProjectMeasure.{Census, Info, Receipt}

  @sha String.duplicate("a", 40)
  @other_sha String.duplicate("b", 40)
  @since ~U[2026-08-21 00:00:00Z]
  @until ~U[2026-08-22 00:00:00Z]

  test "Xaas.Operations mounts the Ash project measurement extension" do
    assert Info.config(Xaas.Operations) == %{
             repository: "seanchatmangpt/xaas",
             output_path: ".artifacts/project-measure/ci-outcomes.json",
             token_env: "GITHUB_TOKEN",
             subject_sha_env: "GITHUB_SHA",
             api_url: "https://api.github.com"
           }
  end

  test "exact-subject half-open census excludes foreign heads and until boundary" do
    rows = [
      run(1, @sha, "2026-08-21T01:00:00Z", "completed", "success"),
      run(2, @sha, "2026-08-21T02:00:00Z", "in_progress", nil),
      run(3, @other_sha, "2026-08-21T03:00:00Z", "completed", "failure"),
      run(4, @sha, "2026-08-22T00:00:00Z", "completed", "failure")
    ]

    assert {:ok, payload} =
             Census.build(config(), @since, @until, rows, subject_sha: @sha)

    assert payload["subject"] == %{
             "repository" => "seanchatmangpt/xaas",
             "sha" => @sha
           }

    assert payload["summary"]["subject_run_count"] == 2
    assert payload["summary"]["completed_run_count"] == 1
    assert payload["summary"]["pending_run_count"] == 1
    assert payload["summary"]["successful_run_count"] == 1
    assert payload["summary"]["failure_like_run_count"] == 0
    assert payload["summary"]["off_subject_run_count"] == 1
    assert payload["summary"]["outside_window_run_count"] == 1
    assert payload["summary"]["evidence_state"] == "PENDING"
    assert payload["standing"] == "PARTIAL_ALIVE"
    assert Enum.map(payload["runs"], & &1["identity"]) == ["id:1", "id:2"]
    assert Receipt.verify(payload)
  end

  test "failure-like exact-subject evidence is BUILD_BROKEN rather than ALIVE" do
    rows = [run(11, @sha, "2026-08-21T04:00:00Z", "completed", "failure")]

    assert {:ok, payload} =
             Census.build(config(), @since, @until, rows, subject_sha: @sha)

    assert payload["summary"]["evidence_state"] == "FAILURE_LIKE"
    assert payload["summary"]["failure_like_run_count"] == 1
    assert payload["standing"] == "BUILD_BROKEN"
  end

  test "absence of exact-subject CI remains UNKNOWN" do
    rows = [run(21, @other_sha, "2026-08-21T04:00:00Z", "completed", "success")]

    assert {:ok, payload} =
             Census.build(config(), @since, @until, rows, subject_sha: @sha)

    assert payload["summary"]["subject_run_count"] == 0
    assert payload["summary"]["evidence_state"] == "NO_OBSERVED_CI"
    assert payload["standing"] == "UNKNOWN"
  end

  test "identical duplicate run identities collapse deterministically" do
    row = run(31, @sha, "2026-08-21T05:00:00Z", "completed", "success")

    assert {:ok, payload} =
             Census.build(config(), @since, @until, [row, row], subject_sha: @sha)

    assert payload["summary"]["subject_run_count"] == 1
    assert length(payload["runs"]) == 1
  end

  test "conflicting duplicate run identities fail closed" do
    original = run(41, @sha, "2026-08-21T06:00:00Z", "completed", "success")
    conflicting = %{original | "conclusion" => "failure"}

    assert {:error, reason} =
             Census.build(
               config(),
               @since,
               @until,
               [original, conflicting],
               subject_sha: @sha
             )

    assert reason =~ "REFUSED[CI_RUN_IDENTITY_CONFLICT]"
  end

  test "subject SHA is mandatory and exact" do
    assert {:error, "REFUSED[SUBJECT_SHA_MISSING]"} =
             Census.build(config(), @since, @until, [], subject_sha: nil)

    assert {:error, reason} =
             Census.build(config(), @since, @until, [], subject_sha: "not-a-sha")

    assert reason =~ "REFUSED[SUBJECT_SHA_INVALID]"
  end

  test "receipt replay detects any observation mutation" do
    assert {:ok, payload} =
             Census.build(
               config(),
               @since,
               @until,
               [run(51, @sha, "2026-08-21T07:00:00Z", "completed", "success")],
               subject_sha: @sha
             )

    assert Receipt.verify(payload)

    tampered = put_in(payload, ["summary", "successful_run_count"], 99)
    refute Receipt.verify(tampered)
  end

  defp config do
    %{
      repository: "seanchatmangpt/xaas",
      output_path: ".artifacts/project-measure/ci-outcomes.json",
      token_env: "GITHUB_TOKEN",
      subject_sha_env: "GITHUB_SHA",
      api_url: "https://api.github.com"
    }
  end

  defp run(id, head_sha, created_at, status, conclusion) do
    %{
      "id" => id,
      "node_id" => "RUN_#{id}",
      "name" => "CI",
      "event" => "pull_request",
      "status" => status,
      "conclusion" => conclusion,
      "head_sha" => head_sha,
      "created_at" => created_at,
      "updated_at" => created_at,
      "html_url" => "https://github.com/seanchatmangpt/xaas/actions/runs/#{id}"
    }
  end
end
