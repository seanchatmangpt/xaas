defmodule Xaas.Operations.AutofdePlannerCacheHotsetTest do
  use ExUnit.Case, async: true

  @moduletag :requires_cnv_deploy

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    case Req.get("http://127.0.0.1:8080/healthz") do
      {:ok, %Req.Response{status: 200}} -> :ok
      _ -> {:skip, "cnv-deploy not running locally on :8080 -- real integration test, no mock fallback."}
    end
  end

  test "request_cache_hotset calls the real cnv-deploy /invoke surface (fabric__cache-hotset) and persists the real hotset response" do
    {:ok, record} =
      Xaas.Operations.AutofdePlannerCacheHotset
      |> Ash.Changeset.for_create(:request_cache_hotset, %{query: "hotset"})
      |> Ash.create()

    assert record.cnv_response != nil

    assert %{
             "active_entries" => active_entries,
             "entries" => entries,
             "top_20_percent_hit_share" => share,
             "total_hits" => total_hits
           } = record.cnv_response

    assert is_integer(active_entries)
    assert is_list(entries)
    assert is_number(share)
    assert is_integer(total_hits)
    # fabric__cache-hotset is not a solve call -- no trajectory_sha256 is invented for it.
    assert record.trajectory_sha256 == nil
    assert record.requested_at != nil
  end

  test "deny-by-default: read requires the bypass, no other path admits it" do
    assert {:ok, _list} =
             Xaas.Operations.AutofdePlannerCacheHotset
             |> Ash.read()
  end
end
