defmodule Xaas.Bridges.HeadShaDeepeningTest do
  @moduledoc """
  W650v7 depth court on `Xaas.Bridges.head_sha/1` — the bridge family's identity
  substrate.

  Census (2026-10-07): every `lib/xaas/bridges/*` module has a dedicated court
  except the resolution branches of `head_sha/1`. `bridges_test.exs` covers the
  loose-ref path and the nonexistent-dir path; the `packed-refs` fallback, the
  detached-HEAD branch, and the non-40-hex guard were all uncovered. Every
  bridge pin (`Sa2a.court_receipt/1` default pin, envelope provenance) resolves
  through this function, so a wrong resolution silently re-binds every
  receipt-match verdict.

  Chicago discipline: real git-shaped files under `System.tmp_dir!/0`, real
  reads, assertions on returned state. No mocks.
  """

  use ExUnit.Case, async: true

  alias Xaas.Bridges

  setup do
    git_dir = Path.join(System.tmp_dir!(), "w650v7-head-sha-#{System.unique_integer([:positive])}")
    File.mkdir_p!(git_dir)
    on_exit(fn -> File.rm_rf!(git_dir) end)
    %{git_dir: git_dir}
  end

  defp write!(git_dir, rel, content) do
    path = Path.join(git_dir, rel)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
    path
  end

  @sha_a String.duplicate("a", 40)
  @sha_b String.duplicate("b", 40)

  test "detached HEAD: a raw 40-hex SHA in HEAD is returned trimmed, never re-resolved",
       %{git_dir: git_dir} do
    # Mutation rationale: the detached branch must return the literal SHA.
    # If it re-routed through ref resolution (or returned "ref: " text), every
    # bridge operating from a detached checkout would pin to nil/mismatch and
    # all receipt matches would silently degrade to :receipt_subject_mismatch.
    write!(git_dir, "HEAD", @sha_a <> "\n")

    assert Bridges.head_sha(git_dir) == @sha_a
  end

  test "corrupt HEAD: non-40-hex content is nil (no-guess), not the garbage passthrough",
       %{git_dir: git_dir} do
    # Mutation rationale: a permissive branch here would let a truncated or
    # hand-edited HEAD become a standing "pin", binding receipts to a subject
    # that is not a commit identity. The guard is the typed no-guess refusal.
    write!(git_dir, "HEAD", "not-a-sha")

    assert Bridges.head_sha(git_dir) == nil
  end

  test "packed-refs fallback: loose ref absent but ref present in packed-refs resolves",
       %{git_dir: git_dir} do
    # Mutation rationale: after `git gc`/`git pack-refs`, feat/* and tags lose
    # their loose files; a resolution that only reads loose refs would return
    # nil on every packed checkout — flipping every bridge pin to UNKNOWN
    # provenance purely from repository storage format, not from any real
    # subject change.
    write!(git_dir, "HEAD", "ref: refs/heads/feat/playwright-surface\n")
    write!(
      git_dir,
      "packed-refs",
      "# pack-refs with: peeled fully-peeled sorted \n" <>
        "#{@sha_a} refs/heads/main\n" <>
        "#{@sha_b} refs/heads/feat/playwright-surface\n"
    )

    assert Bridges.head_sha(git_dir) == @sha_b
  end

  test "packed-refs peeled lines: an annotated-tag ^peeled line is never mistaken for its ref",
       %{git_dir: git_ref_handling} do
    # Mutation rationale: packed-refs interleaves "sha ref" lines with "^sha"
    # peeled continuations. A parser splitting on whitespace without anchoring
    # the ref position would bind the pin to the peeled object instead of the
    # ref — the exact byte the whole family matches receipts against.
    git_dir = git_ref_handling
    write!(git_dir, "HEAD", "ref: refs/tags/v1\n")
    write!(
      git_dir,
      "packed-refs",
      "#{@sha_a} refs/tags/v1\n" <>
        "^#{@sha_b}\n" <>
        "#{@sha_a} refs/heads/main\n"
    )

    assert Bridges.head_sha(git_dir) == @sha_a
  end

  test "loose ref dangling and packed-refs absent: nil, not an exception",
       %{git_dir: git_dir} do
    # Mutation rationale: the fallback must terminate in the typed nil, not
    # raise on the missing packed-refs file — a raise here would take down any
    # bridge call on a fresh/corrupt clone, converting a provenance question
    # into a crash.
    write!(git_dir, "HEAD", "ref: refs/heads/ghost\n")

    assert Bridges.head_sha(git_dir) == nil
  end
end
