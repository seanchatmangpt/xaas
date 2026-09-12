defmodule Xaas.Library.HoldRequest do
  @moduledoc """
  Ash resource for Hold Requests on library books, grounded in Schema.org (schema:ReserveAction) and PROV (prov:Activity).

  Lifecycle: a hold is placed when a book has zero available copies (queueing the reader
  behind any other active holds), fulfilled when a copy becomes available and is handed to
  the reader (decrementing the book's available copies the same way a checkout does), cancelled
  by the reader/librarian before fulfillment, or expired automatically after `hold_expires_after_days`
  (see `Xaas.Library.Config`) days of remaining active/unfulfilled.
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshOban]

  require Ash.Query

  @hold_expires_after_days 7

  postgres do
    table "library_holds"
    repo Xaas.Repo
  end

  pub_sub do
    module XaasWeb.Endpoint
    prefix "holds"
    broadcast_type :notification

    publish :create, ["created"]
    publish :place, ["created"]
    publish :update, ["updated", :id]
    publish :fulfill, ["updated", :id]
    publish :fulfill, ["fulfilled", :id]
    publish :cancel, ["updated", :id]
    publish :cancel, ["cancelled", :id]
    publish :expire, ["updated", :id]
    publish :expire, ["expired", :id]
  end

  # Real AshOban trigger for the `expires_at`-driven hold-expiry semantic
  # above (`:expire` action, `:expirable` read) -- confirmed via grep that
  # ash_oban/oban were real deps with zero resources wired to
  # AshOban.Resource before Xaas.Operations.CapabilityLivenessReceipt's
  # `check_regressions` schedule; this resource had the same gap: a real
  # `:expire`/`:expirable` lifecycle with no scheduled trigger ever calling
  # it, i.e. dead code reachable only by manual invocation. `expire_stale`
  # is a generic action (bulk-reads `:expirable`, calls `:expire` on each)
  # because AshOban scheduled_actions run a single parameterless action,
  # not an update keyed to one record.
  oban do
    scheduled_actions do
      schedule :expire_stale_holds, "0 * * * *" do
        action :expire_stale
        worker_module_name Xaas.Library.HoldRequest.Workers.ExpireStaleHolds
      end
    end
  end

  json_api do
    type "library_hold"

    routes do
      base "/library/holds"
      get :read
      index :read
    end
  end

  graphql do
    type :library_hold
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:book_id, :user_id, :school_id, :position, :status, :expires_at]
    end

    update :update do
      primary? true
      accept [:position, :status]
    end

    create :place do
      description "Places a hold for a reader on a book, queueing behind any other active holds"
      accept [:book_id, :user_id, :school_id]

      change fn changeset, _context ->
        book_id = Ash.Changeset.get_attribute(changeset, :book_id)

        next_position =
          __MODULE__
          |> Ash.Query.for_read(:read)
          |> Ash.Query.filter(book_id == ^book_id and status == :active)
          |> Ash.count!(authorize?: false)
          |> Kernel.+(1)

        expires_at = DateTime.add(DateTime.utc_now(), @hold_expires_after_days * 86_400, :second)

        changeset
        |> Ash.Changeset.force_change_attribute(:position, next_position)
        |> Ash.Changeset.force_change_attribute(:status, :active)
        |> Ash.Changeset.force_change_attribute(:expires_at, expires_at)
      end
    end

    update :fulfill do
      description "Fulfills an active hold when a copy becomes available, decrementing book inventory"
      accept []
      require_atomic? false

      validate compare(:status, is_equal: {:value, :active}),
        message: "Only active holds can be fulfilled"

      change set_attribute(:status, :fulfilled)
      change set_attribute(:fulfilled_at, &DateTime.utc_now/0)

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn _changeset, hold ->
          case Xaas.Library.Book |> Ash.get(hold.book_id, authorize?: false) do
            {:ok, book} ->
              case book
                   |> Ash.Changeset.for_update(:borrow_copy, %{})
                   |> Ash.update(authorize?: false) do
                {:ok, _book} ->
                  {:ok, hold}

                {:error, error} ->
                  {:error, error}
              end

            {:error, error} ->
              {:error, error}
          end
        end)
      end
    end

    update :cancel do
      description "Cancels an active hold before it is fulfilled"
      accept []
      require_atomic? false

      # Unused by this action's own logic, but required so this action can
      # serve as an Ash.Reactor `undo_action` for `create :create_hold` in
      # Xaas.Library.Reactors.CirculationBorrowReactor -- Ash.Reactor's
      # CreateStep.undo/4 always calls the undo action with a single
      # `%{changeset: ...}` argument (deps/ash/lib/ash/reactor/steps/
      # create_step.ex), and its DSL verifier
      # (Ash.Reactor.Dsl.Create.verify_action_takes_changeset/3) rejects any
      # undo_action whose `arguments` list isn't exactly `[%{name: :changeset}]`.
      argument :changeset, :term, allow_nil?: true

      validate compare(:status, is_equal: {:value, :active}),
        message: "Only active holds can be cancelled"

      change set_attribute(:status, :cancelled)
      change set_attribute(:cancelled_at, &DateTime.utc_now/0)
    end

    update :expire do
      description "Expires an active hold whose expires_at has passed"
      accept []
      require_atomic? false

      validate compare(:status, is_equal: {:value, :active}),
        message: "Only active holds can be expired"

      change set_attribute(:status, :expired)
    end

    read :for_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
    end

    read :for_book do
      argument :book_id, :uuid, allow_nil?: false
      filter expr(book_id == ^arg(:book_id))
    end

    read :oldest_active_for_book do
      description "Oldest active hold for a book, for queue-position lookups"
      argument :book_id, :uuid, allow_nil?: false
      get? true
      filter expr(book_id == ^arg(:book_id) and status == :active)
      prepare build(sort: [inserted_at: :asc])
    end

    read :active do
      filter expr(status == :active)
    end

    read :expirable do
      description "Active holds whose expiration time has passed"
      filter expr(status == :active and not is_nil(expires_at) and expires_at <= now())
    end

    action :expire_stale, :map do
      description "Scheduled Oban entry point: expires every active hold past its expires_at"

      run fn _input, _context ->
        expired_count =
          __MODULE__
          |> Ash.Query.for_read(:expirable, %{}, authorize?: false)
          |> Ash.read!(authorize?: false)
          |> Enum.map(fn hold ->
            hold
            |> Ash.Changeset.for_update(:expire, %{}, authorize?: false)
            |> Ash.update!(authorize?: false)
          end)
          |> length()

        {:ok, %{expired_count: expired_count}}
      end
    end
  end

  policies do
    # Real, scoped carve-out for the scheduled expiry entry point -- runs
    # with authorize?: false internally already; this bypass covers the
    # action-level policy check AshOban's worker performs before running it.
    bypass action(:expire_stale) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    # Deny-by-default floor (CLAUDE.md): matches Checkout/Book's sibling
    # policy blocks -- writes require a real actor, not the prior ambient
    # `authorize_if always()`, which permitted `actor: nil` on
    # :place/:update/:cancel/:fulfill/:destroy alike.
    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :school_id, :string do
      allow_nil? false
      default "willow-creek"
      public? true
    end

    attribute :position, :integer do
      allow_nil? false
      default 1
      public? true
    end

    attribute :status, :atom do
      constraints [one_of: [:active, :fulfilled, :cancelled, :expired]]
      default :active
      allow_nil? false
      public? true
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil? true
      public? true
    end

    attribute :fulfilled_at, :utc_datetime_usec do
      allow_nil? true
      public? true
    end

    attribute :cancelled_at, :utc_datetime_usec do
      allow_nil? true
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
