defmodule Mix.Tasks.Xaas.Semantic.Receipt do
  @shortdoc "Export the sealed receipt of a semantic-work Epoch for the graph reconciler"

  @moduledoc """
  Prints the receipt of a completed semantic-work Epoch in the contract
  `mix semantic_jira.xaas_receipt` consumes (see
  `Xaas.Ultracode.SemanticReceipt`):

      mix xaas.semantic.receipt --epoch EPOCH_ID [--out receipt.json]

  Exits non-zero, printing the typed reason, when the Epoch has no bridge, is
  not completed, or has no closing receipt.
  """

  use Mix.Task

  alias Xaas.Ultracode.SemanticReceipt

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args, strict: [epoch: :string, out: :string, help: :boolean])

    if opts[:help] do
      Mix.shell().info(Mix.Task.moduledoc(__MODULE__))
    else
      export(opts)
    end
  end

  defp export(opts) do
    epoch_id = opts[:epoch] || Mix.raise("--epoch EPOCH_ID is required")
    Mix.Task.run("app.start")

    case SemanticReceipt.export(epoch_id) do
      {:ok, export} ->
        json = Jason.encode!(export, pretty: true)
        if opts[:out], do: File.write!(opts[:out], json)
        Mix.shell().info(json)

      {:error, reason} ->
        Mix.raise("receipt export refused: #{inspect(reason)}")
    end
  end
end
