defmodule Xaas.SelfDigest.Replay do
  def verify(receipt, reducer) do
    with true <- Xaas.SelfDigest.Receipt.replayable?(receipt),
         {:ok, output} <-
           Enum.reduce_while(receipt.evidence, {:ok, receipt.before}, fn evidence, {:ok, acc} ->
             case reducer.(evidence, acc) do
               {:ok, next} -> {:cont, {:ok, next}}
               {:error, reason} -> {:halt, {:error, reason}}
             end
           end),
         true <- output == receipt.after do
      {:ok, output}
    else
      false -> {:error, :replay_mismatch}
      error -> error
    end
  end

  def chain(receipts) do
    Enum.reduce_while(receipts, {:ok, nil}, fn receipt, {:ok, previous} ->
      if receipt.previous == previous do
        {:cont, {:ok, receipt.id}}
      else
        {:halt, {:error, {:broken_chain, receipt.id}}}
      end
    end)
  end
end
