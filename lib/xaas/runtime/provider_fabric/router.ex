defmodule Xaas.Runtime.ProviderFabric.Router do
  @moduledoc "Provider fabric router primitive."
  defstruct attempted: []
  def record(r, id), do: %{r | attempted: r.attempted ++ [id]}
end
