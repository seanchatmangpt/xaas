defmodule Xaas.Governance do
  use Ash.Domain,
    otp_app: :kanban,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain, AshPaperTrail.Domain, AshAdmin.Domain]

  admin do
    show? true
  end

  paper_trail do
    include_versions? true
  end

  resources do
    resource Xaas.Governance.ApprovalBackupRetentionChange
    resource Xaas.Governance.ApprovalBreakGlassJustificationReview
    resource Xaas.Governance.ApprovalChangeOfControlNotify
    resource Xaas.Governance.ApprovalCmekKeyBinding
    resource Xaas.Governance.ApprovalComplianceRotationBlock
    resource Xaas.Governance.ApprovalDeniedPartyOverride
    resource Xaas.Governance.ApprovalDeploymentQuarantine
    resource Xaas.Governance.ApprovalDrFailover
    resource Xaas.Governance.ApprovalDsarErasure
    resource Xaas.Governance.ApprovalEnvironmentPromote
    resource Xaas.Governance.ApprovalExportSubscriptionUpdate
    resource Xaas.Governance.ApprovalFreezeOverride
    resource Xaas.Governance.ApprovalGeofenceExceptionGrant
    resource Xaas.Governance.ApprovalInsurancePolicyUpdate
    resource Xaas.Governance.ApprovalLeRequestRespond
    resource Xaas.Governance.ApprovalLegalHoldRelease
    resource Xaas.Governance.ApprovalOrgDelete
    resource Xaas.Governance.ApprovalPentestFindingResolve
    resource Xaas.Governance.ApprovalPersonnelAttestationRecord
    resource Xaas.Governance.ApprovalSourceEscrowSnapshot
    resource Xaas.Governance.ApprovalSsoRoleMappingUpdate
    resource Xaas.Governance.ApprovalSubprocessorRegistryUpdate
    resource Xaas.Governance.ApprovalVendorOffboardingAttestationIssue
    resource Xaas.Governance.AuditExportToken
    resource Xaas.Governance.DataDestructionCertificateIssue
  end
end
