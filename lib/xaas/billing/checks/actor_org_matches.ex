defmodule Xaas.Billing.Checks.ActorOrgMatches do
  @moduledoc """
  Real `Ash.Policy.SimpleCheck` for `Xaas.Billing.ApprovalTierDowngrade`'s
  `:create`/`:approve` actions, closing the real, live-HTTP-proven gap found
  by the fifteenth-pass ERRC grid sweep
  (`docs/claude/diataxis/explanation/errc-innovation-grid.md`): that
  resource's `policies do` block previously bypassed `:create`/`:approve`
  with a bare `authorize_if always()` -- identical to its 6 other Billing
  `Approval*` siblings, but with no `Xaas.Governance.Checks.ActorOrgMatches`-
  style check like its Governance cousins have. A real, temporary
  (deleted-after-run) HTTP test proved live exploitability: an actor
  asserting `X-Org-Id: org-attacker-*` (any org, no relationship to the
  target subscription) could `PATCH .../:id` approve `org-victim-*`'s
  pending tier downgrade, dropping the victim's real `Subscription` tier
  and posting a real `$50.00` `Xaas.Ledger.Transfer` credit.

  ## Real, disclosed reason this is NOT a mechanical copy of
  `Xaas.Governance.Checks.ActorOrgMatches`

  The 4 Governance resources this check's sibling protects each carry their
  own `org_id` attribute plus a real `multitenancy do attribute :org_id;
  global? false end` block, so that check reads `org_id` directly off the
  changeset/record. `Xaas.Billing.ApprovalTierDowngrade` has **no `org_id`
  attribute at all** -- only `subscription_id` (a real `belongs_to`
  `Xaas.Billing.Subscription` FK, see that resource's own attributes
  block) -- and it carries no `multitenancy` block of its own either, so
  there is no Ash-level tenant scoping backstopping this check the way
  `multitenancy` backstops the Governance resources' `:approve` record
  lookup. The org identity lives one hop away, on
  `Xaas.Billing.Subscription.org_id` (`lib/xaas/billing/subscription.ex`,
  a plain `:string` attribute -- that resource is explicitly NOT
  multitenancy-wired either, per its own moduledoc). This check therefore
  has to real-load the related `Subscription` and compare **its**
  `org_id` to the actor's asserted org, rather than reading an attribute
  already on the subject.

  `resolve_subscription_id/1` mirrors the Governance check's `:create`
  vs. non-`:create` split, adapted to this resource's real shape:

  - `:create` -- `subscription_id` is a real, explicitly accepted
    attribute on the pending changeset (`accept [:requested_by,
    :approved_by, :subscription_id, :requested_tier]`), read via
    `Ash.Changeset.get_attribute/2`.
  - `:approve` (an `:update` action) -- `subscription_id` is NOT in
    `:approve`'s accept list, so it is never on the changeset; the real
    fact to check is the existing persisted record's own
    `subscription_id`, read off `changeset.data`.

  Once the real subscription id is resolved, `subscription_org_id/1` does
  a real, `authorize?: false` `Ash.get/3` against `Xaas.Billing.
  Subscription` -- the same `authorize?: false` discipline this repo
  already uses for cross-resource reads inside a policy/change context
  (see `Xaas.Billing.Changes.ApprovalTierDowngradeApprove`'s own
  `Ash.get(Xaas.Billing.Subscription, ..., authorize?: false)` call) --
  and compares the real, persisted `org_id` column against the actor's
  asserted `org_id`. A missing/unresolvable subscription (nil id, or an
  `Ash.get` `{:error, _}`) denies rather than raises: `match?/3` returns
  `false`, which the `bypass` block's `forbid_if always()` catch-all
  then rejects, same fail-closed shape as every other check in this
  codebase.

  Not a mock, stub, or interaction-verifying double -- a real
  `Ash.Policy.Check` (`SimpleCheck`) implementation of `match?/3` against
  the real changeset/record `subscription_id` and the real, separately
  read `Subscription.org_id` column.
  """
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts) do
    "actor's asserted org_id matches this downgrade's real subscription org_id"
  end

  @impl true
  def match?(%{org_id: actor_org_id}, %{subject: subject}, _opts)
      when is_binary(actor_org_id) and actor_org_id != "" do
    case resolve_subscription_id(subject) do
      nil -> false
      subscription_id -> actor_org_id == subscription_org_id(subscription_id)
    end
  end

  def match?(_actor, _context, _opts), do: false

  # :create -- subscription_id is a real attribute being written on the
  # pending changeset (accepted in the :create action).
  defp resolve_subscription_id(%Ash.Changeset{action_type: :create} = changeset) do
    Ash.Changeset.get_attribute(changeset, :subscription_id)
  end

  # :approve (an :update action) -- subscription_id is NOT in :approve's
  # accept list, so it is never on the changeset; the real fact to check
  # is the existing persisted record's own subscription_id.
  defp resolve_subscription_id(%Ash.Changeset{data: %{subscription_id: subscription_id}}) do
    subscription_id
  end

  defp resolve_subscription_id(_), do: nil

  defp subscription_org_id(subscription_id) do
    case Ash.get(Xaas.Billing.Subscription, subscription_id, authorize?: false) do
      {:ok, subscription} -> subscription.org_id
      {:error, _} -> nil
    end
  end
end
