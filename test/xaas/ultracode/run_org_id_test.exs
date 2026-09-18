defmodule Xaas.Ultracode.RunOrgIdTest do
  @moduledoc """
  Real Chicago-style proof that the `org_id` seam on `Xaas.Ultracode.Run`
  round-trips through real persistence: a nullable `org_id` attribute,
  persisted and reloadable via real Ecto Sandbox rows -- state-based
  assertions on the real persisted column, not a mock.

  ## Superseded disclosure (ADR-0002 update)

  Originally (ADR-0002, `docs/adr/0002-ultracode-org-scoping-seam.md`) this
  suite explicitly disclosed `org_id` as schema-only and UNENFORCED, and
  locked in a real "org B's row is readable via org A's context" assertion
  on purpose, so future enforcement work would change it deliberately, not
  by silent regression. That future work is THIS pass: `Xaas.Ultracode.Run`
  now carries real Ash `:attribute` multitenancy (`multitenancy do strategy
  :attribute; attribute :org_id end`, this module's own moduledoc), so the
  cross-org-readable assertion below is gone, replaced by a real
  enforcement proof -- and the dedicated, broader query-layer isolation
  falsifier (both Run AND Epoch, multiple query shapes) lives in
  `test/xaas/ultracode/multitenancy_isolation_test.exs`.

  Every read below that intentionally exercises the OLD unscoped semantics
  (verifying a row was persisted correctly, not the tenant boundary) uses
  the real, explicitly-named `:read_unscoped` action -- never the resource's
  now tenant-`:enforce`d default `:read`.
  """
  use ExUnit.Case, async: true

  @moduletag :ultracode

  alias Xaas.Ultracode.Run

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  test "org_id is accepted on :create and persists across a real reload" do
    run =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "run_org_id_test", org_id: "org-alpha"},
        authorize?: false
      )
      |> Ash.create!()

    assert run.org_id == "org-alpha"

    reloaded = Ash.get!(Run, run.id, action: :read_unscoped, authorize?: false)
    assert reloaded.org_id == "org-alpha"
  end

  test "org_id is nullable: a Run created without it persists org_id == nil" do
    run =
      Run
      |> Ash.Changeset.for_create(:create, %{goal: "run_org_id_test_absent"}, authorize?: false)
      |> Ash.create!()

    assert run.org_id == nil

    reloaded = Ash.get!(Run, run.id, action: :read_unscoped, authorize?: false)
    assert reloaded.org_id == nil
  end

  test "two Runs with distinct org_id values are real, independently persisted rows", %{} do
    run_a =
      Run
      |> Ash.Changeset.for_create(:create, %{goal: "org_a_run", org_id: "org-a"},
        authorize?: false
      )
      |> Ash.create!()

    run_b =
      Run
      |> Ash.Changeset.for_create(:create, %{goal: "org_b_run", org_id: "org-b"},
        authorize?: false
      )
      |> Ash.create!()

    assert Ash.get!(Run, run_a.id, action: :read_unscoped, authorize?: false).org_id == "org-a"
    assert Ash.get!(Run, run_b.id, action: :read_unscoped, authorize?: false).org_id == "org-b"
  end

  # Real enforcement proof, superseding the old disclosed-unenforced
  # assertion (see moduledoc). A minimal single-resource version of the
  # falsifier `multitenancy_isolation_test.exs` proves more broadly.
  test "the DEFAULT :read action now requires a tenant -- no bare Ash.get!/Ash.read! leak" do
    run_a =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "org_a_run_enforced", org_id: "org-a-enforced"},
        authorize?: false
      )
      |> Ash.create!()

    run_b =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "org_b_run_enforced", org_id: "org-b-enforced"},
        authorize?: false
      )
      |> Ash.create!()

    # A bare Ash.get! on the DEFAULT :read action, no tenant supplied:
    # raises, never silently returns another org's row.
    assert_raise Ash.Error.Invalid, ~r/require.*tenant/i, fn ->
      Ash.get!(Run, run_b.id, authorize?: false)
    end

    # With org A's own tenant, org A's row is genuinely visible...
    assert Ash.get!(Run, run_a.id, tenant: "org-a-enforced", authorize?: false).id == run_a.id

    # ...and org A's tenant genuinely does NOT resolve org B's row -- a real
    # NotFound, not a leak.
    assert_raise Ash.Error.Invalid, fn ->
      Ash.get!(Run, run_b.id, tenant: "org-a-enforced", authorize?: false)
    end
  end
end
