defmodule Xaas.Operations.DenyByDefaultBypassAttemptTest do
  @moduledoc """
  Real, adversarial attempt (prompt #14 of the 25-item backlog) to bypass the
  deny-by-default policy floor on 3 real capability resources in
  lib/xaas/operations/: Xaas.Operations.AutofdePlannerCandidate,
  Xaas.Operations.AutofdePlannerCatalog, Xaas.Operations.CapabilityLivenessReceipt.

  Every call below passes `authorize?: true` EXPLICITLY (Ash's own default) with
  no special actor context, targeting actions each resource's `policies do`
  block does NOT cover with an explicit `bypass`/`authorize_if` -- i.e. actions
  that should fall through to the catch-all `policy always() do forbid_if
  always() end` floor. Real Ecto.Adapters.SQL.Sandbox-backed Postgres, real
  Ash.create/Ash.read/Ash.destroy calls. No mocks.
  """
  use ExUnit.Case, async: true

  alias Xaas.Operations.AutofdePlannerCandidate
  alias Xaas.Operations.AutofdePlannerCatalog
  alias Xaas.Operations.CapabilityLivenessReceipt

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # --- Resource 1: AutofdePlannerCandidate -----------------------------------
  # Only actions: :read (bypassed) and :request_candidate (bypassed). Both are
  # deliberately wide-open bypasses, not attack surface. There is no
  # update/destroy action defined at all, so there is no uncovered action to
  # call -- Ash simply has no such action to dispatch. Confirmed by attempting
  # to build a changeset for a nonexistent :destroy action.
  test "AutofdePlannerCandidate: no destroy action exists to slip through" do
    assert_raise ArgumentError, fn ->
      AutofdePlannerCandidate
      |> Ash.Changeset.for_destroy(:destroy, %{}, authorize?: true)
      |> Ash.destroy!(authorize?: true)
    end
  end

  # --- Resource 2: AutofdePlannerCatalog --------------------------------------
  # Same shape as AutofdePlannerCandidate: only :read and :request_catalog
  # exist, both explicitly bypassed. No update/destroy action defined.
  test "AutofdePlannerCatalog: no destroy action exists to slip through" do
    assert_raise ArgumentError, fn ->
      AutofdePlannerCatalog
      |> Ash.Changeset.for_destroy(:destroy, %{}, authorize?: true)
      |> Ash.destroy!(authorize?: true)
    end
  end

  # --- Resource 3: CapabilityLivenessReceipt ----------------------------------
  # defaults([:read, :destroy]) defines a REAL :destroy action, and a REAL
  # :ingest create action -- neither is covered by a `bypass`. Both should fall
  # through to the catch-all `policy always() do forbid_if always() end` floor.
  # This is the actual attack surface: attempt both with authorize?: true.

  test "CapabilityLivenessReceipt: :ingest with authorize?: true is denied by the floor" do
    result =
      CapabilityLivenessReceipt
      |> Ash.Changeset.for_create(
        :ingest,
        %{
          capability: "attack.ingest.check",
          authority: "attacker",
          status: "ALIVE",
          executed: true,
          exit_code: 0,
          subject: "attack-subject-1",
          detail: "adversarial ingest attempt"
        },
        authorize?: true
      )
      |> Ash.create(authorize?: true)

    assert {:error, %Ash.Error.Forbidden{}} = result

    # Confirm nothing was actually persisted by the denied attempt.
    persisted =
      CapabilityLivenessReceipt
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.capability == "attack.ingest.check"))

    assert persisted == []
  end

  test "CapabilityLivenessReceipt: :destroy with authorize?: true is denied by the floor" do
    # Seed a real row via the legitimate system-internal path (authorize?: false,
    # mirroring the real ingest Mix task), then attempt to destroy it as an
    # unauthenticated/unprivileged actor with authorize?: true explicitly.
    receipt =
      CapabilityLivenessReceipt
      |> Ash.Changeset.for_create(
        :ingest,
        %{
          capability: "attack.destroy.check",
          authority: "otel-weaver-v2",
          status: "ALIVE",
          executed: true,
          exit_code: 0,
          subject: "attack-subject-2",
          detail: "seed row for destroy attack"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    result =
      receipt
      |> Ash.Changeset.for_destroy(:destroy, %{}, authorize?: true)
      |> Ash.destroy(authorize?: true)

    assert {:error, %Ash.Error.Forbidden{}} = result

    # Confirm the row survived the denied destroy attempt.
    persisted =
      CapabilityLivenessReceipt
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.capability == "attack.destroy.check"))

    assert [%{status: "ALIVE"}] = persisted
  end
end
