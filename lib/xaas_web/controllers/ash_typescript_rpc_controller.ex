defmodule XaasWeb.AshTypescriptRpcController do
  @moduledoc """
  Authenticated HTTP adapter for the AshTypescript RPC surface.

  The router places both endpoints behind `RequireInternalApiToken`. The
  controller delegates action admission/execution to AshTypescript and does not
  create an independent authority path.
  """

  use XaasWeb, :controller

  def run(conn, params) do
    conn
    |> json(AshTypescript.Rpc.run_action(:xaas, conn, params))
  end

  def validate(conn, params) do
    conn
    |> json(AshTypescript.Rpc.validate_action(:xaas, conn, params))
  end
end
