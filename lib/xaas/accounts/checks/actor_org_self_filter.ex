defmodule Xaas.Accounts.Checks.ActorOrgSelfFilter do
  @moduledoc """
  Real `Ash.Policy.FilterCheck` for `Xaas.Accounts.Org`'s `:read` AND
  `:update` bypasses, added the nineteenth pass alongside
  `Xaas.Accounts.Checks.ActorBelongsToOrg`.

  ## Real, disclosed reason this exists, and why it is a `FilterCheck`
  (matching `Xaas.Marketplace.Checks.ActorOrgFilter`'s own established
  pattern) rather than a `SimpleCheck` comparing `changeset.data`

  Real-found this pass: `PATCH /api/orgs/:id` real-`404`'d even after
  fixing `KanbanWeb.Plugs.ResolveOrgActor` to resolve a real, header-
  asserted `%{org_id: slug}` actor for this route. Root cause: `AshJsonApi`'s
  `PATCH` controller loads the target record via `Org`'s own `:read`
  policy before running `:update` -- that policy was, before this pass,
  gated ONLY by `AshIam.Check`, and the org-token actor carries no
  `iam_policy` key at all (`AshIam.Check` real-denies it, same behavior
  `test/xaas/accounts/org_test.exs`'s own "an actor with no real
  iam_policy is really denied read" test already proves) -- so the row
  was never visible to load.

  A first real attempt at fixing this wired a `SimpleCheck` comparing the
  loaded `changeset.data.slug` value against the actor's asserted
  `org_id` on `:update` alone, real-tested, and real-failed differently:
  once `:read` authorizes via ANY `FilterCheck` (this module, added to
  make the record visible at all), Ash's field-level authorization layer
  switches to `access_type: :filter` for that read -- the loaded record's
  individual field VALUES become real `Ash.ForbiddenField` structs, not
  their real values (`slug` included), so a `SimpleCheck` comparing
  `changeset.data.slug` real-compared a string against a `ForbiddenField`
  struct and always returned `false` -- a real `403`, confirmed via a
  temporary `IO.inspect` on a real failing test run this pass, not
  inferred. `Xaas.Marketplace.Checks.ActorOrgFilter`'s own moduledoc
  already discloses the sibling half of this exact mechanism (`:create`
  serializing a just-written field as `null`) -- this pass's finding is
  the same root cause (`access_type: :filter` field redaction) surfacing
  on a different action (`:read`, contaminating a subsequent `:update`'s
  loaded data) rather than on `:create`'s own response serialization.

  The real fix, matching `ActorOrgFilter`'s own established resolution for
  this identical problem shape: use a `FilterCheck` on `:update` too, not
  a `SimpleCheck` reading loaded field values. A `FilterCheck` composes
  into a real `WHERE slug = ...` clause Ash evaluates directly against the
  database query when finding the row to update -- it never needs to read
  a Elixir field VALUE out of `changeset.data` at all, so the
  `access_type: :filter` field-redaction problem above never applies to
  it. `Org.:update`'s bypass therefore wires 2 checks (real, disclosed OR
  semantics -- see `org.ex`): `Xaas.Accounts.Checks.ActorBelongsToOrg`
  (real per-user `OrgMembership` row, a `SimpleCheck` -- see that module's
  own moduledoc for why it correctly stays one) OR this module (real
  header-asserted org-token self-match, a `FilterCheck`).

  ## Real fail-closed behavior

  An actor with no real `org_id` key contributes no matching filter
  (`actor(:org_id)` resolves to `nil` for such an actor, and
  `slug == nil` matches nothing real, since `slug` is `allow_nil? false`)
  -- fail-closed, not fail-open, for every actor shape that isn't a real,
  header-asserted org-token actor. This check only ever ADDS visibility
  for the narrow case of an actor asserting exactly a given record's own
  identity -- a real, existing caller who only ever relied on
  `AshIam.Check` for `:read` is completely unaffected (multiple
  `authorize_if` clauses within one Ash policy `bypass` combine as OR).
  """
  use Ash.Policy.FilterCheck

  @impl true
  def describe(_opts), do: "record's own slug matches the real actor's asserted org_id"

  @impl true
  def filter(_actor, _context, _opts) do
    expr(slug == ^actor(:org_id))
  end
end
