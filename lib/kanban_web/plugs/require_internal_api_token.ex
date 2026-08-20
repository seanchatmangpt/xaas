defmodule KanbanWeb.Plugs.RequireInternalApiToken do
  @moduledoc """
  Real auth gate for `/internal-api` and `/api` (found genuinely missing
  by an adversarial review of this session's work: both prefixes had
  zero auth plug, reachable by anyone with network access to the host).

  Requires a real, constant-time-compared bearer token
  (`Authorization: Bearer <token>`) matching `INTERNAL_API_TOKEN` (real
  env var, same pattern as `DEV_DB_PASSWORD`/`CLOAK_KEY` elsewhere in
  this repo -- never hardcoded, never committed). If the env var itself
  is unset, every request is real-rejected with 503 (fail closed, not
  fail open) rather than silently allowing everyone through because an
  operator forgot to set it.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case System.get_env("INTERNAL_API_TOKEN") do
      nil ->
        conn
        |> put_status(503)
        |> Phoenix.Controller.json(%{
          error: "internal_api_misconfigured",
          detail: "INTERNAL_API_TOKEN is not set on the server"
        })
        |> halt()

      expected_token ->
        case get_req_header(conn, "authorization") do
          ["Bearer " <> token] when byte_size(token) > 0 ->
            if Plug.Crypto.secure_compare(token, expected_token) do
              conn
            else
              unauthorized(conn)
            end

          _ ->
            unauthorized(conn)
        end
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(401)
    |> Phoenix.Controller.json(%{error: "unauthorized", detail: "missing or invalid Bearer token"})
    |> halt()
  end
end
