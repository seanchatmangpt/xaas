defmodule Xaas.Governance.W984dr3GovStateBearingCourtTest do
  @moduledoc """
  Lane W984dr3 court (v26.10.6 burn-down continuation): 2 most
  state-bearing governance validations NOT in W984cz / W984dr2 /
  W984da's sets (and not W984ds2's running pentest/sso slice):

  1. `Xaas.Governance.Validations.ApprovalBackupRetentionChangeWithinTierRange`
     -- real per-tier retention-range gate on
     `ApprovalBackupRetentionChange :create` (the "400 not a fee" rule;
     the overage-fee change on `:approve` is downstream of it).
  2. `Xaas.Governance.Validations.ApprovalEnvironmentPromoteValidTarget`
     -- real single-stage-forward-only promotion rule on
     `ApprovalEnvironmentPromote :create`.

  Chicago style: real sandboxed Postgres (`Xaas.Repo`), real
  `Ash.Changeset.for_create` + real resource actions (`:create`), real
  persisted `Xaas.Accounts.Org` rows for the FK/multitenancy, zero
  mocks. Each test names the single-line mutation it kills. Unique-per-
  run org slugs / project names make each run a fresh root (no fixture
  reuse across the ×2 fresh-root runs).
  """

  use ExUnit.Case, async: true

  alias Xaas.Accounts.Org
  alias Xaas.Governance.{ApprovalBackupRetentionChange, ApprovalEnvironmentPromote}

  @tier_range Xaas.Governance.Validations.ApprovalBackupRetentionChangeWithinTierRange
  @valid_target Xaas.Governance.Validations.ApprovalEnvironmentPromoteValidTarget

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp unique, do: System.unique_integer([:positive])

  defp real_org!(prefix) do
    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "#{prefix} #{unique()}",
      slug: "#{prefix}-#{unique()}"
    })
    |> Ash.create!(authorize?: false)
  end

  defp create_retention_change(org_slug, tier, days) do
    ApprovalBackupRetentionChange
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_slug,
      requested_by: "w984dr3-requester-#{unique()}",
      tier: tier,
      requested_retention_days: days
    })
    |> Ash.create(tenant: org_slug, authorize?: false)
  end

  defp create_promotion(project, from, to) do
    ApprovalEnvironmentPromote
    |> Ash.Changeset.for_create(:create, %{
      org_id: "w984dr3-org-#{unique()}",
      requested_by: "w984dr3-requester-#{unique()}",
      project_name: project,
      from_environment: from,
      to_environment: to
    })
    |> Ash.create(authorize?: false)
  end

  # ==================================================================
  # Court A: ApprovalBackupRetentionChangeWithinTierRange
  # ==================================================================

  # (1) Upper-bound clause: starter caps at 7 days; 30 is refused with
  # the real typed message. Mutation: widen the @retention_range map
  # (e.g. starter {1, 30}) -- an out-of-tier retention would be
  # admitted at create time and only priced later at :approve.
  test "starter retention above tier max is refused with typed message" do
    org = real_org!("w984dr3-starter-max")

    assert {:error, %Ash.Error.Invalid{} = err} =
             create_retention_change(org.slug, :starter, 30)

    assert msg = Exception.message(err)
    assert msg =~ "must be an integer between 1 and 7 for tier 'starter'"
  end

  # (2) Enterprise boundary (SEC 17a-4 7-year cap): 2555 exactly passes
  # and really persists; 2556 is refused. Mutation: `days <= max_days`
  # relaxed to `days <= max_days + 1` (off-by-one) admits 2556.
  test "enterprise 7-year boundary: 2555 persists, 2556 refused" do
    org = real_org!("w984dr3-ent-max")

    assert {:ok, %ApprovalBackupRetentionChange{} = row} =
             create_retention_change(org.slug, :enterprise, 2555)

    assert {:ok, reloaded} = Ash.get(ApprovalBackupRetentionChange, row.id, tenant: org.slug)
    assert reloaded.tier == :enterprise
    assert reloaded.requested_retention_days == 2555

    assert {:error, %Ash.Error.Invalid{}} = create_retention_change(org.slug, :enterprise, 2556)
  end

  # (3) Lower-bound clause: pro floor is 7; 6 is refused. Mutation:
  # `days >= min_days` dropped from the guard -- a below-tier retention
  # (silent under-protection) would be admitted.
  test "pro retention below tier min is refused" do
    org = real_org!("w984dr3-pro-min")

    assert {:ok, %ApprovalBackupRetentionChange{}} =
             create_retention_change(org.slug, :pro, 7)

    assert {:error, %Ash.Error.Invalid{}} = create_retention_change(org.slug, :pro, 6)
  end

  # (4) Type + missing-tier arms: a non-integer days value fails the
  # same typed per-tier message (not admitted), and an absent tier hits
  # the `:error` arm with the "is required" message. Mutations: drop
  # `is_integer(days)` (comparison against a binary becomes vacuously
  # true/false instead of a typed refusal) and map the `:error` ->
  # {:error, ...} clause to :ok (tier-less changesets admitted).
  test "non-integer days and missing tier are both typed refusals" do
    org = real_org!("w984dr3-type-arms")

    assert {:error, %Ash.Error.Invalid{} = err} =
             create_retention_change(org.slug, :starter, "30")

    assert Exception.message(err) =~ "must be an integer between 1 and 7 for tier 'starter'"

    # The `:error` (missing-tier) arm is NOT reachable through the real
    # `:create` action -- `tier` is `allow_nil? false`, so the attribute
    # constraint refuses nil before validations run. It is exercised
    # directly per the W984cz direct-court method.
    changeset =
      ApprovalBackupRetentionChange
      |> Ash.Changeset.for_create(:create, %{
        org_id: org.slug,
        requested_by: "w984dr3-no-tier-#{unique()}",
        tier: :pro,
        requested_retention_days: 30
      })
      |> Ash.Changeset.force_change_attribute(:tier, nil)

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.create(changeset, tenant: org.slug, authorize?: false)

    assert {:error, [field: :tier, message: msg]} =
             @tier_range.validate(changeset, [], %{})

    assert msg =~ "is required to validate a retention range"
  end

  # (5) Non-vacuity: refusals leave NO row (refusal tracks real DB
  # state, not just a tuple shape). Mutation: remove the validation
  # from the `:create` action -- every refusal test in this court
  # would then persist a row and fail here.
  test "refused retention changes persist no row" do
    org = real_org!("w984dr3-no-row")

    assert {:error, %Ash.Error.Invalid{}} =
             create_retention_change(org.slug, :starter, 100)

    require Ash.Query

    assert [] ==
             ApprovalBackupRetentionChange
             |> Ash.Query.filter(org_id: org.slug)
             |> Ash.read!(tenant: org.slug, authorize?: false)
  end

  # ==================================================================
  # Court B: ApprovalEnvironmentPromoteValidTarget
  # ==================================================================

  # (1) Happy path: the only legal transition dev -> staging is
  # admitted through the real :create action and really persists.
  # Mutation: remove the validation from :create -- trivially true.
  test "dev -> staging is admitted and persists" do
    project = "w984dr3-proj-ok-#{unique()}"

    assert {:ok, %ApprovalEnvironmentPromote{} = row} = create_promotion(project, :dev, :staging)

    assert {:ok, %ApprovalEnvironmentPromote{} = reloaded} =
             Ash.get(ApprovalEnvironmentPromote, row.id)

    assert reloaded.from_environment == :dev
    assert reloaded.to_environment == :staging
    assert reloaded.status == :pending
  end

  # (2) Skip-a-stage clause: dev -> prod is refused with the real
  # typed message. Mutation: `{:ok, expected} when to == expected ->
  # :ok` relaxed to admit any `to` -- a stage-skipping promotion
  # (missing the staging soak) would be admitted.
  test "dev -> prod stage skip is refused with typed message" do
    project = "w984dr3-proj-skip-#{unique()}"

    assert {:error, %Ash.Error.Invalid{} = err} = create_promotion(project, :dev, :prod)

    msg = Exception.message(err)
    assert msg =~ "invalid promotion from 'dev' to 'prod'"
    assert msg =~ "the only valid target is 'staging'"
  end

  # (3) Terminal-stage clause: promoting FROM prod is refused with the
  # real "already the terminal environment" message. Mutation: map the
  # `:error` arm to :ok -- an endless prod -> prod/no-op promotion
  # would be admitted.
  test "promotion from terminal prod is refused" do
    project = "w984dr3-proj-terminal-#{unique()}"

    assert {:error, %Ash.Error.Invalid{} = err} = create_promotion(project, :prod, :prod)

    assert Exception.message(err) =~ "is already the terminal environment"
  end

  # (4) Reversal + no-op clauses: staging -> dev (backwards) and
  # staging -> staging (no-op) are both refused. Mutation:
  # `to == expected` relaxed to `to in [expected, from]` (or dropping
  # the catch-all error clause) admits reversals/no-ops.
  test "staging -> dev reversal and staging -> staging no-op are refused" do
    assert {:error, %Ash.Error.Invalid{}} =
             create_promotion("w984dr3-proj-rev-#{unique()}", :staging, :dev)

    assert {:error, %Ash.Error.Invalid{}} =
             create_promotion("w984dr3-proj-noop-#{unique()}", :staging, :staging)
  end

  # (5) Non-vacuity: refusals leave NO row; the legal transition does.
  # Mutation: remove the validation from :create -- the refused shapes
  # persist and this test fails.
  test "refused promotions persist no row; legal one does" do
    bad = "w984dr3-proj-norow-#{unique()}"
    assert {:error, %Ash.Error.Invalid{}} = create_promotion(bad, :dev, :prod)

    require Ash.Query

    assert [] ==
             ApprovalEnvironmentPromote
             |> Ash.Query.filter(project_name: bad)
             |> Ash.read!(authorize?: false)

    good = "w984dr3-proj-row-#{unique()}"
    assert {:ok, %ApprovalEnvironmentPromote{} = good_row} = create_promotion(good, :dev, :staging)

    assert {:ok, %ApprovalEnvironmentPromote{}} =
             Ash.get(ApprovalEnvironmentPromote, good_row.id)
  end
end
