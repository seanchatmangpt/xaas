defmodule Xaas.Ultracode.RunOrgIdTest do
  @moduledoc """
  Real Chicago-style proof that the schema-only `org_id` seam landed
  (ADR-0002, `docs/adr/0002-ultracode-org-scoping-seam.md`): a nullable
  `org_id` attribute on `Xaas.Ultracode.Run`, persisted and reloadable via
  real Ecto Sandbox rows -- state-based assertions on the real persisted
  column, not a mock.

  Deliberately NOT a cross-org isolation/enforcement test: per ADR-0002, no
  policy or check reads this attribute yet (there is no real actor/org
  identity reaching an Ultracode action on the real HTTP surface today --
  see that ADR for the full disclosed finding), so a real "org A cannot see
  org B's Run" test would have no real boundary to falsify. This test only
  proves the real column exists and round-trips.
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

    reloaded = Ash.get!(Run, run.id, authorize?: false)
    assert reloaded.org_id == "org-alpha"
  end

  test "org_id is nullable: a Run created without it persists org_id == nil" do
    run =
      Run
      |> Ash.Changeset.for_create(:create, %{goal: "run_org_id_test_absent"}, authorize?: false)
      |> Ash.create!()

    assert run.org_id == nil

    reloaded = Ash.get!(Run, run.id, authorize?: false)
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

    assert Ash.get!(Run, run_a.id, authorize?: false).org_id == "org-a"
    assert Ash.get!(Run, run_b.id, authorize?: false).org_id == "org-b"

    # Real, disclosed, current behavior (ADR-0002): nothing scopes reads by
    # org_id yet, so org_b's row is real-readable regardless of run_a's
    # org_id -- this is the exact unenforced seam ADR-0002 names, locked in
    # here so future enforcement work changes this assertion on purpose,
    # not by silent regression.
    assert Ash.get!(Run, run_b.id, authorize?: false).id == run_b.id
  end
end
