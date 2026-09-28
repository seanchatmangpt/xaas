defmodule Xaas.Trimtab.ZcodeAdapter do
  def encode(%{subject:s,objective:o}=r), do: {:ok,%{protocol:"zcode.trimtab.v1",subject:s,objective:o,action:Map.get(r,:action),payload:Map.get(r,:payload)}}
  def encode(_), do: {:error,:invalid_request}
end