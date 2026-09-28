defmodule Xaas.SelfDigest.Replay do
  def verify(receipt,reducer) do
    with true <- Xaas.SelfDigest.Receipt.replayable?(receipt),
         {:ok,out} <- Enum.reduce_while(receipt.evidence,{:ok,receipt.before},fn e,{:ok,a}->case reducer.(e,a) do {:ok,n}->{:cont,{:ok,n}}; {:error,r}->{:halt,{:error,r}} end end),
         true <- out==receipt.after, do: {:ok,out}, else: (false->{:error,:replay_mismatch}; e->e)
  end
  def chain(receipts), do: Enum.reduce_while(receipts,{:ok,nil},fn r,{:ok,p}->if r.previous==p,do:{:cont,{:ok,r.id}},else:{:halt,{:error,{:broken_chain,r.id}}} end)
end
