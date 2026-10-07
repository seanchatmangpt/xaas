defmodule Xaas.Governance.AuditExportToken do
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Governance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  policies do
    # ash-migration Phase 5 (deny-by-default floor). This resource mints
    # bearer credentials for an unattended external system (a SIEM
    # forwarder) -- the same class of sensitivity as an API key, not a
    # read-mostly operational resource. Read is still bypassed open
    # (internal-api-token-gated at the router, same as every other
    # Xaas.Governance resource) so operators/UI can list a token's
    # metadata (never its hash) for an org.
    bypass action_type(:read) do
      authorize_if(always())
    end

    # Real fix (twentieth-pass ERRC grid sweep, item 27): :issue and
    # :revoke previously bypassed with a bare `authorize_if always()` --
    # any actor holding only the shared INTERNAL_API_TOKEN could mint a
    # real, persisted, hashed bearer credential for any caller-supplied
    # org_id, never created, never authenticated. See
    # `Xaas.Governance.Checks.AuditExportTokenActorOrgMatches`'s own
    # moduledoc for the full disclosed finding and the live-HTTP proof.
    bypass action(:issue) do
      authorize_if(Xaas.Governance.Checks.AuditExportTokenActorOrgMatches)
    end

    bypass action(:revoke) do
      authorize_if(Xaas.Governance.Checks.AuditExportTokenActorOrgMatches)
    end

    # SPEC-16 (lane W935): consuming a token is as sensitive as minting
    # or revoking one -- same org-match floor, same bypass idiom.
    bypass action(:use) do
      authorize_if(Xaas.Governance.Checks.AuditExportTokenActorOrgMatches)
    end

    policy always() do
      forbid_if(always())
    end
  end

  json_api do
    type("audit_export_token")

    routes do
      base("/audit_export_tokens")
      get(:read)
      index(:read)
      post(:issue)
      patch(:use, route: "/:id/use")
      patch(:revoke, route: "/:id/revoke")
    end
  end

  postgres do
    table("audit_export_tokens")
    repo(Xaas.Repo)
  end

  actions do
    defaults([:read])

    # Real token minting. The raw token is generated here, hashed before
    # persistence, and returned exactly once via the action's result --
    # never stored, never retrievable again (same discipline as
    # platform-console's audit-export-tokens design doc, "Storage" section).
    create :issue do
      # W900-batch2 (W765 GAP-A): mint-time TTL input -- :expires_at is
      # accepted on the real action surface (previously only reachable via
      # force_change_attributes). Optional: nil stays non-expiring.
      accept([:org_id, :created_by, :expires_at])

      # W801: real freeze-window enforcement (closes W765 GAP-D for this
      # path) -- no new audit-export credential is minted while the org is
      # inside an active FreezeWindow.
      validate(Xaas.Governance.Validations.AuditExportTokenNoActiveFreezeWindow)

      change(Xaas.Governance.Changes.GenerateAuditExportToken)
    end

    update :revoke do
      accept([])
      require_atomic?(false)

      change(set_attribute(:revoked_at, &DateTime.utc_now/0))
      validate(Xaas.Governance.Validations.AuditExportTokenNotAlreadyRevoked)
    end

    # SPEC-16 (lane W935, W765 GAP-B): the real consume surface. Stamps
    # `used_at` once and increments `use_count` atomically; refuses a
    # second use (AuditExportTokenNotAlreadyUsed, the SPEC-16 court
    # idiom) and refuses an already-expired token (SPEC-17,
    # AuditExportTokenExpiredTokenRefused, typed on :expires_at).
    #
    # W801 active-window gating where applicable: unlike :revoke (which
    # mints nothing and stays available during a freeze per W801's
    # scope discipline), :use is the export path the freeze governs, so
    # the same active-freeze validation that gates :issue gates it.
    #
    # require_atomic?(false): the used_at stamp and counter increment
    # run as changes on the loaded record, mirroring the :revoke
    # action's shape.
    update :use do
      accept([])
      require_atomic?(false)

      validate(Xaas.Governance.Validations.AuditExportTokenNoActiveFreezeWindow)
      validate(Xaas.Governance.Validations.AuditExportTokenExpiredTokenRefused)
      validate(Xaas.Governance.Validations.AuditExportTokenNotAlreadyUsed)

      change(set_attribute(:used_at, &DateTime.utc_now/0))
      change(increment(:use_count, amount: 1))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :org_id, :string do
      allow_nil?(false)
      public?(true)
    end

    # Prefix shown in listings/logs ("aet_live_") + first few chars, so an
    # operator can recognize a token without ever seeing or storing the
    # full raw value. Distinct from token_hash.
    attribute :token_prefix, :string do
      allow_nil?(false)
      public?(true)
      writable?(false)
    end

    # SHA-256 hex digest of the raw token. Never the raw token itself --
    # matches platform-console's "SHA-256 hash only" storage discipline.
    attribute :token_hash, :string do
      allow_nil?(false)
      public?(false)
      writable?(false)
    end

    # Fixed at mint time to "audit:read" today -- same single-literal-scope
    # design as platform-console (AUDIT-EXPORT-SCHEMA.md line 36-37).
    # Modeled as a real attribute (not hardcoded in the resource) so a
    # future second scope literal doesn't require a schema migration.
    attribute :scope, :string do
      allow_nil?(false)
      public?(true)
      default("audit:read")
      writable?(false)
    end

    attribute :created_by, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :expires_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :revoked_at, :utc_datetime_usec do
      public?(true)
      writable?(false)
    end

    # SPEC-16: first-use tombstone, stamped by the :use action (never
    # caller-writable), nil until first use.
    attribute :used_at, :utc_datetime_usec do
      public?(true)
      writable?(false)
    end

    # SPEC-16: atomic use counter, defaults to 0 at mint, incremented by
    # :use. Together with used_at this is the audit trail of consumption.
    attribute :use_count, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
      writable?(false)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  calculations do
    # Real derived state a consumer/UI checks before trusting a token is
    # usable -- not stored, computed from revoked_at/expires_at so it can
    # never drift from the two source-of-truth columns.
    calculate(
      :active?,
      :boolean,
      expr(is_nil(revoked_at) and (is_nil(expires_at) or expires_at > now()))
    )
  end
end
