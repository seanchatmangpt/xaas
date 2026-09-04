defmodule Xaas.Operations.AutofdePlannerCrossProductTest do
  @moduledoc """
  Proves the capability x planner combinatorial space actually composes: two independent
  aac:AshConnector individuals from the same real ggen pack, targeting two different real
  fabric tools (fabric__solve, fabric__catalog) on the same real cnv-deploy server, both
  working side by side in the same test run -- not just individually.
  """
  use ExUnit.Case, async: true

  @moduletag :requires_cnv_deploy
  @moduletag skip:
               (case Req.get("http://127.0.0.1:8080/healthz") do
                  {:ok, %Req.Response{status: 200}} -> false
                  _ -> "cnv-deploy not running locally on :8080 -- real integration test, no mock fallback."
                end)

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  test "fabric__solve and fabric__catalog both succeed against the real cnv-deploy server in the same run" do
    query =
      Jason.encode!(%{
        domain_path: "tests/domains/python/pddl_domains/blocks/domain.pddl",
        problem_path: "tests/domains/python/pddl_domains/blocks/probBLOCKS-3-0.pddl"
      })

    {:ok, candidate} =
      Xaas.Operations.AutofdePlannerCandidate
      |> Ash.Changeset.for_create(:request_candidate, %{query: query})
      |> Ash.create()

    {:ok, catalog} =
      Xaas.Operations.AutofdePlannerCatalog
      |> Ash.Changeset.for_create(:request_catalog, %{query: "list"})
      |> Ash.create()

    assert is_binary(candidate.trajectory_sha256)
    assert String.length(candidate.trajectory_sha256) == 64

    assert %{"domains" => domains, "solvers" => solvers} = catalog.cnv_response
    assert "PDDLDomain" in domains
    assert "Astar" in solvers
    assert catalog.trajectory_sha256 == nil
  end
end
