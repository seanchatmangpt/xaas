defmodule Mix.Tasks.Xaas.Wd.StogafReceipt do
  @moduledoc """
  Writes the deterministic WD CS2 STOGAF architecture receipt.

      STOGAF_SUBJECT_SHA=$(git rev-parse HEAD) mix xaas.wd.stogaf_receipt path.json
  """

  use Mix.Task

  alias Xaas.CaseStudies.WdFa.Stogaf.Receipt

  @shortdoc "Write WD CS2 STOGAF receipt"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    path = List.first(args) || "wd-cs2-stogaf-receipt.json"
    # W984gk: an empty-but-set STOGAF_SUBJECT_SHA crashed Receipt.build/1 with
    # FunctionClauseError (it requires a non-empty binary); treat it as unset.
    sha =
      case System.get_env("STOGAF_SUBJECT_SHA") do
        nil -> "UNKNOWN_SUBJECT_SHA"
        "" -> "UNKNOWN_SUBJECT_SHA"
        sha -> sha
      end
    receipt = Receipt.build(sha)

    File.write!(path, Jason.encode_to_iodata!(receipt, pretty: true))
    Mix.shell().info("STOGAF_RECEIPT=#{path}")
  end
end
