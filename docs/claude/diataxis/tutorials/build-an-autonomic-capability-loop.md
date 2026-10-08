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
    validate {Xaas.Operations.Validations.CapabilityLivenessReceiptStatusGate, []}
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
    authorize_if(always())
  end

  bypass action(:check_regressions) do
    authorize_if({Xaas.Checks.SystemActor, []})
  end

  bypass action(:ingest) do
    authorize_if({Xaas.Checks.SystemActor, service: :oban_scheduler})
  end

  policy always() do
    forbid_if(always())
  end
end
```

Beyond the read bypass, the resource now carries two more scoped `bypass`
blocks and a status-vocabulary gate, each with file:line anchors in
`lib/xaas/operations/capability_liveness_receipt.ex`:

- An `oban` scheduled action `:check_regressions` runs the regression
  detector every 15 minutes on a cron (`*/15 * * * *`,
  `capability_liveness_receipt.ex:45-59`), authorized as the real system
  authority `%Xaas.SystemAuthority{service: :oban_scheduler}` — the Analyze
  step no longer runs only when the Mix task or the HTTP route is polled.
- `bypass action(:ingest)` admits only the `:oban_scheduler` system
  authority (`capability_liveness_receipt.ex:100-102`), so the deny floor
  still refuses every other actor.
- The `:ingest` action validates status through
  `Xaas.Operations.Validations.CapabilityLivenessReceiptStatusGate`
  (`capability_liveness_receipt.ex:175`, added by W768 G1) — the mechanical
  ALIVE-requires-execution gate over the standing status vocabulary.

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

Note how the create call authorizes — it runs THROUGH authorization as the
`:oban_scheduler` system authority, never with `authorize?: false`:

```elixir
Xaas.Operations.CapabilityLivenessReceipt
|> Ash.Changeset.for_create(:ingest, %{...})
|> Ash.create(actor: Xaas.SystemAuthority.new(:oban_scheduler), authorize?: true)
```

This is deliberate and documented, not a shortcut: the ingest task is a
system-internal step (real telemetry becoming real Ash state), not a user-facing
action, so it acts AS the real `:oban_scheduler` system authority, which the
resource's scoped `bypass action(:ingest)` policy from step 2 admits
(`capability_liveness_receipt.ex:100-102`) — the deny-by-default floor still
refuses every other actor. No `authorize?: false` bypass remains anywhere on
this path (an earlier version of this tutorial showed `authorize?: false`
here; that path was removed — see the task's own comment,
`xaas.ingest_capability_receipts.ex:55-60`). Every user-facing read of this
resource still goes through the real `bypass action_type(:read)` policy from
step 2.

After ingesting, the task immediately calls the regression detector (step 4) and
prints its result — and the resource's own AshOban cron schedule (step 2) also
re-runs the detector every 15 minutes with or without an ingest: every ingest
run re-checks history for a regression, and the Analyze step now fires on a
schedule too.

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

`lib/xaas_web/plugs/require_internal_api_token.ex` — a real auth gate found
genuinely missing by an adversarial review (both `/internal-api` and `/api` had
zero auth plug, reachable by anyone with network access). It requires a
constant-time-compared bearer token against the `INTERNAL_API_TOKEN` env var, and
fails closed (503) if that env var is unset, rather than silently allowing
everyone through.

`lib/xaas_web/router.ex` registers the specific
`/internal-api/capability_liveness_regressions` route **before** the catch-all
`forward "/internal-api", XaasWeb.InternalApiRouter`:

```elixir
scope "/internal-api", XaasWeb do
  pipe_through [:api, :require_internal_api_token]

  get "/capability_liveness_regressions", CapabilityRegressionsController, :index
  get "/ocel_summary", OcelSummaryController, :index
end

scope "/" do
  pipe_through [:internal_api, :require_internal_api_token]

  forward "/internal-api", XaasWeb.InternalApiRouter
  forward "/api", XaasWeb.ApiRouter
end
```

The ordering matters because a Phoenix `forward` matches every sub-path under its
prefix — declared after the specific route, it would shadow it. This was confirmed
via a real 404 `no_route_found` from `AshJsonApi.Router` before the reorder (see
commit `e07b9c8`).

`lib/xaas_web/controllers/capability_regressions_controller.ex` just calls
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
mounted through `XaasWeb.InternalApiRouter` at `/internal-api`
(`lib/xaas_web/internal_api_router.ex`) — deliberately narrower than the
customer-facing `XaasWeb.ApiRouter` at `/api`
(`lib/xaas_web/api_router.ex`), which mounts all 7 domains (`api_router.ex:12-20`,
including `Xaas.Accounts` and `Xaas.Ledger`) but serves only resource-declared
routes: the sensitive `Xaas.Ledger` and `Xaas.Accounts.User`/`Token` resources
declare no JSON:API routes and remain unserved there, while `Xaas.Accounts.Org`
is the exception that declares routes (`lib/xaas/accounts/org.ex:175-181`,
read + create + update under `/api/orgs`).

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
3. **Analyze/Plan/Execute**: `mix xaas.ingest_capability_receipts` ingests AS
   the real `:oban_scheduler` system authority (through the scoped
   `bypass action(:ingest)` policy — no `authorize?: false` remains) and
   immediately calls `CapabilityLivenessRegressions.detect/1`; the resource's
   AshOban cron also re-runs the detector every 15 minutes.
4. **Exposure**: two token-gated HTTP endpoints
   (`/internal-api/capability_liveness_regressions`,
   `/internal-api/capability_liveness_receipts`) make both the Knowledge and the
   Analyze step reachable outside the Mix task.

Every status value in this loop traces back to a real shell command's real exit
code — nothing in the Ash layer invents or upgrades a status.

## Courts backing this tutorial (v26.10.6)

Dated 2026-10-07, at branch `feat/playwright-surface`, HEAD `a0723bf6`
(+ this lane's working-tree diff). Each entry names the court suite that
pins the claim and the wave receipt that witnessed it.

- **Token floor (the auth gate in step 6)** — W723 token-floor court:
  `test/xaas_web/require_internal_api_token_deepening_test.exs`, 16/16 ALIVE;
  receipt `docs/sjira/v26.10.6/plans/w723-token-floor-court.md`.
- **JSON:API content negotiation on the same mounted surface** (the
  `/internal-api` capability-liveness routes ride this stack) — W817
  negotiation court: `test/xaas_web/jsonapi_content_negotiation_test.exs`,
  which probes `capability_liveness_receipts` on both routers and pins the
  401-floor-first ordering and the 406/415 split; receipt
  `docs/sjira/v26.10.6/plans/w817-negotiation-court.md`.
- **Status vocabulary gate on `:ingest` (step 2)** — W768 G1:
  `Xaas.Operations.Validations.CapabilityLivenessReceiptStatusGate`
  (`capability_liveness_receipt.ex:175`); receipt
  `docs/sjira/v26.10.6/plans/w768-liveness-alive-gate.md`.
- **Lease kernel clock seam (the loop's wider ultracode capacity/lease
  sensing)** — W840: `live_leases/1` and `renew/1` in
  `lib/xaas/ultracode/lease.ex` judge expiry on `DurationBudget.now/0`
  (one clock for the capacity meter and the claim kernel); regression
  courts in `test/xaas/ultracode/lease_kernel_deepening_test.exs`
  (describe block `"W840 clock-seam regression courts"`); receipts
  `docs/sjira/v26.10.6/plans/w840-clock-seam.md` and
  `w811-lease-kernel-deepening.md` (W840 amended 3 W811 gap-asserting
  courts to the fixed semantics).
- **Execution-fabric worker verbs (the loop's actuation surface)** —
  10 MCP verbs on `POST /internal-api/execution/mcp`
  (`claim_next`, `heartbeat`, `admit_tool`, `record_provider_event`,
  `close_candidate`, `refuse`, `cancel_work`, `actuate`,
  `resolve_capability`, `surface` —
  `lib/xaas_web/controllers/execution_fabric_controller.ex:72-220`);
  refusal/idempotency contracts pinned by the W745/W747 deepening suites
  (`test/xaas_web/execution_fabric_deepening_test.exs`,
  `test/xaas/actuation/run_idempotency_deepening_test.exs`); receipt
  `docs/sjira/v26.10.6/plans/w749-runtime-contract-refresh.md` (verdict
  table row 2: brief said 8 verbs, code has 10).
- **OCEL-gated learning evidence (the emitter behind
  `/internal-api/ocel_summary`)** — W666 egress deepening courts:
  `test/xaas/telemetry/ocel_egress_deepening_test.exs`, 6 passed on the
  real emitter -> real ndjson bytes -> `Xaas.Ultracode.Ocel.Validator`
  path (correlation replayed from disk, rotation bound, no-fabricated-record
  law); receipt `docs/sjira/v26.10.6/plans/w666-ocel-egress-deepening.md`.

**Verified 2026-10-08 (W984ky truth-pass, branch `feat/playwright-surface`,
HEAD `7d9968d0` + working tree).** All referenced modules/tasks/tests/receipt
paths re-checked on disk: `Xaas.Actuation.run/4` (`lib/xaas/actuation.ex:26`),
`capability_liveness_receipt.ex` oban block `:45-59`, read bypass `:80`,
`:ingest` bypass `:100-102`, status gate `:175`, `renew/1` (`lease.ex:513`),
`live_leases/1` (`lease.ex:372`), 10 MCP verbs at
`execution_fabric_controller.ex:72-220` (line anchors still exact after the
lane's controller edits; `mcp/2` action at `:323`), `detect/1` defaults
`authorize?: true`, api_router 7 domains `:12-20`, org routes `:175-181`.
Two stale anchors corrected fix-forward this pass: StatusGate `:179`->`:175`,
`org.ex:178-188`->`:175-181`. Note: the step-2 `:ingest` DSL excerpt above now
also carries a `change {Xaas.Operations.Changes.SetPreviousStatus, []}`
(W968c/SPEC-14, prior-status preservation for same-subject regression
detection) that the excerpt predates; the excerpt remains representative of
the upsert-identity and gate claims.

## See Also

- `~/xaas/lib/xaas/operations/capability_liveness_receipt.ex` — the Knowledge resource (step 2)
- `~/xaas/lib/xaas/operations/capability_liveness_regressions.ex` — the Analyze step (step 4)
- `~/xaas/lib/mix/tasks/xaas.ingest_capability_receipts.ex` — the ingest task (step 3)
- `~/xaas/lib/xaas/telemetry/ocel_ash_emitter.ex` — the separate real OCEL v2 emitter
  attached to every Ash action's `:telemetry` `:stop` event (not `:exception` — Ash
  never emits that suffix, per this module's own corrected moduledoc); its log
  backs the `/internal-api/ocel_summary` endpoint above
- `~/xaas/lib/xaas_web/router.ex`, `internal_api_router.ex`, `api_router.ex`,
  `plugs/require_internal_api_token.ex` — the HTTP exposure and auth gate (step 6)
- `docs/archive/ASH-MIGRATION-PLAN.md` (historical) — the broader migration plan this loop is
  part of, including the still-open Phase 5 customer-facing mutation-surface decision
- `~/xaas/test/xaas/operations/capability_liveness_receipt_test.exs`,
  `capability_liveness_regressions_property_test.exs`,
  `capability_liveness_receipt_stress_test.exs` — the real Chicago-style tests
  verified in step 7
