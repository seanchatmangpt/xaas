defmodule Mix.Tasks.Xaas.Fabric.Redeploy do
  @shortdoc "Compile + swap the xaas-fabric zcode plugin (plan only; --cut performs the swap)"

  @moduledoc """
  The ONE documented command for the previously-manual xaas-fabric plugin
  redeploy (wave-9 REDUCE): compiles the app, then either prints the
  byte-digest swap plan or -- with `--cut` -- performs the staged, digest-
  verified swap into the local zcode plugin cache.

  Usage:

      mix xaas.fabric.redeploy              # plan only: no host files touched
      mix xaas.fabric.redeploy --cut        # perform the staged swap
      mix xaas.fabric.redeploy --cut --cache-root /tmp/fake-cache

  The compile step is real (`mix compile` runs first): a broken build never
  reaches the swap. The cut itself is `Xaas.Ultracode.FabricRedeploy`'s
  explicit-cut contract -- stage, verify every file digest against the plan,
  atomically rename over the versioned target directory, write
  `redeploy-receipt.json` beside the plugin manifest. Without `--cut` this
  task is a pure read.

  Exit behavior (this repo's typed-refusal convention, matching
  `mix xaas.ultracode.tick_health`): a refused redeploy (missing/malformed
  plugin projection, staged digest mismatch, cut required) prints the typed
  reason and raises, so automation cannot mistake a no-op for a success.
  """

  use Mix.Task

  alias Xaas.Ultracode.FabricRedeploy

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")

    {parsed, _rest, _invalid} =
      OptionParser.parse(args, strict: [cut: :boolean, cache_root: :string])

    opts = Keyword.take(parsed, [:cut, :cache_root])

    if Keyword.get(opts, :cut, false) do
      cut(opts)
    else
      plan_only(opts)
    end
  end

  defp plan_only(opts) do
    case FabricRedeploy.plan(opts) do
      {:ok, plan} ->
        Mix.shell().info(format_plan(plan))

        Mix.shell().info(
          "DRY PLAN — no host files touched. Re-run with --cut to perform the swap."
        )

      {:error, reason} ->
        Mix.shell().error("REFUSED:#{inspect(reason)}")
        Mix.raise("xaas.fabric.redeploy refused: #{inspect(reason)}")
    end
  end

  defp cut(opts) do
    case FabricRedeploy.redeploy(opts) do
      {:ok, receipt} ->
        Mix.shell().info("CUT PERFORMED")
        Mix.shell().info(format_receipt(receipt))

      {:error, reason} ->
        Mix.shell().error("REFUSED:#{inspect(reason)}")
        Mix.raise("xaas.fabric.redeploy refused: #{inspect(reason)}")
    end
  end

  defp format_plan(plan) do
    [
      "xaas-fabric redeploy plan",
      "  version:        #{plan.version}",
      "  source:         #{plan.source_dir}",
      "  target:         #{plan.target_dir}",
      "  target exists:  #{plan.target_exists?}",
      "  files:          #{plan.file_count} (#{plan.total_bytes} bytes)",
      "  differing:      #{differing_line(plan)}",
      "  cut would change: #{plan.cut_would_change?}"
    ]
    |> Enum.join("\n")
  end

  defp differing_line(%{target_exists?: false}), do: "n/a (fresh install)"

  defp differing_line(%{differing_files: []}), do: "none (target matches source)"

  defp differing_line(%{differing_files: differing}), do: Enum.join(differing, ", ")

  defp format_receipt(receipt) do
    [
      "  version:   #{receipt.version}",
      "  target:    #{receipt.target_dir}",
      "  files:     #{receipt.file_count} (#{receipt.total_bytes} bytes)",
      "  receipt:   #{receipt.receipt}",
      "  cut at:    #{DateTime.to_iso8601(receipt.cut_at)}"
    ]
    |> Enum.join("\n")
  end
end
