defmodule Xaas.Trimtab.Falsifier do
  alias Xaas.Trimtab.Evidence
  def evaluate(%Evidence{falsifier:nil}), do: :not_falsified
  def evaluate(%Evidence{falsifier:f,witness:w}) when is_function(f,1), do: if(f.(w),do: :falsified,else: :not_falsified)
  def evaluate(%Evidence{falsifier:f,witness:w}), do: if(f==w,do: :falsified,else: :not_falsified)
end