defmodule Xaas.Ultracode.RemainderCourtW984hiTest do
  @moduledoc """
  W984hi unclaimed-family probe court for the ultracode remainder (outside
  provider_mesh, outside the validations family, outside semantic_drive /
  semantic_wave_trigger, which other lanes own).

  Censused dispositions live in docs/sjira/v26.10.6/plans/w984hi-probe.md.
  This file courts the branches the census found genuinely unexercised:

    * `Changes.ExtendCycleBudget` never-shrink arm — the existing
      `closure_controller_test` asserts only `max_cycles >= cycle + n`,
      which a shrinking implementation (plain `cycle + additional`
      assignment) can pass.
    * `Changes.RevokeLiveLeases` expired-lease arm — engine_test's stop
      court exercises only the live-lease revocation; the branch that
      deliberately SKIPS an expired lease (leaving the epoch and its lease
      row untouched, no receipt) has no witness anywhere in test/.
    * `Changes.SetTerminalAt` non-terminal arm on the suspend /
      resume_frontier path, which no other test walks.

  Chicago: real Repo, real Ash actions, real Lease kernel, zero doubles.
  """

  use ExUnit.Case, async: true

  @moduletag :ultracode

  require Ash.Query

  alias Xaas.Ultracode.{Epoch, Receipt, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp run!(max_cycles) do
    Run
    |> Ash.Changeset.for_create(:create, %{goal: "w984hi remainder court", max_cycles: max_cycles},
      authorize?: false
    )
    |> Ash.create!()
    |> Ash.Changeset.for_update(:transition_state, %{state: :running}, authorize?: false)
    |> Ash.update!()
  end

  defp leased_epoch!(run, opts) do
    expires_in = Keyword.fetch!(opts, :expires_in)
    tenant = "w984hi-#{System.unique_integer()}"

    epoch =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "w984hi-#{System.unique_integer()}",
          state: :running
        },
        authorize?: false,
        tenant: tenant
      )
      |> Ash.create!()

    epoch
    |> Ash.Changeset.for_update(
      :lease,
      %{
        lease_token: "tok-w984hi-#{System.unique_integer()}",
        lease_expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)
      },
      authorize?: false,
      tenant: tenant
    )
    |> Ash.update!()
  end

  test "resume_frontier never shrinks an existing larger max_cycles (ExtendCycleBudget max arm)" do
    # Mutation rationale: replacing max(current, cycle + additional) with a
    # plain assignment cycle + additional passes closure_controller_test's
    # `>=` assertion while shrinking the budget of a run that already has
    # more headroom — resumption must never reduce remaining cycles.
    run = run!(10)

    suspended =
      run
      |> Ash.Changeset.for_update(:transition_state, %{state: :suspended}, authorize?: false)
      |> Ash.update!()

    # SetTerminalAt non-terminal arm: a suspend edge persists no closing
    # moment; terminal_at must remain nil (the run is not closed).
    assert is_nil(suspended.terminal_at)

    assert {:ok, resumed} =
             suspended
             |> Ash.Changeset.for_update(:resume_frontier, %{additional_cycles: 1},
               authorize?: false
             )
             |> Ash.update()

    assert resumed.state == :running
    assert resumed.max_cycles == 10

    # The non-terminal resume edge persists no closing moment either.
    assert is_nil(resumed.terminal_at)
  end

  test "resume_frontier grows from below (ExtendCycleBudget grow arm, exact)" do
    # Mutation rationale: an implementation that ignores additional_cycles
    # (or clamps to the current max_cycles) passes a `>= cycle` assertion
    # but never re-arms; this pins the exact grown bound.
    run = run!(1)

    suspended =
      run
      |> Ash.Changeset.for_update(:transition_state, %{state: :suspended}, authorize?: false)
      |> Ash.update!()

    assert {:ok, resumed} =
             suspended
             |> Ash.Changeset.for_update(:resume_frontier, %{additional_cycles: 3},
               authorize?: false
             )
             |> Ash.update()

    # max(current = 1, cycle = 0 + 3) == 3
    assert resumed.max_cycles == 3
  end

  test "stop skips an expired lease (RevokeLiveLeases expired arm) while revoking a live one" do
    # Mutation rationale: dropping the `not live? -> false` branch would
    # refuse expired leases too, disturbing epochs that already settled
    # lawfully; no existing test distinguishes the two arms on one run.
    run = run!(5)
    live_epoch = leased_epoch!(run, expires_in: 30 * 60)
    expired_epoch = leased_epoch!(run, expires_in: -60)

    stopped =
      run
      |> Ash.Changeset.for_update(:stop, %{}, authorize?: false)
      |> Ash.update!()

    assert stopped.state == :abandoned

    reloaded_live = Ash.get!(Epoch, live_epoch.id, action: :read_unscoped, authorize?: false)
    assert reloaded_live.state == :failed

    reloaded_expired =
      Ash.get!(Epoch, expired_epoch.id, action: :read_unscoped, authorize?: false)

    assert reloaded_expired.state == :running

    {:ok, receipts} =
      Receipt
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(epoch_id == ^live_epoch.id or epoch_id == ^expired_epoch.id)
      |> Ash.read(authorize?: false)

    live_refusals =
      Enum.filter(receipts, fn r ->
        r.outcome == :refused and r.evidence["refusal_reason"] == "run_stopped"
      end)

    assert length(live_refusals) == 1
    assert Enum.all?(receipts, &(&1.epoch_id == live_epoch.id))
  end
end
