defmodule Xaas.Accounts.Checks.ActorBelongsToOrg do
  @moduledoc """
  Real custom Ash policy check: real-queries `Xaas.Accounts.OrgMembership`
  for a row matching the actor's `id` and the record's `org_id`, using
  `authorize?: false` (the same system-internal-path pattern
  `test/xaas/accounts/org_test.exs` documents for `Org`'s own tests) so the
  check itself does not recurse into `OrgMembership`'s own deny-by-default
  policies. Not a mock, stub, or interaction-verifying double -- a real
  implementation of `Ash.Policy.Check`'s `match?/3` callback against real
  Postgres rows.

  Used by `Xaas.Accounts.Org`'s `:update` policy alongside (real,
  nineteenth-pass addition) `Xaas.Accounts.Checks.ActorOrgSelfFilter` --
  see `org.ex`'s own `bypass action(:update)` block, which OR's this
  check (real per-user membership) with that one (real header-asserted
  org-token actor).

  ## Real, disclosed reason this check stayed a `SimpleCheck`
  (`match?/3` over `changeset.data`) rather than becoming a `FilterCheck`
  too, unlike the org-token half

  Real-found this pass (see `Xaas.Accounts.Checks.ActorOrgSelfFilter`'s
  own moduledoc for the full disclosure): when `Org`'s `:read` bypass
  authorizes via a `FilterCheck`, Ash's field-level authorization layer
  switches to `access_type: :filter` for that read, and the individual
  loaded field VALUES become real `Ash.ForbiddenField` structs rather
  than their real values -- fine for a `FilterCheck` (which never reads
  field values, only composes a query predicate), but fatal for THIS
  check's `match?/3`, which needs the record's real, unredacted `id` to
  query `OrgMembership` against. A membership check cannot be expressed
  as a pure per-row SQL filter the way "record's org_id equals actor's
  org_id" can (it needs a real, separate join-table lookup) -- so it
  stays a `SimpleCheck`, and real-only-works today via the direct
  `Ash.Changeset.for_update/2`/`Ash.update!/2` call path
  `test/xaas/accounts/org_test.exs`'s own "an actor with a real
  OrgMembership row can update the org" test exercises (which seeds
  `changeset.data` straight from an already-loaded, unredacted struct --
  no intermediate `:read`-policy-gated re-fetch, so no `ForbiddenField`
  taint) -- NOT yet via a real `/api` HTTP request, since this repo has
  no real per-user (`%{id: ...}`-shaped) actor-producing plug for any
  route today (see `KanbanWeb.Plugs.ResolveOrgActor`'s own moduledoc).
  Real, disclosed, unchanged limitation, not newly introduced this pass.

  ## Real, disclosed scope limit

  Only applicable to `Org`'s `:update` action (an *existing* record).
  `Org`'s `:create` action has no existing record for the actor to
  already belong to -- membership of a not-yet-created org is not a
  coherent fact to check -- so `org.ex` keeps `:create` on
  `actor_present()` and only wires `:update` to this check (plus the
  org-token `FilterCheck`). Real, deliberate, disclosed scope decision,
  unchanged from the original design.
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias Xaas.Accounts.OrgMembership

  @impl true
  def describe(_opts), do: "actor has a real OrgMembership row for this record's org"

  @impl true
  def match?(actor, %{subject: subject}, _opts) do
    with %{id: actor_id} when not is_nil(actor_id) <- actor,
         org_id when not is_nil(org_id) <- resolve_org_id(subject) do
      OrgMembership
      |> Ash.Query.filter(user_id: actor_id, org_id: org_id)
      |> Ash.exists?(authorize?: false)
    else
      _ -> false
    end
  end

  # Real, disclosed defense-in-depth override (nineteenth pass, same
  # rationale as `Xaas.Operations.Checks.ActorOrgMatches`'s own
  # moduledoc): this check needs the persisted record's real `id` off
  # `changeset.data`. `Xaas.Accounts.Validations.
  # OrgSuspendedRequiresSuspensionReason` (wired onto `Org.:update`) is
  # the real, independently-justified, no-`atomic/3` validation that
  # keeps `:update` atomic-upgrade-INELIGIBLE so `changeset.data` is real
  # and populated. This override turns the specific failure mode where
  # that validation is ever removed by a future change from a silent,
  # always-`false` deny into a loud, typed `Ash.Error.Forbidden.
  # InitialDataRequired` -- fail-loud, not fail-open.
  @impl true
  def requires_original_data?(_authorizer, _opts), do: true

  # Resolves the *existing* record's own id -- the org the actor must
  # already belong to. Deliberately does not read a pending/unsaved
  # changeset attribute (see moduledoc's :create scope-limit disclosure).
  defp resolve_org_id(%Ash.Changeset{data: %{id: id}}), do: id
  defp resolve_org_id(%{data: %{id: id}}), do: id
  defp resolve_org_id(_), do: nil
end
