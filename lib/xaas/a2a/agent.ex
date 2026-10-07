defmodule Xaas.A2a.Agent do
  @moduledoc """
  One A2A agent card (the `GET /.well-known/agent-card.json` surface ash_a2a's
  `AshA2A.Protocol.Plug` serves) as a queryable Ash projection. Field surface
  mirrors `AshA2A.Protocol.AgentCard`'s struct: `name` (identity), `url`,
  `version`, `description`, `skills` (the card's skill list), and
  `transport_bindings` (the card's `supportedInterfaces`).

  Same posture as `Xaas.Marketplace.Pack`: private ETS, card JSON is the
  store, this resource is the projection.
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.A2a,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  ets do
    private?(true)
  end

  attributes do
    attribute :name, :string do
      allow_nil?(false)
      public?(true)
      primary_key?(true)
      writable?(true)
    end

    attribute(:url, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, allow_nil?: false, public?: true)

    attribute(:version, :string,
      public?: true,
      description:
        "Card version. The v1 spec's own L1008 example omits `version` (the documented " <>
          "ash_a2a codec_gap), so this is optional; a served card always carries it."
    )

    attribute(:skills, {:array, :map},
      allow_nil?: false,
      default: [],
      public?: true,
      description: "The card's skills: %{\"id\" => .., \"name\" => .., \"tags\" => [..], ..}"
    )

    attribute(:transport_bindings, {:array, :map},
      allow_nil?: false,
      default: [],
      public?: true,
      description:
        "The card's `supportedInterfaces`: %{\"url\" => .., \"protocolBinding\" => .., " <>
          "\"protocolVersion\" => ..}"
    )

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_name, [:name], pre_check_with: Ash.DataLayer.Ets)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :url, :description, :version, :skills, :transport_bindings])
    end

    update :update do
      accept([:url, :description, :version, :skills, :transport_bindings])
      require_atomic?(false)
    end
  end

  # SPEC-31 deepening (lane W984l): get+list read queries over the existing
  # `:read` action. Deny-by-default floor (W982a/W983h precedent): reads stay
  # open (the catalog projection surface); create/update/destroy refuse
  # through any authorized path — all existing internal callers
  # (`Xaas.A2a.Catalog`) already pass `authorize?: false`.

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end
end
