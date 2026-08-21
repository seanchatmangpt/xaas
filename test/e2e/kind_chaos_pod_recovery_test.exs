defmodule Xaas.E2E.KindChaosPodRecoveryTest do
  @moduledoc """
  Real chaos test against the ACTUAL live `xaas` Deployment running in the
  real `kind-xaas` cluster. Kills the currently-running `xaas` pod for
  real via `kubectl delete pod --context kind-xaas`, then polls the real
  Kubernetes API (`kubectl get pods -l app=xaas`) plus a real HTTP health
  check against the live pod (through a real `kubectl port-forward`,
  reusing the same self-start convention as `kind_deployment_test.exs`)
  until a *new* pod (different `metadata.name`, since the Deployment's
  `ReplicaSet` will recreate one) reaches `Running`/`Ready` and starts
  answering real `GET /` with `200` again. This proves the real
  Deployment controller's self-healing (it owns a `ReplicaSet` with
  `replicas: 1`, so deleting the sole pod forces a real recreate) -- not
  a mocked Kubernetes API. All cluster interaction goes through the real
  `kubectl` CLI via `System.cmd/2`, no client library, no mocking.

  Excluded by default (`test/test_helper.exs`, same pattern as `:stress`
  and the other `:kind`-tagged test) -- run explicitly:

      mix test --include kind test/e2e/kind_chaos_pod_recovery_test.exs

  Requires: `kind-xaas` cluster up and the `xaas` Deployment `Running`
  (see `kind_deployment_test.exs`'s moduledoc for the full real
  port-forward/build-lock-contention notes this test reuses verbatim).

  This test intentionally does NOT touch `Xaas.Ledger.*` or any other
  sensitive resource -- it only observes real Pod/Deployment state and
  hits the unauthenticated `GET /` health endpoint, so it needs no
  `INTERNAL_API_TOKEN`.
  """
  use ExUnit.Case, async: false
  @moduletag :kind

  @kind_context "kind-xaas"
  @namespace "default"
  @label_selector "app=xaas"
  @local_port 4002
  @base_url "http://localhost:#{@local_port}"
  @recovery_timeout_ms 60_000
  @poll_interval_ms 1_000

  test "deleting the live xaas pod triggers real Deployment self-healing to a new Running/Ready pod" do
    original_pod = live_pod_name!()
    assert is_binary(original_pod) and original_pod != ""

    {delete_output, 0} =
      System.cmd("kubectl", [
        "--context",
        @kind_context,
        "delete",
        "pod",
        original_pod,
        "-n",
        @namespace,
        "--wait=false"
      ])

    assert delete_output =~ "deleted"

    {new_pod, ready?} = wait_for_new_pod_ready!(original_pod)

    assert is_binary(new_pod) and new_pod != original_pod,
           "expected a NEW pod name after real deletion of #{original_pod}, got #{inspect(new_pod)}"

    assert ready?, "new pod #{new_pod} did not reach Running/Ready within #{@recovery_timeout_ms}ms"

    # Real HTTP confirmation the recovered pod is actually serving traffic
    # again, not just reporting Ready to the k8s API.
    unless port_forward_reachable?() do
      start_port_forward!()
      wait_for_http_reachable!()
    end

    assert %Req.Response{status: 200} = Req.get!(@base_url <> "/")
  end

  test "real /api create with a real malformed JSON:API body (wrong attribute type) is really rejected" do
    unless port_forward_reachable?() do
      start_port_forward!()
      wait_for_http_reachable!()
    end

    token = live_internal_api_token!()

    # requested_retention_days is a real integer attribute on
    # Xaas.Governance.ApprovalBackupRetentionChange -- sending a string
    # here is a real type mismatch, not a missing/absent field, giving
    # this test a distinct negative shape from
    # kind_deployment_test.exs's missing-data.type case.
    malformed_body = %{
      "data" => %{
        "type" => "approval_backup_retention_change",
        "attributes" => %{
          "org_id" => "kind-e2e-malformed-type-#{System.unique_integer([:positive])}",
          "requested_by" => "kind-e2e-requester",
          "requested_retention_days" => "not-an-integer",
          "tier" => "pro"
        }
      }
    }

    resp =
      Req.post!(@base_url <> "/api/approval_backup_retention_change",
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/vnd.api+json"},
          {"accept", "application/vnd.api+json"}
        ],
        json: malformed_body
      )

    assert resp.status in [400, 422]
  end

  # -- real kubectl helpers, no mocking of the cluster --

  defp live_internal_api_token! do
    {output, 0} =
      System.cmd("kubectl", [
        "--context",
        @kind_context,
        "get",
        "secret",
        "xaas-secrets",
        "-n",
        @namespace,
        "-o",
        "jsonpath={.data.INTERNAL_API_TOKEN}"
      ])

    output |> String.trim() |> Base.decode64!()
  end

  defp live_pod_name! do
    {output, 0} =
      System.cmd("kubectl", [
        "--context",
        @kind_context,
        "get",
        "pods",
        "-n",
        @namespace,
        "-l",
        @label_selector,
        "-o",
        "jsonpath={.items[0].metadata.name}"
      ])

    String.trim(output)
  end

  defp wait_for_new_pod_ready!(original_pod, deadline \\ nil)

  defp wait_for_new_pod_ready!(original_pod, nil) do
    wait_for_new_pod_ready!(original_pod, System.monotonic_time(:millisecond) + @recovery_timeout_ms)
  end

  defp wait_for_new_pod_ready!(original_pod, deadline) do
    {out, 0} =
      System.cmd("kubectl", [
        "--context",
        @kind_context,
        "get",
        "pods",
        "-n",
        @namespace,
        "-l",
        @label_selector,
        "-o",
        "jsonpath={range .items[*]}{.metadata.name}{\" \"}{.status.phase}{\" \"}{.status.containerStatuses[0].ready}{\"\\n\"}{end}"
      ])

    candidates =
      out
      |> String.trim()
      |> String.split("\n", trim: true)
      |> Enum.map(fn line ->
        case String.split(line, " ") do
          [name, phase, ready] -> {name, phase, ready == "true"}
          [name, phase] -> {name, phase, false}
          _ -> {nil, nil, false}
        end
      end)
      |> Enum.reject(fn {name, _, _} -> is_nil(name) or name == original_pod end)

    case Enum.find(candidates, fn {_name, phase, ready} -> phase == "Running" and ready end) do
      {name, _phase, true} ->
        {name, true}

      _ ->
        if System.monotonic_time(:millisecond) >= deadline do
          fallback = List.first(candidates)
          case fallback do
            {name, _phase, _ready} -> {name, false}
            nil -> {nil, false}
          end
        else
          Process.sleep(@poll_interval_ms)
          wait_for_new_pod_ready!(original_pod, deadline)
        end
    end
  end

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
          @namespace,
          "deployment/xaas",
          "#{@local_port}:4000"
        ]
      )

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

  defp wait_for_http_reachable!(attempts \\ 20)

  defp wait_for_http_reachable!(0) do
    raise """
    Could not reach the recovered xaas pod at #{@base_url}/ after starting
    `kubectl port-forward`. Confirm the new pod is Running/Ready
    (`kubectl --context #{@kind_context} get pods -n #{@namespace} -l #{@label_selector}`).
    """
  end

  defp wait_for_http_reachable!(attempts) do
    if port_forward_reachable?() do
      :ok
    else
      Process.sleep(500)
      wait_for_http_reachable!(attempts - 1)
    end
  end
end
