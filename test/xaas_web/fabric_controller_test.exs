defmodule XaasWeb.FabricControllerTest do
  @moduledoc """
  Chicago-style test of the bounded runtime fabric (`/internal-api/fabric`):
  real ConnCase HTTP through the router and `RequireInternalApiToken`, real
  sandboxed Postgres rows (Org, InternalApiToken, Run, Epoch, Receipt via real
  Ash actions), and the real provider-pull seam (`Xaas.Ultracode.Lease`) sealing
  the receipt the long-poll returns. No owned collaborator is replaced.
  """
  use XaasWeb.ConnCase, async: false

  alias Xaas.Accounts.Org
  alias Xaas.Governance.InternalApiTokenAuth
  alias Xaas.Tunnel.Receipt
  alias Xaas.Ultracode.{Epoch, Lease, Run}

  setup do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    org = create_org!("fabric-org-#{System.unique_integer([:positive])}")
    %{org: org, token: org_token!("fabric-test", org)}
  end

  defp create_org!(slug) do
    {:ok, org} =
      Org
      |> Ash.Changeset.for_create(:create, %{name: slug, slug: slug}, authorize?: false)
      |> Ash.create()

    org
  end

  defp org_token!(created_by, %Org{} = org) do
    {:ok, raw_token, _token} = InternalApiTokenAuth.issue(created_by, nil, org)
    raw_token
  end

  defp authed(conn, token) do
    conn
    |> put_req_header("authorization", "Bearer " <> token)
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
  end

  defp legacy(conn), do: authed(conn, System.fetch_env!("INTERNAL_API_TOKEN"))

  defp submit(conn, token, body),
    do: conn |> authed(token) |> post("/internal-api/fabric/runs", Jason.encode!(body))

  defp receipts(conn, token, epoch_id, query),
    do:
      conn
      |> authed(token)
      |> get("/internal-api/fabric/epochs/#{epoch_id}/receipts?" <> URI.encode_query(query))

  test "no bearer is refused before the fabric runs", %{conn: conn} do
    assert conn |> get("/internal-api/fabric/probe") |> response(401)
  end

  test "probe returns the xaas-fabric/1 contract", %{conn: conn, token: token} do
    body = conn |> authed(token) |> get("/internal-api/fabric/probe") |> json_response(200)

    assert body["protocol"] == "xaas-fabric/1"
    assert body["capabilities"] == ~w(fabric.probe run.submit epoch.receipts)
    assert body["refused"] == %{"actuate" => "authority_ceiling"}
    assert body["long_poll_max_ms"] == 25_000
    assert body["org_scoped?"] == true
    refute Map.has_key?(body, "blocked")
  end

  test "probe with an org-less (legacy) token reports run.submit BLOCKED", %{conn: conn} do
    body = conn |> legacy() |> get("/internal-api/fabric/probe") |> json_response(200)

    assert body["org_scoped?"] == false
    assert body["blocked"] == %{"run.submit" => "BLOCKED(org_scoped_token_required)"}
  end

  test "admit intersects the request with the allowlist", %{conn: conn, token: token} do
    body =
      conn
      |> authed(token)
      |> post(
        "/internal-api/fabric/admit",
        Jason.encode!(%{
          capabilities: ~w(fabric.probe run.submit epoch.receipts actuate claim_next)
        })
      )
      |> json_response(200)

    assert body["admitted"] == ~w(fabric.probe run.submit epoch.receipts)

    assert body["refused"] == [
             ["actuate", "authority_ceiling"],
             ["claim_next", "capability_not_admitted"]
           ]
  end

  test "actuate is a typed 403 refusal", %{conn: conn, token: token} do
    body =
      conn
      |> authed(token)
      |> post("/internal-api/fabric/actuate", Jason.encode!(%{resource: "x", action: "y"}))
      |> json_response(403)

    assert body == %{"standing" => "REFUSED", "reason" => "authority_ceiling:actuate"}
  end

  test "submit is idempotent on the key: 201 then 200 with the same ids",
       %{conn: conn, token: token, org: org} do
    req = %{goal: "fabric idempotent submit", idempotency_key: "k-idem-1"}
    first = conn |> submit(token, req) |> json_response(201)

    assert first["replay"] == false
    assert first["exact_subject"] == "fabric:#{org.slug}:k-idem-1"

    second = build_conn() |> submit(token, req) |> json_response(200)
    assert second["replay"] == true

    assert Map.take(second, ~w(run_id epoch_id exact_subject)) ==
             Map.take(first, ~w(run_id epoch_id exact_subject))

    # State, not the response: exactly one Run and one Epoch exist for the key.
    epochs =
      Epoch
      |> Ash.Query.for_read(:read_unscoped, %{}, authorize?: false)
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.exact_subject == first["exact_subject"]))

    assert length(epochs) == 1
    run = Ash.get!(Run, first["run_id"], action: :read_unscoped, authorize?: false)
    assert run.org_id == org.id
    assert hd(epochs).state == :running
  end

  test "concurrent submits of one key create one run", %{token: token} do
    req = %{goal: "fabric concurrent submit", idempotency_key: "k-race-1"}

    results =
      1..4
      |> Enum.map(fn _ -> Task.async(fn -> build_conn() |> submit(token, req) end) end)
      |> Enum.map(&Task.await(&1, 15_000))

    statuses = results |> Enum.map(& &1.status) |> Enum.sort()
    assert statuses == [200, 200, 200, 201]

    assert results
           |> Enum.map(&Jason.decode!(&1.resp_body)["epoch_id"])
           |> Enum.uniq()
           |> length() == 1
  end

  test "submit without a valid idempotency key is a typed 422", %{conn: conn, token: token} do
    body = conn |> submit(token, %{goal: "no key"}) |> json_response(422)
    assert body == %{"standing" => "REFUSED", "reason" => "idempotency_key_required"}

    body =
      build_conn()
      |> submit(token, %{goal: "bad key", idempotency_key: "has space"})
      |> json_response(422)

    assert body["reason"] == "idempotency_key_required"
  end

  test "a legacy (org-less) token cannot submit", %{conn: conn} do
    body =
      conn
      |> legacy()
      |> post("/internal-api/fabric/runs", Jason.encode!(%{goal: "g", idempotency_key: "k"}))
      |> json_response(403)

    assert body == %{"standing" => "BLOCKED", "reason" => "org_scoped_token_required"}
  end

  test "receipts long-poll: 204 at timeout, bounded", %{conn: conn, token: token} do
    %{"epoch_id" => epoch_id} =
      conn
      |> submit(token, %{goal: "poll timeout", idempotency_key: "k-poll-1"})
      |> json_response(201)

    started = System.monotonic_time(:millisecond)
    resp = build_conn() |> receipts(token, epoch_id, wait_ms: 600)
    elapsed = System.monotonic_time(:millisecond) - started

    assert resp.status == 204
    assert get_resp_header(resp, "x-fabric-state") == ["running"]
    assert elapsed >= 550 and elapsed < 5_000
  end

  test "receipts long-poll wakes with the sealed receipt when a worker closes the lease",
       %{conn: conn, token: token} do
    %{"epoch_id" => epoch_id} =
      conn
      |> submit(token, %{goal: "poll sealed", idempotency_key: "k-poll-2"})
      |> json_response(201)

    worker =
      Task.async(fn ->
        Process.sleep(700)

        {:ok, _epoch, lease, _run} =
          Lease.claim_next("zcode", "fabric-test-worker", epoch_id: epoch_id)

        {:ok, _epoch, receipt} =
          Lease.close(lease, "0000000000000000000000000000000000000000", :alive)

        receipt
      end)

    body = build_conn() |> receipts(token, epoch_id, wait_ms: 10_000) |> json_response(200)
    sealed = Task.await(worker, 15_000)

    assert body["state"] == "sealed"
    [%{"receipt" => wire, "digest" => digest}] = body["receipts"]
    assert body["cursor"] == digest
    assert wire["id"] == sealed.id
    assert wire["epoch_id"] == epoch_id
    # No worktree: the head cannot be verified, so the fabric downgrades the claim.
    assert wire["outcome"] == "partial_alive"
    assert wire["standing"] == "PARTIAL_ALIVE"
    assert wire["authority"] == "CONSTRUCT"
    # Replay: the client recomputes the digest from the decoded body.
    assert Receipt.verify_replay(wire, digest) == :ok

    assert Receipt.verify_replay(Map.put(wire, "outcome", "alive"), digest) ==
             {:refused, :replay_digest_mismatch}

    # `after` = the current cursor: nothing new, so the poll times out.
    assert build_conn() |> receipts(token, epoch_id, wait_ms: 300, after: digest) |> response(204)
  end

  test "wait_ms is capped at 25000 and junk falls back to the cap", %{conn: conn, token: token} do
    %{"epoch_id" => epoch_id} =
      conn
      |> submit(token, %{goal: "poll cap", idempotency_key: "k-poll-3"})
      |> json_response(201)

    {:ok, _epoch, lease, _run} = Lease.claim_next("zcode", "cap-worker", epoch_id: epoch_id)
    {:ok, _, _} = Lease.refuse(lease, :blocked)

    # Sealed already: returns immediately even with an absurd wait.
    body = build_conn() |> receipts(token, epoch_id, wait_ms: 10_000_000) |> json_response(200)
    assert [%{"receipt" => %{"outcome" => "refused", "standing" => "REFUSED"}}] = body["receipts"]
    assert Xaas.Tunnel.Fabric.wait_ms("10000000") == 25_000
  end

  test "another org's epoch is not visible; junk ids are 400", %{conn: conn, token: token} do
    other = create_org!("fabric-other-#{System.unique_integer([:positive])}")
    other_token = org_token!("fabric-other", other)

    %{"epoch_id" => epoch_id} =
      conn
      |> submit(other_token, %{goal: "other org", idempotency_key: "k-other"})
      |> json_response(201)

    assert build_conn() |> receipts(token, epoch_id, wait_ms: 0) |> json_response(404) ==
             %{"standing" => "BLOCKED", "reason" => "epoch_not_visible"}

    assert build_conn() |> receipts(token, "not-a-uuid", wait_ms: 0) |> json_response(400) ==
             %{"standing" => "REFUSED", "reason" => "invalid_epoch_id"}
  end
end
