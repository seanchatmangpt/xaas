defmodule Xaas.Operations do
  use Ash.Domain,
    otp_app: :kanban,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(Xaas.Operations.ApprovalCastleVerbSchedule)
    resource(Xaas.Operations.ApprovalK8sFaultRemediateSuggest)
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
