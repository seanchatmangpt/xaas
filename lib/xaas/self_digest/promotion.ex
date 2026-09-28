defmodule Xaas.SelfDigest.Promotion do
  alias Xaas.SelfDigest.{Admission,Receipt,Replay}
  def promote(work,shadow,evidence,reducer) do
    with {:ok,materialized} <- Xaas.SelfDigest.Shadow.materialize(shadow,reducer),
         {:admitted,_} <- Admission.evaluate(work.gap,evidence),
         receipt <- Receipt.seal(work.subject,work.id,shadow.base,materialized.result,evidence),
         {:ok,_} <- Replay.verify(receipt,fn e,acc -> reducer.({:evidence,e},acc) end) do
      {:ok,materialized.result,receipt}
    else
      {:refused,r}->{:refused,r}
      {:error,r}->{:refused,r}
      other->{:refused,{:promotion_failed,other}}
    end
  end
end
