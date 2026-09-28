defmodule Xaas.ResearchRuntime.ExactSubject do
  @moduledoc false
  def bind(subject_sha, source_id, epoch) when subject_sha != nil and source_id != nil, do: {:ok, %{subject_sha: subject_sha, source_id: source_id, epoch: epoch}}
  def bind(subject_sha, source_id, epoch), do: {:refused, :boundary_violation}
end
