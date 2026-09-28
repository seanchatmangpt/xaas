defmodule Xaas.ResearchRuntime.EvidenceWaveTest do
  @moduledoc false
  def case(subject, evidence_subject) when subject != evidence_subject, do: {:ok, :refuse_cross_subject}
  def case(subject, evidence_subject), do: {:refused, :boundary_violation}
end
