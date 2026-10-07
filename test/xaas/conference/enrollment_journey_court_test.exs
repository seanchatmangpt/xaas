defmodule Xaas.Conference.EnrollmentJourneyCourtTest do
  @moduledoc """
  W893 — LiveView-level enrollment court (Ash-level journey, since no
  conference LiveView exists in `lib/xaas_web/live/`: the flow is API/Ash-only).

  Chicago-style: the full registration journey over real Ash actions on real
  `Ash.DataLayer.Ets` tables — event → track → session (capacity set) →
  attendee → registration (refs resolved per W795's guard) → capacity
  exhaustion on the next registration → cancel → the slot is RELEASED
  (W925 fix for W893's `GAP(CancelDoesNotReleaseSlot)`): re-registering the
  same attendee SUCCEEDS. Asserts real rows end-to-end. No mocks.

  Slot-release semantics (read from
  `Xaas.Conference.Changes.EnforceSessionCapacity`): the capacity check
  counts only registrations in an ACTIVE status (`:registered`/`:attended`
  per W795's forward-only transition set); `:cancelled` is terminal and
  frees its slot. Mutation rationale: drop the `status in @active_statuses`
  filter from the capacity count and the re-register assert
  (`assert %Registration{} = re_reg`) fails — the create raises
  `Ash.Error.Invalid` "at capacity (1/1 taken)" instead.
  """
  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Conference.{Attendee, Event, Registration, Session, Speaker, Track}

  setup do
    wipe()
    :ok
  end

  defp wipe do
    for res <- [Registration, Session, Track, Speaker, Attendee, Event] do
      res
      |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
    end
  end

  defp utc(dt), do: dt |> DateTime.truncate(:second) |> DateTime.shift_zone!("Etc/UTC")

  test "full enrollment journey: seed → enroll → capacity refusal → cancel → slot released → re-register succeeds" do
    # --- event ---
    event =
      Ash.create!(
        Ash.Changeset.for_create(Event, :create, %{
          name: "AGNTCon+MCPCon 2026",
          slug: "agntcon-w893",
          location: "San Francisco",
          starts_at: utc(~U[2026-11-04 09:00:00Z]),
          ends_at: utc(~U[2026-11-06 18:00:00Z])
        }),
        authorize?: false
      )

    assert %Event{id: event_id} = event
    assert Ash.get!(Event, event_id, authorize?: false).slug == "agntcon-w893"

    # --- track ---
    track =
      Ash.create!(
        Ash.Changeset.for_create(Track, :create, %{
          name: "Evaluations & Courts",
          slug: "evals-courts-w893",
          description: "Courts all the way down",
          event_id: event_id
        }),
        authorize?: false
      )

    assert %Track{id: track_id} = track
    assert track.event_id == event_id

    # --- speaker (session requires one) ---
    speaker =
      Ash.create!(
        Ash.Changeset.for_create(Xaas.Conference.Speaker, :create, %{
          name: "Sean Chatman",
          slug: "sean-chatman-w893",
          bio: "Chief Scientist, xaas"
        }),
        authorize?: false
      )

    assert %Xaas.Conference.Speaker{id: speaker_id} = speaker

    # --- session with capacity 1 ---
    session =
      Ash.create!(
        Ash.Changeset.for_create(Session, :create, %{
          title: "Enrollment Journey Court",
          slug: "enrollment-journey-w893",
          description: "W893 pinned session",
          track_id: track_id,
          speaker_id: speaker_id,
          starts_at: utc(~U[2026-11-04 10:00:00Z]),
          ends_at: utc(~U[2026-11-04 11:00:00Z]),
          capacity: 1
        }),
        authorize?: false
      )

    assert %Session{id: session_id, capacity: 1} = session

    # --- attendee ---
    attendee =
      Ash.create!(
        Ash.Changeset.for_create(Attendee, :create, %{
          name: "Ada Lovelace",
          email: "ada-w893@example.test",
          affiliation: "Analytical Engine Co"
        }),
        authorize?: false
      )

    assert %Attendee{id: attendee_id} = attendee

    # --- registration: refs resolve, row lands as :registered ---
    reg =
      Ash.create!(
        Ash.Changeset.for_create(Registration, :create, %{
          attendee_id: attendee_id,
          session_id: session_id
        }),
        authorize?: false
      )

    assert %Registration{} = reg
    assert reg.status == :registered
    assert reg.attendee_id == attendee_id
    assert reg.session_id == session_id
    assert Ash.get!(Registration, reg.id, authorize?: false).status == :registered

    # --- capacity exhaustion: second registration refused, nothing written ---
    other =
      Ash.create!(
        Ash.Changeset.for_create(Attendee, :create, %{
          name: "Grace Hopper",
          email: "grace-w893@example.test",
          affiliation: "Navy"
        }),
        authorize?: false
      )

    assert_raise Ash.Error.Invalid,
                 ~r/at capacity \(1\/1 taken\)/,
                 fn ->
                   Ash.create!(
                     Ash.Changeset.for_create(Registration, :create, %{
                       attendee_id: other.id,
                       session_id: session_id
                     }),
                     authorize?: false
                   )
                 end

    assert length(
             Registration
             |> Ash.Query.filter(session_id == ^session_id)
             |> Ash.read!(authorize?: false)
           ) == 1

    # --- cancel: registered -> cancelled is an admitted forward edge ---
    cancelled =
      Ash.update!(
        Ash.Changeset.for_update(reg, :cancel, %{}),
        authorize?: false
      )

    assert cancelled.status == :cancelled
    assert Ash.get!(Registration, reg.id, authorize?: false).status == :cancelled

    # --- W925 slot-release court: capacity counts only ACTIVE statuses
    #     (:registered/:attended), so a cancelled registration frees its
    #     slot and a new registration is admitted ---
    re_reg =
      Ash.create!(
        Ash.Changeset.for_create(Registration, :create, %{
          attendee_id: other.id,
          session_id: session_id
        }),
        authorize?: false
      )

    assert %Registration{} = re_reg
    assert re_reg.status == :registered
    assert Ash.get!(Registration, re_reg.id, authorize?: false).status == :registered

    # --- unregistered third attendee on an unlimited session succeeds
    #     (capacity: nil path is backward compatible) ---
    open_session =
      Ash.create!(
        Ash.Changeset.for_create(Session, :create, %{
          title: "Open Keynote",
          slug: "open-keynote-w893",
          track_id: track_id,
          speaker_id: speaker_id,
          capacity: nil
        }),
        authorize?: false
      )

    open_reg =
      Ash.create!(
        Ash.Changeset.for_create(Registration, :create, %{
          attendee_id: other.id,
          session_id: open_session.id
        }),
        authorize?: false
      )

    assert open_reg.status == :registered
  end

  defp seed_session_with_attendee(slug) do
    event =
      Ash.create!(
        Ash.Changeset.for_create(Event, :create, %{
          name: "AGNTCon+MCPCon 2026 W973b",
          slug: "agntcon-#{slug}",
          location: "San Francisco",
          starts_at: utc(~U[2026-11-04 09:00:00Z]),
          ends_at: utc(~U[2026-11-06 18:00:00Z])
        }),
        authorize?: false
      )

    track =
      Ash.create!(
        Ash.Changeset.for_create(Track, :create, %{
          name: "Evaluations & Courts",
          slug: "evals-#{slug}",
          description: "Courts all the way down",
          event_id: event.id
        }),
        authorize?: false
      )

    speaker =
      Ash.create!(
        Ash.Changeset.for_create(Speaker, :create, %{
          name: "Sean Chatman",
          slug: "sean-chatman-#{slug}",
          bio: "Chief Scientist, xaas"
        }),
        authorize?: false
      )

    session =
      Ash.create!(
        Ash.Changeset.for_create(Session, :create, %{
          title: "Slot Release Cycle Court",
          slug: "slot-cycle-#{slug}",
          description: "W973b pinned session",
          track_id: track.id,
          speaker_id: speaker.id,
          starts_at: utc(~U[2026-11-04 10:00:00Z]),
          ends_at: utc(~U[2026-11-04 11:00:00Z]),
          capacity: 1
        }),
        authorize?: false
      )

    attendee =
      Ash.create!(
        Ash.Changeset.for_create(Attendee, :create, %{
          name: "Ada Lovelace",
          email: "ada-#{slug}@example.test",
          affiliation: "Analytical Engine Co"
        }),
        authorize?: false
      )

    {session, attendee}
  end

  defp register(attendee_id, session_id) do
    Ash.create!(
      Ash.Changeset.for_create(Registration, :create, %{
        attendee_id: attendee_id,
        session_id: session_id
      }),
      authorize?: false
    )
  end

  test "W973b journey: register → cancel → re-register → cancel → re-register (slot released repeatedly)" do
    {session, attendee} = seed_session_with_attendee("w973b-cycle")

    # --- leg 1: register ---
    reg1 = register(attendee.id, session.id)
    assert reg1.status == :registered

    # --- leg 2: cancel via the named W947 :cancel action ---
    cancelled1 =
      Ash.update!(Ash.Changeset.for_update(reg1, :cancel, %{}), authorize?: false)

    assert cancelled1.status == :cancelled
    assert Ash.get!(Registration, reg1.id, authorize?: false).status == :cancelled

    # --- leg 3: W925 slot release witnessed through the named action path ---
    re_reg1 = register(attendee.id, session.id)
    assert re_reg1.status == :registered
    assert re_reg1.id != reg1.id

    # --- leg 4: cancel again ---
    cancelled2 =
      Ash.update!(Ash.Changeset.for_update(re_reg1, :cancel, %{}), authorize?: false)

    assert cancelled2.status == :cancelled
    assert Ash.get!(Registration, re_reg1.id, authorize?: false).status == :cancelled

    # --- leg 5: slot released a second time ---
    re_reg2 = register(attendee.id, session.id)
    assert re_reg2.status == :registered
    assert re_reg2.id != re_reg1.id

    # --- determinism of the end state: exactly one ACTIVE registration ---
    active =
      Registration
      |> Ash.Query.filter(session_id == ^session.id and status in [:registered, :attended])
      |> Ash.read!(authorize?: false)

    assert length(active) == 1
    assert hd(active).id == re_reg2.id
    assert length(Registration |> Ash.Query.filter(session_id == ^session.id) |> Ash.read!(authorize?: false)) == 5
  end

  test "W973b terminal guard: a cancelled registration cannot :cancel again (typed refusal)" do
    {session, attendee} = seed_session_with_attendee("w973b-terminal")

    reg = register(attendee.id, session.id)
    assert reg.status == :registered

    cancelled = Ash.update!(Ash.Changeset.for_update(reg, :cancel, %{}), authorize?: false)
    assert cancelled.status == :cancelled

    assert_raise Ash.Error.Invalid,
                 ~r/cancelled/,
                 fn ->
                   Ash.update!(Ash.Changeset.for_update(cancelled, :cancel, %{}),
                     authorize?: false
                   )
                 end
  end
end
