defmodule Xaas.Governance.W984eiMultiSurfaceCourtTest do
  @moduledoc """
  Lane W984ei (v26.10.6): per-module depth courts for the two
  multi-surface governance validations W984dr2b's thin-batch sweep
  explicitly deferred (its moduledoc: "not courted by this lane
  (multi-surface, need per-module courts)"):

  - `ApprovalBackupRetentionChangeWithinTierRange` (44 lines) --
    per-tier inclusive range edges across the full ladder
    starter {1,7} / pro {7,90} / enterprise {30,2555}.
  - `ApprovalEnvironmentPromoteValidTarget` (39 lines) -- the
    single-stage-forward-only ladder dev->staging->prod: exact-next
    passes; skip, reverse, no-op, and promote-from-terminal all
    refused through the live :create action.

  Relationship to W984dr2b's batch court
  (`w984dr2b_gov_thin_batch_court_test.exs`): that court covers only
  the RequiresApprover row for these two resources plus one
  happy-path each (tier :pro days 90 via
  `approval_backup_retention_change_test.exs`; skip dev->prod via the
  controller test). Neither exercises any exact range EDGE, the
  non-integer guard, the nil/unknown-tier clause, or the
  promote ladder's dev->staging / reverse / no-op / terminal branches.
  This court goes after exactly those, one mutation rationale per
  test.

  Chicago discipline: real sandboxed Postgres, real Ash actions, zero
  mocks. Unique-per-run org ids give every run a fresh root.
  """

  use ExUnit.Case, async: true

  alias Xaas.Governance.{ApprovalBackupRetentionChange, ApprovalEnvironmentPromote}

  # org_id is a real FK to Xaas.Accounts.Org.slug on
  # ApprovalBackupRetentionChange, so every tenant id below is a real,
  # persisted Org row created in this test's own sandbox transaction.
  defp create_org!(suffix) do
    Xaas.Generator.create_org!(%{
      name: "W984ei Org #{suffix}",
      slug: "w984ei-#{suffix}-#{System.unique_integer([:positive])}"
    }).slug
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  @tier_range Xaas.Governance.Validations.ApprovalBackupRetentionChangeWithinTierRange
  @promote_target Xaas.Governance.Validations.ApprovalEnvironmentPromoteValidTarget

  defp uniq(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  # ApprovalEnvironmentPromote has no Org FK relationship -- org_id is a
  # plain string there, so a bare unique string is a fresh root.
  defp org(suffix), do: "w984ei-org-#{suffix}-#{System.unique_integer([:positive])}"

  defp create_retention_change(attrs) do
    ApprovalBackupRetentionChange
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create(tenant: attrs.org_id, authorize?: false)
  end

  defp create_promote(attrs) do
    ApprovalEnvironmentPromote
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create(authorize?: false)
  end

  # ------------------------------------------------------------------
  # Tier-range boundary class: inclusive edges of each tier's range,
  # through the LIVE :create action (which wires the validation).
  # ------------------------------------------------------------------

  # Mutation rationale: flipping a `>=` to `>` (or `<=` to `<`) at any
  # single edge must flip exactly that row from pass to fail (or vice
  # versa). Because every edge below is asserted with its polarity,
  # any single-comparator mutation is killed by the row pair at that
  # edge (min-1 fails, min passes, max passes, max+1 fails).
  test "tier ranges: every inclusive edge of the starter/pro/enterprise ladder" do
    oid = create_org!("edges")
    req = uniq("w984ei-req")

    # starter {1,7}: min-1 out, min in, max in, max+1 out.
    assert {:error, _} = create_retention_change(%{org_id: oid, requested_by: req, tier: :starter, requested_retention_days: 0})
    assert {:ok, _} = create_retention_change(%{org_id: oid, requested_by: req, tier: :starter, requested_retention_days: 1})
    assert {:ok, r7} = create_retention_change(%{org_id: oid, requested_by: req, tier: :starter, requested_retention_days: 7})
    assert {:error, _} = create_retention_change(%{org_id: oid, requested_by: req, tier: :starter, requested_retention_days: 8})
    assert r7.requested_retention_days == 7

    # pro {7,90}: shared-edge overlap with starter at 7 (both tiers
    # admit 7 -- the ladder is inclusive on both bounds), min-1 out,
    # max in, max+1 out.
    assert {:error, _} = create_retention_change(%{org_id: oid, requested_by: req, tier: :pro, requested_retention_days: 6})
    assert {:ok, p7} = create_retention_change(%{org_id: oid, requested_by: req, tier: :pro, requested_retention_days: 7})
    assert {:ok, p90} = create_retention_change(%{org_id: oid, requested_by: req, tier: :pro, requested_retention_days: 90})
    assert {:error, _} = create_retention_change(%{org_id: oid, requested_by: req, tier: :pro, requested_retention_days: 91})
    assert p7.tier == :pro and p90.requested_retention_days == 90

    # enterprise {30,2555}: min-1 out, min in, max in (7y SEC 17a-4
    # bound), max+1 out.
    assert {:error, _} = create_retention_change(%{org_id: oid, requested_by: req, tier: :enterprise, requested_retention_days: 29})
    assert {:ok, _} = create_retention_change(%{org_id: oid, requested_by: req, tier: :enterprise, requested_retention_days: 30})
    assert {:ok, _} = create_retention_change(%{org_id: oid, requested_by: req, tier: :enterprise, requested_retention_days: 2555})
    assert {:error, _} = create_retention_change(%{org_id: oid, requested_by: req, tier: :enterprise, requested_retention_days: 2556})
  end

  # Mutation rationale: dropping the `is_integer(days)` guard admits
  # non-integer (float) retention days into a compliance-evidence
  # window; the type is :integer at storage but the validation must
  # reject before persistence.
  test "tier ranges: non-integer days refused through live :create" do
    assert {:error, _} =
             create_retention_change(%{
               org_id: create_org!("nonint"),
               requested_by: uniq("w984ei-req"),
               tier: :pro,
               requested_retention_days: 30.5
             })
  end

  # Mutation rationale: the `:error -> tier required` Map.fetch clause
  # is unreachable through the live action (the :project_tier enum
  # type rejects unknown tiers at cast). Kill the clause-delete
  # mutation directly on validate/3 with a changeset whose attributes
  # hold an unmapped atom, and pin the exact field + message shape.
  test "tier ranges: unknown-tier clause fires on direct validate with unmapped tier" do
    raw_cs =
      Ash.Changeset.for_create(ApprovalBackupRetentionChange, :create, %{org_id: "o", requested_by: "r", tier: :starter, requested_retention_days: 5})
      |> Map.update!(:attributes, &Map.put(&1, :tier, :free))

    assert {:error, field: :tier, message: m} = @tier_range.validate(raw_cs, [], %{})
    assert m =~ "is required to validate a retention range"
  end

  test "tier ranges: error message names the exact min/max and tier for pro" do
    assert {:error, err} =
             create_retention_change(%{org_id: create_org!("msg"), requested_by: uniq("w984ei-req"), tier: :pro, requested_retention_days: 200})

    msg = Exception.message(err)

    assert msg =~ "between 7 and 90"
    assert msg =~ "'pro'"
  end

  # ------------------------------------------------------------------
  # Promote-target boundary class: the full single-stage-forward-only
  # ladder through the LIVE :create action.
  # ------------------------------------------------------------------

  # Mutation rationale: adding/skipping a stage (mutating @next_environment
  # to %{dev: :prod, staging: :prod}) admits dev->prod skip attacks;
  # the exact-next polarity pair per row kills it.
  test "promote ladder: exact next stage passes (dev->staging, staging->prod)" do
    assert {:ok, p1} =
             create_promote(%{org_id: org("promo-ok"), requested_by: uniq("w984ei-req"), project_name: "svc-a", from_environment: :dev, to_environment: :staging})

    assert {p1.from_environment, p1.to_environment} == {:dev, :staging}

    assert {:ok, p2} =
             create_promote(%{org_id: org("promo-ok2"), requested_by: uniq("w984ei-req"), project_name: "svc-a", from_environment: :staging, to_environment: :prod})

    assert {p2.from_environment, p2.to_environment} == {:staging, :prod}
  end

  # Mutation rationale: deleting the `to == expected` inequality arm
  # (or defaulting it to :ok) admits skip (dev->prod), reverse
  # (staging->dev), and no-op (staging->staging) promotions.
  test "promote ladder: skip, reverse, and no-op targets refused" do
    base = fn suffix ->
      %{org_id: org("promo-bad-#{suffix}"), requested_by: uniq("w984ei-req"), project_name: "svc-b"}
    end

    # skip
    assert {:error, _} = create_promote(Map.merge(base.("skip"), %{from_environment: :dev, to_environment: :prod}))
    # reverse
    assert {:error, _} = create_promote(Map.merge(base.("rev"), %{from_environment: :staging, to_environment: :dev}))
    # no-op
    assert {:error, _} = create_promote(Map.merge(base.("noop"), %{from_environment: :staging, to_environment: :staging}))
    # dev->dev no-op
    assert {:error, _} = create_promote(Map.merge(base.("noop2"), %{from_environment: :dev, to_environment: :dev}))
  end

  # Mutation rationale: deleting the `:error` Map.fetch arm admits
  # promote-from-terminal-prod rows (a promotion with nowhere to go)
  # through live :create.
  test "promote ladder: from prod (terminal) refused through live :create" do
    assert {:error, err} =
             create_promote(%{org_id: org("promo-term"), requested_by: uniq("w984ei-req"), project_name: "svc-c", from_environment: :prod, to_environment: :staging})

    assert Exception.message(err) =~ "terminal environment"
  end

  # Non-vacuity: the validation module is really wired on the live
  # :create action of ApprovalEnvironmentPromote, and the refusals
  # above come from THAT wiring (not from the enum cast or type
  # constraints). Pinned-message assert on the direct validate plus a
  # wiring assert on the action.
  test "wiring non-vacuity: both validations really wired on their live actions" do
    wired_tier =
      ApprovalBackupRetentionChange
      |> Ash.Resource.Info.action(:create)
      |> Map.get(:changes, [])
      |> Enum.filter(&match?(%Ash.Resource.Validation{}, &1))
      |> Enum.map(& &1.module)

    assert @tier_range in wired_tier

    wired_promote =
      ApprovalEnvironmentPromote
      |> Ash.Resource.Info.action(:create)
      |> Map.get(:changes, [])
      |> Enum.filter(&match?(%Ash.Resource.Validation{}, &1))
      |> Enum.map(& &1.module)

    assert @promote_target in wired_promote
  end

  # Direct validate/3 polarity pins for the promote module (kill
  # message-mangling mutations that live :create flattens into a
  # generic error).
  test "promote ladder: direct validate pins exact field/message per refusal class" do
    mk = fn from, to ->
      Ash.Changeset.for_create(ApprovalEnvironmentPromote, :create, %{
        org_id: "o",
        requested_by: "r",
        project_name: "p",
        from_environment: from,
        to_environment: to
      })
    end

    assert :ok = @promote_target.validate(mk.(:dev, :staging), [], %{})
    assert :ok = @promote_target.validate(mk.(:staging, :prod), [], %{})

    assert {:error, field: :to_environment, message: m1} = @promote_target.validate(mk.(:dev, :prod), [], %{})
    assert m1 =~ "the only valid target is 'staging'"

    assert {:error, field: :from_environment, message: m2} = @promote_target.validate(mk.(:prod, :staging), [], %{})
    assert m2 =~ "terminal environment"
  end
end
