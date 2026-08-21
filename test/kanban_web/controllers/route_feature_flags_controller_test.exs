defmodule KanbanWeb.RouteFeatureFlagsControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/route_feature_flags` POST/PATCH routes, real Ash-persisted rows
  in the real sandboxed Postgres (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Platform.RouteFeatureFlags

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp json_headers(conn) do
    conn
    |> with_internal_api_token()
    |> put_req_header("content-type", "application/vnd.api+json")
    |> put_req_header("accept", "application/vnd.api+json")
  end

  test "POST creates a real feature flag", %{conn: conn} do
    flag_key = "checkout-v2-#{System.unique_integer([:positive])}"

    create_body = %{
      "data" => %{
        "type" => "route_feature_flags",
        "attributes" => %{
          "flag_key" => flag_key,
          "enabled" => true,
          "requested_by" => "requester-1",
          "required_tier" => "pro"
        }
      }
    }

    create_resp = conn |> json_headers() |> post("/api/route_feature_flags", create_body)
    created = json_response(create_resp, 201)
    id = created["data"]["id"]

    assert created["data"]["attributes"]["flag_key"] == flag_key
    assert created["data"]["attributes"]["enabled"] == true

    persisted = RouteFeatureFlags |> Ash.get!(id, authorize?: false)
    assert persisted.flag_key == flag_key
    assert persisted.enabled == true
    assert persisted.requested_by == "requester-1"
    assert persisted.required_tier == "pro"
  end

  test "PATCH toggles enabled on an existing flag", %{conn: conn} do
    flag_key = "billing-export-#{System.unique_integer([:positive])}"

    flag =
      RouteFeatureFlags
      |> Ash.Changeset.for_create(:create, %{
        flag_key: flag_key,
        enabled: false,
        requested_by: "requester-2",
        required_tier: "starter"
      })
      |> Ash.create!(authorize?: false)

    update_body = %{
      "data" => %{
        "type" => "route_feature_flags",
        "id" => flag.id,
        "attributes" => %{"enabled" => true}
      }
    }

    update_resp =
      conn |> json_headers() |> patch("/api/route_feature_flags/#{flag.id}", update_body)

    updated = json_response(update_resp, 200)
    assert updated["data"]["attributes"]["enabled"] == true

    persisted = RouteFeatureFlags |> Ash.get!(flag.id, authorize?: false)
    assert persisted.enabled == true
  end

  test "POST rejects a flag with no flag_key", %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "route_feature_flags",
        "attributes" => %{
          "enabled" => true,
          "requested_by" => "requester-3"
        }
      }
    }

    resp = conn |> json_headers() |> post("/api/route_feature_flags", create_body)
    assert resp.status == 400
  end
end
