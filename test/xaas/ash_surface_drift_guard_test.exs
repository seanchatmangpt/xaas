defmodule Xaas.AshSurfaceDriftGuardTest do
  @moduledoc """
  Committed-artifact drift guard for `priv/ash_surface/` (x8 gap #3).

  Regenerates the full ash_surface pipeline into a temp directory via the real
  `Mix.Tasks.Xaas.AshSurface` task (`--target-dir`, which never touches
  `priv/ash_surface/`) and asserts every committed artifact is byte-identical
  (sha256) to the regeneration.

  Excluded files and why: `conference/` (7 files:
  `conference_live_view.json`, `zoela_surface{,.actions,.events,.receipts,
  .schemas,.tanstack}.mjs`). These were produced by commit `bedfa86e` (XA4r)
  through a one-off ad-hoc pipeline — `AshSurface.Projector.Expo` projector and
  a `tier=conference-marketplace` profile — NOT through
  `mix xaas.ash_surface`, so the committed task cannot regenerate them. If a
  committed task regenerates the conference projection later, un-exclude it.

  The 5 task-generated top-level artifacts are compared byte-for-byte; the
  generator is byte-deterministic on this tree (no timestamps or wall-clock
  input in any written artifact). If a generator change introduces
  nondeterminism for a file, exclude that file here with the reason and
  assert on `surface_contract.json`'s `manifestDigest` instead.
  """

  use ExUnit.Case, async: false

  @excluded_prefix "conference/"

  test "committed priv/ash_surface artifacts are byte-identical to regeneration" do
    committed_dir = Path.expand("priv/ash_surface")

    tmp_dir =
      Path.join(System.tmp_dir!(), "ash_surface_drift_#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    assert :ok = Mix.Tasks.Xaas.AshSurface.run(["--target-dir", tmp_dir])

    committed_files =
      committed_dir |> relative_files() |> Enum.reject(&String.starts_with?(&1, @excluded_prefix))

    assert committed_files != [], "no comparable committed artifacts found"
    regenerated_files = relative_files(tmp_dir)

    missing = sorted(committed_files) -- sorted(regenerated_files)
    extra = sorted(regenerated_files) -- sorted(committed_files)

    assert missing == [] and extra == [],
           "file set drift: missing=#{inspect(missing)} extra=#{inspect(extra)}"

    drift =
      for rel <- committed_files,
          sha256(Path.join(committed_dir, rel)) != sha256(Path.join(tmp_dir, rel)) do
        rel
      end

    assert drift == [], "sha256 drift in committed ash_surface artifacts: #{inspect(drift)}"
  end

  defp relative_files(dir) do
    dir
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, dir))
  end

  defp sorted(files), do: Enum.sort(files)

  defp sha256(path), do: :crypto.hash(:sha256, File.read!(path))
end
