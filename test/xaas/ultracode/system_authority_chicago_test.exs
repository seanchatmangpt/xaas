defmodule Xaas.Ultracode.SystemAuthorityChicagoTest do
  @moduledoc """
  Chicago-school proof closing XAAS-2601 (docs/jira/v26.9.15): the exact
  review falsifier -- invoke `Run.transition_state` (and its sibling
  internal-only mutations) as an ordinary non-system actor through real Ash
  authorization -- must now be REFUSED, where the previous action-wide
  `bypass ... authorize_if(always())` authorized any caller at all.

  Extended by the wave-4 authority tightening (XAAS-2601/2602 completion):
  every ultracode schedule clock and internal bookkeeping/lifecycle action
  that still carried a scoped `authorize_if(always())` bypass
  (`:autonomic_wave`, `:semantic_wave`, `:engine_cycle`, `:wave_loop`,
  `:begin_wave_session`, `:record_wave`, `:stop`, `:resume`, and the Epoch
  lease family) is now a canonical `Xaas.Checks.SystemActor` subject, and
  each newly-mapped action gets its exact-classification cases here:
  allowed-for-its-service, refused-for-ambient (ordinary actor AND nil
  actor), and refused-for-a-wrong-genuine-service.

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
    |> Ash.Changeset.for_update(:transition_state, %{state: :running}, authorize?: false)
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

      # And the real row never moved. (Run's `:attribute` multitenancy
      # retrofit requires a tenant on the default `:read`; the tenant-free
      # verification read is `:read_unscoped`, matching the rest of this
      # suite's internal call sites.)
      assert Ash.get!(Run, run.id, action: :read_unscoped, authorize?: false).state == :pending
    end

    test "Run.transition_state refuses a nil actor (any anonymous caller)" do
      run = pending_run!("falsifier: nil actor must be refused")

      assert {:error, %Ash.Error.Forbidden{}} =
               run
               |> Ash.Changeset.for_update(:transition_state, %{state: :running})
               |> Ash.update()

      assert Ash.get!(Run, run.id, action: :read_unscoped, authorize?: false).state == :pending
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
          %{
            run_id: run.id,
            cycle: run.cycle,
            exact_subject: "falsifier-subject",
            state: :expected
          },
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
      _run = running_run!("falsifier: receipt seal for ordinary actors")

      # :blocked (a standing-family outcome with no vocabulary guard) so the
      # refusal this falsifier proves is the AUTHORITY floor's Forbidden --
      # the receipt-vocabulary guard (`Validations.AliveRequiresCourt`)
      # would otherwise fire first on an evidence-less :alive and return
      # Invalid instead.
      assert {:error, %Ash.Error.Forbidden{}} =
               Receipt
               |> Ash.Changeset.for_create(:seal, %{
                 epoch_id: Ash.UUIDv7.generate(),
                 subject: "falsifier-subject",
                 outcome: :blocked,
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

  # ------------------------------------------------------------------
  # Wave-4 authority tightening (XAAS-2601/2602 completion): the seven
  # actions below lost their scoped `authorize_if(always())` bypasses and
  # are now canonical SystemActor subjects. Every classification case is
  # proved against the real policy calculus, exactly like the falsifiers
  # above: real invocation refused for ambient actors (ordinary AND nil),
  # real admission for the mapped service, real refusal for a wrong
  # genuine service.
  # ------------------------------------------------------------------

  describe "wave-4: the schedule clocks are SystemActor subjects, not always() bypasses" do
    test "Run.autonomic_wave refuses an ordinary actor and a nil actor (real invocation)" do
      assert {:error, %Ash.Error.Forbidden{}} =
               Run
               |> Ash.ActionInput.for_action(:autonomic_wave, %{})
               |> Ash.run_action(actor: @ordinary_actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               Run
               |> Ash.ActionInput.for_action(:autonomic_wave, %{})
               |> Ash.run_action()
    end

    test "Run.semantic_wave refuses an ordinary actor and a nil actor (real invocation)" do
      assert {:error, %Ash.Error.Forbidden{}} =
               Run
               |> Ash.ActionInput.for_action(:semantic_wave, %{})
               |> Ash.run_action(actor: @ordinary_actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               Run
               |> Ash.ActionInput.for_action(:semantic_wave, %{})
               |> Ash.run_action()
    end

    test "Run.engine_cycle refuses an ordinary actor and a nil actor (real invocation)" do
      assert {:error, %Ash.Error.Forbidden{}} =
               Run
               |> Ash.ActionInput.for_action(:engine_cycle, %{})
               |> Ash.run_action(actor: @ordinary_actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               Run
               |> Ash.ActionInput.for_action(:engine_cycle, %{})
               |> Ash.run_action()
    end

    test "Run.wave_loop refuses an ordinary actor and a nil actor (real invocation)" do
      assert {:error, %Ash.Error.Forbidden{}} =
               Run
               |> Ash.ActionInput.for_action(:wave_loop, %{})
               |> Ash.run_action(actor: @ordinary_actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               Run
               |> Ash.ActionInput.for_action(:wave_loop, %{})
               |> Ash.run_action()
    end

    test "the four schedule clocks admit exactly the oban_scheduler service" do
      # Real policy calculus over the exact subjects -- no side effects,
      # the same `Ash.can?/2` engine the service-scope suite uses.
      for action <- [:autonomic_wave, :semantic_wave, :engine_cycle, :wave_loop] do
        input = Run |> Ash.ActionInput.for_action(action, %{})

        assert Ash.can?(input, Xaas.SystemAuthority.new(:oban_scheduler)),
               "oban_scheduler must be admitted on :#{action}"

        refute Ash.can?(input, Xaas.SystemAuthority.new(:ultracode_reactor)),
               "ultracode_reactor must NOT be admitted on :#{action}"

        refute Ash.can?(input, Xaas.SystemAuthority.new(:internal_api)),
               "internal_api must NOT be admitted on :#{action}"
      end
    end
  end

  describe "wave-4: duration-budget bookkeeping is scheduler-only" do
    test "begin_wave_session refuses ambient actors and admits only oban_scheduler (real mutation)" do
      refused_run = pending_run!("wave4: begin_wave_session refuses ambient actors")

      assert {:error, %Ash.Error.Forbidden{}} =
               refused_run
               |> Ash.Changeset.for_update(:begin_wave_session, %{})
               |> Ash.update(actor: @ordinary_actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               refused_run
               |> Ash.Changeset.for_update(:begin_wave_session, %{})
               |> Ash.update()

      # The real row never moved.
      assert Ash.get!(Run, refused_run.id, action: :read_unscoped, authorize?: false).state ==
               :pending

      # A genuine system actor from the WRONG service is refused too.
      assert {:error, %Ash.Error.Forbidden{}} =
               refused_run
               |> Ash.Changeset.for_update(:begin_wave_session, %{})
               |> Ash.update(actor: Xaas.SystemAuthority.new(:ultracode_reactor))

      admitted_run = pending_run!("wave4: begin_wave_session admits the scheduler")

      session =
        admitted_run
        |> Ash.Changeset.for_update(:begin_wave_session, %{})
        |> Ash.update!(actor: Xaas.SystemAuthority.new(:oban_scheduler))

      assert session.state == :running
      assert session.wave_session == true
      refute is_nil(session.started_at)
    end

    test "record_wave refuses ambient actors and admits only oban_scheduler (real mutation)" do
      session =
        pending_run!("wave4: record_wave classification")
        |> Ash.Changeset.for_update(:begin_wave_session, %{}, authorize?: false)
        |> Ash.update!()

      assert {:error, %Ash.Error.Forbidden{}} =
               session
               |> Ash.Changeset.for_update(:record_wave, %{})
               |> Ash.update(actor: @ordinary_actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               session
               |> Ash.Changeset.for_update(:record_wave, %{})
               |> Ash.update()

      assert {:error, %Ash.Error.Forbidden{}} =
               session
               |> Ash.Changeset.for_update(:record_wave, %{})
               |> Ash.update(actor: Xaas.SystemAuthority.new(:internal_api))

      recorded =
        session
        |> Ash.Changeset.for_update(:record_wave, %{})
        |> Ash.update!(actor: Xaas.SystemAuthority.new(:oban_scheduler))

      assert recorded.waves_run == 1
    end
  end

  describe "wave-4: lifecycle recovery is reactor-kernel-only" do
    test "stop refuses ambient actors and admits ultracode_reactor (real transition)" do
      refused_run = running_run!("wave4: stop refuses ambient actors")

      assert {:error, %Ash.Error.Forbidden{}} =
               refused_run
               |> Ash.Changeset.for_update(:stop, %{})
               |> Ash.update(actor: @ordinary_actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               refused_run
               |> Ash.Changeset.for_update(:stop, %{})
               |> Ash.update()

      assert Ash.get!(Run, refused_run.id, action: :read_unscoped, authorize?: false).state ==
               :running

      # The scheduler is NOT the lifecycle owner -- wrong genuine service.
      assert {:error, %Ash.Error.Forbidden{}} =
               refused_run
               |> Ash.Changeset.for_update(:stop, %{})
               |> Ash.update(actor: Xaas.SystemAuthority.new(:oban_scheduler))

      admitted_run = running_run!("wave4: stop admits the reactor kernel")

      stopped =
        admitted_run
        |> Ash.Changeset.for_update(:stop, %{})
        |> Ash.update!(actor: Xaas.SystemAuthority.new(:ultracode_reactor))

      assert stopped.state == :abandoned
    end

    test "resume refuses ambient actors and admits ultracode_reactor (real re-arm)" do
      abandoned =
        running_run!("wave4: resume classification")
        |> Ash.Changeset.for_update(:stop, %{}, authorize?: false)
        |> Ash.update!()

      assert {:error, %Ash.Error.Forbidden{}} =
               abandoned
               |> Ash.Changeset.for_update(:resume, %{})
               |> Ash.update(actor: @ordinary_actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               abandoned
               |> Ash.Changeset.for_update(:resume, %{})
               |> Ash.update()

      assert {:error, %Ash.Error.Forbidden{}} =
               abandoned
               |> Ash.Changeset.for_update(:resume, %{})
               |> Ash.update(actor: Xaas.SystemAuthority.new(:oban_scheduler))

      resumed =
        abandoned
        |> Ash.Changeset.for_update(:resume, %{})
        |> Ash.update!(actor: Xaas.SystemAuthority.new(:ultracode_reactor))

      assert resumed.state == :running
    end
  end

  describe "wave-4: the Epoch lease family is reactor-kernel-only" do
    defp running_epoch!(goal) do
      run = running_run!(goal)

      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: run.cycle,
          exact_subject: "wave4-lease-family",
          state: :expected
        },
        authorize?: false
      )
      |> Ash.create!()
      |> Ash.Changeset.for_update(:start, %{})
      |> Ash.update!(actor: Xaas.SystemAuthority.new(:ultracode_reactor))
    end

    # `Epoch.:lease` is the one update action on this resource that is
    # `multitenancy(:allow_global)` instead of `:bypass` -- and Ash 3.33.1's
    # UPDATE pipeline has a second, later tenant checkpoint whose guard does
    # not honor `:allow_global`, so ANY tenant-free authorized `:lease` call
    # raises `TenantRequired` before a row can ever move (this is exactly
    # why the action has no real caller left: `Lease`'s raw atomic row
    # writes replaced it). The admission proof below therefore exercises
    # `:lease` the way a real org-scoped caller must: with an org-bearing
    # row and an explicit tenant.
    defp org_running_epoch!(goal) do
      run =
        Run
        |> Ash.Changeset.for_create(
          :create,
          %{goal: goal, max_cycles: 2, org_id: "org_wave4"},
          authorize?: false
        )
        |> Ash.create!()

      run
      |> Ash.Changeset.for_update(:transition_state, %{state: :running}, authorize?: false)
      |> Ash.update!()

      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          org_id: "org_wave4",
          cycle: run.cycle,
          exact_subject: "wave4-lease-family",
          state: :expected
        },
        authorize?: false
      )
      |> Ash.create!()
      |> Ash.Changeset.for_update(:start, %{})
      |> Ash.update!(actor: Xaas.SystemAuthority.new(:ultracode_reactor))
    end

    defp lease_attrs do
      %{
        lease_token: "wave4-classification-token",
        lease_expires_at: DateTime.add(DateTime.utc_now(), 30, :minute),
        leased_to: "wave4-worker"
      }
    end

    test "Epoch.lease refuses ambient actors and a wrong genuine service" do
      epoch = running_epoch!("wave4: lease refuses ambient actors")

      assert {:error, %Ash.Error.Forbidden{}} =
               epoch
               |> Ash.Changeset.for_update(:lease, lease_attrs())
               |> Ash.update(actor: @ordinary_actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               epoch
               |> Ash.Changeset.for_update(:lease, lease_attrs())
               |> Ash.update()

      assert {:error, %Ash.Error.Forbidden{}} =
               epoch
               |> Ash.Changeset.for_update(:lease, lease_attrs())
               |> Ash.update(actor: Xaas.SystemAuthority.new(:oban_scheduler))

      reloaded = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
      assert is_nil(reloaded.lease_token)
    end

    test "Epoch.lease / renew_lease / record_final_head admit only ultracode_reactor (real mutations)" do
      epoch = org_running_epoch!("wave4: lease family admits the reactor kernel")
      tenant = "org_wave4"

      leased =
        epoch
        |> Ash.Changeset.for_update(:lease, lease_attrs())
        |> Ash.update!(actor: Xaas.SystemAuthority.new(:ultracode_reactor), tenant: tenant)

      assert leased.lease_token == "wave4-classification-token"
      assert leased.leased_to == "wave4-worker"

      renewed =
        leased
        |> Ash.Changeset.for_update(:renew_lease, %{
          lease_expires_at: DateTime.add(DateTime.utc_now(), 60, :minute)
        })
        |> Ash.update!(actor: Xaas.SystemAuthority.new(:ultracode_reactor), tenant: tenant)

      assert DateTime.compare(renewed.lease_expires_at, leased.lease_expires_at) == :gt

      closed =
        renewed
        |> Ash.Changeset.for_update(:record_final_head, %{final_head: "wave4finalhead"})
        |> Ash.update!(actor: Xaas.SystemAuthority.new(:ultracode_reactor), tenant: tenant)

      assert closed.final_head == "wave4finalhead"

      # And the calculus is not membership: the scheduler service cannot
      # lease, even org-scoped.
      refute Ash.can?(
               epoch |> Ash.Changeset.for_update(:lease, lease_attrs()),
               Xaas.SystemAuthority.new(:oban_scheduler)
             )
    end
  end
end
