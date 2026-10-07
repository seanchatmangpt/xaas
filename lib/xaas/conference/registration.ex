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
      change(Xaas.Conference.Changes.ResolveRegistrationRefs)
      change(Xaas.Conference.Changes.EnforceSessionCapacity)
    end

    update :update do
      accept([:status])
      require_atomic?(false)
      validate(Xaas.Conference.Validations.RegistrationStatusTransition)
    end
  end
end

defmodule Xaas.Conference.Validations.RegistrationStatusTransition do
  @moduledoc """
  Forward-only transition guard on `Xaas.Conference.Registration.:update`,
  closing W715's `UNSUPPORTED(transition-guard)` gap in the W772/W740 idiom
  (mirror: `Xaas.A2a.Validations.ForwardOnlyTransition`).

  Lifecycle semantics: `:registered` is the open state, `:attended` is
  terminal (attended work cannot "un-happen"), `:cancelled` may be re-opened
  to `:attended` (cancelled attendee shows up anyway) but not back to
  `:registered`. Allowed non-self edges:

      {:registered, :cancelled}
      {:registered, :attended}
      {:cancelled, :attended}

  Self-transitions `{s, s}` are always allowed (artifacts-only updates must
  not be refused).
  """

  use Ash.Resource.Validation

  @forward_edges [
    {:registered, :cancelled},
    {:registered, :attended},
    {:cancelled, :attended}
  ]

  def forward_edges, do: @forward_edges

  @impl true
  def validate(changeset, _opts, _context) do
    current = Ash.Changeset.get_data(changeset, :status)
    new = Ash.Changeset.get_attribute(changeset, :status)

    if {current, new} in @forward_edges or current == new do
      :ok
    else
      {:error,
       Ash.Error.Changes.InvalidChanges.exception(
         message:
           "registration status transition #{inspect(current)} -> #{inspect(new)} is not an " <>
             "admitted forward edge (allowed: #{inspect(@forward_edges)} plus self-transitions)"
       )}
    end
  end
end

defmodule Xaas.Conference.Changes.ResolveRegistrationRefs do
  @moduledoc """
  Referential integrity on `Xaas.Conference.Registration` create, closing
  W715's `UNSUPPORTED(referential-integrity)` gap: real `Ash.get!`-style
  resolution of `attendee_id` and `session_id` against the Ets-backed
  Attendee/Session tables — a dangling id is refused with typed
  `Ash.Error.Changes.InvalidChanges` and nothing is written.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      Enum.reduce([:attendee_id, :session_id], changeset, fn ref, changeset ->
        id = Ash.Changeset.get_argument(changeset, ref) || Ash.Changeset.get_attribute(changeset, ref)

        resource = ref_resource(ref)

        case id && Ash.get(resource, id, authorize?: false) do
          {:ok, %{} = _row} ->
            changeset

          _ ->
            Ash.Changeset.add_error(
              changeset,
              Ash.Error.Changes.InvalidChanges.exception(
                message:
                  "#{ref} #{inspect(id)} does not resolve to a real #{inspect(resource)} row"
              )
            )
        end
      end)
    end)
  end

  defp ref_resource(:attendee_id), do: Xaas.Conference.Attendee
  defp ref_resource(:session_id), do: Xaas.Conference.Session
end

defmodule Xaas.Conference.Changes.EnforceSessionCapacity do
  @moduledoc """
  Capacity ceiling on `Xaas.Conference.Registration` create, closing W715's
  `UNSUPPORTED(capacity-invariant)` gap: counts existing registrations for the
  target session in an ACTIVE status (`:registered`/`:attended` per W795's
  forward-only transition set — `:cancelled` is terminal and frees its slot,
  closing W893's `GAP(CancelDoesNotReleaseSlot)`) and refuses the write when
  the session's
  `capacity` is set and already full. `capacity == nil` means unlimited —
  backward compatible with pre-capacity seeds.
  """

  use Ash.Resource.Change

  @active_statuses [:registered, :attended]

  def active_statuses, do: @active_statuses

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      session_id = Ash.Changeset.get_argument(changeset, :session_id) || Ash.Changeset.get_attribute(changeset, :session_id)
      session = session_id && Ash.get!(Xaas.Conference.Session, session_id, authorize?: false)

      case session && session.capacity do
        nil ->
          changeset

        capacity ->
          taken =
            Xaas.Conference.Registration
            |> Ash.Query.filter(session_id == ^session_id and status in @active_statuses)
            |> Ash.read!(authorize?: false)
            |> length()

          if taken >= capacity do
            Ash.Changeset.add_error(
              changeset,
              Ash.Error.Changes.InvalidChanges.exception(
                message:
                  "session #{inspect(session_id)} is at capacity (#{taken}/#{capacity} taken); " <>
                    "registration refused"
              )
            )
          else
            changeset
          end
      end
    end)
  end
end
