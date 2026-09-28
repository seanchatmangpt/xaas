defmodule Xaas.ResearchRuntime.QueryContract do
  @moduledoc false
  def admit(query_subject, source_subject) when query_subject == source_subject, do: {:ok, :query_admitted}
  def admit(query_subject, source_subject), do: {:refused, :boundary_violation}
end
