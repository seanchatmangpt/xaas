defmodule Xaas.Governance.ApprovalBreakGlassJustificationReview do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Governance,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  graphql do
    type :approval_break_glass_justification_review
  end

  json_api do
    type "approval_break_glass_justification_review"
  end

  postgres do
    table "approval_break_glass_justification_reviews"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]
  end

  attributes do
    uuid_primary_key :id

    attribute :requested_by, :string do
      allow_nil? false
    end

    attribute :approved_by, :string
  end
end
