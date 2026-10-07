defmodule XaasWeb.TsCodegenDriftCourtTest do
  @moduledoc """
  W837 drift court for the generated ash_typescript artifacts
  (`assets/js/ash_rpc.ts`, `assets/js/ash_types.ts`).

  Law: generated outputs must not drift from their generator without a graph
  change. These tests invoke the REAL generator (`mix ash_typescript.codegen`
  via `Mix.Task`) into a temp directory using the task's documented `--output`
  override, then byte-compare against the tracked artifacts. They never write
  to the tracked files and never hand-edit them; repair for a genuine drift is
  re-running the regen command, not editing the output.

  Chicago-style: real codegen, real files, byte-level assertions on final state.
  """

  use ExUnit.Case, async: false

  @tracked_rpc "assets/js/ash_rpc.ts"
  @tracked_types "assets/js/ash_types.ts"
  @regen_command "mix ash_typescript.codegen --output assets/js"

  setup do
    tmp = Path.join(System.tmp_dir!(), "w837-drift-#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    prev_output_file = Application.get_env(:ash_typescript, :output_file)

    on_exit(fn ->
      Application.put_env(:ash_typescript, :output_file, prev_output_file)
      File.rm_rf!(tmp)
    end)

    %{tmp: tmp}
  end

  # Each generation goes into its own subdirectory: `--output dir/ash_rpc.ts`
  # relocates the whole output set, deriving sibling files by their default
  # names (ash_types.ts), so sibling names cannot be customized per run.
  defp generate!(tmp, run) do
    dir = Path.join(tmp, run)
    File.mkdir_p!(dir)
    out = Path.join(dir, "ash_rpc.ts")
    Mix.Task.rerun("ash_typescript.codegen", ["--output", out])
    rpc = Path.join(dir, "ash_rpc.ts")
    types = Path.join(dir, "ash_types.ts")

    assert File.exists?(rpc), "codegen did not produce #{rpc}"
    assert File.exists?(types), "codegen did not produce #{types}"

    {File.read!(rpc), File.read!(types)}
  end

  defp drift_failure(generated, tracked, path) do
    "DRIFT_ASSET_STALE: generated #{path} differs from the tracked artifact. " <>
      "Generated outputs must not drift from their generator without a graph change. " <>
      "Repair by re-running: #{@regen_command} (never hand-edit the artifact). " <>
      "generated=#{byte_size(generated)}B tracked=#{byte_size(tracked)}B"
  end

  test "tracked ash_rpc.ts is byte-identical to a fresh codegen run", %{tmp: tmp} do
    {gen_rpc, _} = generate!(tmp, "a")
    tracked_rpc = File.read!(@tracked_rpc)

    assert gen_rpc == tracked_rpc, drift_failure(gen_rpc, tracked_rpc, @tracked_rpc)
  end

  test "tracked ash_types.ts is byte-identical to a fresh codegen run", %{tmp: tmp} do
    {_, gen_types} = generate!(tmp, "b")
    tracked_types = File.read!(@tracked_types)

    assert gen_types == tracked_types, drift_failure(gen_types, tracked_types, @tracked_types)
  end

  test "codegen is deterministic across two fresh runs", %{tmp: tmp} do
    {rpc1, types1} = generate!(tmp, "run1")
    {rpc2, types2} = generate!(tmp, "run2")

    assert rpc1 == rpc2,
           "NONDETERMINISTIC_CODEGEN: two consecutive codegen runs produced different " <>
             "ash_rpc.ts bytes (#{byte_size(rpc1)}B vs #{byte_size(rpc2)}B)"

    assert types1 == types2,
           "NONDETERMINISTIC_CODEGEN: two consecutive codegen runs produced different " <>
             "ash_types.ts bytes (#{byte_size(types1)}B vs #{byte_size(types2)}B)"
  end
end
