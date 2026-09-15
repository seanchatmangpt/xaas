defmodule Xaas.SystemAuthority do
  @moduledoc """
  Internal-system actor used by XAAS-2601/XAAS-2602 authorization checks.

  Authority is intentionally a closed vocabulary, not an arbitrary label.
  `Xaas.Checks.SystemActor` maps each protected action to exactly one admitted
  service, so the `service` field is load-bearing capability data rather than
  audit-only decoration.

  Cross-service handoff is also closed. A caller may not manufacture a second
  service identity ad hoc; `delegate/2` admits only declared delegation edges.
  This remains an application-level capability inside the trusted BEAM VM, not
  a cryptographic or OS isolation primitive.
  """

  @services [
    :ultracode_reactor,
    :webhook_dispatcher,
    :oban_scheduler,
    :internal_api,
    :autofde_coverage_monitor
  ]
  @delegations %{
    oban_scheduler: [:webhook_dispatcher]
  }

  @enforce_keys [:service]
  defstruct [:service]

  @type service ::
          :ultracode_reactor
          | :webhook_dispatcher
          | :oban_scheduler
          | :internal_api
          | :autofde_coverage_monitor
  @type t :: %__MODULE__{service: service()}

  @doc "Returns the closed internal-service vocabulary admitted by this authority type."
  @spec services() :: [service()]
  def services, do: @services

  @doc "Builds a root system authority actor for a known internal service."
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

  @doc "Delegates an admitted authority only across a declared service edge."
  @spec delegate(term(), term()) ::
          {:ok, t()} | {:error, {:authority_delegation_refused, term(), term()}}
  def delegate(%__MODULE__{service: source} = authority, target) do
    allowed_targets = Map.get(@delegations, source, [])

    if system?(authority) and target in allowed_targets do
      {:ok, %__MODULE__{service: target}}
    else
      {:error, {:authority_delegation_refused, source, target}}
    end
  end

  def delegate(other, target) do
    {:error, {:authority_delegation_refused, other, target}}
  end
end
