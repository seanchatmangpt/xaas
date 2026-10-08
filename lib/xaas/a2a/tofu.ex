defmodule Xaas.A2a.Tofu do
  @moduledoc """
  Trust-on-first-use (TOFU) pinning for the A2A agent-card trust surface (W784).

  First sighting of a card pins its fingerprint (SHA-256 over the card's
  canonical JSON). Every subsequent sighting of the same card name must
  present the pin: a card that changed under an unchanged name (rotated
  endpoint, swapped interface binding, tampered description, …) refuses with
  a typed `:pin_mismatch` error. First use pins; later mismatch refuses.
  Re-pinning is never silent — `repin/1` is a separate, explicit operation.

  Pins live in a named public ETS table (`__MODULE__`), so the surface is
  real in-process state; the court asserts on table contents as final state,
  Chicago-style. `reset/0` exists for tests and operator tooling only.
  """

  @table __MODULE__

  defmodule Error do
    @moduledoc "Typed TOFU verification error."
    defexception([:reason, :detail])

    @type t :: %__MODULE__{reason: :pin_mismatch | :invalid_card, detail: term}

    def message(%__MODULE__{reason: reason, detail: detail}) do
      "agent-card TOFU refused (#{reason}): #{inspect(detail)}"
    end
  end

  @doc """
  TOFU-verify a decoded agent card (map). First sighting pins; same
  fingerprint passes; changed fingerprint refuses. Returns `{:ok, :pinned}`,
  `{:ok, :unchanged}`, or `{:error, %Error{}}`.
  """
  @spec verify(map()) :: {:ok, :pinned | :unchanged} | {:error, Error.t()}
  def verify(card) when is_map(card) do
    with :ok <- validate(card) do
      name = card["name"]
      fp = fingerprint(card)

      case get_pin(name) do
        nil ->
          :ets.insert(@table, {name, fp})
          {:ok, :pinned}

        ^fp ->
          {:ok, :unchanged}

        _changed ->
          {:error, %Error{reason: :pin_mismatch, detail: %{name: name, observed: fp}}}
        end
    end
  end

  @doc "TOFU-verify, then ingest through the real catalog seam on success."
  @spec verify_and_ingest(map()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  def verify_and_ingest(card) when is_map(card) do
    case verify(card) do
      {:ok, _} -> Xaas.A2a.Catalog.ingest(card)
      {:error, %Error{reason: :pin_mismatch} = e} -> {:error, e}
    end
  end

  @doc """
  The pinned fingerprint for `name`, if any. Reading the real pin state.
  """
  @spec pin_for(String.t()) :: String.t() | nil
  def pin_for(name) when is_binary(name) do
    case get_pin(name) do
      nil -> nil
      fp -> fp
    end
  end

  @doc """
  Explicit re-pin: overwrite the pin even when the fingerprint changed.
  The only lawful rotation path; never invoked by `verify/1`.
  """
  @spec repin(map()) :: {:ok, String.t()} | {:error, Error.t()}
  def repin(card) when is_map(card) do
    with :ok <- validate(card) do
      fp = fingerprint(card)
      :ets.insert(@table, {card["name"], fp})
      {:ok, fp}
    end
  end

  @doc "Test/operator reset: drop the whole pin table."
  @spec reset() :: true
  def reset, do: :ets.delete_all_objects(ensure_table())

  # -- internals -------------------------------------------------------------

  defp validate(card) do
    if is_binary(card["name"]) and is_binary(card["description"]) and is_binary(card["url"]) do
      :ok
    else
      {:error, %Error{reason: :invalid_card, detail: {:bad_field_types, card["name"]}}}
    end
  end

  defp get_pin(name) do
    table = ensure_table()

    case :ets.lookup(table, name) do
      [{^name, fp}] -> fp
      [] -> nil
    end
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      try do
        :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
      rescue
        ArgumentError -> :ok
      end
    end

    @table
  end

  defp fingerprint(card) when is_map(card) do
    card
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
