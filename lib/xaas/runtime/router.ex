defmodule Xaas.Runtime.Router do
  alias Xaas.Runtime.ProviderRegistry

  def execute(capability, input, context \\ %{}) do
    ProviderRegistry.candidates(capability)
    |> route(capability, input, context, [])
  end

  defp route([], capability, _input, _context, attempts),
    do: {:error, :no_provider, %{capability: capability, attempts: Enum.reverse(attempts), selected: nil}}

  defp route([entry | rest], capability, input, context, attempts) do
    provider = entry.provider
    outcome =
      try do
        provider.execute(capability, input, context)
      rescue
        error -> {:error, {:provider_exception, error.__struct__}}
      catch
        kind, reason -> {:error, {:provider_failure, kind, reason}}
      end

    case outcome do
      {:ok, value} ->
        ProviderRegistry.report(provider, :ok)
        {:ok, value, %{capability: capability, selected: provider,
          attempts: Enum.reverse([%{provider: provider, outcome: :ok} | attempts])}}
      {:error, reason} ->
        ProviderRegistry.report(provider, {:error, reason})
        route(rest, capability, input, context, [%{provider: provider, outcome: {:error, reason}} | attempts])
      other ->
        reason = {:invalid_result, other}
        ProviderRegistry.report(provider, {:error, reason})
        route(rest, capability, input, context, [%{provider: provider, outcome: {:error, reason}} | attempts])
    end
  end
end
