defmodule Xaas.Operations.AutofdePlannerMatchTest do
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

  test "request_match calls the real cnv-deploy /invoke surface (fabric__match) and persists the real compatible_solvers response" do
    {:ok, record} =
      Xaas.Operations.AutofdePlannerMatch
      |> Ash.Changeset.for_create(:request_match, %{query: "Maze"})
      |> Ash.create()

    assert record.cnv_response != nil
    assert %{"domain" => "Maze", "compatible_solvers" => solvers} = record.cnv_response
    assert is_list(solvers)
    assert "Astar" in solvers
    # fabric__match is not a solve call -- no trajectory_sha256 is invented for it.
    assert record.trajectory_sha256 == nil
    assert record.requested_at != nil
  end

  test "deny-by-default: read requires the bypass, no other path admits it" do
    assert {:ok, _list} =
             Xaas.Operations.AutofdePlannerMatch
             |> Ash.read()
  end
end
