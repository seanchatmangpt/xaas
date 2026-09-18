defmodule Xaas.Ultracode.AdversarialMultitenancyTest do
  @moduledoc """
  Independent adversarial falsifier for the multitenancy retrofit, written
  by a SEPARATE reviewing agent (not the implementer) against the real
  worktree code -- not a re-run of the implementer's own
  `multitenancy_isolation_test.exs`. Every attack below is real, executed,
  and observed against real Ecto.Adapters.SQL.Sandbox-backed Postgres rows;
  no mocks.

  Covers exactly the five attack classes the review task named:

    1. Raw `Ash.read!`/`Ash.get!` with NO tenant at all.
    2. Org A's tenant explicitly set, targeting org B's real row by id.
    3. The shared worker-pull path (`Lease.claim_next/2`) still sees and can
       claim EVERY org's ready work when called the way it always was (no
       tenant) -- a retrofit that "fixes" isolation by breaking the shared
       pool is not a correct fix.
    4. The `EpochReactor`/`Reactor` internal/system path still processes
       epochs across ALL orgs, not just one.
    5. Bypass attempts specific to Ash's real `:attribute` multitenancy
       semantics: does `:read_unscoped` (`multitenancy :allow_global`)
       genuinely filter when a tenant IS supplied (not just skip
       filtering), and does a relationship load sidestep the tenant filter
       when the parent record's own denormalized `org_id` has drifted from
       its related row's real owner (a confused-deputy shape).
  """

  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Ultracode.{Epoch, Lease, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_org!(slug) do
    Org
    |> Ash.Changeset.for_create(:create, %{name: slug, slug: slug}, authorize?: false)
    |> Ash.create!()
  end

  defp create_run!(org_or_nil, attrs \\ %{}) do
    org_id = if org_or_nil, do: org_or_nil.id, else: nil

    Run
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(%{goal: "adversarial probe run", org_id: org_id}, attrs),
      authorize?: false
    )
    |> Ash.create!()
  end

  defp transition_to_running!(run) do
    run
    |> Ash.Changeset.for_update(:transition_state, %{state: :running}, authorize?: false)
    |> Ash.update!()
  end

  defp create_epoch!(run, org_or_nil, attrs \\ %{}) do
    org_id = if org_or_nil, do: org_or_nil.id, else: nil

    Epoch
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          run_id: run.id,
          org_id: org_id,
          cycle: 0,
          exact_subject: "adversarial_multitenancy_probe",
          state: :expected,
          expected_at: DateTime.utc_now()
        },
        attrs
      ),
      authorize?: false
    )
    |> Ash.create!()
  end

  # ------------------------------------------------------------------
  # Attack 1: raw read, no tenant at all.
  # ------------------------------------------------------------------

  describe "attack 1: raw Ash.read!/Ash.get! with NO tenant" do
    test "Ash.read!(Epoch) with no tenant does NOT silently return every org's rows -- it raises" do
      org_a = create_org!("adv-a1-#{System.unique_integer([:positive])}")
      org_b = create_org!("adv-a2-#{System.unique_integer([:positive])}")
      run_a = create_run!(org_a)
      run_b = create_run!(org_b)
      _epoch_a = create_epoch!(run_a, org_a)
      _epoch_b = create_epoch!(run_b, org_b)

      # The exact falsifier: before the retrofit this would have returned
      # BOTH orgs' epochs in one unscoped list. Real, executed, observed.
      assert_raise Ash.Error.Invalid, fn ->
        Ash.read!(Epoch, authorize?: false)
      end
    end

    test "Ash.get!(Epoch, real_id) with no tenant does NOT return the row" do
      org = create_org!("adv-a3-#{System.unique_integer([:positive])}")
      run = create_run!(org)
      epoch = create_epoch!(run, org)

      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(Epoch, epoch.id, authorize?: false)
      end
    end

    test "Ash.read!(Run) with no tenant raises too (not just Epoch)" do
      org = create_org!("adv-a4-#{System.unique_integer([:positive])}")
      _run = create_run!(org)

      assert_raise Ash.Error.Invalid, fn ->
        Ash.read!(Run, authorize?: false)
      end
    end
  end

  # ------------------------------------------------------------------
  # Attack 2: org A's tenant explicitly set, target org B's real row by id.
  # ------------------------------------------------------------------

  describe "attack 2: org A's tenant explicitly set, target org B's real id" do
    test "Ash.get! for org B's real epoch id, with org A's tenant, does not return org B's row" do
      org_a = create_org!("adv-b1-#{System.unique_integer([:positive])}")
      org_b = create_org!("adv-b2-#{System.unique_integer([:positive])}")
      run_b = create_run!(org_b)
      epoch_b = create_epoch!(run_b, org_b)

      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(Epoch, epoch_b.id, tenant: org_a.id, authorize?: false)
      end
    end

    test "a filtered Ash.Query for org B's real epoch id, tenant org A, returns EMPTY, not the row" do
      org_a = create_org!("adv-b3-#{System.unique_integer([:positive])}")
      org_b = create_org!("adv-b4-#{System.unique_integer([:positive])}")
      run_b = create_run!(org_b)
      epoch_b = create_epoch!(run_b, org_b)

      # Different code shape from Ash.get! -- explicit filter + explicit
      # tenant on a plain read, to rule out get!/read! having different
      # enforcement paths.
      results =
        Epoch
        |> Ash.Query.filter(id == ^epoch_b.id)
        |> Ash.read!(tenant: org_a.id, authorize?: false)

      assert results == []
    end

    test "a filter contradicting the tenant (tenant=A, filter run.org_id==B) still returns EMPTY, never a leak" do
      org_a = create_org!("adv-b5-#{System.unique_integer([:positive])}")
      org_b = create_org!("adv-b6-#{System.unique_integer([:positive])}")
      run_b = create_run!(org_b)
      epoch_b = create_epoch!(run_b, org_b)

      # Probes whether the tenant filter and an app-level filter are ANDed
      # (correct) or whether one can override the other (a real bypass if
      # the explicit filter won).
      results =
        Epoch
        |> Ash.Query.filter(id == ^epoch_b.id)
        |> Ash.read!(tenant: org_a.id, authorize?: false, action: :read_unscoped)

      # :read_unscoped + an explicit tenant: per the resource's own
      # moduledoc claim ("if a caller DOES supply a tenant, it still
      # filters by it"), this must ALSO come back empty -- org A's tenant
      # cannot see org B's row even through the internal action, as long as
      # a tenant is actually supplied.
      assert results == []
    end
  end

  # ------------------------------------------------------------------
  # Attack 3: shared worker-pull path must still see EVERY org's work.
  # ------------------------------------------------------------------

  describe "attack 3: Lease.claim_next/2 (shared worker pool) must NOT be broken by isolation" do
    test "claim_next with no tenant claims across MULTIPLE orgs' ready epochs, oldest first" do
      provider = "adv-shared-pool-#{System.unique_integer([:positive])}"

      org_a = create_org!("adv-c1-#{System.unique_integer([:positive])}")
      org_b = create_org!("adv-c2-#{System.unique_integer([:positive])}")

      run_a = create_run!(org_a, %{provider: provider})
      # Ensure a's epoch is strictly older (claim_next sorts inserted_at asc).
      epoch_a =
        create_epoch!(run_a, org_a, %{state: :running, exact_subject: "org-a-work"})

      Process.sleep(5)

      run_b = create_run!(org_b, %{provider: provider})

      epoch_b =
        create_epoch!(run_b, org_b, %{state: :running, exact_subject: "org-b-work"})

      # Real, observed: the FIRST claim (no tenant, exactly how every real
      # provider worker calls this) must be able to see org A's work.
      assert {:ok, leased_1, _token_1, run_ctx_1} = Lease.claim_next(provider, "worker-adv-1")
      assert leased_1.id == epoch_a.id
      assert run_ctx_1.id == run_a.id

      # The SECOND claim (org A's epoch is now leased) must STILL be able
      # to see org B's work -- proving the pool crosses orgs, not just that
      # the first call happened to work.
      assert {:ok, leased_2, _token_2, run_ctx_2} = Lease.claim_next(provider, "worker-adv-2")
      assert leased_2.id == epoch_b.id
      assert run_ctx_2.id == run_b.id

      # And now the pool is genuinely empty across both orgs.
      assert {:error, :no_ready_work} = Lease.claim_next(provider, "worker-adv-3")
    end
  end

  # ------------------------------------------------------------------
  # Attack 4: the internal/system Reactor path must process ALL orgs.
  # ------------------------------------------------------------------

  describe "attack 4: Xaas.Ultracode.Reactor (the real :tick body) advances epochs across ALL orgs" do
    test "running the full Reactor once transitions BOTH orgs' :expected epochs to :running" do
      org_a = create_org!("adv-d1-#{System.unique_integer([:positive])}")
      org_b = create_org!("adv-d2-#{System.unique_integer([:positive])}")

      run_a = create_run!(org_a) |> transition_to_running!()
      run_b = create_run!(org_b) |> transition_to_running!()

      epoch_a = create_epoch!(run_a, org_a, %{state: :expected})
      epoch_b = create_epoch!(run_b, org_b, %{state: :expected})

      assert {:ok, _result} = Reactor.run(Xaas.Ultracode.Reactor)

      # Re-fetch both via the internal unscoped action (the only lawful way
      # to check real post-tick state from a test with no tenant) --
      # BOTH orgs' epochs must have moved, proving the tenant-enforced
      # :read on the primary action did not silently drop org B (or org A)
      # out of the tick's own internal :fetch_active_runs/:run_active_epochs
      # steps (which use :read_unscoped internally).
      reloaded_a = Ash.get!(Epoch, epoch_a.id, action: :read_unscoped, authorize?: false)
      reloaded_b = Ash.get!(Epoch, epoch_b.id, action: :read_unscoped, authorize?: false)

      assert reloaded_a.state == :running
      assert reloaded_b.state == :running

      # And each org can see ONLY its own epoch via the tenant-enforced path.
      assert Ash.get!(Epoch, epoch_a.id, tenant: org_a.id, authorize?: false).state == :running
      assert Ash.get!(Epoch, epoch_b.id, tenant: org_b.id, authorize?: false).state == :running

      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(Epoch, epoch_b.id, tenant: org_a.id, authorize?: false)
      end
    end
  end

  # ------------------------------------------------------------------
  # Attack 5: Ash-multitenancy-specific bypass attempts.
  # ------------------------------------------------------------------

  describe "attack 5a: does :read_unscoped genuinely FILTER when a tenant IS supplied, or does :allow_global silently ignore it?" do
    test "a bare list read via :read_unscoped WITH org A's tenant excludes org B's rows" do
      org_a = create_org!("adv-e1-#{System.unique_integer([:positive])}")
      org_b = create_org!("adv-e2-#{System.unique_integer([:positive])}")
      run_a = create_run!(org_a)
      run_b = create_run!(org_b)
      epoch_a = create_epoch!(run_a, org_a)
      epoch_b = create_epoch!(run_b, org_b)

      results =
        Epoch
        |> Ash.Query.for_read(:read_unscoped)
        |> Ash.read!(tenant: org_a.id, authorize?: false)

      ids = Enum.map(results, & &1.id)
      assert epoch_a.id in ids
      refute epoch_b.id in ids
    end
  end

  describe "attack 5b: confused-deputy relationship load (Epoch.org_id says A, its Run really is B)" do
    test "a drifted Epoch surfaces only under its OWN org_id, and its loaded :run reflects the REAL owning org" do
      org_a = create_org!("adv-f1-#{System.unique_integer([:positive])}")
      org_b = create_org!("adv-f2-#{System.unique_integer([:positive])}")

      # Deliberately inconsistent data: a Run that really belongs to org B,
      # but an Epoch pointing at it whose OWN org_id attribute is stamped
      # org A -- simulating a hypothetical future bug/drift in the
      # denormalization (no real call site in this codebase produces this
      # today, but nothing in the schema prevents it, so it is worth
      # falsifying explicitly).
      run_b = create_run!(org_b)
      drifted_epoch = create_epoch!(run_b, org_a)

      # The Epoch itself is only visible under org A's tenant (its own
      # stamped org_id), never org B's -- proving the ENFORCEMENT reads
      # strictly from the Epoch's own attribute, not transitively from its
      # relationship.
      assert Ash.get!(Epoch, drifted_epoch.id, tenant: org_a.id, authorize?: false).id ==
               drifted_epoch.id

      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(Epoch, drifted_epoch.id, tenant: org_b.id, authorize?: false)
      end

      # The real adversarial question: once org A's tenant has legitimately
      # loaded this (its own, per org_id) Epoch, does loading :run via the
      # :read_unscoped relationship silently hand back org B's real Run
      # data to a caller whose tenant is org A?
      #
      # REAL, EXECUTED RESULT: it does NOT. Ash's relationship loader
      # inherits the LOADING query's tenant onto the related query
      # (`query.tenant || related_query.tenant` -- `deps/ash/lib/ash/
      # actions/read/relationships.ex`), and `:read_unscoped`'s own
      # `multitenancy :allow_global` setting genuinely FILTERS whenever a
      # tenant IS present (confirmed independently in attack 5a above) --
      # so the inherited tenant (org A, from THIS get!'s own `tenant:`
      # option) is applied to the :run load too, and org B's real Run does
      # not match it. The relationship resolves to `nil`, not a leak: a
      # customer-facing caller that supplies its own tenant never sees
      # another org's related row through this path, even under this
      # deliberately-drifted, should-never-happen-in-production data shape.
      loaded_with_tenant =
        Ash.get!(Epoch, drifted_epoch.id, tenant: org_a.id, authorize?: false, load: [:run])

      assert loaded_with_tenant.run == nil

      # Contrast case, to prove the above is really tenant inheritance and
      # not e.g. a relationship-loading bug that always returns nil: an
      # INTERNAL caller (no tenant supplied anywhere, exactly how
      # `Lease.find_by_lease/2` and `EpochReactor`'s own `:observe` step
      # call this) genuinely resolves the real related Run, by design --
      # this is the deliberate, internal-only, tenant-blind path every
      # real system call site in this codebase relies on, not a bug.
      loaded_unscoped =
        Ash.get!(Epoch, drifted_epoch.id, action: :read_unscoped, authorize?: false, load: [:run])

      assert loaded_unscoped.run.id == run_b.id
      assert loaded_unscoped.run.org_id == org_b.id
    end
  end

  describe "attack 5c: raw Ecto access bypasses Ash's :attribute multitenancy entirely (a disclosed boundary, not a regression)" do
    test "a direct Ecto query against ultracode_epochs sees every org's rows regardless of tenant" do
      org_a = create_org!("adv-g1-#{System.unique_integer([:positive])}")
      org_b = create_org!("adv-g2-#{System.unique_integer([:positive])}")
      run_a = create_run!(org_a)
      run_b = create_run!(org_b)
      epoch_a = create_epoch!(run_a, org_a)
      epoch_b = create_epoch!(run_b, org_b)

      import Ecto.Query

      ids =
        from(e in "ultracode_epochs", select: type(e.id, Ecto.UUID))
        |> Xaas.Repo.all()

      # Real, disclosed: Ash's `:attribute` multitenancy strategy is an
      # APPLICATION-layer filter added to every Ash-issued query, not a
      # Postgres RLS policy -- it was never claimed to protect a raw Ecto
      # query that bypasses Ash entirely. This assertion documents that
      # boundary as a real, executed fact, not a bug this retrofit failed
      # to close (no production code path in this codebase issues a raw
      # Ecto query against ultracode_epochs/ultracode_runs -- confirmed by
      # this session's own re-derivation of every call site).
      assert epoch_a.id in ids
      assert epoch_b.id in ids
    end
  end
end
