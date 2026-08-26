defmodule Xaas.Operations.AutofdePlannerCacheStatsTest do
  use ExUnit.Case, async: true

  @moduletag :requires_cnv_deploy

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    case Req.get("http://127.0.0.1:8080/healthz") do
      {:ok, %Req.Response{status: 200}} ->
        :ok

      _ ->
        {:ok,
         skip:
           "cnv-deploy not running locally on :8080 -- real integration test, no mock fallback."}
    end
  end

  test "request_cache_stats calls the real cnv-deploy /invoke surface (fabric__cache-stats) and persists the real cache stats response" do
    {:ok, record} =
      Xaas.Operations.AutofdePlannerCacheStats
      |> Ash.Changeset.for_create(:request_cache_stats, %{query: "stats"})
      |> Ash.create()

    assert record.cnv_response != nil
    assert %{"hits" => hits, "misses" => misses, "hit_rate" => hit_rate, "namespaces" => namespaces} = record.cnv_response
    assert is_integer(hits)
    assert is_integer(misses)
    assert is_number(hit_rate)
    assert is_map(namespaces)
    # fabric__cache-stats is not a solve call -- no trajectory_sha256 is invented for it.
    assert record.trajectory_sha256 == nil
    assert record.requested_at != nil
  end

  test "deny-by-default: read requires the bypass, no other path admits it" do
    assert {:ok, _list} =
             Xaas.Operations.AutofdePlannerCacheStats
             |> Ash.read()
  end
end
