defmodule KanbanWeb.RouteSecretsControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/route_secrets` POST/DELETE routes, real Ash-persisted rows in
  the real sandboxed Postgres (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Platform.RouteSecrets

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp json_headers(conn) do
    conn
    |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    |> put_req_header("content-type", "application/vnd.api+json")
    |> put_req_header("accept", "application/vnd.api+json")
  end

  test "POST creates a real secret metadata row", %{conn: conn} do
    namespace = "ns-#{System.unique_integer([:positive])}"

    create_body = %{
      "data" => %{
        "type" => "route_secrets",
        "attributes" => %{
          "namespace" => namespace,
          "name" => "db-credentials",
          "requested_by" => "requester-1"
        }
      }
    }

    create_resp = conn |> json_headers() |> post("/api/route_secrets", create_body)
    created = json_response(create_resp, 201)
    id = created["data"]["id"]

    persisted = RouteSecrets |> Ash.get!(id, authorize?: false)
    assert persisted.namespace == namespace
    assert persisted.name == "db-credentials"
    assert persisted.requested_by == "requester-1"
  end

  test "DELETE destroys a real secret metadata row", %{conn: conn} do
    namespace = "ns-#{System.unique_integer([:positive])}"

    change =
      RouteSecrets
      |> Ash.Changeset.for_create(:create, %{
        namespace: namespace,
        name: "db-credentials",
        requested_by: "requester-1"
      })
      |> Ash.create!(authorize?: false)

    delete_resp = conn |> json_headers() |> delete("/api/route_secrets/#{change.id}")
    assert delete_resp.status == 200

    assert {:error, _} = RouteSecrets |> Ash.get(change.id, authorize?: false)
  end

  test "rejects requests without the internal API token", %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "route_secrets",
        "attributes" => %{
          "namespace" => "ns-unauth",
          "name" => "db-credentials",
          "requested_by" => "requester-1"
        }
      }
    }

    resp =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> put_req_header("accept", "application/vnd.api+json")
      |> post("/api/route_secrets", create_body)

    assert resp.status == 401
  end
end
