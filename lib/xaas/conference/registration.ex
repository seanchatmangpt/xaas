defmodule Xaas.Conference.Registration do
  @moduledoc """
  One attendee registered for one session, with consequential `status`
  (`:registered`/`:cancelled`/`:attended`).
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Conference,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  ets do
    private?(true)
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

  # W981s/W983a: the `:unique_attendee_session` identity is intentionally
  # ABSENT. ash 3.34.4's RequirePreCheckWith verifier demands `pre_check_with`
  # on any ETS identity (strict-compile breaker if omitted), but the
  # pre-check path (`Ash.Changeset.do_validate_identity/3`) filters only on
  # the identity keys and ignores the identity's `where` scope (measured:
  # where+pre_check_with → cancelled re-register refused "has already been
  # taken" → enrollment court 2/5). Neither identity shape can express the
  # scoped contract at this ash version, so active-duplicate enforcement
  # lives entirely in EnforceActiveRegistrationIdentity on :create below.

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:attendee_id, :session_id, :status])
      change(Xaas.Conference.Changes.ResolveRegistrationRefs)

      # W981s: ETS enforces no identity constraint at plain-create time
      # without `pre_check_with`, and the unscoped pre-check would ignore the
      # identity's `where` scope — active-duplicate enforcement is explicit.
      change(Xaas.Conference.Changes.EnforceActiveRegistrationIdentity)
      change(Xaas.Conference.Changes.EnforceSessionCapacity)
    end

    update :update do
      accept([:status])
      require_atomic?(false)
      validate(Xaas.Conference.Validations.RegistrationStatusTransition)
    end

    # W947 / W893 GAP(NoServerActionForCancel): named cancel action so callers
    # do not reach for the bare `:update`. The W795 forward-only transition
    # validation on the shared guard covers this action too.
    # W973b terminal guard: `:cancel` is a product action, not an artifacts
    # sync, so the self-transition carve-out (which exists for artifacts-only
    # `:update`s) must not admit cancel-of-terminal. The legal walk is
    # unaffected: re-register after cancel goes through `:create` (W981s
    # scoped identity), and cancelled→attended stays a legal `:update` edge.
    update :cancel do
      accept([])
      require_atomic?(false)
      validate(Xaas.Conference.Validations.RegistrationTerminalCancelGuard)
      validate(Xaas.Conference.Validations.RegistrationStatusTransition)
      change(fn changeset, _ctx ->
        Ash.Changeset.force_change_attribute(changeset, :status, :cancelled)
      end)
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

defmodule Xaas.Conference.Validations.RegistrationTerminalCancelGuard do
  @moduledoc """
  W973b terminal guard on `Xaas.Conference.Registration.:cancel`.

  `:cancel` is an explicit product action, so the self-transition carve-out
  that exists for artifacts-only `:update`s does not apply here: cancelling
  an already-terminal registration (`:cancelled` or `:attended`) is refused
  with a typed `Ash.Error.Changes.InvalidChanges`. Re-registering after a
  cancel is a `:create` (W981s scoped identity) and remains legal;
  cancelled->attended stays a legal `:update` edge.
  """

  use Ash.Resource.Validation

  @terminal_statuses [:cancelled, :attended]

  def terminal_statuses, do: @terminal_statuses

  @impl true
  def validate(changeset, _opts, _context) do
    current = Ash.Changeset.get_data(changeset, :status)

    if current in @terminal_statuses do
      {:error,
       Ash.Error.Changes.InvalidChanges.exception(
         message:
           "cannot cancel a terminal registration: status #{inspect(current)} is terminal " <>
             "and the :cancel action admits no self-transition (re-register via :create instead)"
       )}
    else
      :ok
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

defmodule Xaas.Conference.Changes.EnforceActiveRegistrationIdentity do
  @moduledoc """
  W981s: scoped active-duplicate enforcement on `Xaas.Conference.Registration`
  :create, companion to the `where`-scoped `:unique_attendee_session` identity.

  Boundary (measured in W981s against ash 3.34.4): the ETS `pre_check_with`
  path — `Ash.Changeset.do_validate_identity/3` — filters only on the identity
  keys and does not apply the identity's `where` scope, so the unscoped
  pre-check alone would permanently refuse any cancelled attendee's
  re-registration (the W969e step-6 gap). ETS enforces no constraint at
  plain-create time, so the true scoped rule is explicit here: refuse an
  ACTIVE (`:registered`/`:attended`) same-(attendee, session) row with the
  same error class the pre-check produced
  (`fields: [:attendee_id, :session_id], message: "has already been taken"`).

  Falsifier: dropping this change from :create (or widening its filter to all
  statuses) re-opens W969e step 6 or admits an active double-book — the
  enrollment journey court documents this.
  """

  use Ash.Resource.Change

  @active_statuses [:registered, :attended]

  def active_statuses, do: @active_statuses

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      attendee_id =
        Ash.Changeset.get_argument(changeset, :attendee_id) ||
          Ash.Changeset.get_attribute(changeset, :attendee_id)

      session_id =
        Ash.Changeset.get_argument(changeset, :session_id) ||
          Ash.Changeset.get_attribute(changeset, :session_id)

      duplicate =
        attendee_id && session_id &&
          Xaas.Conference.Registration
          |> Ash.Query.filter(
            attendee_id == ^attendee_id and session_id == ^session_id and
              status in @active_statuses
          )
          |> Ash.read!(authorize?: false)
          |> Enum.any?()

      if duplicate do
        Ash.Changeset.add_error(
          changeset,
          Ash.Error.Changes.InvalidAttribute.exception(
            field: :attendee_id,
            message: "has already been taken"
          )
        )
      else
        changeset
      end
    end)
  end
end
