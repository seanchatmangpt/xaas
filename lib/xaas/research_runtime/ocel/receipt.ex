defmodule Xaas.ResearchRuntime.Receipt do
  @moduledoc false
  def seal(subject, transition) when subject != nil and transition != nil, do: {:ok, %{subject: subject, transition: transition, replayable: true}}
  def seal(subject, transition), do: {:refused, :boundary_violation}
end
