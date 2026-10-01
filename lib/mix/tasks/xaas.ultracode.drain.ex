defmodule Mix.Tasks.Xaas.Ultracode.Drain do
  @shortdoc "Sequenced ultracode drain: wave -> merge into canonical -> verify -> next wave"

  @moduledoc """
  Runs `Xaas.Ultracode.SequencedDrain`: each batch of open tickets is worked by one wave,
  its integration branch is merged into the canonical checkout and verified BEFORE the next
  wave starts. Stops (typed) on conflict, build break, test failure, or a stuck ticket.

      mix xaas.ultracode.drain
      mix xaas.ultracode.drain --batch 3 --max-batches 12 --pattern 'jira-xa-30[0-9][0-9]-'

  The xaas server must be running with `INTERNAL_API_TOKEN` equal to the xaas-fabric plugin's
  token (workers claim and close leases over the `xaas-execution` MCP endpoint).
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [
          batch: :integer,
          max_batches: :integer,
          pattern: :string,
          repo: :string,
          canonical: :string
        ]
      )

    unless invalid == [], do: Mix.raise("invalid arguments: #{inspect(invalid)}")
    Mix.Task.run("app.start")

    drain_opts =
      [
        repo_alias: opts[:repo] || "xaas",
        canonical: opts[:canonical] || File.cwd!(),
        batch_size: opts[:batch] || 3,
        max_batches: opts[:max_batches] || 12,
        pattern: opts[:pattern] || "jira-xa-30[0-9][0-9]-"
      ]

    case Xaas.Ultracode.SequencedDrain.drain(drain_opts) do
      {:ok, {status, batches}} ->
        Enum.with_index(batches, 1)
        |> Enum.each(fn {ids, i} -> Mix.shell().info("batch #{i}: #{Enum.join(ids, ",")}") end)

        Mix.shell().info("#{status}")

      {:error, {:halted, reason, batches}} ->
        Enum.with_index(batches, 1)
        |> Enum.each(fn {ids, i} -> Mix.shell().info("batch #{i}: #{Enum.join(ids, ",")}") end)

        Mix.raise("drain halted: #{inspect(reason, limit: 8)}")
    end
  end
end
