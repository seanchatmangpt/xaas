defmodule Xaas.Operations do
  use Ash.Domain,
    otp_app: :kanban,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain, AshAi]

  admin do
    show?(true)
  end

  # Read-only AshAi tools, modeled on chatgpt-cloud-elixir's
  # ChatGPTCloud.DfcmMemory tools pattern. Both target existing `:read`
  # default actions -- no new resource actions, no write tools this pass.
  tools do
    tool(:read_incidents, Xaas.Operations.Incident, :read,
      description:
        "Read-only: list operations incidents. Filter via the Ash query " <>
          "(pass filter conditions under \"filter\", arguments under \"input\")."
    )

    tool(:read_audit_log, Xaas.Operations.AuditLogEntry, :read,
      description:
        "Read-only: list operations audit log entries. Filter via the Ash query " <>
          "(pass filter conditions under \"filter\", arguments under \"input\")."
    )
  end

  resources do
    resource(Xaas.Operations.ActuationIntent)
    resource(Xaas.Operations.ActuationReceipt)
    resource(Xaas.Operations.ApprovalCastleVerbSchedule)
    resource(Xaas.Operations.AuditLogEntry)
    resource(Xaas.Operations.ApprovalK8sFaultRemediateSuggest)
    resource(Xaas.Operations.AutofdePlannerCacheHotset)
    resource(Xaas.Operations.AutofdePlannerCacheStats)
    resource(Xaas.Operations.AutofdePlannerCandidate)
    resource(Xaas.Operations.AutofdePlannerCatalog)
    resource(Xaas.Operations.AutofdePlannerMatch)
    resource(Xaas.Operations.CastleVerbFortune5Requirements)
    resource(Xaas.Operations.CastleVerbInventoryComponents)
    resource(Xaas.Operations.CastleVerbInventoryGoals)
    resource(Xaas.Operations.CapabilityLivenessReceipt)
    resource(Xaas.Operations.Incident)
    resource(Xaas.Operations.RouteCastleDeploy)
    resource(Xaas.Operations.RouteCastleRun)
    resource(Xaas.Operations.RouteCastleSchedule)
    resource(Xaas.Operations.RouteCastleSunset)
  end
end
