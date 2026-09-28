defmodule Xaas.Trimtab.Admission do
  alias Xaas.Trimtab.{Evidence,Falsifier,Subject}
  def evaluate(%Subject{digest:d},es) do
    exact=Enum.filter(es,&match?(%Evidence{subject_digest: ^d},&1))
    cond do exact==[]->{:refused,:no_exact_subject_evidence}; Enum.any?(exact,&(Falsifier.evaluate(&1)==:falsified))->{:refused,:falsified}; true->{:admitted,exact} end
  end
end