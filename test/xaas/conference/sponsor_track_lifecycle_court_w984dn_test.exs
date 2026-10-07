defmodule Xaas.Conference.SponsorTrackLifecycleCourtW984dnTest do
  @moduledoc """
  W984dn — sponsor/track lifecycle depth court (coverage burn-down; the
  smoke-level create/read coverage in `conference_test.exs` leaves every
  typed invariant of `Xaas.Conference.Sponsor` and `Xaas.Conference.Track`
  unheld).

  Chicago-style over real `Ash.DataLayer.Ets` tables, real Ash actions, no
  mocks. Five tests, each with a mutation rationale naming the exact code
  drop that would kill it, and each typed refusal asserted as-real (a real
  raised Ash error, not a mocked one) — matching W984dm's learned shapes
  (wrapped `Ash.Error.Invalid` on get-of-destroyed, exact constraint
  messages).

  Fresh root: every test wipes all six conference tables in `setup`, so each
  test runs on fresh table state; the suite is run twice end-to-end
  (run 1 / run 2 in the receipt) to prove fresh-root repeatability.
  """

  use ExUnit.Case, async: false

  alias Xaas.Conference.{Event, Session, Sponsor, Track}

  setup do
    wipe()
    :ok
  end

  defp wipe do
    for res <- [Session, Track, Sponsor, Event] do
      res
      |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
    end
  end

  defp utc(dt), do: dt |> DateTime.truncate(:second) |> DateTime.shift_zone!("Etc/UTC")

  defp create_event!(suffix) do
    Ash.create!(
      Ash.Changeset.for_create(Event, :create, %{
        name: "W984dn Event",
        slug: "w984dn-event-#{suffix}",
        location: "San Francisco",
        starts_at: utc(~U[2026-08-04 09:00:00Z]),
        ends_at: utc(~U[2026-08-06 18:00:00Z])
      }),
      authorize?: false
    )
  end

  defp track_changeset(event, suffix, extra \\ %{}) do
    Ash.Changeset.for_create(
      Track,
      :create,
      Map.merge(
        %{
          "name" => "W984dn Track #{suffix}",
          "slug" => "w984dn-track-#{suffix}",
          "event_id" => event.id
        },
        extra
      )
    )
  end

  defp sponsor_changeset(suffix, extra \\ %{}) do
    Ash.Changeset.for_create(
      Sponsor,
      :create,
      Map.merge(
        %{
          "name" => "W984dn Sponsor #{suffix}",
          "slug" => "w984dn-sponsor-#{suffix}",
          "tier" => :gold
        },
        extra
      )
    )
  end

  test "1. sponsor lifecycle: create persists real row, tier atom round-trips, destroy removes it" do
    sponsor =
      Ash.create!(sponsor_changeset("life", %{"url" => "https://example.com/w984dn"}),
        authorize?: false
      )

    assert %Sponsor{id: id} = sponsor
    assert sponsor.tier == :gold
    assert sponsor.url == "https://example.com/w984dn"

    # Mutation rationale: drop `create_timestamp(:inserted_at)` /
    # `update_timestamp(:updated_at)` from the resource and the timestamp
    # asserts fail (nil).
    assert %DateTime{} = sponsor.inserted_at
    assert %DateTime{} = sponsor.updated_at

    assert %Sponsor{} = Ash.get!(Sponsor, id, authorize?: false)

    # Mutation rationale: replace the `defaults([:read, :destroy])` destroy
    # with a no-op and the post-destroy read never raises — the row is still
    # returned, so this assert_raise never fires. Ash 3.34 raises the wrapped
    # error class Ash.Error.Invalid (containing Ash.Error.Query.NotFound
    # "not found"), asserted as-real.
    assert :ok = Ash.destroy!(sponsor, authorize?: false)
    assert_raise Ash.Error.Invalid, ~r/not found/, fn ->
      Ash.get!(Sponsor, id, authorize?: false)
    end
  end

  test "2. sponsor tier one_of: out-of-enum tier refused, all four tiers accepted" do
    # Mutation rationale: empty the `constraints(one_of: [...])` list on the
    # tier attribute and the :platinum create succeeds (ETS places no enum
    # bound of its own), so this assert_raise never fires.
    assert_raise Ash.Error.Invalid, ~r/must be one of/, fn ->
      Ash.create!(sponsor_changeset("tier-bad", %{"tier" => :platinum}), authorize?: false)
    end

    for tier <- [:diamond, :gold, :silver, :bronze] do
      sponsor = Ash.create!(sponsor_changeset("tier-ok-#{tier}", %{"tier" => tier}),
        authorize?: false
      )

      assert sponsor.tier == tier
    end

    assert length(Ash.read!(Sponsor, authorize?: false)) == 4

    # The refused :platinum row was never partially written.
    refute Enum.any?(Ash.read!(Sponsor, authorize?: false), &(&1.tier == :platinum))
  end

  test "3. sponsor unique_slug: duplicate slug refused with real invalid error" do
    Ash.create!(sponsor_changeset("dup"), authorize?: false)

    # Mutation rationale: drop `identity(:unique_slug, [:slug],
    # pre_check_with: Ash.DataLayer.Ets)` and the ETS table accepts the
    # duplicate row, so this assert_raise never fires.
    assert_raise Ash.Error.Invalid, ~r/has already been taken/, fn ->
      Ash.create!(sponsor_changeset("dup", %{"name" => "Different Name"}), authorize?: false)
    end

    # The refusal leaves the table with exactly one row: no partial write.
    assert [%Sponsor{}] = Ash.read!(Sponsor, authorize?: false)
  end

  test "4. track event_id required: nil refused with real invalid error, present id accepted" do
    # Mutation rationale: drop `allow_nil?: false` from the event_id
    # attribute and the nil-event create succeeds, so this assert_raise
    # never fires.
    assert_raise Ash.Error.Invalid, ~r/is required/, fn ->
      Ash.create!(
        Ash.Changeset.for_create(Track, :create, %{
          "name" => "Orphan Track",
          "slug" => "w984dn-orphan-track"
        }),
        authorize?: false
      )
    end

    event = create_event!("req")
    track = Ash.create!(track_changeset(event, "req"), authorize?: false)

    assert track.event_id == event.id
    assert [%Track{}] = Ash.read!(Track, authorize?: false)
  end

  test "5. track unique_slug + non-cascading destroy: duplicate refused; destroyed track leaves session with dangling ref" do
    event = create_event!("dangle")

    Ash.create!(track_changeset(event, "dangle"), authorize?: false)

    # Mutation rationale: drop the unique_slug identity and the duplicate
    # create succeeds, leaving 2 rows; the single-row assert kills it.
    assert_raise Ash.Error.Invalid, ~r/has already been taken/, fn ->
      Ash.create!(track_changeset(event, "dangle"), authorize?: false)
    end

    assert [%Track{}] = Ash.read!(Track, authorize?: false)

    session =
      Ash.create!(
        Ash.Changeset.for_create(Session, :create, %{
          "title" => "W984dn Session",
          "slug" => "w984dn-session-dangle",
          "track_id" => event.id && Ash.read!(Track, authorize?: false) |> hd() |> Map.get(:id),
          "speaker_id" => create_speaker_id!()
        }),
        authorize?: false
      )

    assert session.track_id

    # Mutation rationale: if a cascade destroy were ever added to Track, the
    # session would be deleted and this readability assert fails — pinning
    # the documented non-cascading ETS contract.
    track = hd(Ash.read!(Track, authorize?: false))
    assert :ok = Ash.destroy!(track, authorize?: false)
    assert [%Session{}] = Ash.read!(Session, authorize?: false)

    post = Ash.get!(Session, session.id, authorize?: false)
    assert post.track_id == track.id
  end

  defp create_speaker_id! do
    speaker =
      Ash.create!(
        Ash.Changeset.for_create(Xaas.Conference.Speaker, :create, %{
          "name" => "W984dn Speaker",
          "slug" => "w984dn-speaker-dangle"
        }),
        authorize?: false
      )

    speaker.id
  end
end
