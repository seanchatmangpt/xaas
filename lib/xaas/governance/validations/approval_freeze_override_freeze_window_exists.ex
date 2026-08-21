defmodule Xaas.Governance.Validations.ApprovalFreezeOverrideFreezeWindowExists do
  @moduledoc """
  Real business rule for `Xaas.Governance.ApprovalFreezeOverride`'s
  `:create` action, closing the real, twenty-second-pass ERRC grid finding
  (`docs/claude/diataxis/explanation/errc-innovation-grid.md`):
  `freeze_window_id` (a caller-supplied, plain `:string` attribute --
  `approval_freeze_override.ex:105-108` -- not a `belongs_to`, to match
  this domain's existing Governance resources) was never validated
  against any real `Xaas.Governance.FreezeWindow` row anywhere in the
  `:create` action, nor in
  `ApprovalFreezeOverrideRequiresApprover` (the only other validation on
  this resource, which checks solely approver identity).

  This closes 3 real, distinct gaps in one `validate`:

  1. **Existence** -- `freeze_window_id` must reference a real, persisted
     `FreezeWindow` row, not an arbitrary caller-supplied string.
  2. **Cross-org integrity** -- the referenced `FreezeWindow`'s own
     `org_id` must match this override request's own `org_id`. This is
     orthogonal to (and additive to) the separately-deferred
     actor-vs-request org-scoping question on this resource's own
     `policies do` bypasses (see the grid doc): even a request whose
     `org_id` genuinely matches the filing actor could otherwise reference
     a real freeze window belonging to a *different* org.
  3. **`allow_emergency_override`** -- the referenced `FreezeWindow`'s own
     `allow_emergency_override` flag (`freeze_window.ex:138-142`, default
     `false`) must be `true`. Its own moduledoc states this flag exists
     specifically to gate "whether a maker-checker `ApprovalFreezeOverride`
     request may be filed against this window at all" -- until now, that
     gate was never actually enforced anywhere.

  Real, `authorize?: false` cross-resource read, mirroring the established
  pattern in `Xaas.Billing.Checks.ActorOrgMatches.subscription_org_id/1`
  (a real `Ash.get/3` against a related resource inside a policy/validation
  context, same fail-closed discipline: a missing/unresolvable row denies
  rather than raises).

  Deliberately scoped to `:create` only -- `:approve` never touches
  `freeze_window_id` (not in its `accept` list), so there is nothing new
  to check there.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    freeze_window_id = Ash.Changeset.get_attribute(changeset, :freeze_window_id)
    org_id = Ash.Changeset.get_attribute(changeset, :org_id)

    case freeze_window_id do
      nil ->
        # allow_nil? false on the attribute itself already covers absence;
        # avoid a redundant/duplicate error here.
        :ok

      "" ->
        :ok

      _ ->
        check_freeze_window(freeze_window_id, org_id)
    end
  end

  defp check_freeze_window(freeze_window_id, org_id) do
    case Ash.get(Xaas.Governance.FreezeWindow, freeze_window_id, authorize?: false) do
      {:ok, freeze_window} ->
        cond do
          freeze_window.org_id != org_id ->
            {:error,
             field: :freeze_window_id,
             message: "must reference a freeze window in the same org as this override request"}

          freeze_window.allow_emergency_override != true ->
            {:error,
             field: :freeze_window_id,
             message: "does not allow emergency overrides to be filed against it"}

          true ->
            :ok
        end

      {:error, _} ->
        {:error,
         field: :freeze_window_id,
         message: "does not reference a real freeze window"}
    end
  end
end
