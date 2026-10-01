defmodule Xaas.Fabric.Registry do
  @moduledoc """
  Resolves `capability://` URIs to qualified realizations (modules). Pure value; no repository
  names anywhere. QRI is checked at registration.
  """

  alias Xaas.Fabric.Contract

  defstruct by_uri: %{}
  @type t :: %__MODULE__{by_uri: %{String.t() => [module()]}}

  def new, do: %__MODULE__{}

  @spec register(t(), module()) :: {:ok, t()} | {:error, String.t()}
  def register(%__MODULE__{} = reg, mod) do
    %Contract{uri: uri} = contract = mod.describe()

    cond do
      not String.starts_with?(uri, "capability://") ->
        {:error, "REFUSED:CONTRACT_URI_INVALID"}

      qri_mismatch?(reg, uri, contract) ->
        {:error, "REFUSED:QRI_CONTRACT_MISMATCH"}

      true ->
        {:ok, %{reg | by_uri: Map.update(reg.by_uri, uri, [mod], &(&1 ++ [mod]))}}
    end
  end

  defp qri_mismatch?(reg, uri, contract) do
    case Map.get(reg.by_uri, uri, []) do
      [first | _] -> Contract.qri_key(first.describe()) != Contract.qri_key(contract)
      [] -> false
    end
  end

  def contracts(%__MODULE__{by_uri: m}, uri), do: m |> Map.get(uri, []) |> Enum.map(& &1.describe())

  @doc "Healthy realizations in registration order."
  def resolve(%__MODULE__{by_uri: m}, uri),
    do: m |> Map.get(uri, []) |> Enum.filter(&(&1.health() == :ok))
end
