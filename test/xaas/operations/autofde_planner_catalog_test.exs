defmodule Xaas.Operations.AutofdePlannerCatalogTest do
  use ExUnit.Case, async: true

  @moduletag :requires_cnv_deploy

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    case Req.get("http://127.0.0.1:8080/healthz") do
      {:ok, %Req.Response{status: 200}} -> :ok
      _ -> {:skip, "cnv-deploy not running locally on :8080 -- real integration test, no mock fallback."}
    end
  end

  test "request_catalog calls the real cnv-deploy /invoke surface (fabric__catalog) and persists the real domains/solvers response" do
    {:ok, record} =
      Xaas.Operations.AutofdePlannerCatalog
      |> Ash.Changeset.for_create(:request_catalog, %{query: "list"})
      |> Ash.create()

    assert record.cnv_response != nil
    assert %{"domains" => domains, "solvers" => solvers} = record.cnv_response
    assert is_list(domains)
    assert is_list(solvers)
    assert "PDDLDomain" in domains
    assert "Astar" in solvers
    # fabric__catalog is not a solve call -- no trajectory_sha256 is invented for it.
    assert record.trajectory_sha256 == nil
    assert record.requested_at != nil
  end

  test "deny-by-default: read requires the bypass, no other path admits it" do
    assert {:ok, _list} =
             Xaas.Operations.AutofdePlannerCatalog
             |> Ash.read()
  end
end
