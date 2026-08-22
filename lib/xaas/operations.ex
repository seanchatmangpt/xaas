defmodule Xaas.Operations do
  use Ash.Domain,
    otp_app: :kanban,
    extensions: [
      AshJsonApi.Domain,
      AshGraphql.Domain,
      AshAdmin.Domain,
      Xaas.Operations.ProjectMeasure.Extension
    ]

  project_measure do
    github_actions do
      repository("seanchatmangpt/xaas")
      output_path(".artifacts/project-measure/ci-outcomes.json")
      token_env("GITHUB_TOKEN")
      subject_sha_env("GITHUB_SHA")
      api_url("https://api.github.com")
    end
  end

  admin do
    show?(true)
  end

  resources do
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
