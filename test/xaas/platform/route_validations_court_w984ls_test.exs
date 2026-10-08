defmodule Xaas.Platform.RouteValidationsCourtW984lsTest do
  @moduledoc """
  Lane W984ls (v26.10.6): court for the 5 Platform Route validations from
  W984lq's eighth-census new-top batch (re-derived from the receipt's
  top-10 since W984lq overwrote /tmp/w984it_map.txt):

  - `Xaas.Platform.Validations.RouteFeatureFlagsRequiresApprover`
  - `Xaas.Platform.Validations.RouteOrgsCustomDomainActiveRequiresCertificateSecret`
  - `Xaas.Platform.Validations.RouteOrgsCustomDomainValidHostname`
  - `Xaas.Platform.Validations.RouteProjectsBackupsValidProjectName`
  - `Xaas.Platform.Validations.RouteProjectsRequiresApprover`

  These are the VALIDATIONS, distinct from the W984dv-courted
  RouteProjectsBackupsRetainUntilPassed and the W984fm-courted
  RouteFeatureFlagsApprove / RouteProjectsApprove CHANGES.

  Per-module dispositions (each exercised through its LIVE consumer
  resource's real actions on real sandboxed Postgres, W984dr2b idiom,
  plus a wiring non-vacuity assert per module):

  - RequiresApprover pair: missing/blank, self-approval, distinct-approver
    happy path -- every branch of the cond. (`platform_route_deepening_
    test.exs` already drives some of these through the HTTP/policy
    surface; this court adds the validation-name-keyed mutation coverage
    the census keys on, including the blank-string clause which the
    deepening test's `:"   "` case does hit.)
  - ValidHostname: valid multi-label ok, single-label refused,
    hyphen-edge label refused; the non-binary (nil) branch is typed
    UNREACHABLE-VIA-ACTION (`hostname` is `allow_nil?(false)` :string, so
    Ash's own required/type errors fire before the validation ever sees
    nil).
  - ActiveRequiresCertificateSecret: active-without-secret refused,
    active-with-secret ok, non-active transition without secret ok.
  - ValidProjectName: blank "" refused, whitespace-only refused (trim
    branch), valid name ok; nil branch typed UNREACHABLE-VIA-ACTION
    (`project_name` is `allow_nil?(false)` :string).

  Chicago discipline: real Postgres via `Ecto.Adapters.SQL.Sandbox`,
  real Ash actions (`for_create`/`for_update`), zero mocks, unique-per-run
  ids. Mutation rationale inline per test.
  """

  use ExUnit.Case, async: true

  alias Xaas.Platform.RouteFeatureFlags
  alias Xaas.Platform.RouteOrgsCustomDomain
  alias Xaas.Platform.RouteProjects
  alias Xaas.Platform.RouteProjectsBackups

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp uniq(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp create_approvable_row!(RouteFeatureFlags, label) do
    RouteFeatureFlags
    |> Ash.Changeset.for_create(:create, %{
      flag_key: uniq("#{label}-key"),
      enabled: false,
      requested_by: "w984ls-maker"
    })
    |> Ash.create!(authorize?: false)
  end

  defp create_approvable_row!(RouteProjects, _label) do
    RouteProjects
    |> Ash.Changeset.for_create(:create, %{requested_by: "w984ls-maker"})
    |> Ash.create!(authorize?: false)
  end

  defp wired_validation_modules(resource, action_name) do
    action = Ash.Resource.Info.action(resource, action_name)

    action.changes
    |> Enum.filter(&match?(%Ash.Resource.Validation{}, &1))
    |> Enum.map(& &1.module)
  end

  # ------------------------------------------------------------------
  # Class 1: the maker-checker RequiresApprover pair, through the live
  # :approve actions.
  # ------------------------------------------------------------------
  @approver_rows [
    {RouteFeatureFlags, Xaas.Platform.Validations.RouteFeatureFlagsRequiresApprover, "flag",
     "is required to approve a feature flag"},
    {RouteProjects, Xaas.Platform.Validations.RouteProjectsRequiresApprover, "project",
     "is required to approve a project"}
  ]

  for {resource, validation, label, required_msg} <- @approver_rows do
    test "#{label}: :approve refuses missing and blank approver, self-approval; distinct approver persists (#{inspect(resource)})" do
      resource = unquote(resource)
      validation = unquote(validation)
      required_msg = unquote(required_msg)
      label = unquote(label)

      # Wiring non-vacuity: unwiring the validation from :approve is the
      # batch-kill mutation; this assert fails for any unwired row.
      assert validation in wired_validation_modules(resource, :approve)

      row = create_approvable_row!(resource, label)

      assert row.requested_by == "w984ls-maker"

      # Mutation A (nil/empty clause -> :ok): an approver-less :approve
      # would be admitted -- silent self-service approval.
      assert {:error, %Ash.Error.Invalid{errors: missing_errors}} =
               row
               |> Ash.Changeset.for_update(:approve, %{})
               |> Ash.update(authorize?: false)

      assert Enum.any?(missing_errors, fn e ->
               to_string(e.message) =~ required_msg
             end),
             "expected missing-approver refusal, got: #{inspect(missing_errors)}"

      # Mutation B ("" not treated as empty): blank approver admitted.
      assert {:error, %Ash.Error.Invalid{errors: blank_errors}} =
               row
               |> Ash.Changeset.for_update(:approve, %{approved_by: ""})
               |> Ash.update(authorize?: false)

      assert Enum.any?(blank_errors, fn e ->
               to_string(e.message) =~ required_msg
             end)

      # Mutation C (distinct clause dropped): the requester approves
      # their own request -- maker-checker breach.
      assert {:error, %Ash.Error.Invalid{errors: self_errors}} =
               row
               |> Ash.Changeset.for_update(:approve, %{approved_by: "w984ls-maker"})
               |> Ash.update(authorize?: false)

      assert Enum.any?(self_errors, fn e ->
               to_string(e.message) =~ "distinct"
             end),
             "expected self-approval refusal, got: #{inspect(self_errors)}"

      # Happy path: a second, distinct approver -- real persisted state.
      assert {:ok, approved} =
               row
               |> Ash.Changeset.for_update(:approve, %{approved_by: "w984ls-checker"})
               |> Ash.update(authorize?: false)

      assert approved.approved_by == "w984ls-checker"
    end
  end

  # ------------------------------------------------------------------
  # Class 2: RouteOrgsCustomDomain hostname boundary, through the live
  # :create action.
  # ------------------------------------------------------------------
  test "custom domain create: valid multi-label hostname persists; single-label and hyphen-edge hostnames refused with the typed message" do
    # Wiring non-vacuity.
    assert Xaas.Platform.Validations.RouteOrgsCustomDomainValidHostname in wired_validation_modules(
             RouteOrgsCustomDomain,
             :create
           )

    org = uniq("w984ls-org")

    # Happy path: two RFC 1123 labels -- real persisted row, status
    # "pending" from the create change.
    assert {:ok, %RouteOrgsCustomDomain{} = domain} =
             RouteOrgsCustomDomain
             |> Ash.Changeset.for_create(:create, %{
               org_id: org,
               hostname: "console.customer-example.com"
             })
             |> Ash.create(authorize?: false)

    assert domain.hostname == "console.customer-example.com"
    assert domain.status == "pending"

    # Mutation A (length >= 2 -> >= 1): single-label hostnames admitted.
    assert {:error, %Ash.Error.Invalid{errors: single_errors}} =
             RouteOrgsCustomDomain
             |> Ash.Changeset.for_create(:create, %{org_id: org, hostname: "localhost"})
             |> Ash.create(authorize?: false)

    assert Enum.any?(single_errors, fn e ->
             to_string(e.message) =~ "is not a valid DNS hostname"
           end),
           "expected single-label refusal, got: #{inspect(single_errors)}"

    # Mutation B (@label anchored -> unanchored, or hyphen edges
    # allowed): "-console.customer.com" admitted.
    assert {:error, %Ash.Error.Invalid{errors: hyphen_errors}} =
             RouteOrgsCustomDomain
             |> Ash.Changeset.for_create(:create, %{org_id: org, hostname: "-console.customer.com"})
             |> Ash.create(authorize?: false)

    assert Enum.any?(hyphen_errors, fn e ->
             to_string(e.message) =~ "is not a valid DNS hostname"
           end)

    # Mutation C (@label char class widened, e.g. dots inside a label):
    # "a..b" -- empty middle label admitted.
    assert {:error, %Ash.Error.Invalid{errors: empty_label_errors}} =
             RouteOrgsCustomDomain
             |> Ash.Changeset.for_create(:create, %{org_id: org, hostname: "a..b"})
             |> Ash.create(authorize?: false)

    assert Enum.any?(empty_label_errors, fn e ->
             to_string(e.message) =~ "is not a valid DNS hostname"
           end)
  end

  # ------------------------------------------------------------------
  # Class 3: ActiveRequiresCertificateSecret, through the live :update
  # action on a real pending domain row.
  # ------------------------------------------------------------------
  test "custom domain update: active without certificate secret refused; active with secret and failed transition ok" do
    # Wiring non-vacuity.
    assert Xaas.Platform.Validations.RouteOrgsCustomDomainActiveRequiresCertificateSecret in wired_validation_modules(
             RouteOrgsCustomDomain,
             :update
           )

    org = uniq("w984ls-org")

    {:ok, domain} =
      RouteOrgsCustomDomain
      |> Ash.Changeset.for_create(:create, %{org_id: org, hostname: "app.customer-example.com"})
      |> Ash.create(authorize?: false)

    # Mutation A (status == "active" guard dropped): an "active" domain
    # with no bound TLS secret -- the exact data-quality gap this rule
    # exists to refuse.
    assert {:error, %Ash.Error.Invalid{errors: active_errors}} =
             domain
             |> Ash.Changeset.for_update(:update, %{status: "active"})
             |> Ash.update(authorize?: false)

    assert Enum.any?(active_errors, fn e ->
             to_string(e.message) =~ "is required when marking a custom domain active"
           end),
           "expected active-without-secret refusal, got: #{inspect(active_errors)}"

    # Blank secret is refused too ("" clause).
    assert {:error, %Ash.Error.Invalid{errors: blank_errors}} =
             domain
             |> Ash.Changeset.for_update(:update, %{status: "active", certificate_secret_name: ""})
             |> Ash.update(authorize?: false)

    assert Enum.any?(blank_errors, fn e ->
             to_string(e.message) =~ "is required when marking a custom domain active"
           end)

    # Happy path: active WITH a real secret name -- real persisted state.
    assert {:ok, active} =
             domain
             |> Ash.Changeset.for_update(:update, %{
               status: "active",
               certificate_secret_name: "cert-app-customer-example-com"
             })
             |> Ash.update(authorize?: false)

    assert active.status == "active"
    assert active.certificate_secret_name == "cert-app-customer-example-com"

    # Mutation B (non-active transitions refused by over-broad rule):
    # "failed" without a secret stays lawful.
    {:ok, domain2} =
      RouteOrgsCustomDomain
      |> Ash.Changeset.for_create(:create, %{org_id: org, hostname: "web.customer-example.com"})
      |> Ash.create(authorize?: false)

    assert {:ok, failed} =
             domain2
             |> Ash.Changeset.for_update(:update, %{status: "failed"})
             |> Ash.update(authorize?: false)

    assert failed.status == "failed"
    assert is_nil(failed.certificate_secret_name)
  end

  # ------------------------------------------------------------------
  # Class 4: RouteProjectsBackups project-name shape, through the live
  # :create action on sandboxed Postgres.
  # ------------------------------------------------------------------
  test "backup create: blank and whitespace-only project_name refused; valid name persists" do
    # Wiring non-vacuity.
    assert Xaas.Platform.Validations.RouteProjectsBackupsValidProjectName in wired_validation_modules(
             RouteProjectsBackups,
             :create
           )

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    base = %{
      org_id: uniq("w984ls-org"),
      namespace: "ns-w984ls",
      job_name: "job-w984ls",
      taken_at: now,
      size_bytes: 1024,
      retain_until: DateTime.add(now, 7 * 24 * 3600, :second)
    }

    # Mutation A (String.trim dropped -> only "" refused): a
    # whitespace-only name is admitted -- the exact ported route.ts
    # behavior (`body.projectName.trim()`).
    for blank <- ["", "   "] do
      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               RouteProjectsBackups
               |> Ash.Changeset.for_create(:create, Map.put(base, :project_name, blank))
               |> Ash.create(authorize?: false)

      assert Enum.any?(errors, fn e ->
               to_string(e.message) =~ "is required"
             end),
             "expected blank project_name refusal for #{inspect(blank)}, got: #{inspect(errors)}"
    end

    # Happy path: real persisted backup row.
    assert {:ok, %RouteProjectsBackups{} = backup} =
             RouteProjectsBackups
             |> Ash.Changeset.for_create(:create, Map.put(base, :project_name, "payments-api"))
             |> Ash.create(authorize?: false)

    assert backup.project_name == "payments-api"
    assert backup.status == :pending
  end
end
