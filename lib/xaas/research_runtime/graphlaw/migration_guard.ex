defmodule Xaas.ResearchRuntime.MigrationGuard do
  @moduledoc false
  def admit(before, after) when Map.get(before, :subject) == Map.get(after, :subject), do: {:ok, :subject_preserved}
  def admit(before, after), do: {:refused, :boundary_violation}
end
