defmodule Xaas.Trimtab.Consumer do
  alias Xaas.Trimtab.{SteeringPolicy,SteeringSignal}
  def request(w,%SteeringSignal{}=s,a,p) do
    with {:ok,_}<-SteeringPolicy.admit(s,w,a), do: {:ok,%{subject: w.subject.digest,context: Enum.map(w.observations,& &1.digest),objective: s.objective,action: a,payload: p}}
  end
end