# Build an autonomic capability-liveness loop in Ash

This tutorial walks you through the real MAPE-K (Monitor-Analyze-Plan-Execute over
shared Knowledge) loop already built in this repo: a shell script that checks whether
OTel Weaver registry capabilities are actually alive, an Ash resource that ingests
its output, a regression detector, and HTTP endpoints that expose the result. Every
file referenced here exists in the repo today; you will read, run, and verify the
real thing, not a simplified stand-in.

By the end you will have traced the loop end-to-end and run the same `mix test` and
`curl` commands that were used to verify it in this session.

## Prerequisites

- A working `~/xaas` checkout with dependencies installed (`mix deps.get`).
- Postgres running and `Xaas.Repo` migrated (this loop's tests use the real
  Ecto sandbox against a real Postgres database, not an in-memory fake).
- `~/chatman-ecosystem` checked out as a sibling directory (the default receipt
  path in step 2 assumes this layout: `../chatman-ecosystem/target/weaver-live/receipt.jsonl`
  relative to `~/xaas`).

## Step 1: Read the Monitor step — `weaver-live-matrix.sh`

The loop starts outside Ash entirely. `scripts/weaver-live-matrix.sh` in
`~/chatman-ecosystem` is a real shell script that runs an OTel Weaver v2 registry
check plus a loopback OTLP receiver, and emits one JSON line per capability to
`target/weaver-live/receipt.jsonl` — real OCEL v2 evidence, one row per capability,
real exit codes from an actually-executed command. Nothing in Ash "decides" a
capability is alive; the shell script's real exit code is the source of truth.

```bash
ls -la ~/chatman-ecosystem/scripts/weaver-live-matrix.sh
```

Each JSONL row looks like `{"capability": ..., "authority": ..., "status": ...,
"executed": ..., "exit_code": ..., "subject": ..., "detail": ...}` — this exact
shape is what step 3's ingest task reads.

## Step 2: Read the Knowledge resource — `CapabilityLivenessReceipt`

Open `lib/xaas/operations/capability_liveness_receipt.ex`. This is the Ash resource
that holds the loop's shared Knowledge (the "K" in MAPE-K): one row per
`(capability, subject)` pair, upserted on every re-ingest.

Three things to notice, in the actual DSL:

**The upsert identity** makes re-running the live-check against a new commit an
idempotent re-ingest instead of an append-only log:

```elixir
actions do
  defaults [:read, :destroy]

  create :ingest do
    description "Upsert one real weaver-live-matrix.sh receipt row (idempotent on capability+subject)."
    accept [:capability, :authority, :status, :executed, :exit_code, :subject, :detail]
    upsert? true
    upsert_identity :capability_subject
  end
end

identities do
  identity :capability_subject, [:capability, :subject]
end
```

**The bypass policy** is the load-bearing detail in this resource's `policies do`
block. The repo's floor is deny-by-default (`policy always() do forbid_if
always() end`), so without an explicit carve-out `:read` would be forbidden to
everyone. A plain `authorize_if` policy would still be ANDed against that catch-all
forbid — the resource's own comment documents that this was confirmed by a real
`Ash.read/2` returning `{:ok, []}` with "skipped query run due to filter being
false" before the fix. `bypass` is a distinct Ash mechanism: if it matches and
authorizes, later policies are skipped entirely.

```elixir
policies do
  bypass action_type(:read) do
    authorize_if always()
  end

  policy always() do
    forbid_if always()
  end
end
```

**Every attribute is a straight copy of a receipt field** — `capability`,
`authority`, `status`, `executed`, `exit_code`, `subject`, `detail`. This resource
never fabricates a status: whatever the shell command actually returned is what
gets persisted, verbatim.

## Step 3: Read the ingest task — `mix xaas.ingest_capability_receipts`

Open `lib/mix/tasks/xaas.ingest_capability_receipts.ex`. This is the
Analyze/Plan/Execute half of the loop: it reads the real `receipt.jsonl` file line
by line, decodes each JSON row, and calls the `:ingest` action for each one.

```elixir
path =
  case args do
    [p | _] -> p
    [] -> Path.expand("../chatman-ecosystem/target/weaver-live/receipt.jsonl", File.cwd!())
  end
```

Note the `authorize?: false` on the create call:

```elixir
Xaas.Operations.CapabilityLivenessReceipt
|> Ash.Changeset.for_create(:ingest, %{...})
|> Ash.create(authorize?: false)
```

This is deliberate and documented, not a shortcut: the ingest task is a
system-internal step (real telemetry becoming real Ash state), not a user-facing
action, so it explicitly bypasses the resource's deny-by-default policy floor
rather than weakening the floor itself. Every user-facing read of this resource
still goes through the real `bypass action_type(:read)` policy from step 2.

After ingesting, the task immediately calls the regression detector (step 4) and
prints its result — this is what makes the loop autonomic rather than a one-shot
batch import: every ingest run also re-checks history for a regression.

## Step 4: Read the Analyze step — `CapabilityLivenessRegressions`

Open `lib/xaas/operations/capability_liveness_regressions.ex`. `detect/1` reads all
persisted receipt rows, groups them by capability, sorts each group by
`inserted_at` (ingest time — the comment explains this is deliberate: subjects/commits
are not necessarily chronologically monotonic across branches), and flags any
capability whose most recent ingest is not `"ALIVE"` while an earlier ingest was:

```elixir
case Enum.reverse(sorted) do
  [%{status: latest_status} = latest | [%{status: prev_status} = prev | _]]
  when latest_status != "ALIVE" and prev_status == "ALIVE" ->
    [%{capability: capability, was: ..., now: ...}]

  _ ->
    []
end
```

Note `authorize?` defaults to `true` here (not `false`) — an adversarial review of
this session's work found the default had been `false`, an undocumented second
authorize-bypass path independent of the resource's own `bypass action_type(:read)`
policy from step 2. It was harmless only by coincidence (that policy already grants
read to everyone) but inaccurate against the documented claim that only the ingest
task bypasses authorization. Defaulting to `true` means `detect/1` goes through the
real Ash policy like any other caller unless a caller opts out explicitly.

## Step 5: Run the loop yourself

Generate a real receipt file (or use one already produced by
`weaver-live-matrix.sh` in `~/chatman-ecosystem/target/weaver-live/receipt.jsonl`),
then ingest it:

```bash
cd ~/xaas
mix xaas.ingest_capability_receipts
# or, with an explicit path:
mix xaas.ingest_capability_receipts /path/to/receipt.jsonl
```

You should see output like:

```
Ingested N/N real capability-liveness rows from <path>.
No capability regressions detected against prior real ingests.
```

or, if a capability that was previously `ALIVE` regresses:

```
1 REAL capability regression(s) detected:
  some.capability: ALIVE (commit-was-alive) -> BLOCKED (commit-now-blocked)
```

## Step 6: Read the HTTP exposure — router, plug, controllers

The loop's state and its Analyze step are both reachable over HTTP, not only from
the Mix task. Three real files wire this:

`lib/kanban_web/plugs/require_internal_api_token.ex` — a real auth gate found
genuinely missing by an adversarial review (both `/internal-api` and `/api` had
zero auth plug, reachable by anyone with network access). It requires a
constant-time-compared bearer token against the `INTERNAL_API_TOKEN` env var, and
fails closed (503) if that env var is unset, rather than silently allowing
everyone through.

`lib/kanban_web/router.ex` registers the specific
`/internal-api/capability_liveness_regressions` route **before** the catch-all
`forward "/internal-api", KanbanWeb.InternalApiRouter`:

```elixir
scope "/internal-api", KanbanWeb do
  pipe_through [:api, :require_internal_api_token]

  get "/capability_liveness_regressions", CapabilityRegressionsController, :index
  get "/ocel_summary", OcelSummaryController, :index
end

scope "/" do
  pipe_through [:internal_api, :require_internal_api_token]

  forward "/internal-api", KanbanWeb.InternalApiRouter
  forward "/api", KanbanWeb.ApiRouter
end
```

The ordering matters because a Phoenix `forward` matches every sub-path under its
prefix — declared after the specific route, it would shadow it. This was confirmed
via a real 404 `no_route_found` from `AshJsonApi.Router` before the reorder (see
commit `e07b9c8`).

`lib/kanban_web/controllers/capability_regressions_controller.ex` just calls
`Xaas.Operations.CapabilityLivenessRegressions.detect/1` and renders plain JSON
(not JSON:API, since the response is a computed diagnostic, not a resource
representation):

```elixir
def index(conn, _params) do
  regressions = Xaas.Operations.CapabilityLivenessRegressions.detect()
  json(conn, %{regressions: Enum.map(regressions, &format/1), count: length(regressions)})
end
```

`Xaas.Operations.CapabilityLivenessReceipt` itself is also exposed read-only via
its own `json_api do routes do get :read; index :read end end` block (step 2),
mounted through `KanbanWeb.InternalApiRouter` at `/internal-api`
(`lib/kanban_web/internal_api_router.ex`) — deliberately narrower than the
customer-facing `KanbanWeb.ApiRouter` at `/api`
(`lib/kanban_web/api_router.ex`), which mounts 6 domains' worth of mechanically
added read-only routes but explicitly excludes `Xaas.Ledger` and `Xaas.Accounts`
resources pending a real access-control design.

## Step 7: Verify it worked

Run the real Chicago-style tests — real `Ecto.Adapters.SQL.Sandbox`-backed
Postgres, real `Ash.create!`/`Ash.read!` calls, no mocks:

```bash
cd ~/xaas
mix test test/xaas/operations/capability_liveness_receipt_test.exs
mix test test/xaas/operations/capability_liveness_regressions_property_test.exs
mix test test/xaas/operations/capability_liveness_receipt_stress_test.exs
```

`capability_liveness_receipt_test.exs` asserts, on real persisted state:

- `ingest` creates a row with every field matching what was passed in.
- Re-ingesting the same `(capability, subject)` pair upserts in place (row count
  stays at 1; the second ingest's `status`/`detail` win) — proving the identity
  from step 2 actually enforces idempotency.
- `detect/1` returns `[]` when the only rows for a capability are `"ALIVE"`.
- `detect/1` returns a real regression entry when an `"ALIVE"` row is followed by a
  `"BLOCKED"` row for the same capability.

Boot the server and hit the real HTTP endpoints from step 6:

```bash
mix phx.server
```

```bash
curl -H "Authorization: Bearer $INTERNAL_API_TOKEN" \
  http://localhost:4000/internal-api/capability_liveness_regressions
# => {"count":0,"regressions":[]}  (honest zero, not fabricated)

curl -H "Authorization: Bearer $INTERNAL_API_TOKEN" \
  http://localhost:4000/internal-api/capability_liveness_receipts
# => real JSON:API collection of ingested receipt rows

curl -H "Authorization: Bearer $INTERNAL_API_TOKEN" \
  http://localhost:4000/internal-api/ocel_summary
# => {"total_events":N,"by_activity":{...},"by_outcome":{...},"log_path":"..."}
```

Without the bearer token, both routes now fail closed:

```bash
curl -i http://localhost:4000/internal-api/capability_liveness_regressions
# => 401 {"error":"unauthorized",...}  if INTERNAL_API_TOKEN is set but no header given
# => 503 {"error":"internal_api_misconfigured",...}  if INTERNAL_API_TOKEN is unset
```

## What you built

You traced a real MAPE-K loop:

1. **Monitor**: `~/chatman-ecosystem/scripts/weaver-live-matrix.sh` executes a real
   registry check and writes `receipt.jsonl`.
2. **Knowledge**: `Xaas.Operations.CapabilityLivenessReceipt` persists it, upserting
   on `(capability, subject)`, gated by a `bypass action_type(:read)` policy against
   an otherwise deny-by-default floor.
3. **Analyze/Plan/Execute**: `mix xaas.ingest_capability_receipts` ingests (bypassing
   authorization deliberately, as a documented system-internal exception) and
   immediately calls `CapabilityLivenessRegressions.detect/1`.
4. **Exposure**: two token-gated HTTP endpoints
   (`/internal-api/capability_liveness_regressions`,
   `/internal-api/capability_liveness_receipts`) make both the Knowledge and the
   Analyze step reachable outside the Mix task.

Every status value in this loop traces back to a real shell command's real exit
code — nothing in the Ash layer invents or upgrades a status.

## See Also

- `~/xaas/lib/xaas/operations/capability_liveness_receipt.ex` — the Knowledge resource (step 2)
- `~/xaas/lib/xaas/operations/capability_liveness_regressions.ex` — the Analyze step (step 4)
- `~/xaas/lib/mix/tasks/xaas.ingest_capability_receipts.ex` — the ingest task (step 3)
- `~/xaas/lib/xaas/telemetry/ocel_ash_emitter.ex` — the separate real OCEL v2 emitter
  attached to every Ash action's `:telemetry` `:stop` event (not `:exception` — Ash
  never emits that suffix, per this module's own corrected moduledoc); its log
  backs the `/internal-api/ocel_summary` endpoint above
- `~/xaas/lib/kanban_web/router.ex`, `internal_api_router.ex`, `api_router.ex`,
  `plugs/require_internal_api_token.ex` — the HTTP exposure and auth gate (step 6)
- `~/xaas/docs/ASH-MIGRATION-PLAN.md` — the broader migration plan this loop is
  part of, including the still-open Phase 5 customer-facing mutation-surface decision
- `~/xaas/test/xaas/operations/capability_liveness_receipt_test.exs`,
  `capability_liveness_regressions_property_test.exs`,
  `capability_liveness_receipt_stress_test.exs` — the real Chicago-style tests
  verified in step 7
