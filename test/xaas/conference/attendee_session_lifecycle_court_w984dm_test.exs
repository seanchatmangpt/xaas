defmodule Xaas.Conference.AttendeeSessionLifecycleCourtW984dmTest do
  @moduledoc """
  W984dm — attendee/session lifecycle depth court (coverage burn-down; the
  registration journey itself is already held by the W893 enrollment court
  and W981s/W983a registration courts — this court holds the two referenced
  entities themselves).

  Chicago-style over real `Ash.DataLayer.Ets` tables, real Ash actions, no
  mocks. Five tests, each with a mutation rationale naming the exact code
  drop that would kill it, and each typed refusal asserted as-real (a real
  raised Ash error, not a mocked one).

  Fresh root: every test wipes all six conference tables in `setup`, so each
  test runs on a fresh table state; the suite is additionally run twice
  end-to-end (run 1 / run 2 in the receipt) to prove fresh-root
  repeatability.
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

  defp create_track!(suffix) do
    event =
      Ash.create!(
        Ash.Changeset.for_create(Event, :create, %{
          name: "W984dm Event",
          slug: "w984dm-event-#{suffix}",
          location: "San Francisco",
          starts_at: utc(~U[2026-08-04 09:00:00Z]),
          ends_at: utc(~U[2026-08-06 18:00:00Z])
        }),
        authorize?: false
      )

    Ash.create!(
      Ash.Changeset.for_create(Track, :create, %{
        name: "W984dm Track",
        slug: "w984dm-track-#{suffix}",
        event_id: event.id
      }),
      authorize?: false
    )
  end

  defp create_speaker!(suffix) do
    Ash.create!(
      Ash.Changeset.for_create(Speaker, :create, %{
        name: "W984dm Speaker",
        slug: "w984dm-speaker-#{suffix}"
      }),
      authorize?: false
    )
  end

  defp session_changeset(track, speaker, suffix, extra \\ %{}) do
    Ash.Changeset.for_create(
      Session,
      :create,
      Map.merge(
        %{
          "title" => "W984dm Session #{suffix}",
          "slug" => "w984dm-session-#{suffix}",
          "track_id" => track.id,
          "speaker_id" => speaker.id
        },
        extra
      )
    )
  end

  test "1. attendee lifecycle: create persists real row, timestamps set, destroy removes it" do
    attendee =
      Ash.create!(
        Ash.Changeset.for_create(Attendee, :create, %{
          name: "Ada Lovelace",
          email: "ada-w984dm@example.com",
          affiliation: "Analytical Engine Society"
        }),
        authorize?: false
      )

    assert %Attendee{id: id} = attendee
    assert attendee.name == "Ada Lovelace"
    assert attendee.affiliation == "Analytical Engine Society"

    # Mutation rationale: drop `create_timestamp(:inserted_at)` /
    # `update_timestamp(:updated_at)` from the resource and the timestamp
    # asserts fail (nil).
    assert %DateTime{} = attendee.inserted_at
    assert %DateTime{} = attendee.updated_at

    assert %Attendee{} = Ash.get!(Attendee, id, authorize?: false)

    # Mutation rationale: replace the `defaults([:read, :destroy])` destroy
    # with a no-op and the post-destroy read never raises — the row is still
    # returned, so this assert_raise never fires. Ash 3.34 raises the
    # wrapped error class Ash.Error.Invalid (containing
    # Ash.Error.Query.NotFound "not found"), asserted as-real.
    assert :ok = Ash.destroy!(attendee, authorize?: false)
    assert_raise Ash.Error.Invalid, ~r/not found/, fn ->
      Ash.get!(Attendee, id, authorize?: false)
    end
  end

  test "2. attendee unique_email: duplicate create refused with real invalid error" do
    Ash.create!(
      Ash.Changeset.for_create(Attendee, :create, %{
        name: "First",
        email: "dup-w984dm@example.com"
      }),
      authorize?: false
    )

    # Mutation rationale: drop the `identity(:unique_email, [:email],
    # pre_check_with: Ash.DataLayer.Ets)` line and the ETS table accepts the
    # duplicate row, so this assert_raise never fires.
    assert_raise Ash.Error.Invalid, ~r/has already been taken/, fn ->
      Ash.create!(
        Ash.Changeset.for_create(Attendee, :create, %{
          name: "Second",
          email: "dup-w984dm@example.com"
        }),
        authorize?: false
      )
    end

    # The refusal leaves the table with exactly one row: no partial write.
    assert [%Attendee{}] = Ash.read!(Attendee, authorize?: false)
  end

  test "3. session capacity constraint: capacity 0 refused, nil and >= 1 accepted" do
    track = create_track!("cap")
    speaker = create_speaker!("cap")

    # Mutation rationale: delete the `constraints(min: 1)` block from the
    # capacity attribute and the capacity-0 create succeeds (ETS places no
    # integer bound of its own), so this assert_raise never fires.
    assert_raise Ash.Error.Invalid, ~r/must be greater than or equal to 1/, fn ->
      Ash.create!(session_changeset(track, speaker, "cap-zero", %{"capacity" => 0}),
        authorize?: false
      )
    end

    nil_cap = Ash.create!(session_changeset(track, speaker, "cap-nil"), authorize?: false)
    assert is_nil(nil_cap.capacity)

    one_cap =
      Ash.create!(session_changeset(track, speaker, "cap-one", %{"capacity" => 1}),
        authorize?: false
      )

    assert one_cap.capacity == 1

    assert length(Ash.read!(Session, authorize?: false)) == 2
  end

  test "4. session unique_slug: duplicate slug refused with real invalid error, distinct slugs coexist" do
    track = create_track!("slug")
    speaker = create_speaker!("slug")

    Ash.create!(session_changeset(track, speaker, "slug-a"), authorize?: false)

    # Same slug, different speaker: only the slug identity is violated.
    # Mutation rationale: drop `identity(:unique_slug, [:slug],
    # pre_check_with: Ash.DataLayer.Ets)` and this create succeeds, leaving
    # 2 rows, and the single-row assert below kills it.
    assert_raise Ash.Error.Invalid, ~r/has already been taken/, fn ->
      Ash.create!(
        session_changeset(track, create_speaker!("slug-b"), "slug-a"),
        authorize?: false
      )
    end

    assert [%Session{}] = Ash.read!(Session, authorize?: false)

    Ash.create!(session_changeset(track, speaker, "slug-c"), authorize?: false)
    assert length(Ash.read!(Session, authorize?: false)) == 2
  end

  test "5. session destroy is non-cascading: referencing registration survives with dangling ref" do
    track = create_track!("dangle")
    speaker = create_speaker!("dangle")
    session = Ash.create!(session_changeset(track, speaker, "dangle"), authorize?: false)

    attendee =
      Ash.create!(
        Ash.Changeset.for_create(Attendee, :create, %{
          name: "Grace Hopper",
          email: "grace-w984dm@example.com"
        }),
        authorize?: false
      )

    reg =
      Ash.create!(
        Ash.Changeset.for_create(Registration, :create, %{
          attendee_id: attendee.id,
          session_id: session.id
        }),
        authorize?: false
      )

    assert reg.session_id == session.id

    # Mutation rationale: if a cascade destroy were ever added to Session,
    # the registration would be deleted and this readability assert fails —
    # pinning the documented non-cascading ETS contract.
    assert :ok = Ash.destroy!(session, authorize?: false)
    assert [%Registration{}] = Ash.read!(Registration, authorize?: false)

    post = Ash.get!(Registration, reg.id, authorize?: false)
    assert post.session_id == session.id
  end
end
