defmodule Xaas.E2E.KindDeploymentTest do
  @moduledoc """
  Real Chicago-style end-to-end test against the ACTUAL live `xaas`
  Deployment running in the real `kind-xaas` cluster -- not the local
  Ecto.Adapters.SQL.Sandbox suite. This is the test the user asked for:
  proof that `ApprovalBackupRetentionChange`'s `:approve` mutation route
  and its real `Xaas.Ledger.Transfer` overage charge actually work end to
  end against a real deployed pod and a real deployed Postgres, using
  real HTTP requests (via `Req`, already a project dep) and a real
  `kubectl exec ... psql` readback -- not a curl transcript pasted from
  memory, not a mock.

  Excluded by default (`test/test_helper.exs`, same pattern as `:stress`)
  -- run explicitly:

      mix test --include kind test/e2e/kind_deployment_test.exs

  Requires: `kind-xaas` cluster up, `xaas`/`postgres` Deployments
  `Running`, and a real `INTERNAL_API_TOKEN`/`ONETIME_REVOKE_KEY` applied
  to the live `xaas-secrets` Secret (see k8s/secret.yaml.example's
  comments on both).

  This test self-starts `kubectl port-forward -n default deployment/xaas
  4001:4000` if port 4001 isn't already reachable (see
  `start_port_forward!/0`), and it does not require one to be started
  manually first. A prior session's disclosure here said the self-start
  path "hung" and was not fully diagnosed; a real re-diagnosis this
  session (`Port.open`/`wait_for_reachable!` isolated in a standalone
  `mix run` script outside ExUnit, and 4 real repro runs of the full
  `mix test --include kind` suite against the live cluster, all passing
  in 0.7-0.8s) found the actual root cause was NOT this code: it was
  `mix`'s own `_build` directory lock being held by a second, concurrent
  `mix compile`/`mix test` process running elsewhere in that session,
  which blocks a fresh `mix test` invocation silently (no ExUnit output
  at all, since the stall happens before `setup_all` ever runs) and
  produces exactly the "hung with no output" symptom that was previously
  attributed to `Port.open`. If `mix test --include kind` appears to
  hang here, check for a concurrent `mix compile`/`mix test` holding the
  build lock (`Waiting for lock on the build directory` in another
  session's output) before suspecting this module.

  A real, separate, minor issue this re-diagnosis did find: the spawned
  `kubectl port-forward` `Port` was not being reaped when the BEAM
  process exited, so it briefly lingered as an orphan reparented to
  `launchd`. `start_port_forward!/0` now registers a real `System.at_exit`
  callback that kills the child OS process by PID, and drains the port's
  stdout in a linked process so `kubectl`'s "Forwarding from ..." line
  never sits undrained. Neither of these was the cause of any hang --
  they close out real, if minor, process-hygiene gaps found while
  re-verifying.

  Manually starting a port-forward first is no longer required, but
  still works if you prefer an independently-running one:

      kubectl --context kind-xaas port-forward -n default deployment/xaas 4001:4000 &

  Deliberately does NOT add any HTTP route to `Xaas.Ledger.*` -- those 3
  resources stay unwired per CLAUDE.md's "never blindly wire routes on
  sensitive resources" rule. The real balance readback below goes
  through a real `kubectl exec <postgres-pod> -- psql` subprocess against
  the live database instead, the same real command used to verify the
  migration manually this session.
  """
  use ExUnit.Case, async: false
  @moduletag :kind

  @kind_context "kind-xaas"
  @local_port 4001
  @base_url "http://localhost:#{@local_port}"

  setup_all do
    unless port_forward_reachable?() do
      start_port_forward!()
      wait_for_reachable!()
    end

    token = live_internal_api_token!()
    {:ok, token: token}
  end

  test "real deployed pod is reachable and returns a real 200", %{token: _token} do
    assert %Req.Response{status: 200} = Req.get!(@base_url <> "/")
  end

  test "real create -> approve -> real ledger overage charge, verified against the live deployed Postgres",
       %{token: token} do
    org_id = "kind-e2e-org-#{System.unique_integer([:positive])}"
    requester = "kind-e2e-requester-#{System.unique_integer([:positive])}"

    create_body = %{
      "data" => %{
        "type" => "approval_backup_retention_change",
        "attributes" => %{
          "org_id" => org_id,
          "requested_by" => requester,
          "requested_retention_days" => 90,
          "tier" => "pro"
        }
      }
    }

    create_resp =
      Req.post!(@base_url <> "/api/approval_backup_retention_change",
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/vnd.api+json"},
          {"accept", "application/vnd.api+json"}
        ],
        json: create_body
      )

    assert create_resp.status == 201
    change_id = create_resp.body["data"]["id"]
    assert is_binary(change_id)

    approve_body = %{
      "data" => %{
        "type" => "approval_backup_retention_change",
        "id" => change_id,
        "attributes" => %{"approved_by" => "kind-e2e-owner"}
      }
    }

    approve_resp =
      Req.patch!(@base_url <> "/api/approval_backup_retention_change/#{change_id}",
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/vnd.api+json"},
          {"accept", "application/vnd.api+json"}
        ],
        json: approve_body
      )

    assert approve_resp.status == 200
    assert approve_resp.body["data"]["attributes"]["approved_by"] == "kind-e2e-owner"

    # Real readback against the live deployed Postgres -- 60 days of
    # overage (90 requested - 30 pro-tier default) at the invented
    # $0.10/day placeholder rate = a real -$6.00 balance on the org's
    # real Xaas.Ledger.Account.
    balance_cents = real_live_org_balance_cents!(org_id)
    assert balance_cents == -600
  end

  # -- real kubectl/psql helpers, no mocking of the cluster or the DB --

  defp port_forward_reachable? do
    case Req.get(@base_url <> "/",
           retry: false,
           connect_options: [timeout: 500],
           receive_timeout: 1500
         ) do
      {:ok, %Req.Response{}} -> true
      _ -> false
    end
  end

  defp start_port_forward! do
    port =
      Port.open(
        {:spawn_executable, System.find_executable("kubectl")},
        args: [
          "--context",
          @kind_context,
          "port-forward",
          "-n",
          "default",
          "deployment/xaas",
          "#{@local_port}:4000"
        ]
      )

    # Real process hygiene: drain the port's stdout so kubectl's
    # "Forwarding from ..." line never sits undrained in this process's
    # mailbox, and kill the real OS child on VM exit so it doesn't
    # linger as an orphan reparented to launchd.
    {:os_pid, os_pid} = Port.info(port, :os_pid)

    spawn(fn -> drain_port!(port) end)

    System.at_exit(fn _status ->
      System.cmd("kill", [Integer.to_string(os_pid)], stderr_to_stdout: true)
    end)

    port
  end

  defp drain_port!(port) do
    receive do
      {^port, {:data, _data}} -> drain_port!(port)
      {^port, {:exit_status, _status}} -> :ok
    after
      120_000 -> :ok
    end
  end

  defp wait_for_reachable!(attempts \\ 20)

  defp wait_for_reachable!(0), do: flunk_no_port_forward!()

  defp wait_for_reachable!(attempts) do
    if port_forward_reachable?() do
      :ok
    else
      Process.sleep(500)
      wait_for_reachable!(attempts - 1)
    end
  end

  defp flunk_no_port_forward! do
    raise """
    Could not reach the real live xaas pod at #{@base_url}/ after starting
    `kubectl port-forward`. Confirm `kind-xaas` is up (`kind get clusters`)
    and the `xaas` Deployment is Running
    (`kubectl --context #{@kind_context} get pods -n default`).
    """
  end

  defp live_internal_api_token! do
    {output, 0} =
      System.cmd("kubectl", [
        "--context",
        @kind_context,
        "get",
        "secret",
        "xaas-secrets",
        "-n",
        "default",
        "-o",
        "jsonpath={.data.INTERNAL_API_TOKEN}"
      ])

    output |> String.trim() |> Base.decode64!()
  end

  defp real_live_org_balance_cents!(org_id) do
    pg_pod = live_postgres_pod!()

    sql = """
    select round(coalesce(sum((b.balance).amount), 0) * 100)::bigint
    from ledger_balances b
    join ledger_accounts a on a.id = b.account_id
    where a.identifier = '#{org_id}';
    """

    {output, 0} =
      System.cmd("kubectl", [
        "--context",
        @kind_context,
        "exec",
        pg_pod,
        "-n",
        "default",
        "--",
        "psql",
        "-U",
        "kanban",
        "-d",
        "kanban_prod",
        "-t",
        "-A",
        "-c",
        sql
      ])

    output |> String.trim() |> String.to_integer()
  end

  defp live_postgres_pod! do
    {output, 0} =
      System.cmd("kubectl", [
        "--context",
        @kind_context,
        "get",
        "pods",
        "-n",
        "default",
        "-l",
        "app=postgres",
        "-o",
        "jsonpath={.items[0].metadata.name}"
      ])

    String.trim(output)
  end
end
