# Ash-ecosystem usage rules (xaas)

<!--
Hand-curated, compressed from the Ash-ecosystem core-team usage rules (Zach Daniel
et al.) vendored under deps/*/usage-rules.md and deps/*/usage-rules/*.md. NOT
auto-synced — `mix usage_rules.sync` produced a 2539-line/226-section dump that was
too dense to be a practical read-first doc, so this is a deliberately trimmed,
project-relevant subset instead: only the packages xaas actually depends on
(mix.exs), and only the rules with real bite (gotchas, AND/OR-logic traps, "avoid
this" guidance) rather than full boilerplate setup walkthroughs. When in doubt about
exact syntax, the full source is still in deps/<pkg>/usage-rules.md and
deps/<pkg>/usage-rules/*.md — this file is a map, not a replacement.

Maintenance: update by hand when a real gap is found (a mistake this file would
have prevented), not by re-running the sync tool. If a full re-sync is ever wanted
for comparison: `mix usage_rules.sync /tmp/AGENTS-full.md --all --inline usage_rules:all --link-to-folder deps --yes`.
-->


## Ash core

**Actions & business logic**
- Business logic lives inside actions, not helper modules. Prefer specific,
  well-named actions over generic CRUD.
- Prefer domain **code interfaces** over calling `Ash`/`Ash.Changeset`/`Ash.Query`
  directly, especially from web modules (LiveViews/controllers) — same reasoning as
  not calling `Repo.get/2` outside a context. Define `define :fun_name, action:
  :action_name` on the domain; use `get_by:` for identity-keyed lookups.
- Error handling: `Ash.create/…` and code-interface calls return `{:ok, _}`/`{:error,
  _}`; every function has a `!` variant. Prefer raising `!` variants over
  `{:ok, x} = call(...)` pattern-matching.
- Custom `Change`/`Validation`/`Calculation`/`Preparation` logic: put it in its own
  module (`use Ash.Resource.Change` etc.), not an inline anonymous function.

**Atomic changes / `require_atomic? false`** (xaas has ~20+ instances of this —
see `lib/xaas/marketplace/provider.ex`, `lib/xaas/accounts/user.ex`,
`lib/xaas/accounts/org.ex`, etc.)
- By default, update/destroy actions require every change/validation to support
  atomic (in-database) execution; `require_atomic? false` opts an action out.
- **Legitimately needed** when a `before_action`/`around_action` hook must read/
  mutate the loaded record, a change reads `Ash.Changeset.get_data/2`, or a
  validation genuinely can't be expressed as a DB expression.
- **Not needed** (don't reach for it) for simple attribute sets (`expr(now())`),
  counters (`atomic_update/2`), or purely `after_action`/`after_transaction` hooks —
  those don't block atomicity.
- Custom changes/validations can implement an `atomic/3` callback to stay atomic
  instead of falling back to `require_atomic? false`.
- xaas's own pattern (ReactorContext validation + `transition_state` change on
  lifecycle-transition actions) is a deliberate, disclosed exception, not a default
  reached for convenience — don't "fix" it without a concrete failure driving the
  change.

**Authorization / policies**
- Set the `actor` on the query/changeset/**input**, not as an option to the final
  `Ash.read!`/`Ash.create!` call: `Ash.Query.for_read(:read, %{}, actor: user)`, not
  `Ash.read!(query, actor: user)`.
- **Policy evaluation is OR, not AND, by default** — the first check inside a
  `policy` block that produces a decision determines the outcome. Two
  `authorize_if`s in the same policy are OR'd:
  ```elixir
  # WRONG — passes if EITHER condition holds
  policy action_type(:update) do
    authorize_if actor_attribute_equals(:admin?, true)
    authorize_if relates_to_actor_via(:owner)
  end
  # CORRECT — requires BOTH
  policy action_type(:update) do
    forbid_unless actor_attribute_equals(:admin?, true)
    authorize_if relates_to_actor_via(:owner)
  end
  ```
- `bypass` policies should be reserved almost exclusively for admin bypasses — this
  matches `CLAUDE.md`'s "Ash policy floor: scoped read carve-out uses `bypass`; do
  not replace the floor with ambient allow-all behavior."
- Field policies (`field_policies do ... end`) gate individual attributes/
  calculations/aggregates, separate from action-level policies.
- Custom checks: `Ash.Policy.SimpleCheck` (bool) or `Ash.Policy.FilterCheck`
  (returns a filter expr).

**Querying / filtering**
- `Ash.Query.filter/2` is a macro — `require Ash.Query` or you'll get "misplaced
  operator ^" / "undefined variable" errors that look unrelated to the real cause.
- Prefer code-interface `query:`/`load:` options (`query: [filter: …, sort: …,
  limit: …]`) over manually building `Ash.Query` pipelines.
- Use `strict?: true` on `Ash.Query.load` to avoid loading unnecessary fields.
- `exists/2` works for both related and **unrelated** resources (`exists(Profile,
  name == parent(name))`); unrelated exists auto-applies the target's primary read
  action's authorization.

**Aggregates & calculations**
- Aggregate types: `count`, `sum`, `exists`, `first`, `list`, `max`, `min`, `avg` —
  work over relationships or, via `parent/1`, unrelated resources.
- Expression calculations (`calculate :x, :type, expr(...)`) push down to the data
  layer when possible; module calculations (`use Ash.Resource.Calculation`) for
  logic that can't be expressed that way.

**Relationships**
- Name relationships descriptively (`:authored_posts`, not `:posts`).
- Two ways to manage: `change manage_relationship(:field, type: :append)` in an
  action (input-driven), or `Ash.Changeset.manage_relationship/3-4` in a custom
  change (programmatically-determined values). Management types: `:append`,
  `:append_and_remove`, `:remove`, `:direct_control`, `:create`.

**Testing**
- Test through the code interface, not by calling `Ash`/`Ash.Changeset` directly.
- Use globally-unique values for identity attributes in generators
  (`"user-#{System.unique_integer([:positive])}@..."`) — fixed values deadlock
  concurrent tests. Matches this repo's Chicago-style discipline (real Postgres via
  `Ecto.Adapters.SQL.Sandbox`) — the uniqueness rule is what keeps concurrent
  sandboxed tests from colliding on identity constraints.
- `Ash.can?` for policy assertions; `authorize?: false` where auth isn't the focus
  of the test.

**Codegen**
- After resource changes: `mix ash.codegen <name>` (snake_case name) to generate
  migrations. Mid-session, prefer `mix ash.codegen --dev` iteratively, then one
  final named codegen at the end (squashes dev migrations).

## AshPostgres

- Check constraints (`check_constraints do check_constraint :name, check: "..." end`)
  enforce domain invariants at the DB level — use for things like `balance >= 0`.
- `references do reference :assoc, on_delete: :nilify end` configures FK behavior;
  **DB-level FK actions bypass all Ash logic** — no policies, validations, or
  notifications run when Postgres cascades a delete/nilify.
- Multitenancy: `multitenancy do strategy :context; attribute :tenant end` on the
  resource, plus repo-level tenant enumeration; tenant migrations live in
  `priv/repo/tenant_migrations` and run via `mix ash_postgres.migrate --tenants`.
- Custom indexes/SQL: `custom_indexes do index [...] end` / `custom_statements do
  statement "..." end` inside `postgres do`.

## AshEvents (xaas: `Xaas.Ledger.EventLog`)

- Powers this repo's ledger audit trail/replay. The one disclosed exception to
  "never bypass Ash actions with raw Repo calls" in this codebase
  (`lib/xaas/ledger/event_log/clear_all_records.ex`) exists because
  `AshEvents.ClearRecordsForReplay` is a real replay-support contract that requires
  direct `Repo.delete_all/1` — not an oversight to "fix."

## AshAuthentication

- Provides the resource extension backing `Xaas.Accounts.User`/`Token`. Policy
  `bypass`es scoped to `AshAuthentication.Checks.AshAuthenticationInteraction` are
  the documented pattern for letting the authentication subsystem's own internal
  actions through the deny-by-default floor without opening it generally.

## AshOban

- `oban do triggers do trigger :name do ... end end end` on a resource with
  `extensions: [AshOban]`. Always set explicit `worker_module_name`/
  `scheduler_module_name` (prevents job-identity breakage on refactor).
- From within a triggered action: `Ash.Changeset.add_error(cs,
  AshOban.Errors.SnoozeJob.exception(snooze_for: 60))` to re-schedule without
  burning a retry, or `AshOban.Errors.CancelJob.exception(reason: ...)` to stop
  retries outright.
- Read actions used by triggers must support keyset pagination.

## AshAi

- Real dep (`ash_ai`) — see `deps/ash_ai/usage-rules.md` for the full contract
  (tools exposed to an LLM, vectorization, prompt-backed actions) before adding any
  new AI-driven action; don't hand-roll an LLM call path that duplicates it.

## AshOnetime

- Backs `Xaas.Accounts.Token.RevokeNonce`. Note the reserved-name constraint: a
  resource with an `:expires_at` attribute cannot carry `AshOnetime.Resource`
  directly (it's one of `AshOnetime.reserved_verification_inputs/0`'s five reserved
  names) — hence the separate nonce-ledger resource pattern already used here.

## AshGraphql / AshJsonApi / AshTypescript

- All three are real deps here for API projection, gated by this repo's own
  `docs/claude/diataxis/reference/http-api-surface.md` exposure rules — adding a
  resource to a domain's `graphql do queries/mutations end` or `json_api do
  routes end` block is itself the exposure decision; check the named-sensitive-
  resources list in `CLAUDE.md` before doing so for `Balance`/`Account`/`Transfer`/
  `User`/`Token`.
- AshTypescript generates a typed client from the same resource/action
  definitions — regenerate through its own generator, never hand-edit the output
  (matches this repo's general "generated vs authoritative surfaces" rule).

## Reactor / Igniter / Spark

- `reactor`/`spark` are the DSL/orchestration substrate under Ash itself — this
  repo's own `Xaas.Actuation` Reactor pipeline (see
  `docs/claude/diataxis/reference/actuation-and-semantics.md`) is real, hand-built
  Reactor usage, not a wrapper needing its own separate rules beyond Ash's own
  action/atomicity guidance above.
- `igniter` powers codegen tasks (`mix ash.gen.*`, `mix ash.codegen`, this repo's
  own `mix ggen_igniter.sync`/`.doctor`). Use `--yes` to skip confirmation prompts
  in non-interactive runs; `--yes --dry-run` to preview.

## Elixir/OTP core conventions (from `usage_rules`/`usage_rules:elixir`/`:otp`)

- Pattern-match on function heads instead of `if`/`case` in the body where
  reasonable; `%{}` matches any map — use `map_size(map) == 0` for "truly empty."
- `{:ok, _}`/`{:error, _}` tuples + `with` for fallible chains; avoid exceptions for
  control flow.
- No `String.to_atom/1` on user input (unbounded atom-table growth).
- GenServer: prefer `call` over `cast` for back-pressure; `handle_continue/2` for
  post-init work; explicit `terminate/2` cleanup where needed.
- `Task.Supervisor` + `Task.async_stream/3` for concurrent work with back-pressure
  and fault isolation, over bare `Task.async`.

## Docs / lookup tools available in this repo

- `mix usage_rules.docs Enum.zip/1` — hexdocs lookup for any dependency or Elixir
  itself, without leaving the terminal.
- `mix usage_rules.search_docs "query" -p package` — full-text doc search scoped to
  one package.
