defmodule Xaas.Trimtab.Epoch do
  @enforce_keys [:id,:subject_digest]; defstruct [:id,:subject_digest,status: :open,receipts:[],failures:[]]
  def add_receipt(%__MODULE__{status: :open}=e,r), do: {:ok,%{e|receipts:e.receipts++[r]}}
  def add_receipt(_,_), do: {:error,:epoch_closed}
  def close(e), do: %{e|status: :closed}
end