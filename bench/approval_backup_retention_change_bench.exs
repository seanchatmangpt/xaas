Mix.Task.run("app.start")

# Real Benchee benchmark against the real, live docker-compose Postgres
# (Xaas.Repo, configured via DEV_DB_* env vars per config/dev.exs's real
# pattern -- run this script with those exported, e.g.:
#
#   cd ~/xaas && export DEV_DB_USERNAME=postgres \
#     DEV_DB_PASSWORD=$(cat secrets/.postgrespassword) \
#     DEV_DB_HOSTNAME=localhost \
#     DEV_DB_PORT=$(docker compose port db 5432 | cut -d: -f2) && \
#     mix run bench/approval_backup_retention_change_bench.exs
#
# Measures real Ash.create!/Ash.update! latency for
# Xaas.Governance.ApprovalBackupRetentionChange's :create (submit) and
# :approve actions:
#
#   (a) create -- real Ash.create!, hitting the real
#       ApprovalBackupRetentionChangeWithinTierRange validation.
#   (b) approve (no overage) -- real Ash.update! with `tier: :pro`,
#       `requested_retention_days: 30` (== ApprovalBackupRetentionChange
#       ChargeOverage's real `:pro` default of 30, so overage_days == 0
#       and no real Xaas.Ledger.Transfer fires), isolating the approve
#       action's own real validation/change cost.
#   (c) approve (with overage) -- real Ash.update! with
#       `requested_retention_days: 90` (max of :pro's real 7-90 range),
#       which DOES exceed the :pro default of 30 and so DOES trigger a
#       real Xaas.Ledger.Transfer inside the approve action's own
#       transaction -- measuring the real cost of the ledger side effect.

alias Xaas.Governance.ApprovalBackupRetentionChange

org =
  Ash.create!(
    Xaas.Accounts.Org,
    %{
      name: "Bench Org",
      slug: "bench-org-#{System.unique_integer([:positive, :monotonic])}"
    },
    action: :create,
    authorize?: false
  )

Benchee.run(
  %{
    "create (submit retention-change request)" => fn ->
      Ash.create!(
        ApprovalBackupRetentionChange,
        %{
          org_id: org.slug,
          requested_by: "bench-requester-#{System.unique_integer([:positive, :monotonic])}",
          requested_retention_days: 30,
          tier: :pro
        },
        action: :create,
        authorize?: false
      )
    end,
    "approve (no overage, requested == tier default)" => fn ->
      created =
        Ash.create!(
          ApprovalBackupRetentionChange,
          %{
            org_id: org.slug,
            requested_by: "bench-requester-#{System.unique_integer([:positive, :monotonic])}",
            requested_retention_days: 30,
            tier: :pro
          },
          action: :create,
          authorize?: false
        )

      Ash.update!(
        created,
        %{approved_by: "bench-approver-#{System.unique_integer([:positive, :monotonic])}"},
        action: :approve,
        authorize?: false
      )
    end,
    "approve (with overage, real Ledger.Transfer)" => fn ->
      created =
        Ash.create!(
          ApprovalBackupRetentionChange,
          %{
            org_id: org.slug,
            requested_by: "bench-requester-#{System.unique_integer([:positive, :monotonic])}",
            requested_retention_days: 90,
            tier: :pro
          },
          action: :create,
          authorize?: false
        )

      Ash.update!(
        created,
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
