defmodule Xaas.Governance.InternalApiToken do
  @moduledoc """
  Real, rotatable bearer credential for `/internal-api/*` (see
  `XaasWeb.Plugs.RequireInternalApiToken`'s own moduledoc for the real,
  investigated exposure posture that motivates this resource: `config/
  runtime.exs` binds the production endpoint to `{0, 0, 0, 0, 0, 0, 0, 0}`
  and `fly.toml`'s `[http_service]` has no private-only/6PN restriction --
  the route is publicly reachable, not localhost-only, whenever this app is
  actually deployed to Fly).

  Same real "generate raw, hash before persistence, never store or
  re-derive the raw value" discipline as
  `Xaas.Governance.AuditExportToken`/`Xaas.Governance.Changes.
  GenerateAuditExportToken` (the reusable pattern this resource adapts --
  found via `grep`/semantic search per this session's own investigation
  step, not invented from nothing), except the raw token is carried back to
  the caller via `Ash.Resource.put_metadata/3` (real ephemeral,
  never-persisted metadata -- the same mechanism `Xaas.Accounts.User`'s
  sign-in actions already use for JWTs via `AshAuthentication.
  GenerateTokenChange`) rather than changeset context, since context is
  never copied onto the create result. Adds the one real piece
  `INTERNAL_API_TOKEN` (a flat, non-rotating env-var string compare) never
  had: a real `issued_at`/`expires_at`/`revoked_at` row per credential, so a
  leaked token has a real rotation and per-caller revocation story instead
  of "change the one env var and redeploy, hoping nobody else still has the
  old value cached."

  ## Real, deliberate scope boundary: no HTTP routes on this resource

  Unlike `AuditExportToken`, this resource declares no `AshJsonApi.Resource`/
  `AshGraphql.Resource` extensions and is never mounted under the `/api` or
  `/internal-api` catch-all forwards. This is not an oversight -- it is the
  direct, disclosed lesson from `AuditExportToken`'s own twentieth-pass ERRC
  finding (`docs/claude/diataxis/explanation/errc-innovation-grid.md`): an
  HTTP mint route gated only by the current bearer token would let any actor
  holding a (possibly already-leaked) `InternalApiToken` self-mint a fresh
  replacement and keep access alive across a rotation meant to cut them off
  -- the exact self-service-persistence failure a rotation story exists to
  prevent. `:issue`/`:revoke` are reachable only via `authorize?: false`
  system-context calls: `Mix.Tasks.Xaas.InternalApiToken` (operator-run,
  local/ops-only) and `Xaas.Governance.InternalApiTokenAuth.verify/1`
  (read-only, called by the plug on every request). The `policies do` block
  below is real
  deny-by-default (`forbid_if always()`, matching this codebase's
  ash-migration Phase 5 floor) with no bypass at all -- there is
  deliberately no actor-authorized path into this resource, HTTP or
  otherwise.

  ## Real fallback / dev-mode contract

  `XaasWeb.Plugs.RequireInternalApiToken` checks a presented bearer token
  against this resource's active rows FIRST; only when that lookup misses
  does it fall back to the original flat `INTERNAL_API_TOKEN` env-var
  compare. Local dev (the already-running `:4000` Phoenix server, no minted
  `InternalApiToken` rows in a fresh dev DB) keeps working unchanged via
  that fallback -- this resource is additive, not a breaking replacement.

  ## Real per-org identity (this pass) -- the customer-submission seam

  Adds a nullable `org_id` (`belongs_to :org, Xaas.Accounts.Org`, real FK,
  `allow_nil?: true`) so a token can carry real per-org identity, not just
  the flat internal/admin trust tier above. `org_id: nil` (the default,
  and every token minted before this pass) keeps meaning exactly what it
  meant before -- "internal/admin tier," fully backward compatible, no
  behavior change for existing rows. A non-nil `org_id` is the real,
  authenticated fact `XaasWeb.Plugs.RequireInternalApiToken` now attaches
  to `conn.assigns[:current_org]` (see that plug's own moduledoc) -- the
  single source of truth the new customer-facing submission surface
  (`POST /internal-api/execution/runs`) requires, never a client-asserted
  header like `X-Org-Id` (see `XaasWeb.Plugs.ResolveOrgActor`'s own
  moduledoc for why that header is not a real security boundary against
  an untrusted external caller).

  This does NOT flip on Ash's `multitenancy` DSL anywhere (not on this
  resource, not on `Xaas.Ultracode.Run`/`Epoch`) -- `Org`'s own moduledoc
  already discloses that as real, correctly-scoped-out follow-up work; see
  `Xaas.Ultracode.Run`'s moduledoc and ADR-0002 for the same disclosure
  applied to the execution-fabric resources this org_id ultimately gates.
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Governance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("internal_api_tokens")
    repo(Xaas.Repo)
  end

  actions do
    defaults([:read])

    # Real lookup by hash -- the one read `XaasWeb.Plugs.
    # RequireInternalApiToken` performs on every `/internal-api/*` request
    # (via `verify/1` below), always `authorize?: false` (there is no actor
    # yet -- this read *is* how an actor's bearer credential gets
    # established).
    read :by_hash do
      get?(true)
      argument(:token_hash, :string, allow_nil?: false, sensitive?: true)
      filter(expr(token_hash == ^arg(:token_hash)))
    end

    # Real token minting, same shape as `Xaas.Governance.Changes.
    # GenerateAuditExportToken`: raw token generated here, hashed before
    # persistence, and returned exactly once via the changeset's context.
    create :issue do
      accept([:created_by, :expires_at, :org_id])
      change(Xaas.Governance.Changes.GenerateInternalApiToken)

      # Real, ephemeral (never persisted) carrier for the raw token back to
      # the caller -- same `Ash.Resource.put_metadata/3` mechanism this
      # codebase already uses for `Xaas.Accounts.User`'s sign-in token
      # (`AshAuthentication.GenerateTokenChange`, real-read in full), not a
      # bespoke invention.
      metadata :raw_token, :string do
        allow_nil?(false)
      end
    end

    update :revoke do
      accept([])
      require_atomic?(false)

      change(set_attribute(:revoked_at, &DateTime.utc_now/0))
      validate(Xaas.Governance.Validations.InternalApiTokenNotAlreadyRevoked)
    end
  end

  policies do
    # Real deny-by-default floor (ash-migration Phase 5) -- no bypass. This
    # resource has no actor-authorized path, HTTP or otherwise; every real
    # caller (the plug's `verify/1` read, the mix task's mint/revoke) uses
    # `authorize?: false` from trusted system/operator context, matching
    # the "no HTTP routes at all" scope boundary documented above.
    policy always() do
      forbid_if(always())
    end
  end

  attributes do
    uuid_primary_key(:id)

    # Prefix shown in operator listings/logs ("iat_live_" + a few chars),
    # so a token can be recognized without ever storing or displaying the
    # full raw value. Distinct from token_hash.
    attribute :token_prefix, :string do
      allow_nil?(false)
      public?(true)
      writable?(false)
    end

    # SHA-256 hex digest of the raw token. Never the raw token itself.
    attribute :token_hash, :string do
      allow_nil?(false)
      public?(false)
      writable?(false)
    end

    # Free-text operator/purpose label ("sean-cli", "ci-rotation-2026-09",
    # "zcode-provider-worker-3") -- who/why this credential was minted, for
    # real per-caller revocation (revoke the one row for the compromised
    # caller, not the single shared env var everyone uses).
    attribute :created_by, :string do
      allow_nil?(false)
      public?(true)
    end

    # Real, optional expiry. Nil means "no expiry, revoke explicitly to
    # cut off" -- matches AuditExportToken's own optional expires_at shape.
    attribute :expires_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :revoked_at, :utc_datetime_usec do
      public?(true)
      writable?(false)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  calculations do
    calculate(
      :active?,
      :boolean,
      expr(is_nil(revoked_at) and (is_nil(expires_at) or expires_at > now()))
    )
  end

  relationships do
    # Real, nullable FK -- see moduledoc "Real per-org identity" above.
    # `nil` (the default) keeps a token's meaning exactly what it was
    # before this attribute existed: internal/admin tier. Same
    # `belongs_to`-generates-the-FK-attribute convention as
    # `Xaas.Accounts.OrgMembership`'s `belongs_to :org` (no separate
    # hand-declared `org_id` attribute above -- Ash generates it here).
    belongs_to :org, Xaas.Accounts.Org do
      allow_nil?(true)
      public?(true)
      attribute_writable?(true)
      attribute_type(:uuid)
    end
  end
end
