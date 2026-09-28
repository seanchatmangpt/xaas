defmodule Xaas.ResearchRuntime.EvidenceAdmission do
  @moduledoc false
  def admit(subject, evidence_subject) when subject == evidence_subject, do: {:ok, :admitted}
  def admit(subject, evidence_subject), do: {:refused, :boundary_violation}
end
