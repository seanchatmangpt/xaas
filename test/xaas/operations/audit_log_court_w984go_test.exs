defmodule Xaas.Operations.AuditLogCourtW984goTest do
  @moduledoc """
  Lane W984go unclaimed-family court on `Xaas.Operations.AuditLogEntry`.

  Census result (real grep of `test/`): existing coverage exercises the
  resource only *through writers* —
  `test/xaas/governance/audit_log_entry_test.exs` (Governance approve
  side-effects via `Xaas.Governance.Changes.WriteAuditLogEntry`) and
  `test/xaas/operations/audit_log_deepening_test.exs` (`/mcp` plug
  writes). Neither touches the resource's own unexercised branches:

  - direct `:create` typed pinning: `occurred_at`/`metadata` defaults,
    `allow_nil?(false)` rejections on action/resource_type/resource_id
  - the deny-by-default policy floor: an `authorize?: true` create is
    forbidden (the moduledoc claims the catch-all fires; nothing ran it)
  - append-only shape: no update action exists, so an update attempt is
    refused
  - read filter scopes (action / resource_type / org_id) as standalone
    queries

  Chicago-style: real sandboxed `Xaas.Repo`, real Ash actions, zero
  mocks. Mutation rationale per test below.
  """

  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Operations.AuditLogEntry

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_entry!(extra \\ %{}) do
    AuditLogEntry
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          action: "court.w984go.probe",
          resource_type: "court_probe",
          resource_id: "probe-#{System.unique_integer([:positive])}"
        },
        extra
      ),
      authorize?: false
    )
    |> Ash.create!()
  end

  test "direct create pins typed defaults: occurred_at now, metadata %{}" do
    # Mutation rationale: deleting the attribute defaults (or mistyping
    # them) would leave nil/deserialized-wrong values; this fails if the
    # default functions are removed or changed.
    before = DateTime.utc_now()
    entry = create_entry!()

    assert DateTime.compare(entry.occurred_at, before) in [:gt, :eq]

    assert entry.metadata == %{}
    assert entry.actor_id == nil
    assert entry.org_id == nil
  end

  test "direct create rejects nil action / resource_type / resource_id" do
    # Mutation rationale: dropping allow_nil?(false) on any required
    # attribute would let a null key column through; each branch is
    # exercised so removing one pin fails its own assertion.
    for field <- [:action, :resource_type, :resource_id] do
      assert_raise Ash.Error.Invalid, fn ->
        AuditLogEntry
        |> Ash.Changeset.for_create(
          :create,
          %{action: "a", resource_type: "t", resource_id: "r"} |> Map.delete(field),
          authorize?: false
        )
        |> Ash.create!()
      end
    end
  end

  test "authorize?: true create is forbidden by the catch-all policy" do
    # Mutation rationale: adding a bypass for :create (or weakening
    # forbid_if always()) would admit a public write route; this fails
    # the moment the deny floor is breached.
    assert_raise Ash.Error.Forbidden, fn ->
      AuditLogEntry
      |> Ash.Changeset.for_create(:create, %{
        action: "court.w984go.public",
        resource_type: "court_probe",
        resource_id: "r-1"
      })
      |> Ash.create!(authorize?: true)
    end
  end

  test "append-only: updating an entry is refused (no update action)" do
    # Mutation rationale: adding :update/:destroy defaults would let the
    # trail be rewritten; this fails as soon as a mutable action exists.
    entry = create_entry!()

    assert_raise ArgumentError,
                 ~r/No such update action/,
                 fn ->
                   entry
                   |> Ash.Changeset.for_update(:update, %{actor_id: "rewritten"})
                   |> Ash.update!(authorize?: false)
                 end
  end

  test "read filter scopes pin action / resource_type / org_id selection" do
    # Mutation rationale: a filter regression (wrong attribute or dropped
    # scope) would return foreign rows; cross-seeding makes any leak of
    # non-matching rows fail the length/pin assertions.
    matching = create_entry!(%{org_id: "org-w984go", metadata: %{"k" => "v"}})

    create_entry!(%{action: "court.w984go.other", org_id: "org-other"})

    scoped =
      AuditLogEntry
      |> Ash.Query.filter(action == ^"court.w984go.probe")
      |> Ash.Query.filter(org_id == ^"org-w984go")
      |> Ash.read!(authorize?: false)

    assert [entry] = scoped
    assert entry.id == matching.id
    assert entry.resource_type == "court_probe"
    assert entry.metadata["k"] == "v"
  end
end
