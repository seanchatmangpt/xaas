defmodule Xaas.ConferenceDeepeningTest do
  @moduledoc """
  W715 conference-deepening courts over `Xaas.Conference` (AGNTCon+MCPCon 2026).

  Chicago-style: real `Ash.DataLayer.Ets` tables, real Ash actions
  (`Ash.create!`/`Ash.update!`/`Ash.get!`/`Ash.read!`), assertions on real row
  state. No mocks — the Ets tables ARE the collaborators.

  W795 landed the three typed gaps as invariants (read before writing):
  - `Registration` status is guarded by the forward-only
    `Xaas.Conference.Validations.RegistrationStatusTransition`
    (`:registered -> :cancelled/:attended`, `:cancelled -> :attended`;
    `:attended` terminal; self-transitions allowed).
  - `Session.capacity` (`:integer`, min 1, nil = unlimited) is enforced on
    Registration create by `Xaas.Conference.Changes.EnforceSessionCapacity`.
  - Registration `attendee_id`/`session_id` must resolve to real rows on
    create (`Xaas.Conference.Changes.ResolveRegistrationRefs`).
  """

  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Conference.{Attendee, Registration, Session, Speaker, Sponsor, Track, Event}

  setup do
    wipe()
    :ok
  end

  defp wipe do
    for res <- [Registration, Session, Track, Speaker, Sponsor, Attendee, Event] do
      Ash.bulk_destroy!(res, :destroy, %{}, authorize?: false)
    end
  end

  defp create!(resource, attrs) do
    resource
    |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  defp seed do
    speaker = create!(Speaker, %{name: "Sean Chatman", slug: "sean-chatman", keynote?: true})

    event =
      create!(Event, %{name: "AGNTCon+MCPCon 2026", slug: "agntcon-mcpcon-2026"})

    track =
      create!(Track, %{name: "Evaluations & Courts", slug: "evaluations-courts", event_id: event.id})

    session =
      create!(Session, %{
        title: "Courts Over Chaos",
        slug: "courts-over-chaos",
        track_id: track.id,
        speaker_id: speaker.id
      })

    attendee =
      create!(Attendee, %{name: "Ada Lovelace", email: "ada@example.com", affiliation: "Analytical Engines"})

    %{event: event, track: track, session: session, speaker: speaker, attendee: attendee}
  end

  # (a) registration lifecycle
  test "registration lifecycle: create defaults to :registered, then real status transitions persist" do
    %{session: session, attendee: attendee} = seed()

    reg =
      create!(Registration, %{attendee_id: attendee.id, session_id: session.id})

    assert reg.status == :registered
    assert reg.attendee_id == attendee.id
    assert reg.session_id == session.id

    reg =
      reg
      |> Ash.Changeset.for_update(:update, %{status: :cancelled}, authorize?: false)
      |> Ash.update!(authorize?: false)
    assert %{status: :cancelled} = Ash.get!(Registration, reg.id, authorize?: false)

    reg =
      reg
      |> Ash.Changeset.for_update(:update, %{status: :attended}, authorize?: false)
      |> Ash.update!(authorize?: false)
    assert %{status: :attended} = Ash.get!(Registration, reg.id, authorize?: false)
  end

  test "typed refusal: status outside the one_of constraint is rejected" do
    %{session: session, attendee: attendee} = seed()

    assert_raise Ash.Error.Invalid, ~r/invalid value/i, fn ->
      Registration
      |> Ash.Changeset.for_create(:create, %{
        attendee_id: attendee.id,
        session_id: session.id,
        status: :refunded
      }, authorize?: false)
      |> Ash.create!(authorize?: false)
    end

    # Real state: nothing was written.
    assert [] = Ash.read!(Registration, authorize?: false)
  end

  test "typed refusal: duplicate (attendee_id, session_id) violates unique_attendee_session" do
    %{session: session, attendee: attendee} = seed()

    create!(Registration, %{attendee_id: attendee.id, session_id: session.id})

    assert_raise Ash.Error.Invalid, fn ->
      create!(Registration, %{attendee_id: attendee.id, session_id: session.id})
    end

    assert length(Ash.read!(Registration, authorize?: false)) == 1
  end

  test "invariant: forward edges admitted, backward edge :attended -> :registered refused" do
    %{session: session, attendee: attendee} = seed()

    reg = create!(Registration, %{attendee_id: attendee.id, session_id: session.id})

    reg =
      reg
      |> Ash.Changeset.for_update(:update, %{status: :cancelled}, authorize?: false)
      |> Ash.update!(authorize?: false)
    assert reg.status == :cancelled

    reg =
      reg
      |> Ash.Changeset.for_update(:update, %{status: :attended}, authorize?: false)
      |> Ash.update!(authorize?: false)
    assert reg.status == :attended

    # Mutation rationale: delete the guard (or its {:attended, :registered}
    # absence) from Registration.:update and this write would re-succeed,
    # letting attended work "un-happen" — exactly the W715 regression.
    assert_raise Ash.Error.Invalid, ~r/not an admitted forward edge/i, fn ->
      reg
      |> Ash.Changeset.for_update(:update, %{status: :registered}, authorize?: false)
      |> Ash.update!(authorize?: false)
    end

    # Real state: the refusal left the terminal row untouched.
    assert %{status: :attended} = Ash.get!(Registration, reg.id, authorize?: false)
  end

  test "invariant: self-transition {s, s} still allowed (artifacts-only updates not refused)" do
    %{session: session, attendee: attendee} = seed()

    reg = create!(Registration, %{attendee_id: attendee.id, session_id: session.id})

    reg =
      reg
      |> Ash.Changeset.for_update(:update, %{status: :registered}, authorize?: false)
      |> Ash.update!(authorize?: false)

    assert %{status: :registered} = Ash.get!(Registration, reg.id, authorize?: false)
  end

  # (b) cross-resource integrity
  test "registration references resolve to the real Attendee and Session rows (application-level join)" do
    %{session: session, attendee: attendee} = seed()

    reg = create!(Registration, %{attendee_id: attendee.id, session_id: session.id})

    loaded_attendee = Ash.get!(Attendee, reg.attendee_id, authorize?: false)
    loaded_session = Ash.get!(Session, reg.session_id, authorize?: false)

    assert loaded_attendee.id == attendee.id
    assert loaded_attendee.email == "ada@example.com"
    assert loaded_session.id == session.id
    assert loaded_session.slug == "courts-over-chaos"

    # And the session resolves through its track to the event.
    loaded_track = Ash.get!(Track, loaded_session.track_id, authorize?: false)
    loaded_event = Ash.get!(Event, loaded_track.event_id, authorize?: false)
    assert loaded_event.slug == "agntcon-mcpcon-2026"
  end

  test "invariant: dangling attendee_id/session_id are refused on create with typed InvalidChanges" do
    %{session: session, attendee: attendee} = seed()

    ghost = Ash.UUID.generate()

    # Mutation rationale: remove the ResolveRegistrationRefs validate from
    # Registration.:create and this write would be stored dangling, exactly
    # the W715 gap (the data layer itself has no FK enforcement).
    assert_raise Ash.Error.Invalid, ~r/does not resolve to a real/i, fn ->
      create!(Registration, %{attendee_id: ghost, session_id: session.id})
    end

    assert_raise Ash.Error.Invalid, ~r/does not resolve to a real/i, fn ->
      create!(Registration, %{attendee_id: attendee.id, session_id: Ash.UUID.generate()})
    end

    # Real state: nothing was written for either refusal.
    assert [] = Ash.read!(Registration, authorize?: false)
  end

  # (c) capacity / sponsorship invariants
  test "sponsor tier one_of is the enforced sponsorship invariant; out-of-tier refusals are typed" do
    seed()

    assert_raise Ash.Error.Invalid, ~r/invalid value/i, fn ->
      create!(Sponsor, %{name: "FauxCorp", slug: "fauxcorp", tier: :platinum})
    end

    assert [] =
             Sponsor
             |> Ash.Query.filter(tier == :platinum)
             |> Ash.read!(authorize?: false)
  end

  test "invariant: session capacity is enforced at the ceiling; nil capacity stays unlimited" do
    %{track: track, speaker: speaker, session: uncapped} = seed()

    capped =
      create!(Session, %{
        title: "Capacity Court",
        slug: "capacity-court",
        track_id: track.id,
        speaker_id: speaker.id,
        capacity: 2
      })

    assert capped.capacity == 2

    for i <- 1..2 do
      a = create!(Attendee, %{name: "C#{i}", email: "c#{i}@example.com"})
      create!(Registration, %{attendee_id: a.id, session_id: capped.id})
    end

    # Mutation rationale: delete EnforceSessionCapacity from Registration.:create
    # (or set the seeded capacity to nil) and this third write would be accepted,
    # reproducing W715's "5 registrations, no refusal" finding.
    assert_raise Ash.Error.Invalid, ~r/at capacity/i, fn ->
      over = create!(Attendee, %{name: "C3", email: "c3@example.com"})
      create!(Registration, %{attendee_id: over.id, session_id: capped.id})
    end

    assert length(Ash.read!(Registration, authorize?: false)) == 2

    # A session with no capacity set remains unlimited (backward compatible).
    for i <- 4..8 do
      a = create!(Attendee, %{name: "C#{i}", email: "c#{i}@example.com"})
      create!(Registration, %{attendee_id: a.id, session_id: uncapped.id})
    end

    count =
      Registration
      |> Ash.Query.filter(session_id == ^uncapped.id)
      |> Ash.read!(authorize?: false)
      |> length()

    assert count == 5
  end

  test "invariant: Session.capacity must be a positive integer (min 1); zero/negative refused" do
    %{track: track, speaker: speaker} = seed()

    # Mutation rationale: drop the `constraints(min: 1)` on Session.capacity
    # and a zero-capacity session would be creatable — a ceiling of 0 that
    # silently refuses every registration with a confusing message.
    assert_raise Ash.Error.Invalid, fn ->
      create!(Session, %{
        title: "Zero Cap",
        slug: "zero-cap",
        track_id: track.id,
        speaker_id: speaker.id,
        capacity: 0
      })
    end

    ok =
      create!(Session, %{
        title: "One Cap",
        slug: "one-cap",
        track_id: track.id,
        speaker_id: speaker.id,
        capacity: 1
      })

    assert ok.capacity == 1
  end

  # (d) determinism of reads after writes — W983a/W981s contract
  test "reads are deterministic after writes: duplicate active registration refuses typed, successful writes re-read identically" do
    %{session: session, attendee: attendee} = seed()

    create!(Registration, %{attendee_id: attendee.id, session_id: session.id})

    a = create!(Attendee, %{name: "B", email: "b@example.com"})
    b = create!(Attendee, %{name: "C", email: "c@example.com"})
    create!(Registration, %{attendee_id: a.id, session_id: session.id})
    create!(Registration, %{attendee_id: b.id, session_id: session.id, status: :cancelled})

    projection = fn ->
      Registration
      |> Ash.Query.filter(session_id == ^session.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&{&1.attendee_id, &1.status})
      |> Enum.sort()
    end

    first = projection.()
    assert length(first) == 3
    assert {b.id, :cancelled} in first

    # W981s/W983a: a duplicate ACTIVE (attendee, session) write is refused
    # typed (EnforceActiveRegistrationIdentity) and leaves the projection
    # untouched — that typed refusal IS the deterministic behavior now.
    assert_raise Ash.Error.Invalid, ~r/has already been taken/i, fn ->
      create!(Registration, %{attendee_id: a.id, session_id: session.id})
    end

    for _ <- 1..5 do
      assert projection.() == first
    end

    # Cancelled re-registration remains legal (W981s scoped identity).
    re_reg = create!(Registration, %{attendee_id: b.id, session_id: session.id})
    assert re_reg.status == :registered

    second = projection.()
    assert length(second) == 4
    assert {b.id, :registered} in second

    # ... and every successful write stays deterministic on re-read.
    for _ <- 1..5 do
      assert projection.() == second
    end

    assert length(Ash.read!(Registration, authorize?: false)) == 4
  end
end
