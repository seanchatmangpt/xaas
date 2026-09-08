defmodule Xaas.Library.Checkout do
  @moduledoc """
  Ash resource for Book Checkouts, grounded in Schema.org (schema:BorrowAction) and PROV (prov:Activity).
  Tracks circulation transactions of books borrowed by readers.
  """
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "library_checkouts"
    repo Xaas.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:book_id, :user_id, :borrowed_at, :returned_at, :status]
    end

    update :update do
      primary? true
      accept [:returned_at, :status]
    end

    read :for_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
    end
  end

  policies do
    bypass always() do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :borrowed_at, :utc_datetime_usec do
      allow_nil? false
      default &DateTime.utc_now/0
      public? true
    end

    attribute :returned_at, :utc_datetime_usec do
      allow_nil? true
      public? true
    end

    attribute :status, :atom do
      constraints [one_of: [:borrowed, :returned, :overdue]]
      default :borrowed
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :book, Xaas.Library.Book do
      allow_nil? false
      attribute_writable? true
      public? true
    end

    belongs_to :user, Xaas.Accounts.User do
      allow_nil? false
      attribute_writable? true
      public? true
    end
  end
end
