defmodule Xaas.AshSurfaceDriftMutationTest do
  @moduledoc """
  Anti-vacuity mutation leg for the ash_surface manufacture gate
  (test/xaas/ash_surface_drift_guard_test.exs).

  Mirrors ash_pplan's `manufacture_test.exs` mutation pattern (W706 trio gap
  fill): the drift guard's byte-comparison court is only meaningful if it
  actually DETECTS a hand edit. This court regenerates the real surface once,
  hand-edits one regenerated artifact on disk (real File write, no mock), and
  asserts the same sha256 comparison the guard relies on reports exactly that
  file. It then restores the bytes and asserts the drift list collapses to [] —
  proving the earlier detection was caused by the edit, not by regeneration
  nondeterminism.

  Like ash_pplan's version: if every byte-identical assertion in the guard were
  deleted, this test still fails, because it runs the comparison machinery
  itself against a genuinely tampered copy.
  """

  use ExUnit.Case, async: false

  @committed_dir Path.expand("priv/ash_surface", File.cwd!())
  @excluded_prefix "conference/"

  @tag timeout: 900_000
  test "tampering one regenerated artifact is detected; restoring clears the drift" do
    assert File.dir?(@committed_dir), "committed priv/ash_surface artifacts missing"

    tmp_dir =
      Path.join(System.tmp_dir!(), "ash_surface_mutation_#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    # Real manufacture: the same regeneration the guard court runs.
    assert :ok = Mix.Tasks.Xaas.AshSurface.run(["--target-dir", tmp_dir])

    regenerated = relative_files(tmp_dir)
    assert regenerated != [], "regeneration produced no artifacts"

    # 1) Baseline: regeneration is byte-identical to the committed surface
    #    (same comparison the guard runs).
    committed =
      @committed_dir
      |> relative_files()
      |> Enum.reject(&String.starts_with?(&1, @excluded_prefix))

    assert drift(committed, tmp_dir) == [], "regeneration itself drifted from committed surface"

    # 2) Mutation: genuinely hand-edit one regenerated artifact on disk.
    victim = Enum.max_by(regenerated, &byte_size(Path.join(tmp_dir, &1)))
    victim_path = Path.join(tmp_dir, victim)
    original_bytes = File.read!(victim_path)
    File.write!(victim_path, original_bytes <> "\n# hand edit\n")

    assert drift(committed, tmp_dir) == [victim],
           "sha256 comparison failed to detect the hand edit of #{victim}"

    # 3) Restore: the drift list collapses to [] on the original bytes,
    #    so the detection above came from the edit, not from flakiness.
    File.write!(victim_path, original_bytes)
    assert drift(committed, tmp_dir) == []
  end

  # -- the guard court's own comparison machinery, exercised for real --------

  defp drift(committed_files, tmp_dir) do
    for rel <- committed_files,
        sha256(Path.join(@committed_dir, rel)) != sha256(Path.join(tmp_dir, rel)) do
      rel
    end
    |> Enum.sort()
  end

  defp relative_files(dir) do
    dir
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, dir))
  end

  defp sha256(path), do: :crypto.hash(:sha256, File.read!(path))
end
