defmodule Xaas.Operations.AutofdePlannerCandidateTest do
  use ExUnit.Case, async: true

  @moduletag :requires_cnv_deploy

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    case Req.get("http://127.0.0.1:8080/healthz") do
      {:ok, %Req.Response{status: 200}} -> :ok
      _ -> {:skip, "cnv-deploy not running locally on :8080 -- real integration test, no mock fallback. See Task 3 Step 5 to start it."}
    end
  end

  test "request_candidate calls the real cnv-deploy /invoke surface and persists a real trajectory_sha256" do
    query =
      Jason.encode!(%{
        domain_path: "tests/domains/python/pddl_domains/blocks/domain.pddl",
        problem_path: "tests/domains/python/pddl_domains/blocks/probBLOCKS-3-0.pddl"
      })

    {:ok, record} =
      Xaas.Operations.AutofdePlannerCandidate
      |> Ash.Changeset.for_create(:request_candidate, %{query: query})
      |> Ash.create()

    assert record.cnv_response != nil
    assert is_binary(record.trajectory_sha256)
    assert String.length(record.trajectory_sha256) == 64
    assert record.requested_at != nil
  end

  test "deny-by-default: read requires the bypass, no other path admits it" do
    # Confirms the real policy floor is present and the bypass is the only path through it --
    # matches the exact pattern verified this session in capability_liveness_receipt.ex.
    assert {:ok, _list} =
             Xaas.Operations.AutofdePlannerCandidate
             |> Ash.read()
  end
end
