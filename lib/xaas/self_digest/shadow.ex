defmodule Xaas.SelfDigest.Shadow do
  @enforce_keys [:subject,:base]
  defstruct [:subject,:base,operations:[],result:nil,status: :open]
  def open(subject,base), do: %__MODULE__{subject:subject,base:base}
  def append(%__MODULE__{status: :open}=s,op), do: %{s|operations:s.operations++[op]}
  def materialize(%__MODULE__{status: :open}=s,reducer) do
    case Enum.reduce_while(s.operations,{:ok,s.base},fn op,{:ok,acc}->case reducer.(op,acc) do {:ok,n}->{:cont,{:ok,n}}; {:error,r}->{:halt,{:error,r}} end end) do
      {:ok,result}->{:ok,%{s|result:result,status: :materialized}}
      {:error,r}->{:error,%{s|status:{:refused,r}}}
    end
  end
end
