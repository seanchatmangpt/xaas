defmodule Xaas.Ultracode.LeaseCancelTest do
  @moduledoc """
  Qualification of the cancellation verb: `Lease.cancel/3` (lease holder --
  the token IS the capability) and `Lease.cancel_epoch/4` (internal, through
  the real `Xaas.Checks.SystemActor` service mapping), plus the fabric MCP
  wire shape (`cancel_work` over `XaasWeb.ExecutionFabricController`).

  Laws under court:

    * standing: a cancelled epoch lands `:failed` + a `:blocked` receipt with
      `cancelled_by` evidence -- never a silent abandonment, never a new fork
      of the epoch state machine;
    * authority: an internal cancel carries an admitted `:ultracode_reactor`
      system authority; any other service is `{:error, :refused_no_authority}`
      (anti-vacuity: the wrong-service mutation must flip the court);
    * race posture: a stale (expired + re-claimed) token no longer resolves
      at all -- the typed `{:error, {:no_lease, _}}` (same answer refuse/3
      gives); an internal cancel of a concurrently-closed epoch is the typed
      `{:error, {:epoch_not_cancellable, _}}`; a cancelled epoch's revoked
      lease is dead to its old holder (token column cleared -> `no_lease`);
    * terminal epochs are not cancellable.
  """

  use ExUnit.Case, async: false

  import Plug.Test

  alias Xaas.Ultracode.{Epoch, Lease, Receipt, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
    end)

    :ok
  end

  defp provider_run_and_epoch(provider) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "cancel verb qualification.", provider: provider},
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
          exact_subject: "lease-cancel-test:#{System.unique_integer([:positive])}",
          state: :running
        },
        authorize?: false
      )
      |> Ash.create()

    {run, epoch}
  end

  defp receipts_for(epoch_id) do
    Receipt
    |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch_id})
    |> Ash.read!(authorize?: false)
  end

  defp reload(epoch_id), do: Ash.get!(Epoch, epoch_id, action: :read_unscoped)

  # ------------------------------------------------------------------
  # Lease-holder cancel
  # ------------------------------------------------------------------

  describe "cancel/3 (lease holder)" do
    test "a live lease holder cancels: epoch :failed, one :blocked receipt, cancelled_by evidence" do
      {_run, epoch} = provider_run_and_epoch("cancel-holder")
      {:ok, _epoch, token, _run} = Lease.claim_next("cancel-holder", "worker-1")

      assert {:ok, cancelled, receipt} = Lease.cancel(token, :superseded, %{"note" => "x"})

      assert cancelled.state == :failed
      assert cancelled.terminal_at

      assert [%{id: receipt_id, outcome: :blocked, evidence: evidence}] = receipts_for(epoch.id)
      assert receipt_id == receipt.id

      assert evidence["cancelled_by"] == "lease_holder"
      assert evidence["cancellation_reason"] == "superseded"
      assert evidence["note"] == "x"
      assert receipt.subject == epoch.exact_subject
    end

    test "cancel after TTL expiry + legitimate re-claim is the typed stale-token refusal (never clobbers B)" do
      provider = "cancel-stale-#{System.unique_integer([:positive])}"
      {_run, epoch} = provider_run_and_epoch(provider)

      {:ok, _epoch, token_a, _run} = Lease.claim_next(provider, "A", lease_ttl_minutes: 0)
      Process.sleep(5)

      {:ok, _epoch_b, token_b, _run} = Lease.claim_next(provider, "B")

      # Same typed answer refuse/3 gives on a fully-stale token: no live row
      # carries it any more (the re-claim replaced it), so the capability is
      # dead -- B's lease is untouched either way.
      assert {:error, {:no_lease, ^token_a}} = Lease.cancel(token_a, :superseded)

      # B's lease is untouched and exactly one receipt-sealing path remains open.
      assert length(receipts_for(epoch.id)) == 0
      assert {:ok, _epoch, _receipt} = Lease.close(token_b, "head-b", :blocked)
      assert length(receipts_for(epoch.id)) == 1
    end

    test "cancel with a forged/unknown token is typed" do
      assert {:error, {:no_lease, _}} = Lease.cancel("forged-token", :superseded)
    end
  end

  # ------------------------------------------------------------------
  # Internal cancel
  # ------------------------------------------------------------------

  describe "cancel_epoch/4 (internal authority)" do
    test "the admitted kernel authority cancels an UNCLAIMED epoch and records revoked_lease false" do
      {_run, epoch} = provider_run_and_epoch("cancel-internal")
      actor = Xaas.SystemAuthority.new(:ultracode_reactor)

      assert {:ok, cancelled, receipt} = Lease.cancel_epoch(epoch.id, actor, :episode_drain)

      assert cancelled.state == :failed
      assert receipt.outcome == :blocked
      assert receipt.evidence["cancelled_by"] == "internal"
      assert receipt.evidence["revoked_lease"] == false
    end

    test "internal cancel REVOKES a bound lease: the old token is dead to its holder" do
      {_run, epoch} = provider_run_and_epoch("cancel-revoke")
      {:ok, _epoch, token, _run} = Lease.claim_next("cancel-revoke", "worker-1")
      actor = Xaas.SystemAuthority.new(:ultracode_reactor)

      assert {:ok, cancelled, receipt} = Lease.cancel_epoch(epoch, actor, :episode_drain)

      assert cancelled.lease_token == nil
      assert receipt.evidence["revoked_lease"] == true
      # The token COLUMN was cleared, so the old capability no longer
      # resolves at all (stronger than "not live"): renew and close both
      # answer the typed no_lease.
      assert {:error, {:no_lease, ^token}} = Lease.renew(token)
      assert {:error, {:no_lease, ^token}} = Lease.close(token, "head", :blocked)
    end

    test "wrong-service authority is refused (anti-vacuity: the court must flip)" do
      {_run, epoch} = provider_run_and_epoch("cancel-wrong-service")
      actor = Xaas.SystemAuthority.new(:oban_scheduler)

      assert {:error, :refused_no_authority} =
               Lease.cancel_epoch(epoch, actor, :episode_drain)

      assert reload(epoch.id).state == :running
      assert receipts_for(epoch.id) == []
    end

    test "terminal epochs are not cancellable" do
      {_run, epoch} = provider_run_and_epoch("cancel-terminal")
      {:ok, _epoch, token, _run} = Lease.claim_next("cancel-terminal", "worker-1")
      {:ok, _closed, _receipt} = Lease.close(token, "head", :blocked)
      actor = Xaas.SystemAuthority.new(:ultracode_reactor)

      assert {:error, {:epoch_not_cancellable, :completed}} =
               Lease.cancel_epoch(epoch.id, actor, :episode_drain)
    end

    test "internal cancel racing a concurrent close: exactly one lands, exactly one receipt" do
      {_run, epoch} = provider_run_and_epoch("cancel-race")
      {:ok, _epoch, token, _run} = Lease.claim_next("cancel-race", "worker-1")
      actor = Xaas.SystemAuthority.new(:ultracode_reactor)

      task_close = Task.async(fn -> Lease.close(token, "head-race", :blocked) end)
      task_cancel = Task.async(fn -> Lease.cancel_epoch(epoch, actor, :episode_drain) end)

      [close_result, cancel_result] = Task.await_many([task_close, task_cancel], 10_000)

      cond do
        match?({:ok, _, _}, close_result) ->
          # Close won the row; the internal cancel must see a terminal epoch.
          assert match?({:error, {:epoch_not_cancellable, _}}, cancel_result)

        match?({:ok, _, _}, cancel_result) ->
          # Cancel won the row (lease revoked); the stale close is typed-dead.
          assert match?({:error, _}, close_result)

        true ->
          flunk("neither close nor cancel landed: #{inspect({close_result, cancel_result})}")
      end

      # Exactly one receipt-sealing write won the row, whichever way the race went.
      receipts = receipts_for(epoch.id)

      assert length(receipts) == 1,
             "expected exactly one receipt after close-vs-internal-cancel, got " <>
               "#{length(receipts)}: #{inspect([close_result, cancel_result])}"

      assert reload(epoch.id).state in [:completed, :failed]
    end
  end

  # ------------------------------------------------------------------
  # MCP wire shape (cancel_work over the fabric controller)
  # ------------------------------------------------------------------

  describe "MCP cancel_work wire shape" do
    defp rpc_call(method, params) do
      conn =
        conn(:post, "/internal-api/execution/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => method,
          "params" => params
        })

      XaasWeb.ExecutionFabricController.mcp(conn, %{})
    end

    defp decode_body(body) when is_binary(body), do: Jason.decode!(body)
    defp decode_body(body) when is_map(body), do: body

    defp unwrap_tool_result(conn) do
      %{"result" => result} = decode_body(conn.resp_body)

      # The success shape carries no isError key (absent = false).
      is_error = Map.get(result, "isError", false)
      %{"content" => [%{"text" => text}] = content} = result

      {is_error, Jason.decode!(text), length(content)}
    end

    test "tools/list declares cancel_work with the documented schema" do
      conn = rpc_call("tools/list", %{})

      %{"result" => %{"tools" => tools}} = decode_body(conn.resp_body)
      tool = Enum.find(tools, &(&1["name"] == "cancel_work"))

      assert tool, "cancel_work must be declared on the fabric MCP surface"

      assert %{"type" => "object", "required" => ["lease_token", "reason"]} =
               tool["inputSchema"]

      assert %{"lease_token" => %{"type" => "string"}, "reason" => %{"type" => "string"}} =
               tool["inputSchema"]["properties"]
    end

    test "a live lease holder cancels over the wire: typed result, no isError" do
      {_run, epoch} = provider_run_and_epoch("cancel-mcp")
      {:ok, _epoch, token, _run} = Lease.claim_next("cancel-mcp", "worker-1")

      {is_error, result, content_count} =
        rpc_call("tools/call", %{
          "name" => "cancel_work",
          "arguments" => %{"lease_token" => token, "reason" => "superseded", "evidence" => %{"k" => "v"}}
        })
        |> unwrap_tool_result()

      assert is_error == false
      assert content_count == 1
      assert result["status"] == "cancelled"
      assert result["epoch_id"] == epoch.id
      assert result["outcome"] == "blocked"
      assert result["cancelled_by"] == "lease_holder"
    end

    test "a stale token's wire cancel is a JSON-RPC tool error carrying the typed reason" do
      _run_and_epoch = provider_run_and_epoch("cancel-mcp-stale")

      {is_error, result, _count} =
        rpc_call("tools/call", %{
          "name" => "cancel_work",
          "arguments" => %{"lease_token" => "forged", "reason" => "superseded"}
        })
        |> unwrap_tool_result()

      assert is_error == true
      assert result["error"] =~ "no_lease"
    end
  end
end
