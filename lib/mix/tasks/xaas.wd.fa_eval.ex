defmodule Mix.Tasks.Xaas.Wd.FaEval do
  @moduledoc """
  Writes the repository-local WD CS2 offline evaluation report.
  """

  use Mix.Task

  alias Xaas.CaseStudies.WdFa.Evaluation

  @shortdoc "Write WD CS2 offline evaluation report"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    path = List.first(args) || "wd-cs2-evaluation.json"
    File.write!(path, Jason.encode_to_iodata!(Evaluation.offline_report(), pretty: true))
    Mix.shell().info("WD_FA_EVALUATION=#{path}")
  end
end
