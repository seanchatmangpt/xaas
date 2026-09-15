defmodule Xaas.SystemAuthority do
  @moduledoc """
  Internal-system actor used by XAAS-2601 authorization checks.

  Authority is intentionally a closed vocabulary, not an arbitrary label.
  `Xaas.Checks.SystemActor` maps each protected action to exactly one admitted
  service, so the `service` field is load-bearing capability data rather than
  audit-only decoration.
  """

  @services [:ultracode_reactor, :webhook_dispatcher, :oban_scheduler]

  @enforce_keys [:service]
  defstruct [:service]

  @type service :: :ultracode_reactor | :webhook_dispatcher | :oban_scheduler
  @type t :: %__MODULE__{service: service()}

  @doc "Returns the closed internal-service vocabulary admitted by this authority type."
  @spec services() :: [service()]
  def services, do: @services

  @doc "Builds a system authority actor for a known internal service."
  @spec new(service()) :: t()
  def new(service) when service in @services, do: %__MODULE__{service: service}

  def new(service) do
    raise ArgumentError,
          "unknown Xaas.SystemAuthority service #{inspect(service)}; expected one of #{inspect(@services)}"
  end

  @doc "True only for a system authority carrying an admitted service value."
  @spec system?(term()) :: boolean()
  def system?(%__MODULE__{service: service}) when service in @services, do: true
  def system?(_other), do: false
end
