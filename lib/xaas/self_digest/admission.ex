defmodule Xaas.SelfDigest.Admission do
  alias Xaas.SelfDigest.{Evidence, Gap}

  def evaluate(%Gap{} = gap, evidence) do
    exact = Enum.filter(evidence, &Evidence.same_subject?(&1, gap.subject))

    cond do
      exact == [] -> {:refused, :no_exact_subject_evidence}
      falsified?(gap, exact) -> {:refused, :falsified}
      true -> {:admitted, Gap.admit(gap, exact)}
    end
  end

  defp falsified?(%Gap{falsifier: f}, evidence) when is_function(f, 1),
    do: Enum.any?(evidence, f)

  defp falsified?(_, _), do: false
end
