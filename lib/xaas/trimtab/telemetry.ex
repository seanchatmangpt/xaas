defmodule Xaas.Trimtab.Telemetry do
  @prefix [:xaas, :trimtab]
  def emit(e, m \\ %{}, md \\ %{}), do: :telemetry.execute(@prefix ++ [e], m, md)
  def prefix, do: @prefix
end
