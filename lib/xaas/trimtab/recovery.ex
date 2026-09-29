defmodule Xaas.Trimtab.Recovery do
  alias Xaas.Trimtab.{Failure, ProviderSet}

  def next(ps, c, fs) do
    excluded = fs |> Enum.map(& &1.provider_id) |> MapSet.new()

    case ProviderSet.select(ps, c, excluded) do
      nil -> {:error, :no_lawful_provider}
      p -> {:ok, p}
    end
  end

  def record(fs, p, c, r) do
    with {:ok, f} <- Failure.new(p, c, r), do: {:ok, fs ++ [f]}
  end
end
