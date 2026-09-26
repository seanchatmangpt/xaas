defmodule Mix.Tasks.Xaas.Autonomy.Stress do
  @shortdoc "Runs the injected-failure stress suite (real-DB claim storms, provider disappearance, cancel races)"

  @moduledoc """
  The injected-failure suite runner: executes the stress + extinction courts
  against the real test Postgres --

    * `test/xaas/ultracode/autonomy_stress_test.exs` (claim storms across
      candidate-provider lists, registry disable mid-episode, duplicate
      delivery, worker crash + lease expiry, retry races, cancel races)
    * `test/xaas/ultracode/provider_extinction_test.exs` (provider A
      disappears -> equivalent work re-executes under provider B with an
      identical receipt shape; anti-vacuity mutation variant)

      mix xaas.autonomy.stress                    # the whole suite
      mix xaas.autonomy.stress -- seeds=123       # args pass through to mix test

  Exit code is the suite's exit code (failures are failures; this task adds
  nothing on top of the courts).
  """

  use Mix.Task

  @suite_files ~w(
    test/xaas/ultracode/autonomy_stress_test.exs
    test/xaas/ultracode/provider_extinction_test.exs
  )

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    files = Enum.map(@suite_files, &Path.absname(&1, File.cwd!()))
    pass_through = Enum.join(args, " ")

    cmd = "mix test #{Enum.join(files, " ")} #{pass_through}"

    case Mix.shell().cmd(cmd, quiet: false) do
      0 ->
        Mix.shell().info("autonomy stress suite: all courts green")

      code ->
        Mix.shell().error("autonomy stress suite: FAILED (exit #{code})")
        System.halt(code)
    end
  end
end
