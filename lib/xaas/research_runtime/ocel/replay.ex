defmodule Xaas.ResearchRuntime.Replay do
  @moduledoc false
  def verify(receipt, subject) when receipt.subject == subject and receipt.replayable, do: {:ok, :replay_admitted}
  def verify(receipt, subject), do: {:refused, :boundary_violation}
end
