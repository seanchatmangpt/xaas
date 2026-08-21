defmodule Xaas.Governance.AuditExportToken do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Governance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  policies do
    # ash-migration Phase 5 (deny-by-default floor). This resource mints
    # bearer credentials for an unattended external system (a SIEM
    # forwarder) -- the same class of sensitivity as an API key, not a
    # read-mostly operational resource. Read is still bypassed open
    # (internal-api-token-gated at the router, same as every other
    # Xaas.Governance resource) so operators/UI can list a token's
    # metadata (never its hash) for an org; :issue and :revoke are the
    # real mutation surface and are bypassed the same way pending a real
    # per-org-owner authorization design (mirrors platform-console's
    # requireRoleIn(..., "owner") gate, not yet modeled as an xaas
    # actor/role concept).
    bypass action_type(:read) do
      authorize_if always()
    end

    bypass action(:issue) do
      authorize_if always()
    end

    bypass action(:revoke) do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :audit_export_token
  end

  json_api do
    type "audit_export_token"

    routes do
      base "/audit_export_tokens"
      get :read
      index :read
      post :issue
      patch :revoke
    end
  end

  postgres do
    table "audit_export_tokens"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    # Real token minting. The raw token is generated here, hashed before
    # persistence, and returned exactly once via the action's result --
    # never stored, never retrievable again (same discipline as
    # platform-console's audit-export-tokens design doc, "Storage" section).
    create :issue do
      accept [:org_id, :created_by]

      change Xaas.Governance.Changes.GenerateAuditExportToken
    end

    update :revoke do
      accept []
      require_atomic? false

      change set_attribute(:revoked_at, &DateTime.utc_now/0)
      validate Xaas.Governance.Validations.AuditExportTokenNotAlreadyRevoked
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :org_id, :string do
      allow_nil? false
      public? true
    end

    # Prefix shown in listings/logs ("aet_live_") + first few chars, so an
    # operator can recognize a token without ever seeing or storing the
    # full raw value. Distinct from token_hash.
    attribute :token_prefix, :string do
      allow_nil? false
      public? true
      writable? false
    end

    # SHA-256 hex digest of the raw token. Never the raw token itself --
    # matches platform-console's "SHA-256 hash only" storage discipline.
    attribute :token_hash, :string do
      allow_nil? false
      public? false
      writable? false
    end

    # Fixed at mint time to "audit:read" today -- same single-literal-scope
    # design as platform-console (AUDIT-EXPORT-SCHEMA.md line 36-37).
    # Modeled as a real attribute (not hardcoded in the resource) so a
    # future second scope literal doesn't require a schema migration.
    attribute :scope, :string do
      allow_nil? false
      public? true
      default "audit:read"
      writable? false
    end

    attribute :created_by, :string do
      allow_nil? false
      public? true
    end

    attribute :expires_at, :utc_datetime_usec do
      public? true
    end

    attribute :revoked_at, :utc_datetime_usec do
      public? true
      writable? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  calculations do
    # Real derived state a consumer/UI checks before trusting a token is
    # usable -- not stored, computed from revoked_at/expires_at so it can
    # never drift from the two source-of-truth columns.
    calculate :active?, :boolean, expr(
      is_nil(revoked_at) and (is_nil(expires_at) or expires_at > now())
    )
  end
end
