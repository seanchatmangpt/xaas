defmodule Xaas.Ultracode.SystemAuthorityChicagoTest do
  @moduledoc """
  Chicago-school proof closing XAAS-2601 (docs/jira/v26.9.15): the exact
  review falsifier -- invoke `Run.transition_state` (and its sibling
  internal-only mutations) as an ordinary non-system actor through real Ash
  authorization -- must now be REFUSED, where the previous action-wide
  `bypass ... authorize_if(always())` authorized any caller at all.

  Everything real: real Postgres via `Ecto.Adapters.SQL.Sandbox` over
  `Xaas.Repo`, real Ash resources with the real `Ash.Policy.Authorizer`
  calculus, real `Xaas.Checks.SystemActor` SimpleCheck, and a real
  fabricated ORDINARY actor (`%{id: ..., org_id: ...}` -- the map shape
  every other actor-check in this repo consumes), not a mock.
  """

  use ExUnit.Case, async: true

  @moduletag :ultracode

  alias Xaas.Ultracode.{Epoch, Receipt, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp pending_run!(goal) do
    Run
    |> Ash.Changeset.for_create(:create, %{goal: goal, max_cycles: 2}, authorize?: false)
    |> Ash.create!()
  end

  defp running_run!(goal) do
    pending_run!(goal)
    |> Ash.Changeset.for_update(:transition_state, %{state: :running},
      authorize?: false
    )
    |> Ash.update!()
  end

  # An ORDINARY actor: a plausible, well-formed caller identity carrying
  # exactly the fields this repo's real actor checks read -- and none of
  # them is a system authority. This is the actor the review's falsifier
  # names: "invoke transition_state as an ordinary non-system actor through
  # Ash authorization. It must be refused."
  @ordinary_actor %{id: "user_12345", org_id: "org_normal", role: :member}

  describe "the review falsifier: ordinary actors are refused on internal-only mutations" do
    test "Run.transition_state refuses an ordinary non-system actor" do
      run = pending_run!("falsifier: ordinary actor must be refused")

      assert {:error, %Ash.Error.Forbidden{}} =
               run
               |> Ash.Changeset.for_update(:transition_state, %{state: :running})
               |> Ash.update(actor: @ordinary_actor)

      # And the real row never moved.
      assert Ash.get!(Run, run.id, authorize?: false).state == :pending
    end

    test "Run.transition_state refuses a nil actor (any anonymous caller)" do
      run = pending_run!("falsifier: nil actor must be refused")

      assert {:error, %Ash.Error.Forbidden{}} =
               run
               |> Ash.Changeset.for_update(:transition_state, %{state: :running})
               |> Ash.update()

      assert Ash.get!(Run, run.id, authorize?: false).state == :pending
    end

    test "Run.advance_cycle and Run.tick refuse an ordinary actor" do
      run = running_run!("falsifier: advance_cycle for ordinary actors")

      assert {:error, %Ash.Error.Forbidden{}} =
               run
               |> Ash.Changeset.for_update(:advance_cycle, %{})
               |> Ash.update(actor: @ordinary_actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               Run
               |> Ash.ActionInput.for_action(:tick, %{})
               |> Ash.run_action(actor: @ordinary_actor)
    end

    test "Epoch.start and Epoch.mark_missed refuse an ordinary actor" do
      run = running_run!("falsifier: epoch mutations for ordinary actors")

      epoch =
        Epoch
        |> Ash.Changeset.for_create(
          :create,
          %{run_id: run.id, cycle: run.cycle, exact_subject: "falsifier-subject", state: :expected},
          authorize?: false
        )
        |> Ash.create!()

      assert {:error, %Ash.Error.Forbidden{}} =
               epoch
               |> Ash.Changeset.for_update(:start, %{})
               |> Ash.update(actor: @ordinary_actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               epoch
               |> Ash.Changeset.for_update(:mark_missed, %{})
               |> Ash.update(actor: @ordinary_actor)
    end

    test "Receipt.seal refuses an ordinary actor" do
      run = running_run!("falsifier: receipt seal for ordinary actors")

      assert {:error, %Ash.Error.Forbidden{}} =
               Receipt
               |> Ash.Changeset.for_create(:seal, %{
                 epoch_id: Ash.UUIDv7.generate(),
                 subject: "falsifier-subject",
                 outcome: :alive,
                 evidence: %{},
                 sealed_at: DateTime.utc_now()
               })
               |> Ash.create(actor: @ordinary_actor)
    end

    test "WebhookDelivery.retry_failed_deliveries refuses an ordinary actor" do
      assert {:error, %Ash.Error.Forbidden{}} =
               Xaas.Platform.WebhookDelivery
               |> Ash.ActionInput.for_action(:retry_failed_deliveries, %{})
               |> Ash.run_action(actor: @ordinary_actor)
    end

    test "HoldRequest.expire_stale refuses an ordinary actor" do
      assert {:error, %Ash.Error.Forbidden{}} =
               Xaas.Library.HoldRequest
               |> Ash.ActionInput.for_action(:expire_stale, %{})
               |> Ash.run_action(actor: @ordinary_actor)
    end
  end

  describe "the real system authority actor is admitted" do
    test "Run.transition_state admits the system actor and performs the real transition" do
      run = pending_run!("admission: system actor may transition")

      updated =
        run
        |> Ash.Changeset.for_update(:transition_state, %{state: :running})
        |> Ash.update!(actor: Xaas.SystemAuthority.new(:ultracode_reactor))

      assert updated.state == :running
    end

    test "the SystemActor check narrows admission by service when asked (calculus is real, not membership)" do
      # The check's :service option is a real predicate over the actor's
      # service field -- proven by admitting a matching service and
      # refusing a non-matching one against the check itself.
      assert Xaas.Checks.SystemActor.match?(
               Xaas.SystemAuthority.new(:ultracode_reactor),
               %{subject: %{}},
               service: :ultracode_reactor
             )

      refute Xaas.Checks.SystemActor.match?(
               Xaas.SystemAuthority.new(:webhook_dispatcher),
               %{subject: %{}},
               service: :ultracode_reactor
             )

      # Fail-closed for every non-system term.
      refute Xaas.Checks.SystemActor.match?(@ordinary_actor, %{subject: %{}}, [])
      refute Xaas.Checks.SystemActor.match?(nil, %{subject: %{}}, [])
      refute Xaas.SystemAuthority.system?(%{service: :ultracode_reactor})
    end

    test "a fabricated lookalike actor (plain map carrying the same fields) is NOT a system authority" do
      run = pending_run!("falsifier: lookalike actor must be refused")

      lookalike = %{service: :ultracode_reactor, id: "fake", org_id: "org_fabricated"}

      assert {:error, %Ash.Error.Forbidden{}} =
               run
               |> Ash.Changeset.for_update(:transition_state, %{state: :running})
               |> Ash.update(actor: lookalike)
    end
  end
end
