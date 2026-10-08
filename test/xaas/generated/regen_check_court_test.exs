defmodule Xaas.Generated.RegenCheckCourtTest do
  @moduledoc """
  SPEC-34 court (`test/xaas/generated/regen_check_court_test.exs`), mirroring
  W837's `ts_codegen_drift_court_test.exs` generalized: the REAL regen leg
  (`mix xaas.generated.regen_check`) must report every in-repo-regenerable
  surface clean, deterministically, and an injected hand-edit of a generated
  artifact must flip the verdict to drift (mutation kill).

  Chicago-style: real generator subprocesses, real files, byte-level verdicts.
  """

  use ExUnit.Case, async: false

  alias Xaas.Generated.RegenCheck

  # W984g: the real ggen_igniter subprocesses (oxigraph engine, one mix spawn
  # per surface) take ~60s+ each — the ExUnit default 60s timeout is too tight
  # now that three surfaces run under this test.
  @moduletag timeout: 900_000

  @tag :regen_check
  test "ggen_igniter surfaces report clean via the generator's own --check contract" do
    ggen_surfaces =
      Enum.filter(RegenCheck.surfaces(), &(&1.kind == :ggen_igniter_check))

    # W984g: capital_census/facts.ex upgraded from disclosed_skip to
    # :ggen_igniter_check (corrected invocation proven byte-identical by W983c).
    assert length(ggen_surfaces) == 3

    report = RegenCheck.check(surfaces: ggen_surfaces)

    for {path, verdict} <- report do
      assert verdict == :ok,
             "expected clean regen for #{path}, got: #{inspect(verdict)}"
    end
  end

  @tag :regen_check
  test "ash_typescript surface is byte-identical to a fresh regen, deterministically (x2)" do
    surface = %{
      path: "assets/js/ash_rpc.ts",
      kind: :byte_compare,
      regen_command: "mix ash_typescript.codegen --output assets/js",
      outputs: ["assets/js/ash_rpc.ts", "assets/js/ash_types.ts"],
      argv_builder: fn out -> ["ash_typescript.codegen", "--output", out] end
    }

    report1 = RegenCheck.check(surfaces: [surface])
    report2 = RegenCheck.check(surfaces: [surface])

    assert report1["assets/js/ash_rpc.ts"] == :ok,
           "first regen drifted: #{inspect(report1)}"

    assert report1 == report2, "regen leg is nondeterministic across two runs"
  end

  @tag :regen_check
  test "MUTATION KILL: injected hand-edit of a generated artifact flips the verdict to drift" do
    tracked = File.read!("assets/js/ash_types.ts")
    tampered = String.replace_prefix(tracked, "//", "// TAMPERED BY W982g MUTATION\n//")

    tmp = Path.join(System.tmp_dir!(), "w982g-mutation-#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(tmp, "assets/js"))
    File.write!(Path.join(tmp, "assets/js/ash_types.ts"), tampered)

    # Point the leg's tracked-read seam (`:tracked_root`) at the tampered temp
    # copy: same real regen subprocess, same compare — only the tracked bytes
    # are hand-edited. The tracked tree is never touched.
    mutated_surface = %{
      path: "assets/js/ash_types.ts",
      kind: :byte_compare,
      regen_command: "mix ash_typescript.codegen --output assets/js",
      outputs: ["assets/js/ash_types.ts"],
      tracked_root: tmp,
      argv_builder: fn out -> ["ash_typescript.codegen", "--output", out] end
    }

    try do
      report = RegenCheck.check(surfaces: [mutated_surface])
      {:drift, detail} = report["assets/js/ash_types.ts"]

      assert detail =~ "DRIFT_SURFACE_STALE"
      assert detail =~ "assets/js/ash_types.ts"
      assert detail =~ "mix ash_typescript.codegen"
    after
      File.rm_rf!(tmp)
    end
  end

  @tag :regen_check
  test "every registry surface is accounted for: executable or typed disclosed skip" do
    report = RegenCheck.check()

    assert map_size(report) == 11

    {skipped, executed} =
      Enum.split_with(report, fn {_path, verdict} -> match?({:skipped, _}, verdict) end)

    assert length(executed) == 4,
           "expected 4 executable surfaces, got: #{inspect(Map.new(executed))}"

    assert length(skipped) == 7

    for {path, {:skipped, reason}} <- skipped do
      assert reason =~ "UNSUPPORTED(" or reason =~ "BLOCKED(",
             "skip for #{path} must carry a typed UNSUPPORTED/BLOCKED reason, got: #{reason}"
    end

    # Typed disclosed skips never fail the leg (UNSUPPORTED ≠ drift), but they
    # are visible in the report, never silently green.
    assert RegenCheck.clean?(Map.new(skipped))
  end
end
