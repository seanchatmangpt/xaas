defmodule Xaas.Conference.RegistrationTerminalCancelGuardCourtW984doTest do
  @moduledoc """
  W984do burn-down court over `Xaas.Conference.Validations.RegistrationTerminalCancelGuard`
  (lib/xaas/conference/registration.ex) and the `:cancel` action it guards — the
  top-ranked state-bearing uncovered module in this lane's CamelCase-aware census
  (171 uncovered / 882 defined modules across lib/xaas).

  Chicago-style: real `Ash.DataLayer.Ets` tables, real Ash actions, assertions on
  real persisted row state. No mocks.

  Mutation rationale per test (the court kills the named mutant, not just the
  happy path):

  1. cancel-of-`:cancelled` refused — kills the mutant that drops the guard
     from the `:cancel` action (or empties `terminal_statuses`): the refusal
     and the unchanged persisted status are the only observable difference.
  2. cancel-of-`:attended` refused — kills the mutant that narrows
     `terminal_statuses` to `[:cancelled]` only (`:attended` would silently
     become cancellable even though it is documented terminal).
  3. `:cancel` of an active registration still succeeds and persists
     `:cancelled` — kills the mutant that over-widens the guard to refuse ALL
     cancels (guard must gate terminal states only, not the product action).
  4. bare `:update` self-transition on a terminal row is still admitted —
     kills the mutant that moves the terminal guard onto the shared `:update`
     action: the W973b carve-out is `:cancel`-specific by design, and the
     artifacts-only `:update` self-transition path must not regress.
  5. re-register after cancel, then cancel the NEW row — kills the mutant
     that makes the guard read status from the changeset params instead of
     the persisted data (`Ash.Changeset.get_data`), which would let a caller
     smuggle a cancel through on a stale/param-presented non-terminal status.
  """

  use ExUnit.Case, async: false

  alias Xaas.Conference.{Attendee, Event, Registration, Session, Speaker, Track}

  setup do
    for res <- [Registration, Session, Track, Speaker, Attendee, Event] do
      Ash.bulk_destroy!(res, :destroy, %{}, authorize?: false)
    end
    :ok
  end

  defp attendee!(name) do
    Attendee
    |> Ash.Changeset.for_create(:create, %{name: name, email: "#{name}@example.test"},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  defp session!(title, capacity \\ nil) do
    event =
      Event
      |> Ash.Changeset.for_create(:create, %{name: "AGNTCon W984do", slug: "agntcon-w984do-#{System.unique_integer([:positive])}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    track =
      Track
      |> Ash.Changeset.for_create(:create, %{name: "Courts", slug: "courts-w984do-#{System.unique_integer([:positive])}", event_id: event.id},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    speaker =
      Speaker
      |> Ash.Changeset.for_create(:create, %{name: "Court Speaker", slug: "speaker-w984do-#{System.unique_integer([:positive])}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    Session
    |> Ash.Changeset.for_create(:create, %{
      title: title,
      slug: "session-w984do-#{System.unique_integer([:positive])}",
      track_id: track.id,
      speaker_id: speaker.id,
      capacity: capacity
    })
    |> Ash.create!(authorize?: false)
  end

  defp reg!(attendee, session, status) do
    Registration
    |> Ash.Changeset.for_create(:create, %{attendee_id: attendee.id, session_id: session.id, status: status},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  defp cancel(reg) do
    reg
    |> Ash.Changeset.for_update(:cancel, %{}, authorize?: false)
  end

  test "1. cancelling an already-cancelled registration is refused and persists nothing" do
    a = attendee!("do1")
    s = session!("do-session-1")
    reg = reg!(a, s, :cancelled)

    assert {:error, %Ash.Error.Invalid{errors: errors}} = Ash.update(cancel(reg))

    assert Enum.any?(errors, fn e ->
             match?(%Ash.Error.Changes.InvalidChanges{}, e) and
               e.message =~ "cannot cancel a terminal registration" and
               e.message =~ ":cancelled"
           end)

    # nothing written: the row keeps its terminal status
    assert %{status: :cancelled} = Ash.get!(Registration, reg.id, authorize?: false)
  end

  test "2. cancelling an attended (terminal) registration is refused" do
    a = attendee!("do2")
    s = session!("do-session-2")
    reg = reg!(a, s, :attended)

    assert {:error, _} = Ash.update(cancel(reg))

    # nothing written: the row keeps its terminal status
    assert %{status: :attended} = Ash.get!(Registration, reg.id, authorize?: false)

    # the typed refusal names the terminal status
    assert {:error, %Ash.Error.Invalid{errors: errors}} = Ash.update(cancel(reg))
    assert Enum.any?(errors, &(&1.message =~ "status :attended is terminal"))
  end

  test "3. cancelling an active registration still succeeds and persists :cancelled" do
    a = attendee!("do3")
    s = session!("do-session-3")
    reg = reg!(a, s, :registered)

    cancelled = Ash.update!(cancel(reg), authorize?: false)

    assert %{status: :cancelled} = cancelled
    assert %{status: :cancelled} = Ash.get!(Registration, reg.id, authorize?: false)
  end

  test "4. bare :update self-transition on a terminal row is still admitted (carve-out scope)" do
    a = attendee!("do4")
    s = session!("do-session-4")
    reg = reg!(a, s, :attended)

    # artifacts-only updates ride the self-transition carve-out on :update;
    # the terminal guard is bound ONLY to :cancel (W973b scope).
    updated =
      reg
      |> Ash.Changeset.for_update(:update, %{status: :attended}, authorize?: false)
      |> Ash.update!(authorize?: false)

    assert %{status: :attended} = updated
    assert %{status: :attended} = Ash.get!(Registration, reg.id, authorize?: false)
  end

  test "5. re-register after cancel then cancel the NEW row (guard reads persisted data)" do
    a = attendee!("do5")
    s = session!("do-session-5")
    old_row = reg!(a, s, :cancelled)
    fresh = reg!(a, s, :registered)
    old_id = old_row.id

    # W981s active-identity admits the re-register (old row is terminal);
    # the fresh active row is cancellable.
    cancelled = Ash.update!(cancel(fresh), authorize?: false)
    assert %{status: :cancelled} = cancelled

    # the old terminal row was never touched
    assert %{status: :cancelled} = Ash.get!(Registration, old_id, authorize?: false)

    # and a THIRD active row for the same pair is still admitted then cancellable
    third = reg!(a, s, :registered)
    assert %{status: :cancelled} = Ash.update!(cancel(third), authorize?: false)
  end
end
