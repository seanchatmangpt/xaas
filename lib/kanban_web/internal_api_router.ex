defmodule KanbanWeb.InternalApiRouter do
  @moduledoc """
  Narrow AshJsonApi router for internal Operations resources.

  The parent Phoenix router applies `RequireInternalApiToken` before forwarding
  here. Only explicitly declared resource routes are served; controller, SPARQL,
  and AshTypescript RPC paths are registered before this catch-all forward.
  """

  use AshJsonApi.Router,
    domains: [Xaas.Operations],
    prefix: "/internal-api"
end
