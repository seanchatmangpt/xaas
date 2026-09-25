Mix.Task.run("app.start")

# Real Benchee benchmark against the real, live docker-compose Postgres
# (Xaas.Repo, configured via DEV_DB_* env vars per config/dev.exs's real
# pattern -- run this script with those exported, e.g.:
#
#   cd ~/xaas && export DEV_DB_USERNAME=postgres \
#     DEV_DB_PASSWORD=$(cat secrets/.postgrespassword) \
#     DEV_DB_HOSTNAME=localhost \
#     DEV_DB_PORT=$(docker compose port db 5432 | cut -d: -f2) && \
#     mix run bench/capability_liveness_ingest_bench.exs
#
# Measures real Ash.create! throughput for
# Xaas.Operations.CapabilityLivenessReceipt's :ingest upsert action:
#
#   (a) update path  -- repeated real upsert of one fixed capability+subject
#       row (already exists after the first iteration), exercising the real
#       Postgres UPDATE branch of the upsert.
#   (b) insert path   -- a real fresh row (random subject each iteration),
#       exercising the real Postgres INSERT branch of the upsert.

alias Xaas.Operations.CapabilityLivenessReceipt

# Ensure the fixed "update path" row exists before benchmarking updates to it.
Ash.create!(
  CapabilityLivenessReceipt,
  %{
    capability: "bench.update.capability",
    authority: "bench",
    status: "ALIVE",
    executed: true,
    exit_code: 0,
    subject: "bench-fixed-subject",
    detail: "benchee warmup row"
  },
  action: :ingest,
  authorize?: false
)

Benchee.run(
  %{
    "ingest upsert (update path, fixed capability+subject)" => fn ->
      Ash.create!(
        CapabilityLivenessReceipt,
        %{
          capability: "bench.update.capability",
          authority: "bench",
          status: "ALIVE",
          executed: true,
          exit_code: 0,
          subject: "bench-fixed-subject",
          detail: "benchee update run at #{System.system_time(:microsecond)}"
        },
        action: :ingest,
        authorize?: false
      )
    end,
    "ingest upsert (insert path, random subject each run)" => fn ->
      Ash.create!(
        CapabilityLivenessReceipt,
        %{
          capability: "bench.insert.capability",
          authority: "bench",
          status: "ALIVE",
          executed: true,
          exit_code: 0,
          subject: "bench-random-#{System.unique_integer([:positive, :monotonic])}",
          detail: "benchee insert run"
        },
        action: :ingest,
        authorize?: false
      )
    end
  },
  time: 5,
  warmup: 2,
  memory_time: 1
)
