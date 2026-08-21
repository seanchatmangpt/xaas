# Security and Testing Decisions in the Ash Migration

This is an EXPLANATION document (Diataxis: understanding-oriented) covering the reasoning
behind two decision clusters made during the Ash migration work on `~/xaas`: the
deny-by-default `Ash.Policy.Authorizer` floor and its `bypass` carve-out pattern, and the
Chicago-style testing discipline followed throughout. It is written to calibrate trust
accurately, including a real bug this session found and a real capability gap that still
exists.

## 1. Why deny-by-default, and why `bypass` specifically

### The floor

`docs/ASH-MIGRATION-PLAN.md` Phase 5 put a real, explicit deny-by-default policy block on
every one of the 47 previously-unauthorized Ash resources ported into `~/xaas`. The pattern,
seen verbatim in `lib/xaas/operations/capability_liveness_receipt.ex`:

```elixir
policies do
  policy always() do
    forbid_if always()
  end
end
```

The comment on this block in the real file states the actual state before this commit:
"this resource had zero policy blocks before this commit, meaning implicit allow-all
authorization on a repo with real deployed infra." That is the reason for the floor: Ash's
default when a resource has `authorizers: [Ash.Policy.Authorizer]` but no matching policy is
to deny, but a resource with *no* policies at all under `Ash.Policy.Authorizer` behaves
differently across versions and configurations, and the migration was not willing to depend
on that default holding for 47 newly-ported resources with live production data behind them.
An explicit `forbid_if always()` makes the deny unconditional and legible in the source, not
implicit in framework behavior someone has to look up.

### The bug this floor caused, found by adversarial review

Once the floor exists, every resource needs at least one policy that authorizes some real
access, or it is permanently read-only-to-nobody. The first attempt at exposing
`CapabilityLivenessReceipt`'s own ingested state read-only (see commit `7a2ed67`, "feat:
real internal-api JSON:API route for CapabilityLivenessReceipt, live-verified") used the
naive-looking construct:

```elixir
policy action_type(:read) do
  authorize_if always()
end
```

placed alongside the `policy always() do forbid_if always() end` floor. This looks correct
by local reading — "authorize reads, deny everything else" — but it is wrong under Ash's
real multi-policy semantics, and the commit message is honest about how this was caught: "a
real `Ash.read/2` call [confirmed] that a plain read policy still ANDs against the catch-all
`forbid_if always()`... returning `{:ok, []}` silently filtered."

The mechanism: Ash does not evaluate policies as first-match-wins. When more than one
`policy` block *matches* a given request (here, both `policy action_type(:read)` and
`policy always()` match a read request, since `always()` matches everything), **all
matching policies must authorize** for the request to succeed. The `policy always() do
forbid_if always() end` block matches every request, including reads, and its
`forbid_if always()` unconditionally denies. So a read request satisfies the first policy's
`authorize_if always()` but still fails the second policy's `forbid_if always()` — the
overall result is deny, silently. The observed symptom was not an error or a 403; it was
`{:ok, []}`, with Ash's own internal note (quoted in the code comment) "skipped query run due
to filter being false" — a query that returns successfully with zero rows looks exactly like
"there is no data yet," not "you were denied," which is precisely why this needed a real
`Ash.read/2` call against real seeded rows to surface, not a read of the DSL alone.

### Why `bypass` is the correct construct, not a weaker floor

The fix, present in the current file, replaces `policy` with `bypass`:

```elixir
bypass action_type(:read) do
  authorize_if always()
end
```

`bypass` is a distinct, deliberate Ash mechanism, not syntactic sugar for `policy`: if a
`bypass` block *matches* the request and its checks *authorize* it, Ash short-circuits —
later policies, including the catch-all floor, are skipped entirely for that request. It is
the escape hatch the deny-by-default floor's own comment implicitly calls for ("replace with
real per-action rules... never relax this to allow-all without an explicit rule") — `bypass`
lets that explicit rule actually win against the floor instead of being ANDed against it.

This was deliberately scoped as narrowly as the bug allowed, not used as a general
workaround: the carve-out is `action_type(:read)` only, on one resource
(`CapabilityLivenessReceipt`), justified in the same code comment as "internal
self-observability, not a customer-facing business decision." `:ingest` and `:destroy`
actions on this resource remain forbidden to every actor; the `mix
xaas.ingest_capability_receipts` task (see
`lib/mix/tasks/xaas.ingest_capability_receipts.ex`) writes to this resource via
`authorize?: false` as its own separate, explicit, system-internal exception, not by relying
on any policy. The `json_api routes` block on the same resource is likewise scoped to
`get :read` / `index :read` only, and the commit message calls out that this is
"deliberately narrower than the standing, deferred 'wire the real customer-facing API
surface for all 49 resources' decision" — the bypass fixes one resource's real, observed bug;
it is not a template for skipping the floor elsewhere without the same live-verification
step.

### The honest limitation

This gotcha is specific to Ash's AND-across-matching-policies semantics and is easy to get
wrong again on any of the other 46 resources still carrying only the bare
`policy always() do forbid_if always() end` floor: the instinct to add
`policy action_type(:read) do authorize_if always() end` when wiring the next resource's
routes will reproduce the exact same silent `{:ok, []}` bug unless `bypass` is used instead.
Nothing in the DSL prevents writing `policy` where `bypass` was needed — the only way this
was actually caught here was a live `Ash.read/2` call against real seeded data, not a code
review of the policy block's shape. Anyone porting another resource's read access should
budget for that same live check, not trust that the block "looks right."

## 2. Chicago-style testing discipline: what was done, and what was deliberately not

### What was done: real Postgres, zero mocks

Every test file added this session against the capability-liveness/OCEL work follows the
same real pattern, visible directly in `test/xaas/operations/capability_liveness_receipt_test.exs`:

```elixir
setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
  Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
  :ok
end
```

and its own moduledoc states the discipline explicitly: "Real Chicago-style tests: real
`Ecto.Adapters.SQL.Sandbox`-backed Postgres (`Xaas.Repo`), real `Ash.create!`/`Ash.read!`
calls against the real `capability_liveness_receipts` table. No mocks/stubs of any
collaborator." `test/test_helper.exs` sets `Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo,
:manual)` globally, so every test in the suite opts into a real, isolated, rolled-back
Postgres transaction rather than any in-memory fake — assertions run against actual
persisted rows returned by actual `Ash.create!`/`Ash.read!` calls, not against a stand-in
that only approximates Ecto's or Postgres's behavior.

This pattern repeats across the other test files added this session:
`test/xaas/operations/capability_liveness_regressions_property_test.exs` (property-based
tests over real ingested rows), `test/xaas/operations/capability_liveness_receipt_stress_test.exs`
(stress tests against the real Sandbox-backed repo), `test/mix/tasks/xaas_ingest_capability_receipts_test.exs`
(the real Mix task exercised against a real receipt file, not a stubbed file reader), and
`test/kanban_web/internal_api_router_test.exs` / `test/kanban_web/controllers/*_test.exs`
(real Phoenix/AshJsonApi.Router requests through the real router, real JSON:API responses
asserted on).

A real grep run this session over the test directory for the banned interaction-mocking
vocabulary — `unittest.mock`, `Mock(`, `MagicMock`, `patch(`, `monkeypatch`, `Mox` (Elixir's
mocking library, the direct equivalent of Python's `unittest.mock` for this codebase) —
returned zero matches:

```console
$ grep -rn "unittest.mock\|Mock(\|MagicMock\|patch(\|monkeypatch\|Mox" test/
$ echo $?
0
```

Zero matches means the test suite added this session has no interaction-based test doubles
standing in for a collaborator this codebase owns (the real `Xaas.Repo`, the real Ash
resources, the real Phoenix router) — every assertion is state-based, checking real returned
structs, real persisted attribute values, or real HTTP response bodies.

### What was deliberately not done: the dead `:exception` telemetry handlers

The Chicago discipline is about using real collaborators, not about claiming a capability the
code does not actually have. `lib/xaas/telemetry/ocel_ash_emitter.ex`'s moduledoc documents a
real, corrected gap found by adversarial review of the module itself, not by a test:

An earlier version of this emitter attached `:telemetry` handlers for both the `:stop` and
`:exception` event suffixes on Ash's action telemetry spans (`[:ash, <domain>, <action_type>,
:stop]` and the equivalent `:exception` variant). Reading Ash's own source
(`deps/ash/lib/ash/tracer/tracer.ex`, `Ash.Tracer.telemetry_span/4`) showed that Ash wraps
every action in `try/after`, not `try/rescue`, and emits only the `:stop` event —
unconditionally, whether the action returns normally or raises. There is no `:exception`
event anywhere in Ash's own action pipeline for this module to attach to. The `:exception`
handlers in the earlier version were real, verified dead code: never once invoked, on any
real action, successful or failing. They were removed.

The documented, current, narrower capability is stated in the same moduledoc: "This module
cannot currently tell a successful action from a failed one — only 'ran to completion of the
span.'" Every OCEL v2 event this emitter writes has `outcome: "stop"` regardless of whether
the underlying Ash action succeeded or raised; a raised exception still produces a `:stop`
telemetry event (since it fires in the `after` clause) before the exception itself
propagates and surfaces through the action's normal `{:error, ...}` return path or a crashed
process, not through any distinguishable telemetry payload this module currently reads.

This is named here as a deliberate scope limit, not a bug still open: fixing it would require
either parsing the action's own result inside the telemetry handler (the `:stop` event's
measurements/metadata do carry enough to potentially distinguish success from `{:error,
...}`, but this module does not currently do that inspection) or wrapping actions in
application-level `try/rescue` to synthesize a real exception signal Ash itself does not
provide. Neither was built this session. The honest status of the OCEL log this module
produces is: a complete, correlated record of *which* Ash actions ran, on *which* resources,
correlated to real OpenTelemetry spans — and an incomplete record of *whether* they
succeeded.

## See Also

- `docs/claude/diataxis/explanation/architecture-overview.md` — whole-system map this doc is one narrow piece of
- `lib/xaas/operations/capability_liveness_receipt.ex` — the real `bypass`/floor policy code
  discussed in section 1
- `lib/mix/tasks/xaas.ingest_capability_receipts.ex` — the real `authorize?: false` ingest
  exception referenced in section 1
- `lib/xaas/telemetry/ocel_ash_emitter.ex` — the real emitter and its documented `:stop`-only
  limitation discussed in section 2
- `test/xaas/operations/capability_liveness_receipt_test.exs` — the real Sandbox-backed test
  pattern quoted in section 2
- `test/test_helper.exs` — the real global `Ecto.Adapters.SQL.Sandbox.mode(..., :manual)`
  setup
- `docs/ASH-MIGRATION-PLAN.md` — Phase 5 deny-by-default floor plan and the deferred
  customer-facing API surface decision referenced in section 1
