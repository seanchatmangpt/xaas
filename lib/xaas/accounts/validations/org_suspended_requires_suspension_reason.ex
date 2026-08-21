defmodule Xaas.Accounts.Validations.OrgSuspendedRequiresSuspensionReason do
  @moduledoc """
  Real data-quality rule for `Xaas.Accounts.Org`'s `:update` action,
  matching the same real "status transition requires a supporting fact"
  shape this session already established twice (`Xaas.Operations.
  Validations.IncidentResolvedRequiresResolvedAt`,
  `Xaas.Platform.Validations.
  RouteOrgsCustomDomainActiveRequiresCertificateSecret`): an org being
  marked `:suspended` must carry a real `suspension_reason` -- a
  suspended tenant with no recorded reason is exactly the kind of gap a
  real support/compliance workflow (who suspended it, and why) depends on
  not existing.

  ## Real, disclosed side effect: this is also why `Org.:update` is
  atomic-upgrade-INELIGIBLE, which is exactly what
  `Xaas.Accounts.Checks.ActorBelongsToOrg`'s org-token match half needs

  Before this validation existed, `Org.:update` had zero custom
  changes/validations -- only plain accepted-attribute assignment, the
  exact bare shape `Incident.:update` and `RouteOrgsCustomDomain.:update`
  each had before their own fix (see those 2 modules' moduledocs for the
  full disclosure of the underlying Ash behavior: `AshJsonApi`'s PATCH
  controller routes single-record updates through `Ash.bulk_update/2`
  with `strategy: [:atomic, :stream, :atomic_batches]`, and the `:atomic`
  strategy can express a plain accepted-attribute-only update as a single
  UPDATE query with no prior read -- `changeset.data` becomes a real
  `Ash.Changeset.OriginalDataNotAvailable{}`, not the persisted row).
  `Xaas.Accounts.Checks.ActorBelongsToOrg`'s org-token clause (added the
  same pass as this validation -- see that module's own moduledoc) reads
  the persisted record's own `slug` off `changeset.data`; without this
  validation, a real, live-HTTP-confirmed `403` results on every
  `PATCH /api/orgs/:id` request even from a legitimate, correctly
  org-asserting caller -- real-reproduced and real-fixed this pass, not
  assumed from the sibling fixes' pattern alone.

  A real `Ash.Resource.Validation` with no `atomic/3` implementation (the
  default -- this module does not add one) is exactly what
  `deps/ash/lib/ash/resource/verifiers/verify_actions_atomic.ex`'s own
  compile-time atomic-eligibility check treats as atomic-INELIGIBLE.
  Adding this real, independently-justified validation makes `Org.:update`
  disqualify atomic mode at the FIRST attempt -- a clean, single
  `{:not_atomic, reason}` result, going straight to the real,
  `changeset.data`-populated `:stream` strategy, with no fragile nested
  retry.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    status = Ash.Changeset.get_attribute(changeset, :status)
    suspension_reason = Ash.Changeset.get_attribute(changeset, :suspension_reason)

    if status == :suspended and blank?(suspension_reason) do
      {:error,
       field: :suspension_reason,
       message: "is required when suspending an org"}
    else
      :ok
    end
  end

  # Real, disclosed, nineteenth-pass finding: when `suspension_reason` is
  # NOT part of the current request's accepted attributes,
  # `Ash.Changeset.get_attribute/2` falls back to the *loaded* record's
  # own value off `changeset.data` -- and because `Org`'s `:read` policy
  # (which the `PATCH` controller uses to load the record before running
  # `:update`) authorizes an org-token actor via a `FilterCheck`
  # (`Xaas.Accounts.Checks.ActorOrgSelfFilter`), Ash's field-level
  # authorization switches to `access_type: :filter` for that load, and
  # unread fields come back as real `Ash.ForbiddenField` structs, not
  # `nil` and not the real value (real-confirmed via a temporary
  # `IO.inspect` on a real failing test run this pass, not inferred).
  # Treating a `ForbiddenField` sentinel as "a value is present" would be
  # a real, silent hole (a caller could suspend an org while genuinely
  # unable to prove any reason exists) -- this check fails closed instead:
  # an org-token actor must explicitly (re-)supply `suspension_reason` in
  # the SAME request that sets `status: :suspended`, every time.
  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(%Ash.ForbiddenField{}), do: true
  defp blank?(_), do: false
end
