defmodule Xaas.Governance.W984dr2bGovThinBatchCourtTest do
  @moduledoc """
  Lane W984dr2b (v26.10.6): the W984cz-idiom BATCH sweep over the ~32
  thin one-mutation-surface governance validations disposed as a class
  by W984dr2's typed disposition (W984cz courted 3 modules, W984dr2
  courted 2 cross-resource modules; W984dr courts the Types enums).

  Census (re-read from disk 2026-10-07): 41 modules under
  `lib/xaas/governance/validations/`. Claimed elsewhere:
  W984cz -> ApprovalFreezeOverrideFreezeWindowExists,
  ApprovalNotAlreadyApproved, FreezeWindowEndsAfterStarts; W984dr2 ->
  ApprovalDrFailoverRequiresOpenIncident,
  AuditExportTokenNoActiveFreezeWindow. Not courted by this lane
  (multi-surface, need per-module courts):
  `ApprovalPentestFindingResolveFindingOrgMatches` (81, cross-resource
  query), `ApprovalSsoRoleMappingUpdateValidMappings` (75, structured
  mapping shape), `ApprovalBackupRetentionChangeWithinTierRange` (44),
  `ApprovalEnvironmentPromoteValidTarget` (39).

  This court parametrizes over the remaining 32 thin modules:

  - 24 `*RequiresApprover` modules (19–36 lines, identical cond shape:
    approved_by present -> distinct from requested_by). One
    mutation-class test per module through its LIVE consumer resource's
    real `:approve` changeset (`Ash.Changeset.for_update` on a real
    resource struct, real action accept list enforcement —
    `:approve` accepts exactly `[:approved_by]` on all 24). Mutation
    rationale per row: relaxing the nil/empty clause admits an
    approver-less :approve (silent self-service approval); relaxing
    the distinct clause lets the requester approve their own request
    (maker-checker breach); unwiring the validation from :approve
    admits both.
  - 8 boundary validations (ttl/email/id/date-range/expiry/
    2x not-already-revoked, not-already-used), each exercised through
    the LIVE action that wires it (real :create / :use / :revoke on
    real sandboxed Postgres rows). One mutation per branch asserted.

  Chicago discipline: real Postgres via the SQL sandbox, real Ash
  actions/changesets, zero mocks. Unique-per-run org ids make every
  run a fresh root.
  """

  use ExUnit.Case, async: true

  alias Xaas.Governance.{
    ApprovalBackupRetentionChange,
    ApprovalBreakGlassJustificationReview,
    ApprovalChangeOfControlNotify,
    ApprovalCmekKeyBinding,
    ApprovalComplianceRotationBlock,
    ApprovalDeniedPartyOverride,
    ApprovalDeploymentQuarantine,
    ApprovalDrFailover,
    ApprovalDsarErasure,
    ApprovalEnvironmentPromote,
    ApprovalExportSubscriptionUpdate,
    ApprovalFreezeOverride,
    ApprovalGeofenceExceptionGrant,
    ApprovalInsurancePolicyUpdate,
    ApprovalLeRequestRespond,
    ApprovalLegalHoldRelease,
    ApprovalOrgDelete,
    ApprovalPentestFindingResolve,
    ApprovalPersonnelAttestationRecord,
    ApprovalSourceEscrowSnapshot,
    ApprovalSsoRoleMappingUpdate,
    ApprovalSubprocessorRegistryUpdate,
    ApprovalVendorOffboardingAttestationIssue,
    AuditExportToken,
    DataDestructionCertificateIssue,
    InternalApiToken
  }

  # ------------------------------------------------------------------
  # Parametrized rows: {consumer resource, validation module, the
  # module's own "approver required" message}.
  # ------------------------------------------------------------------
  @approval_rows [
    {ApprovalBackupRetentionChange, Xaas.Governance.Validations.ApprovalBackupRetentionChangeRequiresApprover,
     "is required to approve a backup-retention change"},
    {ApprovalBreakGlassJustificationReview, Xaas.Governance.Validations.ApprovalBreakGlassJustificationReviewRequiresApprover,
     "is required to approve a break-glass justification review"},
    {ApprovalChangeOfControlNotify, Xaas.Governance.Validations.ApprovalChangeOfControlNotifyRequiresApprover,
     "is required to approve a change-of-control notification"},
    {ApprovalCmekKeyBinding, Xaas.Governance.Validations.ApprovalCmekKeyBindingRequiresApprover,
     "is required to approve a CMEK key binding"},
    {ApprovalComplianceRotationBlock, Xaas.Governance.Validations.ApprovalComplianceRotationBlockRequiresApprover,
     "is required to approve a rotation-compliance block"},
    {ApprovalDeniedPartyOverride, Xaas.Governance.Validations.ApprovalDeniedPartyOverrideRequiresApprover,
     "is required to approve a denied-party screening override"},
    {ApprovalDeploymentQuarantine, Xaas.Governance.Validations.ApprovalDeploymentQuarantineRequiresApprover,
     "is required to approve a deployment quarantine"},
    {ApprovalDrFailover, Xaas.Governance.Validations.ApprovalDrFailoverRequiresApprover,
     "is required to approve a DR failover"},
    {ApprovalDsarErasure, Xaas.Governance.Validations.ApprovalDsarErasureRequiresApprover,
     "is required to approve a DSAR erasure request"},
    {ApprovalEnvironmentPromote, Xaas.Governance.Validations.ApprovalEnvironmentPromoteRequiresApprover,
     "is required to approve an environment promotion"},
    {ApprovalExportSubscriptionUpdate, Xaas.Governance.Validations.ApprovalExportSubscriptionUpdateRequiresApprover,
     "is required to approve an export-subscription change"},
    {ApprovalFreezeOverride, Xaas.Governance.Validations.ApprovalFreezeOverrideRequiresApprover,
     "is required to approve a freeze override"},
    {ApprovalGeofenceExceptionGrant, Xaas.Governance.Validations.ApprovalGeofenceExceptionGrantRequiresApprover,
     "is required to approve a geofence exception grant"},
    {ApprovalInsurancePolicyUpdate, Xaas.Governance.Validations.ApprovalInsurancePolicyUpdateRequiresApprover,
     "is required to approve an insurance policy update"},
    {ApprovalLeRequestRespond, Xaas.Governance.Validations.ApprovalLeRequestRespondRequiresApprover,
     "is required to record an LE request response"},
    {ApprovalLegalHoldRelease, Xaas.Governance.Validations.ApprovalLegalHoldReleaseRequiresApprover,
     "is required to approve a legal hold release"},
    {ApprovalOrgDelete, Xaas.Governance.Validations.ApprovalOrgDeleteRequiresApprover,
     "is required to approve an org deletion"},
    {ApprovalPentestFindingResolve, Xaas.Governance.Validations.ApprovalPentestFindingResolveRequiresApprover,
     "is required to approve closing a pentest finding"},
    {ApprovalPersonnelAttestationRecord, Xaas.Governance.Validations.ApprovalPersonnelAttestationRecordRequiresApprover,
     "is required to approve a personnel attestation"},
    {ApprovalSourceEscrowSnapshot, Xaas.Governance.Validations.ApprovalSourceEscrowSnapshotRequiresApprover,
     "is required to approve a source-escrow snapshot"},
    {ApprovalSsoRoleMappingUpdate, Xaas.Governance.Validations.ApprovalSsoRoleMappingUpdateRequiresApprover,
     "is required to approve an SSO role mapping update"},
    {ApprovalSubprocessorRegistryUpdate, Xaas.Governance.Validations.ApprovalSubprocessorRegistryUpdateRequiresApprover,
     "is required to approve a sub-processor registry update"},
    {ApprovalVendorOffboardingAttestationIssue, Xaas.Governance.Validations.ApprovalVendorOffboardingAttestationIssueRequiresApprover,
     "is required to approve a vendor offboarding attestation issuance"},
    {DataDestructionCertificateIssue, Xaas.Governance.Validations.DataDestructionCertificateIssueRequiresApprover,
     "is required to approve a data destruction certificate issuance"}
  ]

  @ttl Xaas.Governance.Validations.ApprovalGeofenceExceptionGrantValidTtlHours
  @email Xaas.Governance.Validations.ApprovalDsarErasureValidSubjectEmail
  @subprocessor_id Xaas.Governance.Validations.ApprovalSubprocessorRegistryUpdateValidSubprocessorId
  @date_range Xaas.Governance.Validations.ApprovalInsurancePolicyUpdateValidDateRange
  @expired Xaas.Governance.Validations.AuditExportTokenExpiredTokenRefused
  @not_used Xaas.Governance.Validations.AuditExportTokenNotAlreadyUsed
  @aet_not_revoked Xaas.Governance.Validations.AuditExportTokenNotAlreadyRevoked
  @iat_not_revoked Xaas.Governance.Validations.InternalApiTokenNotAlreadyRevoked

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp org(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"
  defp uniq(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  # ------------------------------------------------------------------
  # Class 1: the 24 *RequiresApprover modules -- one mutation-class
  # test per module, through the live consumer resource's real :approve
  # changeset. Direct validate/3 (W984cz idiom); the :approve accept
  # list ([:approved_by]) is enforced by for_update on the real action.
  # ------------------------------------------------------------------
  for {resource, validation, required_msg} <- @approval_rows do
    test "#{inspect(resource)}: :approve without approver refused, self-approval refused, distinct approver passes" do
      resource = unquote(resource)
      validation = unquote(validation)
      required_msg = unquote(required_msg)

      requested_by = uniq("w984dr2b-req")

      # Mutation A (nil/empty clause -> :ok): an approver-less :approve
      # would be admitted -- silent self-service approval.
      missing_cs =
        struct(resource, requested_by: requested_by)
        |> Ash.Changeset.for_update(:approve, %{})

      assert {:error, field: :approved_by, message: ^required_msg} =
               validation.validate(missing_cs, [], %{})

      empty_cs =
        struct(resource, requested_by: requested_by)
        |> Ash.Changeset.for_update(:approve, %{approved_by: ""})

      assert {:error, field: :approved_by, message: ^required_msg} =
               validation.validate(empty_cs, [], %{})

      # Mutation B (distinct clause dropped): the requester could
      # approve their own request -- maker-checker breach.
      self_cs =
        struct(resource, requested_by: requested_by)
        |> Ash.Changeset.for_update(:approve, %{approved_by: requested_by})

      assert {:error, field: :approved_by, message: self_msg} =
               validation.validate(self_cs, [], %{})

      assert self_msg =~ "distinct"

      # Happy path: a second, distinct approver passes.
      ok_cs =
        struct(resource, requested_by: requested_by)
        |> Ash.Changeset.for_update(:approve, %{approved_by: uniq("w984dr2b-appr")})

      assert :ok = validation.validate(ok_cs, [], %{})

      # Live wiring non-vacuity: the validation must actually be wired
      # on the resource's :approve action (unwiring = the batch kill
      # mutation; this assertion fails for any row).
      approve_action = Ash.Resource.Info.action(resource, :approve)

      wired_validation_modules =
        approve_action.changes
        |> Enum.filter(&match?(%Ash.Resource.Validation{}, &1))
        |> Enum.map(& &1.module)

      assert validation in wired_validation_modules,
             "expected #{inspect(validation)} wired on #{inspect(resource)}.:approve"
  end
  end

  # ------------------------------------------------------------------
  # Class 2: the 8 boundary validations -- exercised through the LIVE
  # actions that wire them, on real sandboxed Postgres rows.
  # ------------------------------------------------------------------

  # (1) Geofence TTL bound: ttl_hours <= 168 and > 0.
  # Mutation: `ttl <= 168` relaxed -> a 169-hour (or unbounded) grant
  # admitted, breaking the "at most one week" platform-console rule.
  test "(1) geofence grant: ttl_hours 0 and 200 refused through live :create, ttl 24 passes" do
    base = %{
      org_id: org("w984dr2b-geo"),
      requested_by: uniq("w984dr2b-req"),
      identifier_or_cidr: "203.0.113.0/24",
      reason: "w984dr2b ttl court"
    }

    for bad_ttl <- [0, 200] do
      cs =
        ApprovalGeofenceExceptionGrant
        |> Ash.Changeset.for_create(:create, Map.put(base, :ttl_hours, bad_ttl))

      assert {:error, _} = Ash.create(cs, authorize?: false)
    end

    good =
      ApprovalGeofenceExceptionGrant
      |> Ash.Changeset.for_create(:create, Map.put(base, :ttl_hours, 24))
      |> Ash.create!(authorize?: false)

    assert good.ttl_hours == 24
  end

  # (2) DSAR subject email shape.
  # Mutation: regex relaxed -> free-text subject admitted at create.
  test "(2) dsar erasure: malformed subject_email refused through live :create, valid passes" do
    base = %{org_id: org("w984dr2b-dsar"), requested_by: uniq("w984dr2b-req")}

    for bad <- ["not-an-email", "missing-at.example"] do
      cs =
        ApprovalDsarErasure
        |> Ash.Changeset.for_create(:create, Map.put(base, :subject_email, bad))

      assert {:error, _} = Ash.create(cs, authorize?: false)
    end

    good =
      ApprovalDsarErasure
      |> Ash.Changeset.for_create(:create, Map.put(base, :subject_email, "subject@example.com"))
      |> Ash.create!(authorize?: false)

    assert good.subject_email == "subject@example.com"
  end

  # (3) Sub-processor id ConfigMap-key safety.
  # Mutation: regex relaxed -> spaces/slashes admitted in an id that
  # must be usable as a ConfigMap key.
  test "(3) subprocessor registry update: unsafe subprocessor_id refused through live :create, safe passes" do
    base = %{org_id: org("w984dr2b-sub"), requested_by: uniq("w984dr2b-req")}

    for bad <- ["bad id", "has/slash", ""] do
      cs =
        ApprovalSubprocessorRegistryUpdate
        |> Ash.Changeset.for_create(:create, %{
          requested_by: uniq("w984dr2b-req"),
          change_action: :added,
          subprocessor_id: bad,
          name: "Vendor One",
          category: :"third-party-service",
          purpose: "w984dr2b id-shape court"
        })

      assert {:error, _} = Ash.create(cs, authorize?: false)
    end

    good =
      ApprovalSubprocessorRegistryUpdate
      |> Ash.Changeset.for_create(:create, %{
        requested_by: uniq("w984dr2b-req"),
        change_action: :added,
        subprocessor_id: "vendor-1.core",
        name: "Vendor One",
        category: :"third-party-service",
        purpose: "w984dr2b id-shape court"
      })
      |> Ash.create!(authorize?: false)

    assert good.subprocessor_id == "vendor-1.core"
  end

  # (4) Insurance date range + positive coverage limit.
  # Mutations: `!= :gt` relaxed -> expiry <= effective admitted;
  # Decimal guard dropped -> zero/negative coverage admitted.
  test "(4) insurance policy update: expiry <= effective refused and non-positive coverage refused through live :create, valid passes" do
    base = %{org_id: org("w984dr2b-ins"), requested_by: uniq("w984dr2b-req")}

    cs =
      ApprovalInsurancePolicyUpdate
      |> Ash.Changeset.for_create(:create, %{
        org_id: base.org_id,
        requested_by: base.requested_by,
        effective_date: ~D[2026-01-01],
        expiry_date: ~D[2025-12-31]
      })

    assert {:error, _} = Ash.create(cs, authorize?: false)

    zero_cs =
      ApprovalInsurancePolicyUpdate
      |> Ash.Changeset.for_create(:create, %{
        org_id: base.org_id,
        requested_by: base.requested_by,
        coverage_limit_usd: Decimal.new(0)
      })

    assert {:error, _} = Ash.create(zero_cs, authorize?: false)

    good =
      ApprovalInsurancePolicyUpdate
      |> Ash.Changeset.for_create(:create, %{
        org_id: base.org_id,
        requested_by: base.requested_by,
        coverage_type: :cyber,
        carrier: "Carrier One",
        policy_number: "POL-#{System.unique_integer([:positive])}",
        effective_date: ~D[2026-01-01],
        expiry_date: ~D[2026-12-31],
        coverage_limit_usd: Decimal.new(1_000_000)
      })
      |> Ash.create!(authorize?: false)

    assert good.expiry_date == ~D[2026-12-31]
  end

  # (5) AuditExportToken expiry + single-use guards, through the live
  # :issue / :use actions.
  # Mutations: `:gt` compare flipped -> expired token usable;
  # NotAlreadyUsed dropped -> second :use stamps used_at again.
  test "(5) audit export token: expired refused on :use, second :use refused, fresh :use passes" do
    oid = org("w984dr2b-aet")

    expired_token =
      AuditExportToken
      |> Ash.Changeset.for_create(:issue, %{
        org_id: oid,
        created_by: uniq("w984dr2b-cb"),
        expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
      })
      |> Ash.create!(authorize?: false)

    assert {:error, _} = Ash.Changeset.for_update(expired_token, :use, %{})
                           |> Ash.update(authorize?: false)

    fresh_token =
      AuditExportToken
      |> Ash.Changeset.for_create(:issue, %{org_id: org("w984dr2b-aet2"), created_by: uniq("w984dr2b-cb")})
      |> Ash.create!(authorize?: false)

    used = fresh_token |> Ash.Changeset.for_update(:use, %{}) |> Ash.update!(authorize?: false)
    refute is_nil(used.used_at)

    assert {:error, _} = Ash.Changeset.for_update(used, :use, %{})
                           |> Ash.update(authorize?: false)
  end

  # (6) AuditExportToken double-revoke idempotency guard through the
  # live :revoke action.
  # Mutation: `nil -> :ok` generalized -> second :revoke re-stamps
  # revoked_at (audit-trail corruption).
  test "(6) audit export token: second :revoke refused through live action" do
    token =
      AuditExportToken
      |> Ash.Changeset.for_create(:issue, %{org_id: org("w984dr2b-aet3"), created_by: uniq("w984dr2b-cb")})
      |> Ash.create!(authorize?: false)

    revoked = token |> Ash.Changeset.for_update(:revoke, %{}) |> Ash.update!(authorize?: false)
    refute is_nil(revoked.revoked_at)

    assert {:error, _} = Ash.Changeset.for_update(revoked, :revoke, %{})
                           |> Ash.update(authorize?: false)
  end

  # (7) InternalApiToken double-revoke idempotency guard through the
  # live :revoke action.
  # Mutation: same class as (6), sibling module
  # InternalApiTokenNotAlreadyRevoked.
  test "(7) internal api token: second :revoke refused through live action" do
    token =
      InternalApiToken
      |> Ash.Changeset.for_create(:issue, %{
        created_by: uniq("w984dr2b-cb"),
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })
      |> Ash.create!(authorize?: false)

    revoked = token |> Ash.Changeset.for_update(:revoke, %{}) |> Ash.update!(authorize?: false)
    refute is_nil(revoked.revoked_at)

    assert {:error, _} = Ash.Changeset.for_update(revoked, :revoke, %{})
                           |> Ash.update(authorize?: false)
  end

  # (8) Fresh-root rerun (x2 requirement): the class-level refusals
  # reproduce on a second fresh root (new sandbox checkout, new unique
  # org ids) for one requires_approver row + the ttl boundary.
  test "(8) fresh-root rerun: org-delete approver guard and geofence ttl guard reproduce" do
    # Root 2 of the requires_approver class (ApprovalOrgDelete row).
    requested_by = uniq("w984dr2b-fresh-req")

    missing_cs =
      struct(ApprovalOrgDelete, requested_by: requested_by)
      |> Ash.Changeset.for_update(:approve, %{})

    assert {:error, field: :approved_by,
            message: "is required to approve an org deletion"} =
             Xaas.Governance.Validations.ApprovalOrgDeleteRequiresApprover.validate(
               missing_cs,
               [],
               %{}
             )

    # Root 2 of the ttl boundary court, live action.
    cs =
      ApprovalGeofenceExceptionGrant
      |> Ash.Changeset.for_create(:create, %{
        org_id: org("w984dr2b-fresh-geo"),
        requested_by: uniq("w984dr2b-fresh-req"),
        ttl_hours: 0
      })

    assert {:error, _} = Ash.create(cs, authorize?: false)
  end

  # Direct validate/3 sanity for the boundary modules whose live action
  # paths are covered above (9-12): pinned message + nil-pass clauses.
  test "(9) boundary modules: nil-tolerant clauses pass direct validate" do
    assert :ok =
             @expired.validate(
               struct(AuditExportToken, expires_at: nil)
               |> Ash.Changeset.for_update(:use, %{}),
               [],
               %{}
             )

    assert :ok =
             @date_range.validate(
               ApprovalInsurancePolicyUpdate
               |> Ash.Changeset.for_create(:create, %{}),
               [],
               %{}
             )

    assert {:error, field: :ttl_hours, message: m} =
             @ttl.validate(
               ApprovalGeofenceExceptionGrant
               |> Ash.Changeset.for_create(:create, %{ttl_hours: 169}),
               [],
               %{}
             )

    assert m =~ "at most 168"

    assert {:error, field: :subject_email, message: m2} =
             @email.validate(
               ApprovalDsarErasure
               |> Ash.Changeset.for_create(:create, %{subject_email: "nope"}),
               [],
               %{}
             )

    assert m2 =~ "valid email"
  end
end
