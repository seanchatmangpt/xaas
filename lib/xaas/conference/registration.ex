defmodule Xaas.Conference.Registration do
  @moduledoc """
  One attendee registered for one session, with consequential `status`
  (`:registered`/`:cancelled`/`:attended`).
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Conference,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource, AshJsonApi.Resource]

  ets do
    private?(true)
  end

  graphql do
    type(:conference_registration)
  end

  json_api do
    type("conference_registration")

    routes do
      base("/conference/registrations")
      get(:read)
      index(:read)
      post(:create)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:attendee_id, :uuid, allow_nil?: false, public?: true)
    attribute(:session_id, :uuid, allow_nil?: false, public?: true)

    attribute :status, :atom do
      allow_nil?(false)
      public?(true)
      default(:registered)
      constraints(one_of: [:registered, :cancelled, :attended])
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_attendee_session, [:attendee_id, :session_id],
      pre_check_with: Ash.DataLayer.Ets
    )
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:attendee_id, :session_id, :status])
    end

    update :update do
      accept([:status])
      require_atomic?(false)
    end
  end
end
