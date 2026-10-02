defmodule Xaas.Chicago.NegativeCourts.AuthorityCourtsTest do
  @moduledoc """
  Lane L8 runtime authority courts (wave-1 design, file 2) over the real
  `Xaas.Chicago.Court` (RESOLUTIONS.md R4, landed by L4):

    * CHI-CASE-002 above the delegated limit — typed refusal; the exact
      boundary amount admits (anti-vacuity positive control);
    * CHI-CASE-003 wrong principal — refused before protected DO; the
      delegated principal admits;
    * CHI-CASE-004 expired delegation — refused with NO implicit renewal:
      the stale expiry is echoed unchanged, a repeat decision is identical,
      and the conservative `now >= expires_at` boundary is expired;
    * CHI-CASE-010 consumer court — any claimed grant through a projection
      is `:authority_none`, never an admission;
    * CHI-CASE-010 real fabric court — `/internal-api/execution/mcp` is
      fail-closed with the REAL gate semantics (unset token => 503,
      missing/wrong bearer => 401) and admits only the real token
      (anti-vacuity). Needs no `Xaas.Chicago.Court`.
  """

  use XaasWeb.ConnCase, async: true

  Code.require_file("support/mutants.ex", __DIR__)
  alias Xaas.Chicago.Court
  alias Xaas.Chicago.NegativeCourts.Mutants, as: M

  ## CHI-CASE-002: delegated limit #############################################

  test "CHI-CASE-002: above the delegated limit is refused :above_delegated_limit; the boundary amount admits" do
    refused = M.decide_case("CHI-CASE-002")

    M.assert_refusal(refused, :above_delegated_limit)
    assert %{amount: 150, delegated_limit: 100} = elem(refused, 2)
    M.assert_no_standing_promotion(refused)

    # positive controls: the delegated limit is exactly admissible and the
    # bounded baseline admits — the limit law can actually pass
    M.assert_admitted(Court.decide(Court.bounded_purchase(%{amount: 100}), Court.baseline_policy()))
    M.assert_admitted(M.decide_case("CHI-CASE-001"))

    M.assert_deterministic(fn -> M.decide_case("CHI-CASE-002") end)
  end

  ## CHI-CASE-003: wrong principal #############################################

  test "CHI-CASE-003: wrong principal is refused :wrong_principal; the delegated principal admits" do
    refused = M.decide_case("CHI-CASE-003")

    M.assert_refusal(refused, :wrong_principal)
    assert %{expected: "principal-001", got: "principal-mallory"} = elem(refused, 2)
    M.assert_no_standing_promotion(refused)

    # positive control: the principal matching the delegation is not refused
    M.assert_admitted(M.decide_case("CHI-CASE-001"))
  end

  ## CHI-CASE-004: expired delegation, no implicit renewal #####################

  test "CHI-CASE-004: expired delegation is refused :delegation_expired with no implicit renewal" do
    expired_at = ~U[2020-01-01 00:00:00Z]
    refused = M.decide_case("CHI-CASE-004")

    M.assert_refusal(refused, :delegation_expired)

    # no implicit renewal: the refusal echoes the STALE expiry (never a
    # refreshed one) and deciding again is identical
    assert %{expires_at: ^expired_at} = elem(refused, 2)
    M.assert_no_standing_promotion(refused)
    M.assert_deterministic(fn -> M.decide_case("CHI-CASE-004") end)

    # conservative boundary mutation: now == expires_at is already expired
    {request, _policy} = M.case_request_and_policy("CHI-CASE-001")
    boundary = Court.baseline_policy(%{delegation_expires_at: ~U[2026-10-01 00:00:00Z]})
    M.assert_refusal(Court.decide(request, boundary), :delegation_expired)

    # anti-vacuity: the expiry law can pass — the fresh baseline admits
    M.assert_admitted(Court.decide(request, Court.baseline_policy()))
  end

  ## CHI-CASE-010: consumer authority_none #####################################

  test "CHI-CASE-010 consumer court: no claimed grant mints DO (:authority_none for every variant)" do
    for claim <- ["DO", "OPERATOR-GRANT", "SURFACE-MINTED", true] do
      refused = Court.decide(Court.bounded_purchase(%{authority_claim: claim}), Court.baseline_policy())

      M.assert_refusal(refused, :authority_none)
      M.assert_no_standing_promotion(refused)
    end

    M.assert_deterministic(fn -> M.decide_case("CHI-CASE-010") end)
  end

  ## CHI-CASE-010: real fabric court (green now — routes exist) ################

  test "CHI-CASE-010 real fabric court: /internal-api/execution/mcp is fail-closed (unset token => 503, missing/wrong bearer => 401) and admits only the real token" do
    body = Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "initialize", params: %{}})

    # unset INTERNAL_API_TOKEN: the gate fails CLOSED, never open (same
    # env-safe delete/restore pattern as XaasWeb.ExecutionFabricControllerTest)
    previous = System.fetch_env!("INTERNAL_API_TOKEN")
    System.delete_env("INTERNAL_API_TOKEN")

    try do
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post("/internal-api/execution/mcp", body)
      |> json_response(503)
    after
      System.put_env("INTERNAL_API_TOKEN", previous)
    end

    # no bearer at all (env set): a real rejection, not silent passage
    build_conn()
    |> put_req_header("content-type", "application/json")
    |> post("/internal-api/execution/mcp", body)
    |> json_response(401)

    # wrong bearer: a real rejection
    build_conn()
    |> put_req_header("content-type", "application/json")
    |> put_req_header("authorization", "Bearer not-a-real-internal-token")
    |> post("/internal-api/execution/mcp", body)
    |> json_response(401)

    # anti-vacuity: the gate is not merely dead — the real test token admits
    build_conn()
    |> put_req_header("content-type", "application/json")
    |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    |> post("/internal-api/execution/mcp", body)
    |> json_response(200)
  end
end
