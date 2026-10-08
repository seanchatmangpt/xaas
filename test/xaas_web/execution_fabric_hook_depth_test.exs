defmodule XaasWeb.ExecutionFabricHookDepthTest do
  @moduledoc """
  W984bp lane: hook-surface DEPTH court for XaasWeb.ExecutionFabricController
  (lib/xaas_web/controllers/execution_fabric_controller.ex), covering the
  slice the existing courts leave open.

  Coverage gap evidence (grep over the four existing fabric courts,
  test/xaas_web/execution_fabric_controller_test.exs,
  execution_fabric_deepening_test.exs, quiescent_fabric_tie_test.exs,
  controllers/execution_fabric_surface_test.exs):

    * pre_tool_use is exercised ONLY in its no-lease arm (403 :no_lease).
      The with-lease arms -- the allow path with its atom->string key
      normalization (Map.new(allow, {to_string(k), v})) and the
      with-lease 403 deny path -- have no wire coverage.
    * user_prompt_submit / post_tool_use / post_tool_use_failure have NO
      HTTP coverage at all (only the Lease-level record path elsewhere) --
      neither the 200 {status: recorded} nor the 422 no_lease envelope,
      which deliberately diverges from pre_tool_use's 403.
    * hook `stop` is exercised ONLY without a lease (not_closeable). The
      with-lease closure arm (200 {status: closed, epoch_id, outcome})
      and the with-lease-but-uncloseable arm (200 not_closeable + reason,
      epoch stays claimable) have no wire coverage.

  Real ConnCase HTTP, real sandboxed rows, real claim_next claims.
  Mutation rationale per test inline: each test names the mutant class it
  kills. Ran x2 fresh-root clean.
  """

  use XaasWeb.ConnCase

  alias Xaas.Ultracode.{Epoch, Run}

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp hook_post(conn, event, body) do
    conn
    |> with_internal_api_token()
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> post("/internal-api/execution/hooks/#{event}", Jason.encode!(body))
  end

  defp mcp_post(conn, body) do
    conn
    |> with_internal_api_token()
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> post("/internal-api/execution/mcp", Jason.encode!(body))
  end

  defp tool_call(conn, name, arguments) do
    conn
    |> mcp_post(%{jsonrpc: "2.0", id: 1, method: "tools/call", params: %{"name" => name, "arguments" => arguments}})
    |> json_response(200)
    |> Map.fetch!("result")
    |> Map.fetch!("content")
    |> List.first()
    |> Map.fetch!("text")
    |> Jason.decode!()
  end

  defp provider_run_and_epoch(provider) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "W984bp hook-depth qualification.", provider: provider},
        authorize?: false
      )
      |> Ash.create()

    {:ok, epoch} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "XaasWeb.ExecutionFabricHookDepthTest",
          state: :running
        },
        authorize?: false
      )
      |> Ash.create()

    {run, epoch}
  end

  defp claim_lease!(conn, provider) do
    claim =
      tool_call(conn, "claim_next", %{provider: provider, provider_worker_id: "hook-depth-worker"})

    assert claim["lease_token"], "setup: claim must succeed"
    claim
  end

  # Kills: mutant flips the allow arm to the refused arm; mutant drops the
  # Map.new atom->string key normalization (keys would encode as ERLANG
  # atom keys or stay absent over the wire).
  test "pre_tool_use with a live lease ALLOWS a construction tool as string-keyed JSON", %{
    conn: conn
  } do
    provider = "hook-depth-allow-#{System.unique_integer([:positive])}"
    {run, _epoch} = provider_run_and_epoch(provider)
    claim = claim_lease!(conn, provider)
    assert run.goal

    conn = hook_post(conn, "pre_tool_use", %{"lease_token" => claim["lease_token"], "tool" => "Edit"})

    assert json_response(conn, 200) == %{"decision" => "allow"}
  end

  # Kills: mutant collapses the {:error, reason} arm of handle_hook's
  # pre_tool_use into the allow arm (deny becomes 200 allow), or drops the
  # typed reason from the 403 body.
  test "pre_tool_use with a live lease DENIES a consequence tool as a typed 403", %{conn: conn} do
    provider = "hook-depth-deny-#{System.unique_integer([:positive])}"
    {_run, _epoch} = provider_run_and_epoch(provider)
    claim = claim_lease!(conn, provider)

    conn =
      hook_post(conn, "pre_tool_use", %{"lease_token" => claim["lease_token"], "tool" => "git_push"})

    body = json_response(conn, 403)
    assert body["decision"] == "deny"
    assert body["reason"] == "refused_no_authority:\"git_push\""
  end

  # Kills: mutants (a) route user_prompt_submit to the pre_tool_use 403 arm
  # (envelope divergence), (b) drop the 200 recorded acknowledgment, (c)
  # invent a lease token for the no-lease arm instead of refusing 422.
  test "post_tool_use and user_prompt_submit RECORD for a live lease (200) and are a typed 422 without one",
       %{conn: conn} do
    provider = "hook-depth-record-#{System.unique_integer([:positive])}"
    {_run, _epoch} = provider_run_and_epoch(provider)
    claim = claim_lease!(conn, provider)

    for event <- ["post_tool_use", "user_prompt_submit"] do
      recorded =
        conn
        |> hook_post(event, %{
          "lease_token" => claim["lease_token"],
          "tool" => "Edit",
          "tool_use_id" => "tu_1",
          "session_id" => "sess-1"
        })
        |> json_response(200)

      assert recorded == %{"status" => "recorded"}
    end

    no_lease =
      conn
      |> hook_post("post_tool_use", %{"tool" => "Edit"})
      |> json_response(422)

    # Live contract (W984ca's format_reason/1 atom clause): bare atoms
    # render as plain strings, never an atom-inspected ":no_lease" leak.
    assert no_lease == %{"decision" => "deny", "reason" => "no_lease"}
  end

  # Kills: mutants (a) treat hook stop-with-lease as not_closeable (the
  # never-closure floor is only for the failure arm), (b) drop the sealed
  # outcome from the response, (c) skip the durable Receipt write.
  test "hook stop WITH a live lease closes the epoch and seals a durable Receipt", %{
    conn: conn
  } do
    provider = "hook-depth-stop-#{System.unique_integer([:positive])}"
    {_run, epoch} = provider_run_and_epoch(provider)
    claim = claim_lease!(conn, provider)

    body =
      conn
      |> hook_post("stop", %{
        "lease_token" => claim["lease_token"],
        "final_head" => "0123456789abcdef0123456789abcdef01234567",
        "standing" => "partial_alive",
        "evidence" => %{"verifier" => "w984bp-hook-depth"}
      })
      |> json_response(200)

    assert body["status"] == "closed"
    assert body["epoch_id"] == epoch.id
    assert body["outcome"] == "partial_alive"

    receipts =
      conn
      |> with_internal_api_token()
      |> get("/internal-api/execution/epochs/#{epoch.id}/receipts")
      |> json_response(200)

    assert [%{"outcome" => "partial_alive"}] = receipts["receipts"]
  end

  # Kills: mutants (a) turn a failed close with a (stale/unknown) token into
  # a 4xx/500 or silent closure, (b) invent success. The lease-expiry floor:
  # stop without a closeable lease is observed, never fatal, never closure.
  test "hook stop with an unclosable lease stays 200 not_closeable and seals nothing", %{
    conn: conn
  } do
    provider = "hook-depth-stale-#{System.unique_integer([:positive])}"
    {_run, epoch} = provider_run_and_epoch(provider)

    body =
      conn
      |> hook_post("stop", %{
        "lease_token" => "wleb-no-such-lease",
        "final_head" => "0123456789abcdef0123456789abcdef01234567",
        "standing" => "alive"
      })
      |> json_response(200)

    assert body["status"] == "not_closeable"
    assert body["reason"]

    # Nothing sealed: the epoch's receipt list is empty through the lawful read.
    receipts =
      conn
      |> with_internal_api_token()
      |> get("/internal-api/execution/epochs/#{epoch.id}/receipts")
      |> json_response(200)

    assert receipts["receipts"] == []
  end
end
