defmodule Xaas.Platform do
  use Ash.Domain,
    otp_app: :kanban,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain]

  admin do
    show? true
  end


  resources do
    resource Xaas.Platform.RouteFeatureFlags
    resource Xaas.Platform.RouteOrgsCustomDomain
    resource Xaas.Platform.RouteProjects
    resource Xaas.Platform.RouteProjectsBackups
    resource Xaas.Platform.RouteSecrets
  end
end
