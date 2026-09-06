defmodule KanbanWeb.GgenWorkbenchController do
  @moduledoc """
  Authenticated HTTP front door for the private Fly GGen workbench.

  `/api/workbench/ggen` is intentionally a construction surface, not a shell
  or an actuation surface. `Xaas.Workbench.GgenClient` admits a bounded
  `ggen` argv vector and ephemeral file bundle, then forwards it to the
  private worker. The worker repeats admission and returns an exact execution
  receipt plus manufactured artifacts.

  Every workbench response advertises the canonical AsyncAPI 3.1 service
  description through the registered `service-desc` Web Link relation.
  """

  use KanbanWeb, :controller

  alias Xaas.Workbench.GgenClient

  @asyncapi_link ~s(</asyncapi.yaml>; rel="service-desc"; type="application/yaml")

  def run(conn, params) do
    conn = advertise_contract(conn)

    case GgenClient.run(params) do
      {:ok, body} ->
        json(conn, body)

      {:error, {:refused, code, detail}} ->
        status =
          if code in ["WORKBENCH_NOT_CONFIGURED", "WORKBENCH_TOKEN_MISSING"],
            do: 503,
            else: 422

        conn
        |> put_status(status)
        |> json(%{
          standing: "REFUSED[#{code}]",
          refused: true,
          detail: detail
        })

      {:error, {:upstream, status, body}} when status in 400..599 ->
        conn
        |> put_status(status)
        |> json(body)

      {:error, reason} ->
        conn
        |> put_status(502)
        |> json(%{
          standing: "BLOCKED",
          blocked: true,
          detail: inspect(reason)
        })
    end
  end

  def health(conn, _params) do
    conn = advertise_contract(conn)

    case GgenClient.health() do
      {:ok, body} ->
        json(conn, body)

      {:error, {:refused, code, detail}} ->
        conn
        |> put_status(503)
        |> json(%{
          standing: "REFUSED[#{code}]",
          refused: true,
          detail: detail
        })

      {:error, {:upstream, status, body}} when status in 400..599 ->
        conn
        |> put_status(status)
        |> json(body)

      {:error, reason} ->
        conn
        |> put_status(502)
        |> json(%{
          standing: "BLOCKED",
          blocked: true,
          detail: inspect(reason)
        })
    end
  end

  defp advertise_contract(conn), do: put_resp_header(conn, "link", @asyncapi_link)
end
