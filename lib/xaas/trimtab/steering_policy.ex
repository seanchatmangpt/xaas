defmodule Xaas.Trimtab.SteeringPolicy do
  alias Xaas.Trimtab.{AuthorityFence,SteeringSignal}
  def admit(%SteeringSignal{}=s,w,a) do
    with true <- s.subject_digest==w.subject.digest || {:error,:subject_mismatch},
         {:ok,_} <- AuthorityFence.admit(a),
         false <- Enum.member?(s.exclusions,a) || {:error,:excluded_action}, do: {:ok,%{signal:s,context:w,action:a}}
  end
end