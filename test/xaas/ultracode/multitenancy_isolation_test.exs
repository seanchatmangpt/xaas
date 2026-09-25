defmodule Xaas.Ultracode.MultitenancyIsolationTest do
  @moduledoc """
  THE real falsifier for the multitenancy retrofit (see `Xaas.Ultracode.Run`
  and `Xaas.Ultracode.Epoch`'s own moduledocs for the design). Proves the
  boundary is real at the QUERY layer, not only at one HTTP controller
  action -- the exact gap this retrofit closes.

  Real Chicago-style: two real orgs (`Xaas.Accounts.Org`), two real Runs,
  two real Epochs, real Ecto.Adapters.SQL.Sandbox-backed Postgres rows. No
  mocks/stubs of any collaborator. Every assertion is a DIRECT `Ash.get!`/
  `Ash.read!` call against the resource's own DEFAULT `:read` action --
  never `XaasWeb.ExecutionFabricController`, never `:read_unscoped`.

  Before this retrofit, every one of the "raises" / "returns empty"
  assertions below would instead have silently returned the OTHER org's
  real row -- `test/xaas/ultracode/run_org_id_test.exs`'s previous version
  (superseded this pass, see its own moduledoc) explicitly locked that
  leak in as documented, disclosed, current behavior. This file proves it
  is closed.
  """
  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Ultracode.{Epoch, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_org!(slug) do
    Org
    |> Ash.Changeset.for_create(:create, %{name: slug, slug: slug}, authorize?: false)
    |> Ash.create!()
  end

  defp create_run!(org, goal) do
    Run
    |> Ash.Changeset.for_create(:create, %{goal: goal, org_id: org.id}, authorize?: false)
    |> Ash.create!()
  end

  defp create_epoch!(run, org, cycle) do
    Epoch
    |> Ash.Changeset.for_create(
      :create,
      %{
        run_id: run.id,
        # Real denormalization from the parent Run's org_id, exactly as
        # every real production create path (controller,
        # Changes.CreateFirstEpoch, NextEpoch.advance_from_completed/2)
        # does -- see Epoch's own moduledoc "Org scoping" section.
        org_id: org.id,
        cycle: cycle,
        exact_subject: "multitenancy_isolation_test",
        state: :expected,
        expected_at: DateTime.utc_now()
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  describe "Run: default :read is genuinely tenant-enforced" do
    setup do
      org_a = create_org!("mt-isolation-org-a-#{System.unique_integer([:positive])}")
      org_b = create_org!("mt-isolation-org-b-#{System.unique_integer([:positive])}")
      run_a = create_run!(org_a, "org A's real run")
      run_b = create_run!(org_b, "org B's real run")

      %{org_a: org_a, org_b: org_b, run_a: run_a, run_b: run_b}
    end

    test "a bare Ash.get! with NO tenant raises, never silently returns the row", %{run_b: run_b} do
      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(Run, run_b.id, authorize?: false)
      end
    end

    test "a bare Ash.read! with NO tenant raises, never silently returns every org's rows" do
      assert_raise Ash.Error.Invalid, fn ->
        Ash.read!(Run, authorize?: false)
      end
    end

    test "org A's tenant cannot resolve org B's Run by id -- a real NotFound, not a leak", %{
      org_a: org_a,
      run_b: run_b
    } do
      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(Run, run_b.id, tenant: org_a.id, authorize?: false)
      end
    end

    test "org A's own tenant DOES resolve org A's own Run -- the positive path", %{
      org_a: org_a,
      run_a: run_a
    } do
      assert Ash.get!(Run, run_a.id, tenant: org_a.id, authorize?: false).id == run_a.id
    end

    test "org A's tenant on Ash.read! filters to ONLY org A's rows -- never org B's", %{
      org_a: org_a,
      run_a: run_a,
      run_b: run_b
    } do
      results = Ash.read!(Run, tenant: org_a.id, authorize?: false)
      ids = Enum.map(results, & &1.id)

      assert run_a.id in ids
      refute run_b.id in ids
    end
  end

  describe "Epoch: default :read is genuinely tenant-enforced (the literal target of this retrofit)" do
    setup do
      org_a = create_org!("mt-isolation-epoch-a-#{System.unique_integer([:positive])}")
      org_b = create_org!("mt-isolation-epoch-b-#{System.unique_integer([:positive])}")
      run_a = create_run!(org_a, "org A's real run for epoch isolation")
      run_b = create_run!(org_b, "org B's real run for epoch isolation")
      epoch_a = create_epoch!(run_a, org_a, 0)
      epoch_b = create_epoch!(run_b, org_b, 0)

      %{org_a: org_a, org_b: org_b, epoch_a: epoch_a, epoch_b: epoch_b}
    end

    test "a bare Ash.get! with NO tenant raises -- the exact query shape that used to leak", %{
      epoch_b: epoch_b
    } do
      # Before this retrofit, this was `XaasWeb.ExecutionFabricController`'s
      # own pre-this-pass `receipts_for_org/3` implementation, verbatim:
      # `Ash.get(Epoch, epoch_id, authorize?: false, load: [:run])`, gated
      # only by a controller-layer comparison AFTER the unscoped fetch
      # already succeeded. Now the fetch itself refuses.
      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(Epoch, epoch_b.id, authorize?: false)
      end
    end

    test "a bare Ash.read! with NO tenant raises, never silently returns every org's epochs" do
      assert_raise Ash.Error.Invalid, fn ->
        Ash.read!(Epoch, authorize?: false)
      end
    end

    test "org A's tenant cannot resolve org B's Epoch by id -- a real NotFound, not a leak", %{
      org_a: org_a,
      epoch_b: epoch_b
    } do
      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(Epoch, epoch_b.id, tenant: org_a.id, authorize?: false)
      end
    end

    test "an epoch with the WRONG tenant explicitly set is also refused (not just a missing tenant)",
         %{org_b: org_b, epoch_a: epoch_a} do
      # Same falsifier as above, phrased the other way: a caller that DOES
      # supply a tenant, but the wrong one, still cannot cross the
      # boundary -- this is real filtering, not merely "tenant present?".
      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(Epoch, epoch_a.id, tenant: org_b.id, authorize?: false)
      end
    end

    test "org A's own tenant DOES resolve org A's own Epoch -- the positive path", %{
      org_a: org_a,
      epoch_a: epoch_a
    } do
      assert Ash.get!(Epoch, epoch_a.id, tenant: org_a.id, authorize?: false).id == epoch_a.id
    end

    test "org A's tenant on Ash.read! filters to ONLY org A's epochs -- never org B's", %{
      org_a: org_a,
      epoch_a: epoch_a,
      epoch_b: epoch_b
    } do
      results = Ash.read!(Epoch, tenant: org_a.id, authorize?: false)
      ids = Enum.map(results, & &1.id)

      assert epoch_a.id in ids
      refute epoch_b.id in ids
    end
  end

  describe "internal/system call sites keep their real, deliberate, unscoped access via :read_unscoped" do
    test "Run.:read_unscoped still returns a row with no tenant at all -- unchanged internal behavior" do
      org = create_org!("mt-isolation-internal-run-#{System.unique_integer([:positive])}")
      run = create_run!(org, "internal path stays unscoped")

      assert Ash.get!(Run, run.id, action: :read_unscoped, authorize?: false).id == run.id
    end

    test "Epoch.:read_unscoped still returns a row with no tenant at all -- unchanged internal behavior" do
      org = create_org!("mt-isolation-internal-epoch-#{System.unique_integer([:positive])}")
      run = create_run!(org, "internal path stays unscoped (epoch)")
      epoch = create_epoch!(run, org, 0)

      assert Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false).id == epoch.id
    end

    test "Epoch.:read_unscoped, across TWO different orgs' epochs, sees both -- the real shared worker-pool shape",
         %{} do
      org_a = create_org!("mt-isolation-pool-a-#{System.unique_integer([:positive])}")
      org_b = create_org!("mt-isolation-pool-b-#{System.unique_integer([:positive])}")
      run_a = create_run!(org_a, "pool run a")
      run_b = create_run!(org_b, "pool run b")
      epoch_a = create_epoch!(run_a, org_a, 0)
      epoch_b = create_epoch!(run_b, org_b, 0)

      results =
        Epoch
        |> Ash.Query.for_read(:read_unscoped)
        |> Ash.Query.filter(id in [^epoch_a.id, ^epoch_b.id])
        |> Ash.read!(authorize?: false)

      ids = Enum.map(results, & &1.id)
      assert epoch_a.id in ids
      assert epoch_b.id in ids
    end
  end
end
