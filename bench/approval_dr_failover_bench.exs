Mix.Task.run("app.start")

# Real Benchee benchmark against the real, live docker-compose Postgres
# (Xaas.Repo, configured via DEV_DB_* env vars per config/dev.exs's real
# pattern -- run this script with those exported, e.g.:
#
#   cd ~/xaas && export DEV_DB_USERNAME=postgres \
#     DEV_DB_PASSWORD=$(cat secrets/.postgrespassword) \
#     DEV_DB_HOSTNAME=localhost \
#     DEV_DB_PORT=$(docker compose port db 5432 | cut -d: -f2) && \
#     mix run bench/approval_dr_failover_bench.exs
#
# Measures real Ash.create!/update! throughput for
# Xaas.Governance.ApprovalDrFailover's :create and :approve actions:
#
#   (a) create path  -- real Postgres INSERT of a fresh DR failover
#       request row (random requested_by/region each iteration).
#   (b) approve path -- real Postgres UPDATE approving a freshly-created
#       failover row, after opening a real, matching open
#       Xaas.Operations.Incident so
#       ApprovalDrFailoverRequiresOpenIncident passes, and using a
#       distinct approved_by so ApprovalDrFailoverRequiresApprover passes.

alias Xaas.Governance.ApprovalDrFailover
alias Xaas.Operations.Incident

Benchee.run(
  %{
    "create (real INSERT, fresh region each run)" => fn ->
      Ash.create!(
        ApprovalDrFailover,
        %{
          org_id: "bench-org",
          requested_by: "bench-requester-#{System.unique_integer([:positive, :monotonic])}",
          from_region: "bench-region-#{System.unique_integer([:positive, :monotonic])}",
          to_region: "bench-target-region",
          reason: "benchee create run"
        },
        action: :create,
        authorize?: false
      )
    end,
    "approve (real UPDATE, with real open incident precondition)" => fn ->
      region = "bench-approve-region-#{System.unique_integer([:positive, :monotonic])}"

      Ash.create!(
        Incident,
        %{
          org_id: "bench-org",
          title: "bench incident",
          description: "benchee approve-path incident precondition",
          region: region,
          status: :open,
          opened_at: DateTime.utc_now()
        },
        action: :create,
        authorize?: false
      )

      failover =
        Ash.create!(
          ApprovalDrFailover,
          %{
            org_id: "bench-org",
            requested_by: "bench-requester-#{System.unique_integer([:positive, :monotonic])}",
            from_region: region,
            to_region: "bench-target-region",
            reason: "benchee approve run"
          },
          action: :create,
          authorize?: false
        )

      Ash.update!(
        failover,
        %{approved_by: "bench-approver-#{System.unique_integer([:positive, :monotonic])}"},
        action: :approve,
        authorize?: false
      )
    end
  },
  time: 5,
  warmup: 2,
  memory_time: 1
)
