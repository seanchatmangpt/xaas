defmodule Xaas.ResearchRuntime.IdentityWaveTest do
  @moduledoc false
  def case(subject_sha, source_id) when subject_sha == source_id, do: {:ok, :exact_identity}
  def case(subject_sha, source_id), do: {:refused, :boundary_violation}
end
