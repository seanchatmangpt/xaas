defmodule Xaas.Trimtab.ProviderAdapter do
  alias Xaas.Trimtab.Provider

  def invoke(%Provider{module: m} = p, r, opts \\ []) do
    try do
      case m.run(r, opts) do
        {:ok, v} -> {:ok, %{provider: p.id, value: v}}
        {:error, x} -> {:error, {:provider_error, p.id, x}}
        x -> {:error, {:invalid_provider_result, p.id, x}}
      end
    rescue
      e -> {:error, {:provider_crash, p.id, e.__struct__, Exception.message(e)}}
    end
  end
end
