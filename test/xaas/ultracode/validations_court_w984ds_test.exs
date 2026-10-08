defmodule Xaas.Ultracode.ValidationsCourtW984dsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  @moduletag :ultracode

  alias Xaas.Ultracode.{Epoch, Receipt, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp run!(goal) do
    Run
    |> Ash.Changeset.for_create(:create, %{goal: goal, max_cycles: 3}, authorize?: false)
    |> Ash.create!()
  end

  defp epoch!(run, state, cycle \\ 0) do
    Epoch
    |> Ash.Changeset.for_create(
      :create,
      %{run_id: run.id, cycle: cycle, exact_subject: "w984ds", state: state, org_id: "w984ds-court"},
      authorize?: false
    )
    |> Ash.create!()
  end

  defp upd!(record, action, params \\ %{}) do
    # `:lease`/`:renew_lease` are `multitenancy(:allow_global)` actions but
    # still hit Ash's second update-pipeline tenant checkpoint; supplying a
    # tenant satisfies it and :allow_global ignores the value.
    opts =
      if action in [:lease, :renew_lease],
        do: [authorize?: false, tenant: "w984ds-court"],
        else: [authorize?: false]

    record
    |> Ash.Changeset.for_update(action, params, opts)
    |> Ash.update!()
  end

  defp refusal_text(fun) do
    try do
      fun.()
      flunk("expected typed refusal, got success")
    rescue
      e in Ash.Error.Invalid ->
        Enum.map_join(e.errors, "; ", fn err -> err.message || to_string(err) end)
    end
  end

  # 1. EpochTransitionAllowed
  test "epoch complete from expected refused, from running admitted" do
    run = run!("w984ds epoch transition court")
    expected = epoch!(run, :expected)

    text = refusal_text(fn -> upd!(expected, :complete, %{final_head: "abc123"}) end)
    assert text =~ "epoch must be in [:running]"

    running = epoch!(run, :running, 1)
    completed = upd!(running, :complete, %{final_head: "abc123"})
    assert completed.state == :completed
  end

  # 2. EpochTransitionAllowed (mark_missed)
  test "epoch mark_missed from running admitted, from completed refused" do
    run = run!("w984ds mark missed court")
    running = epoch!(run, :expected) |> upd!(:start)
    missed = upd!(running, :mark_missed)
    assert missed.state == :missed

    completed = epoch!(run, :completed, 1)
    text = refusal_text(fn -> upd!(completed, :mark_missed) end)
    assert text =~ "epoch must be in"
    assert text =~ ":expected"
    assert text =~ ":running"
  end

  # 3. RunTransitionAllowed
  test "run transition_state refuses non-admitted edge, admits listed edge" do
    run = run!("w984ds run transition court")

    text = refusal_text(fn ->
      run
      |> Ash.Changeset.for_update(:transition_state, %{state: :completed}, authorize?: false)
      |> Ash.update!()
    end)

    assert text =~ "is not an admitted edge"

    run2 = run!("w984ds run transition court 2")
    running2 = upd!(run2, :start, %{exact_subject: "w984ds"})

    suspended =
      running2
      |> Ash.Changeset.for_update(:transition_state, %{state: :suspended}, authorize?: false)
      |> Ash.update!()

    assert suspended.state == :suspended

    completed =
      suspended
      |> Ash.Changeset.for_update(:transition_state, %{state: :completed}, authorize?: false)
      |> Ash.update!()

    assert completed.state == :completed
  end

  # 4. AliveRequiresCourt
  test "receipt alive without court refused, with court admitted" do
    run = run!("w984ds alive requires court")
    epoch = epoch!(run, :running)

    text = refusal_text(fn ->
      Receipt
      |> Ash.Changeset.for_create(
        :seal,
        %{epoch_id: epoch.id, subject: "w984ds", outcome: :alive, evidence: %{}},
        authorize?: false
      )
      |> Ash.create!()
    end)

    assert text =~ "REFUSED_ALIVE_WITHOUT_COURT"

    admitted =
      Receipt
      |> Ash.Changeset.for_create(
        :seal,
        %{
          epoch_id: epoch.id,
          subject: "w984ds",
          outcome: :alive,
          evidence: %{"head_verified" => true, "fabric_verifier" => %{"status" => "pass"}}
        },
        authorize?: false
      )
      |> Ash.create!()

    assert admitted.outcome == :alive
  end

  # 5. LeaseAvailable
  test "epoch lease fenced by wrong state and live lease, expired lease admits" do
    run = run!("w984ds lease fencing court")
    expected = epoch!(run, :expected)

    text = refusal_text(fn -> upd!(expected, :lease) end)
    assert text =~ "lease requires a running epoch"

    running = upd!(expected, :start)

    leased =
      upd!(running, :lease, %{
        lease_token: "tok-1",
        lease_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        leased_to: "w1"
      })

    text2 = refusal_text(fn ->
      upd!(leased, :lease, %{lease_token: "tok-2", lease_expires_at: DateTime.utc_now()})
    end)

    assert text2 =~ "epoch already holds a live lease"

    refreshed = Ash.reload!(leased, authorize?: false)
    expired =
      refreshed
      |> Ash.Changeset.for_update(:renew_lease,
        %{lease_expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)},
        authorize?: false
      )
      |> Ash.update!()

    reclaimed = upd!(expired, :lease, %{lease_token: "tok-3", lease_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)})
    assert reclaimed.lease_token == "tok-3"
  end
end
