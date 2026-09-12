defmodule Xaas.Library.PersonaGrant do
  @moduledoc """
  Real, deny-by-default authorization record binding an authenticated A2A/MCP
  *caller* credential identity to the `Xaas.Accounts.User` id it is allowed
  to act as ("persona").

  ## Why this exists

  `XaasWeb.A2A.NextReadUserAgent.resolve_actor/1` previously accepted a bare,
  self-asserted `as:<user_id>` claim and loaded that `User` with no check
  that the calling credential (the shared `INTERNAL_API_TOKEN` bearer token
  validated by `XaasWeb.Plugs.RequireInternalApiToken` upstream) was actually
  authorized to act as that user -- any holder of the token could impersonate
  any user id it could guess or enumerate. This resource is the real,
  queryable grant record that closes that gap: a caller may only assert a
  given `user_id` if an active (non-revoked) `PersonaGrant` row exists
  binding that `caller_id` to that `user_id`.

  `caller_id` is, for now, always the literal string `"internal_api_token"`
  -- the only caller identity this repo's A2A/MCP surface actually
  authenticates on that path (there is exactly one shared bearer token, not
  per-caller credentials). A future multi-tenant/per-caller credential system
  would widen this to a real per-caller identity without changing this
  resource's shape.

  ## Deny-by-default policy

  Mirrors `Xaas.Operations.AuditLogEntry`'s own bypass-only-on-`:read`-type
  pattern: every action is forbidden by the catch-all `policy always() do
  forbid_if always() end` unless explicitly bypassed. `:grant` and `:revoke`
  require a real, resolved actor (`actor_present()`) -- there is no separate
  admin-role concept anywhere in `Xaas.Accounts.User` yet (confirmed by a
  real grep before writing this policy), so "an authenticated actor is
  present" is the strongest admin check this codebase can express today;
  widening this to a real role-based check is a separate concern outside
  this cycle's scope. `:list_active` has no bypass at all -- it is only ever
  called internally with `authorize?: false` from
  `NextReadUserAgent.resolve_actor/2`, exactly like `Config.default_school/0`
  and other internal-only reads elsewhere in this domain. `:read` is
  bypassed for authenticated actors (admin/audit tooling).
  """

  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "library_persona_grants"
    repo Xaas.Repo

    identity_wheres_to_sql active_caller_user: "revoked_at IS NULL"
  end

  actions do
    defaults [:read]

    create :grant do
      description "Grants a caller credential permission to act as a given user persona"
      accept [:caller_id, :user_id, :granted_by]
      change set_attribute(:granted_at, &DateTime.utc_now/0)
    end

    update :revoke do
      description "Revokes a previously granted persona binding"
      accept []
      require_atomic? false
      change set_attribute(:revoked_at, &DateTime.utc_now/0)
    end

    read :list_active do
      description "Active (non-revoked) grants for a given caller+user pair -- internal use only, always called with authorize?: false"
      argument :caller_id, :string, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false
      filter expr(caller_id == ^arg(:caller_id) and user_id == ^arg(:user_id) and is_nil(revoked_at))
    end
  end

  code_interface do
    define :grant, args: [:caller_id, :user_id, :granted_by]
    define :revoke
    define :read
    define :active_for, action: :list_active, args: [:caller_id, :user_id]
  end

  policies do
    bypass action_type(:read) do
      authorize_if always()
    end

    policy action([:grant, :revoke]) do
      # No admin-role concept exists on Xaas.Accounts.User yet (real grep
      # confirmed before writing this) -- actor_present() is the strongest
      # "authenticated admin" check this codebase can express today.
      authorize_if actor_present()
    end

    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :caller_id, :string do
      allow_nil? false
      public? true
    end

    attribute :granted_by, :string do
      allow_nil? true
      public? true
    end

    attribute :granted_at, :utc_datetime_usec do
      allow_nil? false
      default &DateTime.utc_now/0
      public? true
    end

    attribute :revoked_at, :utc_datetime_usec do
      allow_nil? true
      public? true
    end
  end

  relationships do
    belongs_to :user, Xaas.Accounts.User do
      allow_nil? false
      attribute_writable? true
      public? true
    end
  end

  identities do
    identity :active_caller_user, [:caller_id, :user_id] do
      where expr(is_nil(revoked_at))
    end
  end
end
