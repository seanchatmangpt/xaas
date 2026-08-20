defmodule Xaas.Accounts.Token do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication.TokenResource, AshCloak]

  cloak do
    vault Xaas.Vault
    attributes [:extra_data]
  end

  postgres do
    table "tokens"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    read :expired do
      description "Look up all expired tokens."
      filter expr(expires_at < now())
    end

    read :get_token do
      description "Look up a token by JTI or token, and an optional purpose."
      get? true
      argument :token, :string, sensitive?: true
      argument :jti, :string, sensitive?: true
      argument :purpose, :string, sensitive?: false

      prepare AshAuthentication.TokenResource.GetTokenPreparation
    end

    action :revoked?, :boolean do
      description "Returns true if a revocation token is found for the provided token"
      argument :token, :string, sensitive?: true
      argument :jti, :string, sensitive?: true

      run AshAuthentication.TokenResource.IsRevoked
    end

    create :revoke_token do
      description "Revoke a token. Creates a revocation token corresponding to the provided token."
      accept [:extra_data]
      argument :token, :string, allow_nil?: false, sensitive?: true

      # ash_onetime cannot protect Xaas.Accounts.Token itself: AshOnetime.Resource's
      # compile-time verifier rejects any protected resource that declares an attribute
      # named :expires_at (one of AshOnetime.reserved_verification_inputs/0's five
      # reserved names), whether or not the protected action accepts it -- accepting it
      # trips "exposes reserved verification inputs", not accepting it trips "declares a
      # reserved verification attribute". Token has a real, required :expires_at
      # attribute (AshAuthentication.TokenResource's own token-expiry column), so this is
      # a structural conflict, not a config choice. The one-time-nonce spend fence lives
      # on Xaas.Accounts.Token.RevokeNonce instead (no :expires_at attribute), and is
      # enforced here via a real change that runs a real Ash.create/2 against that
      # resource before the revocation record is written.
      change Xaas.Accounts.Token.EnforceSingleRevoke

      change AshAuthentication.TokenResource.RevokeTokenChange
    end

    create :revoke_jti do
      description "Revoke a token by JTI. Creates a revocation token corresponding to the provided jti."
      accept [:extra_data]
      argument :subject, :string, allow_nil?: false, sensitive?: true
      argument :jti, :string, allow_nil?: false, sensitive?: true

      change AshAuthentication.TokenResource.RevokeJtiChange
    end

    create :store_token do
      description "Stores a token used for the provided purpose."
      accept [:extra_data, :purpose]
      argument :token, :string, allow_nil?: false, sensitive?: true
      change AshAuthentication.TokenResource.StoreTokenChange
    end

    destroy :expunge_expired do
      description "Deletes expired tokens."
      change filter(expr(expires_at < now()))
    end

    update :revoke_all_stored_for_subject do
      description "Revokes all stored tokens for a specific subject."
      accept [:extra_data]
      argument :subject, :string, allow_nil?: false, sensitive?: true
      change AshAuthentication.TokenResource.RevokeAllStoredForSubjectChange
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      description "AshAuthentication can interact with the token resource"
      authorize_if always()
    end
  end

  attributes do
    attribute :jti, :string do
      primary_key? true
      public? true
      allow_nil? false
      sensitive? true
    end

    attribute :subject, :string do
      allow_nil? false
      public? true
    end

    attribute :expires_at, :utc_datetime do
      allow_nil? false
      public? true
    end

    attribute :purpose, :string do
      allow_nil? false
      public? true
    end

    attribute :extra_data, :map do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end
end
