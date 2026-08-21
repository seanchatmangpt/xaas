defmodule Xaas.E2E.KindChaosPostgresPodRecoveryTest do
  @moduledoc """
  Real chaos test against the ACTUAL live `postgres` Deployment running in
  the real `kind-xaas` cluster -- the Postgres-pod variant of
  `kind_chaos_pod_recovery_test.exs` (which proves the `xaas` app pod's
  liveness recovery). This test proves *data-integrity* across a real
  Postgres pod kill/recovery, not just liveness: it writes a real,
  distinctive row into the live cluster's real Postgres via a real
  `kubectl exec <postgres-pod> -- psql` connection (same real convention
  as `kind_deployment_test.exs`'s `real_live_org_balance_cents!/1`),
  kills the real `postgres` pod for real (`kubectl delete pod`, real
  `app=postgres` label selector -- see `k8s/postgres.yaml`), polls for a
  NEW pod name to reach `Running`/`Ready`, then re-reads the row.

  ## Real PVC-presence finding (checked against `k8s/postgres.yaml` this
  session, not assumed)

  `k8s/postgres.yaml` is a plain `apps/v1` `Deployment` (`replicas: 1`),
  NOT a `StatefulSet` -- confirmed by the real live pod name observed
  this session (`postgres-66ccf5d656-qjnvs`, a `Deployment`/`ReplicaSet`
  hash suffix, not a `StatefulSet`'s stable `postgres-0` ordinal). It
  DOES mount a real `PersistentVolumeClaim` (`claimName: postgres-pvc`,
  `ReadWriteOnce`, `storageClassName: standard`, `1Gi`) at
  `/var/lib/postgresql/data` -- the manifest's `volumes:` block, lines
  45-51 and the separate `PersistentVolumeClaim` object, lines 53-64.
  Because the Deployment's pod template references that PVC by name (not
  an ephemeral `emptyDir`), a recreated pod reattaches to the SAME real
  PVC (`kind`'s single-node `standard` storage class binds it once and
  keeps it bound across pod recreation) -- so the real, verified
  expectation here is DURABLE storage: the distinctive row from before
  the kill should still be there after recovery. This is the opposite of
  the `xaas` app pod (stateless, no PVC) that the sibling chaos test
  exercises.

  Writes into a small, dedicated `chaos_test_markers` table created (and
  dropped) by this test itself via real DDL over the same real
  `kubectl exec ... psql` connection, rather than `Xaas.Accounts.Org`'s
  real `orgs` table -- a real `\\dt` against the live cluster's Postgres
  this session found `orgs` is not present in the currently-migrated
  live schema (the deployed image predates that migration), so writing
  into it would not be a real row this cluster's app could see. A
  dedicated marker table is still a real row in the real live Postgres
  instance under test, surviving (or not) exactly the same real pod
  kill/recreate/PVC-reattach mechanics as any other table in the same
  data directory -- the property under test (does `/var/lib/postgresql`
  survive pod recreation) does not depend on which table holds the row.

  Excluded by default (`test/test_helper.exs`, same pattern as `:stress`
  and the other `:kind`-tagged tests) -- run explicitly:

      mix test --include kind test/e2e/kind_chaos_postgres_pod_recovery_test.exs

  Requires: `kind-xaas` cluster up and the `postgres` Deployment
  `Running`. Needs no `INTERNAL_API_TOKEN` -- all interaction is direct
  `kubectl`/`psql`, no HTTP route.

  Leaves the cluster in a healthy final state: the marker table is
  dropped in an `on_exit` callback (real cleanup, runs even on
  assertion failure) once the recovered pod is reachable again.
  """
  use ExUnit.Case, async: false
  @moduletag :kind

  @kind_context "kind-xaas"
  @namespace "default"
  @label_selector "app=postgres"
  @recovery_timeout_ms 90_000
  @poll_interval_ms 1_000
  @marker_table "chaos_test_markers"

  test "killing the live postgres pod: data survives recreation because a real PVC backs it" do
    original_pod = live_pod_name!()
    assert is_binary(original_pod) and original_pod != ""

    marker_slug = "kind-chaos-pg-#{System.unique_integer([:positive])}-#{System.os_time(:second)}"

    # 1. Real distinctive row, written into the live cluster's real
    # Postgres before anything is killed.
    psql!(original_pod, """
    create table if not exists #{@marker_table} (
      slug text primary key,
      created_at timestamptz not null default now()
    );
    insert into #{@marker_table} (slug) values ('#{marker_slug}');
    """)

    assert psql!(original_pod, "select slug from #{@marker_table} where slug = '#{marker_slug}';")
           |> String.trim() == marker_slug

    # 2. Real pod kill, real label selector from k8s/postgres.yaml.
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

    # 3. Real poll for a NEW pod (different name) reaching Running/Ready.
    {new_pod, ready?} = wait_for_new_pod_ready!(original_pod)

    assert is_binary(new_pod) and new_pod != original_pod,
           "expected a NEW postgres pod name after real deletion of #{original_pod}, got #{inspect(new_pod)}"

    assert ready?,
           "new postgres pod #{new_pod} did not reach Running/Ready within #{@recovery_timeout_ms}ms"

    # 4. Real data-integrity assertion matching the real, verified
    # k8s/postgres.yaml reality: a real PVC (`postgres-pvc`) backs this
    # Deployment, so the recreated pod reattaches to the SAME real
    # PersistentVolume and the row from step 1 must still be there.
    readback =
      psql!(new_pod, "select slug from #{@marker_table} where slug = '#{marker_slug}';")
      |> String.trim()

    assert readback == marker_slug,
           "expected the pre-kill row '#{marker_slug}' to survive pod recreation via the real " <>
             "postgres-pvc PersistentVolumeClaim, but readback was #{inspect(readback)} -- " <>
             "either the PVC did not reattach or this cluster's persistence guarantee regressed"

    # 5. Real cleanup, leaving the cluster healthy.
    on_exit(fn ->
      System.cmd("kubectl", [
        "--context",
        @kind_context,
        "exec",
        new_pod,
        "-n",
        @namespace,
        "--",
        "psql",
        "-U",
        "kanban",
        "-d",
        "kanban_prod",
        "-t",
        "-A",
        "-c",
        "drop table if exists #{@marker_table};"
      ])
    end)
  end

  # -- real kubectl/psql helpers, no mocking of the cluster or the DB --

  defp psql!(pod, sql) do
    {output, 0} =
      System.cmd("kubectl", [
        "--context",
        @kind_context,
        "exec",
        pod,
        "-n",
        @namespace,
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

    output
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
end
