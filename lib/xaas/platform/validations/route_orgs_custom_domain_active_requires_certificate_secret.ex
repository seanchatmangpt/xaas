defmodule Xaas.Platform.Validations.RouteOrgsCustomDomainActiveRequiresCertificateSecret do
  @moduledoc """
  Real data-quality rule for `Xaas.Platform.RouteOrgsCustomDomain`'s
  `:update` action, matching this resource's own moduledoc's real cert-sync
  semantics: a binding cannot honestly be reported `"active"` without a
  real bound TLS secret name (the artifact `lib/k8s.ts`'s real
  `getCertificateStatus` resync would have written before flipping status
  to active) -- an `"active"` domain with no `certificate_secret_name` is
  exactly the kind of gap this resource's own disclosed "external cert-sync
  job writes status" contract depends on being trustworthy.

  ## Real, disclosed side effect: this is also why `RouteOrgsCustomDomain.
  :update` is atomic-upgrade-INELIGIBLE, which is exactly what
  `Xaas.Platform.Checks.ActorOrgMatches`'s `:update` half needs

  Before this validation existed, `:update` had zero custom
  changes/validations -- only plain accepted-attribute assignment, and a
  real, confirmed-via-running-test finding this pass showed that,
  DESPITE the action's own `require_atomic?(false)` declaration, Ash's
  atomic-upgrade optimization can still express such an action as a single
  atomic UPDATE query with no prior read when reached through
  `AshJsonApi`'s PATCH controller (`Ash.bulk_update/2` with `strategy:
  [:atomic, :stream, :atomic_batches]` -- `require_atomic?` on the action
  governs `Ash.update!/2`'s own direct-call contract, a different code path
  than the bulk-update strategy list the JSON:API PATCH controller always
  uses). That atomic path never populates `changeset.data` --
  `Xaas.Platform.Checks.ActorOrgMatches`'s `:update` half needs the
  persisted record's real `org_id` from exactly that field, and silently
  denied every real PATCH with a real `403` before this validation existed
  (caught by this pass's own real, running `RouteOrgsCustomDomainControllerTest`
  PATCH test, not by static reasoning alone).

  A real `Ash.Resource.Validation` with no `atomic/3` implementation (the
  default -- this module does not add one) is exactly what
  `deps/ash/lib/ash/resource/verifiers/verify_actions_atomic.ex`'s own
  compile-time atomic-eligibility check treats as atomic-INELIGIBLE,
  matching the identical fix `Xaas.Operations.Validations.
  IncidentResolvedRequiresResolvedAt` already applied to
  `Xaas.Operations.Incident.:update` for the same reason. Adding this real,
  independently-justified validation makes `:update` disqualify atomic mode
  at the FIRST attempt -- a clean, single `{:not_atomic, reason}` result,
  going straight to the real, `changeset.data`-populated `:stream`
  strategy, with no fragile nested retry.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    status = Ash.Changeset.get_attribute(changeset, :status)
    certificate_secret_name = Ash.Changeset.get_attribute(changeset, :certificate_secret_name)

    if status == "active" and (is_nil(certificate_secret_name) or certificate_secret_name == "") do
      {:error,
       field: :certificate_secret_name,
       message: "is required when marking a custom domain active"}
    else
      :ok
    end
  end
end
