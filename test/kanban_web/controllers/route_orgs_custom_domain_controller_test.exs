defmodule KanbanWeb.RouteOrgsCustomDomainControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/route_orgs_custom_domain` POST/PATCH routes, real Ash-persisted
  rows in the real sandboxed Postgres (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  require Ash.Query

  alias Xaas.Platform.RouteOrgsCustomDomain

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

  test "POST creates a real custom domain record with a valid hostname", %{conn: conn} do
    org_id = "org-#{System.unique_integer([:positive])}"
    hostname = "console.customer-#{System.unique_integer([:positive])}.com"

    create_body = %{
      "data" => %{
        "type" => "route_orgs_custom_domain",
        "attributes" => %{
          "org_id" => org_id,
          "hostname" => hostname
        }
      }
    }

    create_resp = conn |> json_headers() |> post("/api/route_orgs_custom_domain", create_body)
    created = json_response(create_resp, 201)
    id = created["data"]["id"]

    assert created["data"]["attributes"]["org_id"] == org_id
    assert created["data"]["attributes"]["hostname"] == hostname
    assert created["data"]["attributes"]["status"] == "pending"

    persisted = RouteOrgsCustomDomain |> Ash.get!(id, authorize?: false)
    assert persisted.org_id == org_id
    assert persisted.hostname == hostname
    assert persisted.status == "pending"
  end

  test "PATCH updates status and certificate fields", %{conn: conn} do
    org_id = "org-u-#{System.unique_integer([:positive])}"
    hostname = "app.customer-#{System.unique_integer([:positive])}.com"

    domain =
      RouteOrgsCustomDomain
      |> Ash.Changeset.for_create(:create, %{org_id: org_id, hostname: hostname})
      |> Ash.create!(authorize?: false)

    update_body = %{
      "data" => %{
        "type" => "route_orgs_custom_domain",
        "id" => domain.id,
        "attributes" => %{
          "status" => "active",
          "certificate_secret_name" => "tls-secret-#{domain.id}",
          "certificate_reason" => "Issued",
          "certificate_message" => "Certificate issued successfully"
        }
      }
    }

    update_resp =
      conn |> json_headers() |> patch("/api/route_orgs_custom_domain/#{domain.id}", update_body)

    updated = json_response(update_resp, 200)
    assert updated["data"]["attributes"]["status"] == "active"
    assert updated["data"]["attributes"]["certificate_reason"] == "Issued"

    persisted = RouteOrgsCustomDomain |> Ash.get!(domain.id, authorize?: false)
    assert persisted.status == "active"
    assert persisted.certificate_secret_name == "tls-secret-#{domain.id}"
    assert persisted.certificate_reason == "Issued"
    assert persisted.certificate_message == "Certificate issued successfully"
  end

  test "POST rejects an invalid hostname (fewer than two DNS labels)", %{conn: conn} do
    org_id = "org-bad-#{System.unique_integer([:positive])}"

    create_body = %{
      "data" => %{
        "type" => "route_orgs_custom_domain",
        "attributes" => %{
          "org_id" => org_id,
          "hostname" => "not-a-valid-hostname"
        }
      }
    }

    resp = conn |> json_headers() |> post("/api/route_orgs_custom_domain", create_body)
    assert resp.status == 400

    count =
      RouteOrgsCustomDomain
      |> Ash.Query.filter(org_id == ^org_id)
      |> Ash.count!(authorize?: false)

    assert count == 0
  end
end
