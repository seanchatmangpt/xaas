# AshIam.Check on :create/:update: real root cause

Real, evidence-backed root cause for the limitation disclosed in the moduledocs of
`lib/xaas/accounts/org.ex`, `lib/xaas/billing/subscription.ex`,
`lib/xaas/marketplace/provider.ex`, `lib/xaas/accounts/org_membership.ex`, and
`lib/xaas/governance/freeze_window.ex`: `AshIam.Check` (`ash_iam` 2.1.0, per
`mix.lock`) real-tested as `Ash.Error.Forbidden` on `:create`/`:update` actions in
earlier sessions. Root-caused this session with a real, minimal repro against
`Xaas.Accounts.Org` (temporarily patched `bypass action(:create) do authorize_if
AshIam.Check end`, run, then reverted -- no permanent change to `org.ex`).

## Two distinct real findings, not one bug

### 1. Exact-ID `Allow` statements genuinely cannot match `:create` (architectural, not a bug)

Real repro: an actor with
`%{"Effect" => "Allow", "Action" => ["create"], "Resource" => ["xaas:org:<uuid>"]}`
where `<uuid>` is a freshly-generated, never-persisted id (`Ash.UUID.generate/0`) --
i.e. the same "guess the row's id ahead of time" pattern the working `:read` tests use
(`test/xaas/accounts/org_test.exs`'s `xaas:org:#{visible.id}` pattern) -- really
returns `{:error, %Ash.Error.Forbidden{...}}`.

This is architecturally correct, confirmed against `deps/ash_iam/lib/ash_iam/policy.ex`:

```elixir
# AshIam.Policy.allowed?/4
candidate = build_permission_candidate(resource_module, record, permission_base)
# build_permission_candidate/3, no identifier_field configured:
"#{final_permission_base}:#{record_id(record)}"
```

For `:create`, `record_id(record)` is the id Ash's `uuid_primary_key` default generator
assigned to the changeset at build time -- a real UUID, but one that did not exist
before this exact request and that no `Allow` statement authored in advance can name.
An IAM policy authored *before* a row exists cannot legitimately grant access by that
row's future, randomly-generated id; there is no "row to filter" yet, unlike `:read`
where the id is a real fact already in the database when the policy is evaluated. This
matches the architectural hypothesis in this task's brief and is now verified against
the real source, not assumed.

**Real, verified-working pattern for `:create`/`:update` at the action level**: a
wildcard-resource `Allow` (e.g. `"xaas:org:*"` or `"*"`), never an exact-id `Allow`.
Real repro with `%{"Effect" => "Allow", "Action" => ["create"], "Resource" =>
["xaas:org:*"]}` against the same patched bypass returned `{:ok, %Xaas.Accounts.Org{
id: "...", ...}}` -- a real, successful, non-Forbidden create. The prior sessions'
"real-tested Forbidden even with a matching real Allow statement" disclosure is
consistent with those sessions having authored an exact-id `Allow` (mirroring the
`:read` test pattern) rather than a wildcard one -- the one pattern that can never work
for `:create` by construction, not an `ash_iam` defect.

### 2. Field-level access is real, separately broken for :create/:update even with a wildcard Allow

Even with the action-level create succeeding (`{:ok, ...}`), the returned struct's
attributes come back as `Ash.ForbiddenField`, not real values:

```elixir
{:ok,
 %Xaas.Accounts.Org{
   id: "69fe972b-325d-47ca-93dd-7bdc015ccb1d",
   name: #Ash.ForbiddenField<field: :name, type: :attribute, ...>,
   slug: #Ash.ForbiddenField<field: :slug, type: :attribute, ...>,
   status: #Ash.ForbiddenField<field: :status, type: :attribute, ...>,
   __meta__: #Ecto.Schema.Metadata<:loaded, "orgs">
 }}
```

Real repro added an explicit `field_policies do field_policy :* do authorize_if
AshIam.Check end end` block (also reverted) to rule out "no field_policies configured
== default deny" as the explanation -- the `ForbiddenField` result was identical with
or without it. Root cause, confirmed against `deps/ash/lib/ash/policy/field_policy.ex`:

```elixir
defp set_field_policy_opt({module, opts}) do
  {module, Keyword.merge(opts, ash_field_policy?: true, access_type: :filter)}
end
```

Ash's field-policy layer forces every check used in a `field_policies` block to run as
`access_type: :filter`, regardless of the check's own declared type. `AshIam.Check`'s
`type, do: :filter` means its field-level evaluation goes through `auto_filter/3`
(`deps/ash_iam/lib/ash_iam/check.ex`), which is fundamentally a query-time,
row-already-exists mechanism (it returns Ash filter keyword lists such as `[id: [in:
allowed_ids]]` to be ANDed into a `WHERE` clause). A `:create` action has no query to
filter and no persisted row to re-fetch a field's authorized value from at
field-authorization time, so Ash's field-policy layer cannot determine per-field
visibility for a not-yet-persisted record and defaults to `Ash.ForbiddenField` for
safety -- same underlying "no row to filter yet" architectural gap as finding 1, one
layer up (per-field instead of per-action).

## Outcome: genuine, real, evidence-backed upstream/architectural limitation

This is `ash_iam` 2.1.0's `AshIam.Check` genuinely not being designed to support
`:create`/`:update` in a way that also returns real field values -- not an xaas-side
misconfiguration. No configuration or documented alternative API in
`deps/ash_iam/README.md` or `deps/ash_iam/CHANGELOG.md` addresses field-level access
for filter-type checks on non-read actions; `AshIam.SimpleCheck`
(`deps/ash_iam/lib/ash_iam/simple_check.ex`) was checked as a possible alternative --
it is a `type: :simple` check (no `auto_filter`), which would sidestep finding 2's
field-filter problem, but it has no built-in IAM policy-document evaluation of its own
(it is a thin `Ash.Policy.SimpleCheck` scaffold for hand-written boolean checks, not a
drop-in IAM-policy evaluator) -- adopting it would mean re-implementing
`AshIam.Policy.allowed?/4`'s IAM-document evaluation as a resource-specific
`SimpleCheck`, not configuring an existing option.

**Real, verified-working action-level pattern**, if `AshIam.Check` is used for
`:create`/`:update` going forward: author only wildcard-resource `Allow` statements for
those actions (never exact-id), and pair the action-level bypass with a real
`authorize?: false` re-read (the pattern the existing `org_test.exs` "system-internal
path" tests already use) rather than trusting the returned struct's fields, until
finding 2 is separately addressed -- e.g. by wrapping `AshIam.Check`'s IAM-document
evaluation in a `type: :simple` check for `:create`/`:update` field policies
specifically (real, disclosed follow-up work, not done in this pass; no resource in
this repo was changed to adopt this pattern, since it does not fully resolve finding 2
and the moduledocs' current `actor_present()` / `ActorBelongsToOrg` fallbacks remain the
better real, working choice today).

## Upstream issue check

`ash_iam` is not an `ash-project`-org package -- its real source repo, per
`deps/ash_iam/hex_metadata.config`'s `links` field, is
`https://github.com/wearecococo/ash-iam`. Real `WebFetch`/`gh api` check against that
exact URL returned HTTP 404 (real, checked 2026-08-20): the repo is private, renamed,
or deleted -- there is no public issue tracker to search. A broader `WebSearch` across
GitHub/Hex for `ash_iam` create/update/field-policy/ForbiddenField issues also found no
hits (the closest results were unrelated AWS-IAM tooling, not this Elixir package).
Filing an upstream issue is real, disclosed follow-up work -- not done as part of this
task (external action outside this task's scope) -- and the maintainer would need to be
reached through a channel other than a public GitHub issue tracker, since the
repository URL Hex publishes for this package is not currently reachable.

## Files touched during this investigation, all reverted

- `lib/xaas/accounts/org.ex` -- temporarily added a second `bypass action(:create) do
  authorize_if AshIam.Check end` and a `field_policies` block, both reverted; the file
  is byte-identical to before this task (`git diff` clean).
- `test/xaas/accounts/org_iam_create_repro_test.exs` -- throwaway repro test, deleted
  before finishing.
