defmodule Xaas.Sa2a.Execution do
  @moduledoc """
  Durable record of one SA2A `sa2a_execute` DO (generated `EdgeCatalog` edge 40,
  `do_boundary?: true`), reachable ONLY through `Xaas.Actuation.run/4`.

  The `:execute` create action is the admitted Ash half of the edge:

    * `Xaas.Actuation.Validations.ReactorContext` -- a direct `Ash.create/2` (even with
      `authorize?: false`) fails closed; the action needs the live intent/receipt context
      `Xaas.Actuation.Reactor` manufactures.
    * the policy admits exactly one actor: a `Xaas.SystemAuthority` holding the scoped
      `:sa2a_executor` capability (`Xaas.Checks.SystemActor`'s exact-subject map).
      Every other capability (`:webhook_dispatcher`, `:ultracode_reactor`, ...) and
      every non-system actor is denied by the deny-by-default floor with
      `Ash.Error.Forbidden`.
    * `Xaas.Sa2a.Changes.Execute` re-runs `Xaas.Sa2a.Court` (allowlisted query, reproducible
      admit receipt, reproducible bound plan hash, idempotency key =
      `sha256(work_order_digest|query|plan_hash)`), performs the port DO, enforces the
      `llm_avoidance_ratio` floor, builds a replayable manifest and runs
      `Bridge.replay(manifest, hash)` automatically. A violated condition is a typed
      `Xaas.Actuation.Refusal`: the changeset is invalid, no `Execution` row is written
      (rolled back) and the actuation intent/receipt are sealed `:refused`.

  No route, GraphQL or RPC surface exposes this resource.
  """

  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Operations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("sa2a_executions")
    repo(Xaas.Repo)
  end

  actions do
    defaults([:read])

    create :execute do
      public?(false)
      accept([:work_order_id, :work_order_digest, :query])

      argument(:compiled_rules, {:array, {:array, :string}}, allow_nil?: true)
      argument(:admit, :map, allow_nil?: true)
      argument(:plan, :map, allow_nil?: true)
      argument(:expected_manifest_hash, :string, allow_nil?: true)

      validate(Xaas.Actuation.Validations.ReactorContext)
      change(Xaas.Sa2a.Changes.Execute)
    end
  end

  policies do
    # The scoped machine capability -- a real system-authority predicate, not always().
    bypass action(:execute) do
      authorize_if({Xaas.Checks.SystemActor, []})
    end

    policy always() do
      forbid_if(always())
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :work_order_id, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :work_order_digest, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :query, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute(:plan_hash, :string, allow_nil?: false, public?: true)
    attribute(:idempotency_key, :string, allow_nil?: false, public?: true)
    attribute(:class_id, :string, allow_nil?: false, public?: true)
    attribute(:admit_receipt_id, :string, public?: true)
    attribute(:admit_candidate_hash, :string, allow_nil?: false, public?: true)
    attribute(:capability, :string, allow_nil?: false, public?: true)
    attribute(:result, :string, allow_nil?: false, public?: true)
    attribute(:llm_avoidance_ratio, :float, allow_nil?: false, public?: true)
    attribute(:manifest, :map, allow_nil?: false, public?: true)
    attribute(:manifest_hash, :string, allow_nil?: false, public?: true)
    attribute(:replay_verified, :boolean, allow_nil?: false, default: false, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_idempotency_key, [:idempotency_key])
  end
end
