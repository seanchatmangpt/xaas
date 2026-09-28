defmodule Xaas.ResearchRuntime.FederationWaveTest do
  @moduledoc false
  def case(query_subject, source_subject) when query_subject != source_subject, do: {:ok, :refuse_misbinding}
  def case(query_subject, source_subject), do: {:refused, :boundary_violation}
end
