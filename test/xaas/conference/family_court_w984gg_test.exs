defmodule Xaas.Conference.FamilyCourtW984ggTest do
  @moduledoc """
  W984gg — unclaimed-family probe court for the conference/booking domain
  (lib/xaas/conference/*.ex).

  Coverage census (as of 2026-10-07): all seven conference resources are
  held by five existing courts + the (sibling-modified) deepening file. The
  census surfaced one genuinely unexercised state-bearing family: BOTH
  `EnforceSessionCapacity` and `EnforceActiveRegistrationIdentity` treat
  `:attended` as ACTIVE — but every existing test exercises those guards
  with `:registered`-holder rows only. A directly-`:attended` registration
  (the `:create` action accepts `:status`) has no witnessed state behavior:

  - does an `:attended` holder consume a capacity slot? (EnforceSessionCapacity
    counts `status in [:registered, :attended]`)
  - is an `:attended` same-(attendee, session) duplicate refused by the scoped
    identity guard? (EnforceActiveRegistrationIdentity same filter)
  - does cancelling an `:attended` holder release the slot? (it must — the
    capacity count includes :attended — but the terminal cancel guard must
    refuse cancel-of-attended; the two guards interlock and no test holds
    the interlock)
  - does the create-time path admit `:attended` on the SAME session while a
    `:registered` holder sits there under capacity 1, i.e. is the capacity
    count a real query over mixed active statuses, not a count of
    `:registered` rows only?

  Chicago-style: real Ash actions over real ETS tables, zero mocks; each test
  carries a mutation rationale naming the exact lib-side drop that would kill
  it.
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

  defp utc(dt), do: DateTime.truncate(dt, :second)

  defp event! do
    Ash.create!(
      Ash.Changeset.for_create(Event, :create, %{
        name: "AGNTCon W984gg",
        slug: "agntcon-w984gg-#{System.unique_integer([:positive])}",
        location: "San Francisco",
        starts_at: utc(~U[2026-11-06 09:00:00Z]),
        ends_at: utc(~U[2026-11-08 18:00:00Z])
      }),
      authorize?: false
    )
  end

  defp track!(event) do
    Ash.create!(
      Ash.Changeset.for_create(Track, :create, %{
        name: "Courts",
        slug: "courts-w984gg-#{System.unique_integer([:positive])}",
        event_id: event.id
      }),
      authorize?: false
    )
  end

  defp speaker!(track) do
    Ash.create!(
      Ash.Changeset.for_create(Speaker, :create, %{
        name: "Court Speaker",
        slug: "speaker-w984gg-#{System.unique_integer([:positive])}"
      }),
      authorize?: false
    )
  end

  defp session!(track, speaker, title, capacity) do
    Ash.create!(
      Ash.Changeset.for_create(Session, :create, %{
        title: title,
        slug: "session-w984gg-#{System.unique_integer([:positive])}",
        track_id: track.id,
        speaker_id: speaker.id,
        capacity: capacity
      }),
      authorize?: false
    )
  end

  defp attendee!(name) do
    Ash.create!(
      Ash.Changeset.for_create(Attendee, :create, %{
        name: name,
        email: "#{String.downcase(String.replace(name, " ", "-"))}-w984gg@example.test"
      }),
      authorize?: false
    )
  end

  defp register!(attendee, session, status) do
    Ash.create!(
      Ash.Changeset.for_create(Registration, :create, %{
        attendee_id: attendee.id,
        session_id: session.id,
        status: status
      }),
      authorize?: false
    )
  end

  defp register(attendee, session, status \\ :registered) do
    Ash.create(
      Ash.Changeset.for_create(Registration, :create, %{
        attendee_id: attendee.id,
        session_id: session.id,
        status: status
      }),
      authorize?: false
    )
  end

  defp active_count(session_id) do
    Registration
    |> Ash.Query.filter(session_id == ^session_id and status in [:registered, :attended])
    |> Ash.read!(authorize?: false)
    |> length()
  end

  @tag :w984gg
  test "1. a directly-attended registration consumes a capacity slot (capacity 1: attended holder blocks a later registered create)" do
    # Mutation rationale: EnforceSessionCapacity drops :attended from
    # @active_statuses (leaving [:registered] only) — then the :attended
    # create succeeds but the SECOND create would also succeed (0 counted
    # registered), and the final active_count assert would read 2 instead
    # of 1. This test kills that mutant by holding the full interlock:
    # attended create admitted, registered create refused "at capacity
    # (1/1 taken)", and the refusal persists nothing.
    event = event!()
    track = track!(event)
    speaker = speaker!(track)
    session = session!(track, speaker, "attended-holds-a-slot", 1)
    ada = attendee!("Ada W984gg")
    grace = attendee!("Grace W984gg")

    attended = register!(ada, session, :attended)
    assert attended.status == :attended
    assert active_count(session.id) == 1

    {:error, %Ash.Error.Invalid{errors: errors}} = register(grace, session)

    assert Enum.any?(errors, fn e ->
             e.message =~ "at capacity (1/1 taken)"
           end)

    # nothing persisted by the refused create
    assert active_count(session.id) == 1
    assert %{status: :attended} = Ash.get!(Registration, attended.id, authorize?: false)
  end

  @tag :w984gg
  test "2. attended same-(attendee, session) duplicate is refused by the scoped active-identity guard" do
    # Mutation rationale: EnforceActiveRegistrationIdentity drops :attended
    # from @active_statuses — the second :attended create for the same
    # (attendee, session) would succeed, producing an active double-book,
    # and the final count assert would read 2 instead of 1. Kills the
    # symmetric mutant on the identity guard that test 1 kills on the
    # capacity guard.
    event = event!()
    track = track!(event)
    speaker = speaker!(track)
    session = session!(track, speaker, "attended-duplicate", nil)
    ada = attendee!("Ada Dup")

    first = register!(ada, session, :attended)
    assert first.status == :attended

    assert_raise Ash.Error.Invalid, ~r/has already been taken/, fn ->
      register!(ada, session, :attended)
    end

    # nothing persisted by the refused duplicate
    assert length(Registration |> Ash.read!(authorize?: false)) == 1
  end

  @tag :w984gg
  test "3. the guards interlock: cancel-of-attended is refused (terminal guard) even though attended holds a capacity slot" do
    # Mutation rationale A: RegistrationTerminalCancelGuard narrows
    # terminal_statuses to [:cancelled] — cancel-of-attended would succeed,
    # freeing a slot the terminal contract says is frozen; the final status
    # assert would read :cancelled instead of :attended. Held by the W984do
    # court only via update-walk rows; here it is held against a row whose
    # slot-bearing state is load-bearing for capacity.
    # Mutation rationale B: EnforceSessionCapacity widens the pre-check to
    # all statuses (or drops the :attended count) — no other test holds the
    # capacity side of an :attended holder.
    event = event!()
    track = track!(event)
    speaker = speaker!(track)
    session = session!(track, speaker, "interlock", 1)
    ada = attendee!("Ada Interlock")

    attended = register!(ada, session, :attended)
    assert active_count(session.id) == 1

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             Ash.update(
               Ash.Changeset.for_update(attended, :cancel, %{}),
               authorize?: false
             )

    assert Enum.any?(errors, fn e ->
             e.message =~ "cannot cancel a terminal registration" and e.message =~ ":attended"
           end)

    # slot stays consumed; status untouched
    assert %{status: :attended} = Ash.get!(Registration, attended.id, authorize?: false)
    assert active_count(session.id) == 1
  end
end
