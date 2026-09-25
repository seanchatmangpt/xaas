defmodule Xaas.Marketplace.Validations.ApprovalProviderStatusChangeProviderOrgMatches do
  @moduledoc """
  Real business rule for `Xaas.Marketplace.ApprovalProviderStatusChange`'s
  `:create` action, closing the real, twenty-third-pass ERRC grid finding
  (`docs/claude/diataxis/explanation/errc-innovation-grid.md`, item 33):
  `provider_id` (a real `:uuid` attribute backing a real `belongs_to
  :provider, Xaas.Marketplace.Provider` -- `approval_provider_status_change.ex:124,153-158`
  -- with a real Postgres FK constraint,
  `approval_provider_status_changes_provider_id_fkey`) was never validated
  against the referenced `Provider` row's own `org_id`. The existing
  `policies do` bypasses (`Xaas.Marketplace.Checks.ActorOrgMatches` on
  `:create`, `Xaas.Marketplace.Checks.ActorOrgFilter` on `:approve`) both
  correctly scope the *request row's own* `org_id` to the actor -- but
  neither reads or filters on `provider_id`'s own `org_id`.

  This left a real, live, infra-level exploit (independently re-verified
  by this fix's own live-repro-then-fix proof): an actor entirely within
  its own real org -- passing `ActorOrgMatches` on `:create` and
  `ActorOrgFilter` on `:approve` cleanly, no forgery of its own identity
  anywhere -- could supply a *different*, victim org's real `provider_id`.
  `:approve`'s change module,
  `Xaas.Marketplace.Changes.ApplyProviderStatusChange`, is not inert: it
  really writes the referenced `Provider.status` inside the same DB
  transaction, regardless of which org that `Provider` belongs to. This
  closes the gap with one real check: `provider_id` must reference a real,
  persisted `Provider` row whose own `org_id` matches this request's own
  `org_id`.

  Real, `authorize?: false` cross-resource read, mirroring the established
  pattern in `Xaas.Governance.Validations.ApprovalFreezeOverrideFreezeWindowExists`
  and `Xaas.Billing.Checks.ActorOrgMatches.subscription_org_id/1` -- a real
  `Ash.get/3` against a related resource inside a validation context, same
  fail-closed discipline: a missing/unresolvable row denies rather than
  raises.

  Deliberately scoped to `:create` only -- `:approve` never accepts
  `provider_id` (not in its `accept` list, it only ever reads the
  already-validated persisted value off `changeset.data`), so there is
  nothing new to check there.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    provider_id = Ash.Changeset.get_attribute(changeset, :provider_id)
    org_id = Ash.Changeset.get_attribute(changeset, :org_id)

    case provider_id do
      nil ->
        # allow_nil? false on the attribute itself already covers absence;
        # avoid a redundant/duplicate error here.
        :ok

      _ ->
        check_provider(provider_id, org_id)
    end
  end

  defp check_provider(provider_id, org_id) do
    case Ash.get(Xaas.Marketplace.Provider, provider_id, authorize?: false) do
      {:ok, provider} ->
        if provider.org_id == org_id do
          :ok
        else
          {:error,
           field: :provider_id,
           message: "must reference a provider in the same org as this status-change request"}
        end

      {:error, _} ->
        {:error, field: :provider_id, message: "does not reference a real provider"}
    end
  end
end
