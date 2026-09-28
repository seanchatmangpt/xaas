defmodule Xaas.Runtime.Provider do
  @moduledoc """
  Behaviour for substitutable runtime providers.

  Providers expose capability membership separately from execution so routing can
  remain deterministic and provider-specific failures stay outside planner logic.
  """

  @type capability :: atom()
  @type context :: map()
  @type result :: {:ok, term()} | {:error, term()}

  @callback capabilities() :: [capability()]
  @callback execute(capability(), term(), context()) :: result()
  @callback health(context()) :: :healthy | :degraded | {:unavailable, term()}

  def supports?(provider, capability) when is_atom(provider) and is_atom(capability) do
    capability in provider.capabilities()
  end
end
