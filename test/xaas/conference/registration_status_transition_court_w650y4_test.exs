defmodule Xaas.Conference.RegistrationStatusTransitionCourtW650y4Test do
  @moduledoc """
  W650y4 — first direct depth court over
  `Xaas.Conference.Validations.RegistrationStatusTransition`
  (lib/xaas/conference/registration.ex), the W795 forward-only guard on
  `Xaas.Conference.Registration.:update`.

  Prior coverage was implicit/walk-shaped: conference_deepening covers a
  registered→cancelled→attended walk plus one backward refusal; W984do's
  `registration_terminal_cancel_guard_court` owns the `:cancel` terminal
  guard. This court pins the transition surface itself: the full 9-cell
  edge matrix, every illegal-edge typed refusal, self-transitions in all
  three states, and one-shot (irreversible) attendance semantics.
  Chicago-style: real `Ash.DataLayer.Ets` tables, real Ash actions,
  assertions on real persisted row state. No mocks.

  Mutation rationale per test:

  1. forward-edge matrix — kills the mutant that drops any single edge
     from `@forward_edges` (e.g. removes `{:cancelled, :attended}`): the
     corresponding legal walk would raise instead of persisting.
  2. illegal-edge typed refusals — kills the mutant that widens the guard
     to `:ok` unconditionally (or inverts membership to `current != new`):
     each refusal message names the exact pair, and the persisted row is
     untouched — the only observable difference.
  3. self-transition matrix — kills the mutant that removes the
     `current == new` carve-out (or scopes it to `:registered` only):
     artifacts-only updates on `:cancelled`/`:attended` rows would start
     refusing.
  4. one-shot attendance — kills the mutant that makes `:attended` a
     non-terminal open state (adds `{:attended, :cancelled}` /
     `{:attended, :registered}` to the edge list): the refusals after the
     walk are the observable difference.
  5. `forward_edges/0` contract — kills the mutant that edits the edge
     list in a way both add and remove (net-zero on tests 1-2), and pins
     the module's published introspection surface other code may read.
  """

  use ExUnit.Case, async: false

  alias Xaas.Conference.{Attendee, Event, Registration, Session, Speaker, Track}
  alias Xaas.Conference.Validations.RegistrationStatusTransition

  setup do
    for res <- [Registration, Session, Track, Speaker, Attendee, Event] do
      Ash.bulk_destroy!(res, :destroy, %{}, authorize?: false)
    end
    :ok
  end

  defp attendee!(name) do
    Attendee
    |> Ash.Changeset.for_create(:create, %{name: name, email: "#{name}-w650y4@example.test"},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  defp session!(title) do
    event =
      Event
      |> Ash.Changeset.for_create(:create, %{
        name: "AGNTCon W650y4",
        slug: "agntcon-w650y4-#{System.unique_integer([:positive])}"
      }, authorize?: false)
      |> Ash.create!(authorize?: false)

    track =
      Track
      |> Ash.Changeset.for_create(:create, %{
        name: "Courts",
        slug: "courts-w650y4-#{System.unique_integer([:positive])}",
        event_id: event.id
      }, authorize?: false)
      |> Ash.create!(authorize?: false)

    speaker =
      Speaker
      |> Ash.Changeset.for_create(:create, %{
        name: "Court Speaker",
        slug: "speaker-w650y4-#{System.unique_integer([:positive])}"
      }, authorize?: false)
      |> Ash.create!(authorize?: false)

    Session
    |> Ash.Changeset.for_create(:create, %{
      title: title,
      slug: "session-w650y4-#{System.unique_integer([:positive])}",
      track_id: track.id,
      speaker_id: speaker.id,
      capacity: nil
    })
    |> Ash.create!(authorize?: false)
  end

  defp reg!(attendee, session, status) do
    Registration
    |> Ash.Changeset.for_create(:create, %{
      attendee_id: attendee.id,
      session_id: session.id,
      status: status
    }, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  defp update_status(reg, status) do
    reg
    |> Ash.Changeset.for_update(:update, %{status: status}, authorize?: false)
    |> Ash.update!(authorize?: false)
  end

  test "1. forward-edge matrix: all three admitted edges persist through :update" do
    s = session!("y4-forward-edges")

    for {{from, to}, i} <- Enum.with_index(RegistrationStatusTransition.forward_edges()) do
      # one fresh attendee per row: the active-duplicate identity guard
      # refuses a second ACTIVE (attendee, session) row.
      reg = reg!(attendee!("y4-fwd-#{i}"), s, from)
      assert reg.status == from

      updated = update_status(reg, to)

      assert updated.status == to
      assert %{status: ^to} = Ash.get!(Registration, reg.id, authorize?: false)
    end
  end

  test "2. illegal edges are refused with a typed message and persist nothing" do
    s = session!("y4-illegal-edges")

    illegal = [
      {:cancelled, :registered},
      {:attended, :registered},
      {:attended, :cancelled}
    ]

    for {{from, to}, i} <- Enum.with_index(illegal) do
      reg = reg!(attendee!("y4-illegal-#{i}"), s, from)

      assert_raise Ash.Error.Invalid,
                   ~r/not an admitted forward edge/,
                   fn -> update_status(reg, to) end

      # Real state: the refusal left the row at its prior status.
      assert %{status: ^from} = Ash.get!(Registration, reg.id, authorize?: false)
    end
  end

  test "3. self-transition {s, s} is admitted in all three states" do
    s = session!("y4-self-transitions")

    for {status, i} <- Enum.with_index([:registered, :cancelled, :attended]) do
      reg = reg!(attendee!("y4-self-#{i}"), s, status)
      updated = update_status(reg, status)

      assert updated.status == status
      assert %{status: ^status} = Ash.get!(Registration, reg.id, authorize?: false)
    end
  end

  test "4. one-shot attendance: after registered -> attended only self-edges succeed" do
    a = attendee!("y4-oneshot")
    s = session!("y4-one-shot")

    reg = reg!(a, s, :registered)
    attended = update_status(reg, :attended)
    assert attended.status == :attended

    # Every non-self target from :attended is now refused, one walk only.
    for to <- [:registered, :cancelled] do
      assert_raise Ash.Error.Invalid,
                   ~r/not an admitted forward edge/,
                   fn -> update_status(attended, to) end
    end

    # ...while the artifacts-only self-update stays admitted.
    assert %{status: :attended} = update_status(attended, :attended)
    assert %{status: :attended} = Ash.get!(Registration, reg.id, authorize?: false)
  end

  test "5. forward_edges/0 matches the documented lifecycle contract exactly" do
    # Introspection surface: kills an edge-list mutant that both adds and
    # removes an edge (invisible to tests 1/2 individually since they
    # iterate the published list / its complement).
    assert Enum.sort(RegistrationStatusTransition.forward_edges()) ==
             Enum.sort([{:registered, :cancelled}, {:registered, :attended}, {:cancelled, :attended}])

    # And the guard refuses a pair absent from that same published list,
    # proving the runtime guard and the introspection share one source.
    a = attendee!("y4-contract")
    s = session!("y4-contract")

    reg = reg!(a, s, :attended)

    assert_raise Ash.Error.Invalid, ~r/attended -> :cancelled/, fn ->
      update_status(reg, :cancelled)
    end
  end
end
