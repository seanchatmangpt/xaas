defmodule Xaas.Trimtab.Standing do
  def derive(rs,n) when n>0 do
    observed=rs |> Enum.map(& &1.id) |> Enum.uniq() |> length()
    if observed>=n,do: {:alive,%{observed: observed,required: n}},else: {:partial,%{observed: observed,required: n}}
  end
end