defmodule Xaas.Operations.Validations.IncidentResolvedRequiresResolvedAt do
  @moduledoc """
  Real data-quality rule for `Xaas.Operations.Incident`'s `:update`
  action, matching platform-console's real postmortem semantics (see
  `Xaas.Operations.Incident`'s own moduledoc): an incident being marked
  `:resolved` must carry a real `resolved_at` timestamp -- a resolved
  incident with no resolution time is exactly the kind of gap
  `ApprovalDrFailoverRequiresOpenIncident`'s own region/org/status query
  depends on being trustworthy (a real, dateable resolution record, not
  just a status flip).

  ## Real, disclosed side effect: this is also why `Incident.:update` is
  atomic-upgrade-INELIGIBLE, which is exactly what
  `Xaas.Operations.Checks.ActorOrgMatches`'s `:update` half needs

  Before this validation existed, `Incident.:update` had zero custom
  changes/validations -- only plain accepted-attribute assignment. Ash's
  atomic-upgrade optimization (real, confirmed via a running test
  capturing the real changeset) can express such an action as a single
  atomic UPDATE query with no prior read, which never populates
  `changeset.data` -- `Xaas.Operations.Checks.ActorOrgMatches`'s
  `:update` half needs the persisted record's real `org_id` from exactly
  that field. A bare `requires_original_data?/2 -> true` override on the
  check alone does not cleanly fix this: `AshJsonApi`'s PATCH flow routes
  single-record updates through `Ash.bulk_update/2` with `strategy:
  [:atomic, :stream, :atomic_batches]`
  (`deps/ash_json_api/lib/ash_json_api/controllers/helpers.ex`), and a
  real, confirmed-via-running-test finding this pass: the resulting
  InitialDataRequired-triggered retry cascade through that 3-strategy
  list is fragile for a plain, changes/validations-free update action and
  produced a real, observed `Ash.Error.Invalid.NoMatchingBulkStrategy`
  rather than a clean fallback.

  A real `Ash.Resource.Validation` with no `atomic/3` implementation (the
  default -- this module does not add one) is exactly what
  `deps/ash/lib/ash/resource/verifiers/verify_actions_atomic.ex`'s own
  compile-time atomic-eligibility check treats as atomic-INELIGIBLE,
  matching every other org-checked, non-`:create` action in this codebase
  (`ApprovalDrFailover:approve`, `ApprovalSlaCreditApply:approve`, etc.,
  all of which carry real validations of their own and have never hit
  this problem). Adding this real, independently-justified validation
  makes `Incident.:update` disqualify atomic mode at the FIRST attempt --
  a clean, single `{:not_atomic, reason}` result, going straight to the
  real, `changeset.data`-populated `:stream` strategy, with no fragile
  nested retry.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    status = Ash.Changeset.get_attribute(changeset, :status)
    resolved_at = Ash.Changeset.get_attribute(changeset, :resolved_at)

    if status == :resolved and is_nil(resolved_at) do
      {:error,
       field: :resolved_at,
       message: "is required when marking an incident resolved"}
    else
      :ok
    end
  end
end
