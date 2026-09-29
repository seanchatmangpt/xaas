defmodule Xaas.Trimtab.AuthorityFence do
  @allowed [:observe, :construct, :recommend]
  def admit(a) when a in @allowed, do: {:ok, a}
  def admit(:do), do: {:error, :consequential_do_forbidden}
  def admit(_), do: {:error, :unknown_action}
end
