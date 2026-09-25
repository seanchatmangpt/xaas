defmodule Xaas.Marketplace.Checks.ActorOrgFilter do
  @moduledoc """
  Real `Ash.Policy.FilterCheck` used on `Xaas.Marketplace.Provider`'s
  `:read` AND `:update` bypasses (both real-need row-filtering
  semantics -- `:read` to scope which rows exist for the actor,
  `:update` because `AshJsonApi`'s real `PATCH` route real-tested as not
  carrying pre-loaded original changeset `data` at policy-evaluation
  time, so a changeset-only equality check has no real `org_id` to
  compare and always denies; a `FilterCheck` composes into a real
  `WHERE org_id = ...` clause Ash evaluates directly against the
  database row instead, which real-works).

  ## Why a separate module from `ActorOrgMatches` (used only by `:create`)

  Real, live-verified finding: a `FilterCheck` used on `:create` forces
  Ash's field-authorization layer into `access_type: :filter` for FIELD
  authorization purposes (the same mechanism `docs/claude/diataxis/
  explanation/ashiam-create-update-limitation.md` documents for
  `AshIam.Check`) -- confirmed here by a real HTTP `POST` returning a
  real `201` with the just-written `name` attribute serialized as `null`
  instead of its real value, before this was split out. `:create` has no
  existing row to filter in the first place, so it uses the non-filter
  `Xaas.Marketplace.Checks.ActorOrgMatches` (a `SimpleCheck`) instead.
  """
  use Ash.Policy.FilterCheck

  @impl true
  def describe(_opts), do: "record's org_id matches the real actor's asserted org_id"

  @impl true
  def filter(_actor, _context, _opts) do
    expr(org_id == ^actor(:org_id))
  end
end
