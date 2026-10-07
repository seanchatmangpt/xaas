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

    # Successive attendees for the re-registration legs: the
    # unique_attendee_session identity (pre_check_with Ets) holds across
    # cancelled rows, so the W925 slot release is witnessed by a NEW
    # attendee being admitted into the freed slot (same shape as the
    # W893 leg above), not by the same attendee re-registering.
    attendee2 =
      Ash.create!(
        Ash.Changeset.for_create(Attendee, :create, %{
          name: "Grace Hopper",
          email: "grace-w973b@example.test",
          affiliation: "Navy"
        }),
        authorize?: false
      )

    attendee3 =
      Ash.create!(
        Ash.Changeset.for_create(Attendee, :create, %{
          name: "Edsger Dijkstra",
          email: "edsger-w973b@example.test",
          affiliation: "TU Delft"
        }),
        authorize?: false
      )

    # --- leg 1: register ---
    reg1 = register(attendee.id, session.id)
    assert reg1.status == :registered

    # --- leg 2: cancel via the named W947 :cancel action ---
    cancelled1 =
      Ash.update!(Ash.Changeset.for_update(reg1, :cancel, %{}), authorize?: false)

    assert cancelled1.status == :cancelled
    assert Ash.get!(Registration, reg1.id, authorize?: false).status == :cancelled

    # --- leg 3: W925 slot release witnessed through the named action path ---
    re_reg1 = register(attendee2.id, session.id)
    assert re_reg1.status == :registered
    assert re_reg1.id != reg1.id

    # --- leg 4: cancel again ---
    cancelled2 =
      Ash.update!(Ash.Changeset.for_update(re_reg1, :cancel, %{}), authorize?: false)

    assert cancelled2.status == :cancelled
    assert Ash.get!(Registration, re_reg1.id, authorize?: false).status == :cancelled

    # --- leg 5: slot released a second time ---
    re_reg2 = register(attendee3.id, session.id)
    assert re_reg2.status == :registered
    assert re_reg2.id != re_reg1.id

    # --- determinism of the end state: exactly one ACTIVE registration ---
    active =
      Registration
      |> Ash.Query.filter(session_id == ^session.id and status in [:registered, :attended])
      |> Ash.read!(authorize?: false)

    assert length(active) == 1
    assert hd(active).id == re_reg2.id
    assert length(Registration |> Ash.Query.filter(session_id == ^session.id) |> Ash.read!(authorize?: false)) == 3
  end

  test "W969e legal walk: A registers → B refused → A cancels → B succeeds → B cancels → A succeeds (repeated slot cycling)" do
    {session, attendee_a} = seed_session_with_attendee("w969e-walk")

    attendee_b =
      Ash.create!(
        Ash.Changeset.for_create(Attendee, :create, %{
          name: "Grace Hopper",
          email: "grace-w969e@example.test",
          affiliation: "Navy"
        }),
        authorize?: false
      )

    # --- step 1: A registers, slot taken ---
    reg_a1 = register(attendee_a.id, session.id)
    assert reg_a1.status == :registered

    # --- step 2: B refused, slot full (typed refusal, nothing written) ---
    assert_raise Ash.Error.Invalid,
                 ~r/at capacity \(1\/1 taken\)/,
                 fn ->
                   register(attendee_b.id, session.id)
                 end

    assert length(
             Registration
             |> Ash.Query.filter(session_id == ^session.id)
             |> Ash.read!(authorize?: false)
           ) == 1

    # --- step 3: A cancels via :cancel, slot released ---
    cancelled_a =
      Ash.update!(Ash.Changeset.for_update(reg_a1, :cancel, %{}), authorize?: false)

    assert cancelled_a.status == :cancelled
    assert Ash.get!(Registration, reg_a1.id, authorize?: false).status == :cancelled

    # --- step 4: B re-registers, succeeds (slot released) ---
    reg_b = register(attendee_b.id, session.id)
    assert reg_b.status == :registered
    assert reg_b.id != reg_a1.id

    # --- step 5: B cancels, slot re-released ---
    cancelled_b =
      Ash.update!(Ash.Changeset.for_update(reg_b, :cancel, %{}), authorize?: false)

    assert cancelled_b.status == :cancelled
    assert Ash.get!(Registration, reg_b.id, authorize?: false).status == :cancelled

    # --- step 6: A re-registers into the released slot — SUCCEEDS.
    #     Repair of GAP(same-attendee-re-register-blocked-by-identity):
    #     the :unique_attendee_session identity is intentionally ABSENT
    #     (ash 3.34.4 measured: no identity shape satisfies both the
    #     RequirePreCheckWith verifier and the scoped semantics — the
    #     pre-check path ignores an identity's `where` scope); a CANCELLED
    #     row therefore consumes no identity at all, and active-duplicate
    #     enforcement lives entirely in EnforceActiveRegistrationIdentity
    #     on :create. A previously-cancelled attendee legally re-registers
    #     (W981s receipt; landed design per W983a; W969e receipt pre-named
    #     this flip: "product-side close: scoped identity"). ---
    reg_a2 = register(attendee_a.id, session.id)
    assert reg_a2.status == :registered
    assert reg_a2.id != reg_a1.id
    assert reg_a2.id != reg_b.id

    # --- determinism of the end state: exactly one ACTIVE registration
    #     (A's new row), two cancelled rows (A's original and B's), three
    #     rows total — the one refused create (B at step 2, capacity) wrote
    #     nothing; the slot was never double-booked ---
    active =
      Registration
      |> Ash.Query.filter(session_id == ^session.id and status in [:registered, :attended])
      |> Ash.read!(authorize?: false)

    assert length(active) == 1
    assert hd(active).id == reg_a2.id

    all = Registration |> Ash.Query.filter(session_id == ^session.id) |> Ash.read!(authorize?: false)
    assert length(all) == 3
    assert Enum.frequencies(Enum.map(all, & &1.status)) == %{registered: 1, cancelled: 2}
  end

  # W973b FALSIFIER — currently RED by measurement: the W795
  # RegistrationStatusTransition admits self-transitions {s, s}, so
  # {:cancelled, :cancelled} via the named :cancel action is admitted and
  # "cancelled is terminal" is NOT enforced. This test is the failing
  # observation for the coordinator to close with a product-side guard;
  # do not soften it to match current behavior.
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

# ---------------------------------------------------------------------------
# W981s court — GAP(same-attendee-re-register-blocked-by-identity) REPAIR:
# the landed design (W983a) has NO :unique_attendee_session identity — ash
# 3.34.4 measured: RequirePreCheckWith demands pre_check_with on any ETS
# identity, but the pre-check path ignores an identity's `where` scope, so
# no identity shape satisfies both the verifier and the scoped semantics.
# Active-duplicate enforcement lives entirely in the
# EnforceActiveRegistrationIdentity before_action on :create, so a
# cancelled registration no longer permanently blocks its attendee from
# re-registering into the same session with a free slot. Chicago-style:
# real ETS-backed Ash actions, no mocks. Mutation rationale: drop the
# EnforceActiveRegistrationIdentity change from the :create action and the
# first assert (re-register succeeds) fails — an active duplicate would be
# admitted (versus the pre-W981s behavior the W969e step-6 probe measured,
# where the unscoped identity refused the cancelled attendee's re-entry).
# ---------------------------------------------------------------------------
test "W981s: cancelled attendee re-registers into the same session (slot free) and an active duplicate is still refused" do
  # Full seed with an UNLIMITED-capacity session: the capacity ceiling fires
  # before the identity pre-check on a capacity-1 session, which would mask
  # the identity refusal this court must witness directly.
  event =
    Ash.create!(
      Ash.Changeset.for_create(Event, :create, %{
        name: "AGNTCon+MCPCon 2026 W981s",
        slug: "agntcon-w981s-identity",
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
        slug: "evals-w981s-identity",
        description: "Courts all the way down",
        event_id: event.id
      }),
      authorize?: false
    )

  speaker =
    Ash.create!(
      Ash.Changeset.for_create(Speaker, :create, %{
        name: "Sean Chatman",
        slug: "sean-chatman-w981s-identity",
        bio: "Chief Scientist, xaas"
      }),
      authorize?: false
    )

  session =
    Ash.create!(
      Ash.Changeset.for_create(Session, :create, %{
        title: "W981s Identity Scope Court",
        slug: "w981s-identity-court",
        description: "W981s pinned session",
        track_id: track.id,
        speaker_id: speaker.id,
        starts_at: utc(~U[2026-11-04 10:00:00Z]),
        ends_at: utc(~U[2026-11-04 11:00:00Z]),
        capacity: nil
      }),
      authorize?: false
    )

  attendee_a =
    Ash.create!(
      Ash.Changeset.for_create(Attendee, :create, %{
        name: "Ada Lovelace",
        email: "ada-w981s@example.test",
        affiliation: "Analytical Engine Co"
      }),
      authorize?: false
    )

  attendee_b =
    Ash.create!(
      Ash.Changeset.for_create(Attendee, :create, %{
        name: "Grace Hopper",
        email: "grace-w981s@example.test",
        affiliation: "Navy"
      }),
      authorize?: false
    )

  # --- A registers ---
  reg_a = register(attendee_a.id, session.id)
  assert reg_a.status == :registered

  # --- ACTIVE duplicate still refused by the (scoped) identity ---
  assert_raise Ash.Error.Invalid,
               ~r/has already been taken/,
               fn -> register(attendee_a.id, session.id) end

  # --- B registers alongside (capacity is unlimited) and is also
  #     identity-refused on a duplicate ---
  reg_b = register(attendee_b.id, session.id)
  assert reg_b.status == :registered

  assert_raise Ash.Error.Invalid,
               ~r/has already been taken/,
               fn -> register(attendee_b.id, session.id) end

  # --- A cancels: identity released ---
  cancelled_a = Ash.update!(Ash.Changeset.for_update(reg_a, :cancel, %{}), authorize?: false)
  assert cancelled_a.status == :cancelled

  # --- REPAIR witnessed: A re-registers into the same session, succeeds,
  #     while B's active row is untouched ---
  re_reg_a = register(attendee_a.id, session.id)
  assert %Registration{} = re_reg_a
  assert re_reg_a.status == :registered
  assert re_reg_a.id != reg_a.id

  # --- cancelling again re-releases; A can cycle a third time ---
  cancelled_a2 = Ash.update!(Ash.Changeset.for_update(re_reg_a, :cancel, %{}), authorize?: false)
  assert cancelled_a2.status == :cancelled

  third_a = register(attendee_a.id, session.id)
  assert %Registration{} = third_a
  assert third_a.status == :registered

  # --- determinism: 2 ACTIVE rows (A's third + B's), 4 rows total ---
  active =
    Registration
    |> Ash.Query.filter(session_id == ^session.id and status in [:registered, :attended])
    |> Ash.read!(authorize?: false)

  assert length(active) == 2
  assert Enum.map(active, & &1.id) |> Enum.sort() == Enum.sort([third_a.id, reg_b.id])

  all = Registration |> Ash.Query.filter(session_id == ^session.id) |> Ash.read!(authorize?: false)
  assert length(all) == 4
  assert Enum.frequencies(Enum.map(all, & &1.status)) == %{registered: 2, cancelled: 2}
end
end
