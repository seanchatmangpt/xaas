defmodule Xaas.SelfDigest.Promotion do
  alias Xaas.SelfDigest.{Admission, Receipt, Replay, Shadow}

  def promote(work, shadow, evidence, reducer) do
    with {:ok, materialized} <- Shadow.materialize(shadow, reducer),
         {:admitted, _} <- Admission.evaluate(work.gap, evidence),
         receipt <-
           Receipt.seal(work.subject, work.id, shadow.base, materialized.result, evidence),
         {:ok, _} <- Replay.verify(receipt, fn item, acc -> reducer.({:evidence, item}, acc) end) do
      {:ok, materialized.result, receipt}
    else
      {:refused, reason} -> {:refused, reason}
      {:error, reason} -> {:refused, reason}
      other -> {:refused, {:promotion_failed, other}}
    end
  end
end
