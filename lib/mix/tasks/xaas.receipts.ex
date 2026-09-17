defmodule Mix.Tasks.Xaas.Receipts do
  @moduledoc """
  Real operator read path onto `Xaas.Ultracode.Receipt` that does not go
  through `Ash.read!(authorize?: false)` (the test-only escape hatch this
  fix closes -- see that resource's moduledoc's "Real lawful read path"
  section). Calls the same lawfully-authorized `:for_epoch` action the
  `GET /internal-api/execution/epochs/:epoch_id/receipts` HTTP route uses,
  via the resource's own `code_interface`, so an operator can inspect
  sealed receipts from `iex`/`mix` through the same real Ash policy path a
  production caller would use -- not a parallel, unauthorized shortcut.

  Usage:

      mix xaas.receipts <epoch_id>

  Prints every sealed Receipt for that Epoch (outcome, sealed_at, subject,
  evidence), newest first, or a clear message if none exist / the id is
  not a valid UUID.
  """
  use Mix.Task

  @shortdoc "List sealed receipts for one Epoch via the real, authorized Ash read path"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [epoch_id | _] -> list(epoch_id)
      [] -> Mix.raise("usage: mix xaas.receipts <epoch_id>")
    end
  end

  defp list(epoch_id) do
    case Xaas.Ultracode.Receipt.for_epoch(epoch_id) do
      {:ok, []} ->
        Mix.shell().info("No receipts found for epoch #{epoch_id}.")

      {:ok, receipts} ->
        Mix.shell().info("#{length(receipts)} receipt(s) for epoch #{epoch_id}:\n")

        Enum.each(receipts, fn receipt ->
          Mix.shell().info("""
          id:        #{receipt.id}
          outcome:   #{receipt.outcome}
          subject:   #{receipt.subject}
          sealed_at: #{receipt.sealed_at}
          evidence:  #{inspect(receipt.evidence)}
          """)
        end)

      {:error, reason} ->
        Mix.shell().error("Could not read receipts for #{inspect(epoch_id)}: #{inspect(reason)}")
    end
  end
end
