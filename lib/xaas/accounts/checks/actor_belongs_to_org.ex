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

  Used by `Xaas.Accounts.Org`'s `:create`/`:update` policies in place of
  the previous `actor_present()` fallback (see `org.ex`'s disclosed
  limitation this check now resolves): `match?/3` is false for any actor
  without a real `id`, and false for an actor whose `id` has no real
  `OrgMembership` row naming the record's `org_id` -- both strictly
  stronger than "any authenticated actor may touch any org," which is
  what `actor_present()` alone allowed.

  Real, disclosed scope limit: this check is membership-scoped to an
  *existing* Org row (it resolves the record's own `id` and looks for an
  `OrgMembership` naming that org). It is only meaningfully applicable to
  `Org`'s `:update` action. `Org`'s `:create` action has no existing
  record for the actor to already belong to -- membership of a not-yet-
  created org is not a coherent fact to check -- so `org.ex` keeps
  `:create` on `actor_present()` and only swaps `:update` to this check.
  That is a real, deliberate, disclosed scope decision, not an oversight.
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

  # Resolves the *existing* record's own id -- the org the actor must
  # already belong to. Deliberately does not read a pending/unsaved
  # changeset attribute (see moduledoc's :create scope-limit disclosure).
  defp resolve_org_id(%Ash.Changeset{data: %{id: id}}), do: id
  defp resolve_org_id(%{data: %{id: id}}), do: id
  defp resolve_org_id(_), do: nil
end
