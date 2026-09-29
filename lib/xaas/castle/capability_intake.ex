defmodule Xaas.Castle.CapabilityIntake do
  @moduledoc """
  Runtime-readable CASTLE capability donor registry.

  The registry is deliberately side-effect free. It records which projected
  capabilities XaaS may wrap or absorb while preserving XaaS as the runtime
  crown and CASTLE as the consequence crown.
  """

  @projection_source "seanchatmangpt/ggen-ecosystem@50fdfa20c84205a80c6eb94e916cffbedc4b816e"
  @owner_capability "RUNTIME_EXISTENCE"
  @authority_ceiling :construct

  @donors [
    %{repository: "seanchatmangpt/zcode-cli", sha: "a568c3c3ee4b377e98fe9db0f37fa90da760734f", capability: :external_worker_provider, disposition: :wrap},
    %{repository: "seanchatmangpt/chatgpt-cloud-elixir", sha: "8efaa40b69c8162d22fe2dc5e59657f8dcff529e", capability: :model_provider_bridge, disposition: :wrap},
    %{repository: "seanchatmangpt/dteam", sha: "5c00d757ebc614e1db1dd0d564dd0c34896d57a0", capability: :capability_kernel_research, disposition: :candidate_absorb},
    %{repository: "seanchatmangpt/mcpp", sha: "5f5ee2175424c63edc6cdc211d3a5289a1c5556f", capability: :proof_carrying_work_runtime_research, disposition: :candidate_absorb}
  ]

  @spec projection_source() :: String.t()
  def projection_source, do: @projection_source

  @spec owner_capability() :: String.t()
  def owner_capability, do: @owner_capability

  @spec authority_ceiling() :: :construct
  def authority_ceiling, do: @authority_ceiling

  @spec donors() :: [map()]
  def donors, do: @donors

  @spec fetch(String.t()) :: {:ok, map()} | {:error, :unknown_castle_capability_donor}
  def fetch(repository) when is_binary(repository) do
    case Enum.find(@donors, &(&1.repository == repository)) do
      nil -> {:error, :unknown_castle_capability_donor}
      donor -> {:ok, donor}
    end
  end

  @spec consequence_authority?(String.t()) :: false
  def consequence_authority?(_repository), do: false
end
