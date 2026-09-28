defmodule Xaas.ResearchRuntime.SourceBinding do
  @moduledoc false
  def bind(source_id, subject_sha) when source_id != nil and subject_sha != nil, do: {:ok, %{source_id: source_id, subject_sha: subject_sha}}
  def bind(source_id, subject_sha), do: {:refused, :boundary_violation}
end
