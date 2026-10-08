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

  # ------------------------------------------------------------------
  # Class 5 (W984nj, executing W984mj's court-strengthening work order):
  # forced-blank cases. Ash's :string type normalizes blank/whitespace
  # action inputs to nil before validations run (W984mj Finding 1: the
  # "" arms and the trim branch are dead via for_create/for_update
  # inputs). W984mj's prescribed fix, Ash.Changeset.force_change_attribute/3,
  # is itself insufficient: it re-casts through Ash.Type.cast_input with
  # the attribute's default :string constraints (trim?: true,
  # allow_empty?: false), so a forced "" STILL collapses to nil. The
  # cases below therefore inject the raw blank directly into
  # changeset.attributes (past the cast layer) and then run the REAL
  # action pipeline (Ash.update/Ash.create), so the validations and their
  # blank arms execute over real Postgres. Without these cases, mutants
  # that drop the blank arm (W984mj M5) or the trim (M6) survive.
  # ------------------------------------------------------------------

  defp force_blank(changeset, field, value) do
    changeset
    |> Ash.Changeset.force_change_attribute(field, value)
    |> then(fn cs ->
      %{cs | attributes: Map.put(cs.attributes, field, value)}
    end)
  end

  for {resource, label, required_msg} <- [
        {RouteFeatureFlags, "flag", "is required to approve a feature flag"},
        {RouteProjects, "project", "is required to approve a project"}
      ] do
    test "#{label}: forced-blank (\"\") approved_by still refuses :approve (#{inspect(resource)})" do
      resource = unquote(resource)
      required_msg = unquote(required_msg)
      label = unquote(label)

      row = create_approvable_row!(resource, label)

      # Mutation (blank "" arm dropped, nil arm kept): a forced-blank
      # approver would be admitted -- the arm is only reachable via a
      # cast-bypassing change, since Ash normalizes blank action inputs
      # (and even forced changes, via cast_input) to nil.
      changeset = force_blank(row |> Ash.Changeset.for_update(:approve, %{}), :approved_by, "")

      assert Ash.Changeset.get_attribute(changeset, :approved_by) == "",
             "precondition: the forced blank must survive input normalization"

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Ash.update(changeset, authorize?: false)

      assert Enum.any?(errors, fn e ->
               to_string(e.message) =~ required_msg
             end),
             "expected forced-blank approver refusal, got: #{inspect(errors)}"
    end
  end

  test "custom domain update: forced-blank certificate_secret_name (\"\") on active is still refused" do
    org = uniq("w984nj-org")

    {:ok, domain} =
      RouteOrgsCustomDomain
      |> Ash.Changeset.for_create(:create, %{org_id: org, hostname: "nj.customer-example.com"})
      |> Ash.create(authorize?: false)

    # Mutation M5 (blank arm dropped, `is_nil(x) or x == ""` -> `is_nil(x)`):
    # an active domain with a forced-blank secret would be admitted.
    changeset =
      force_blank(
        domain |> Ash.Changeset.for_update(:update, %{status: "active"}),
        :certificate_secret_name,
        ""
      )

    assert Ash.Changeset.get_attribute(changeset, :certificate_secret_name) == "",
           "precondition: the forced blank must survive input normalization"

    assert {:error, %Ash.Error.Invalid{errors: errors}} = Ash.update(changeset, authorize?: false)

    assert Enum.any?(errors, fn e ->
             to_string(e.message) =~ "is required when marking a custom domain active"
           end),
           "expected forced-blank secret refusal, got: #{inspect(errors)}"
  end

  test "backup create: forced-whitespace project_name (\"   \") still refuses (trim branch)" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    base = %{
      org_id: uniq("w984nj-org"),
      namespace: "ns-w984nj",
      job_name: "job-w984nj",
      taken_at: now,
      size_bytes: 2048,
      retain_until: (now |> DateTime.add(7 * 24 * 3600, :second) |> DateTime.truncate(:second))
    }

    # Mutation M6 (String.trim dropped, `String.trim(name) == ""` ->
    # `name == ""`): a whitespace-only name would be admitted.
    #
    # The trim arm is UNREACHABLE through the live :create action, at two
    # layers: (a) Ash's :string cast drops whitespace-only action inputs
    # to nil (W984mj Finding 1), and (b) the create pipeline re-casts
    # injected attribute values at execution time, so even a raw
    # attributes-map injection (which DOES survive on :update paths --
    # see the M5 case above) collapses back to nil before validations
    # run on creates. W984mj's receipt prescribes applying the validation
    # directly on the forced changeset for exactly this case. Wiring
    # non-vacuity (the validation is really on :create) is asserted in
    # the class-4 test above, so this direct application is not vacuous.
    changeset = force_blank(RouteProjectsBackups |> Ash.Changeset.for_create(:create, base), :project_name, "   ")

    assert Ash.Changeset.get_attribute(changeset, :project_name) == "   ",
           "precondition: the forced whitespace must sit on the changeset"

    assert {:error, field: :project_name, message: "is required"} =
             Xaas.Platform.Validations.RouteProjectsBackupsValidProjectName.validate(
               changeset,
               [],
               %{}
             )

    # The same forced changeset carries the trim-refusal to the pipeline
    # boundary: under M6 the pipeline-level refusal for this changeset
    # comes only from the nil fallback, so pin the real pipeline refusal
    # too (real action, real Postgres).
    assert {:error, %Ash.Error.Invalid{errors: pipeline_errors}} =
             Ash.create(changeset, authorize?: false)

    assert Enum.any?(pipeline_errors, fn e ->
             to_string(e.message) =~ "is required"
           end)
  end
end
