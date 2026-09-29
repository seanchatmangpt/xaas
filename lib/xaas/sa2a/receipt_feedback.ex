defmodule Xaas.Sa2a.ReceiptFeedback do
  @moduledoc """
  Projects an XaaS execution receipt into the SA2A receipt-feedback/replanning
  boundary without granting authority or performing DO.
  """

  alias Xaas.Sa2a.WaveOutcome

  def decision(receipt, provider \\ :xaas) when is_map(receipt) do
    normalized = %{
      semantic_subject: subject(receipt),
      receipt_id: value(receipt, :receipt_id) || value(receipt, :id),
      terminal_status: WaveOutcome.consequence(value(receipt, :outcome)),
      projection_digest: value(receipt, :projection_digest)
    }

    AshA2A.Replan.ReceiptFeedback.ingest(normalized, provider)
  end

  defp subject(receipt),
    do:
      value(receipt, :semantic_subject) ||
        value(receipt, :subject) ||
        value(receipt, :exact_subject)

  defp value(map, key), do: Map.get(map, key, Map.get(map, Atom.to_string(key)))
end
