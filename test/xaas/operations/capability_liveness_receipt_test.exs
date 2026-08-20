defmodule Xaas.Operations.CapabilityLivenessReceiptTest do
  @moduledoc """
  Real Chicago-style tests: real Ecto.Adapters.SQL.Sandbox-backed Postgres
  (Xaas.Repo), real Ash.create!/Ash.read! calls against the real
  `capability_liveness_receipts` table. No mocks/stubs of any collaborator.
  """
  use ExUnit.Case, async: true

  alias Xaas.Operations.CapabilityLivenessReceipt
  alias Xaas.Operations.CapabilityLivenessRegressions

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp ingest!(attrs) do
    CapabilityLivenessReceipt
    |> Ash.Changeset.for_create(:ingest, attrs)
    |> Ash.create!(authorize?: false)
  end

  test "ingest creates a real row with real persisted attributes" do
    receipt =
      ingest!(%{
        capability: "weaver.registry.check",
        authority: "otel-weaver-v2",
        status: "ALIVE",
        executed: true,
        exit_code: 0,
        subject: "commit-abc123",
        detail: "real receipt row"
      })

    assert receipt.capability == "weaver.registry.check"
    assert receipt.authority == "otel-weaver-v2"
    assert receipt.status == "ALIVE"
    assert receipt.executed == true
    assert receipt.exit_code == 0
    assert receipt.subject == "commit-abc123"
    assert receipt.detail == "real receipt row"

    persisted =
      CapabilityLivenessReceipt
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.id == receipt.id))

    assert [%{capability: "weaver.registry.check", subject: "commit-abc123"}] = persisted
  end

  test "idempotent re-ingest with same capability+subject upserts instead of duplicating" do
    ingest!(%{
      capability: "weaver.idempotent.check",
      authority: "otel-weaver-v2",
      status: "ALIVE",
      executed: true,
      exit_code: 0,
      subject: "commit-same",
      detail: "first ingest"
    })

    ingest!(%{
      capability: "weaver.idempotent.check",
      authority: "otel-weaver-v2",
      status: "PARTIAL",
      executed: true,
      exit_code: 1,
      subject: "commit-same",
      detail: "second ingest, same capability+subject"
    })

    rows =
      CapabilityLivenessReceipt
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.capability == "weaver.idempotent.check"))

    assert length(rows) == 1
    assert [%{status: "PARTIAL", detail: "second ingest, same capability+subject"}] = rows
  end

  test "detect/1 returns [] when the only real rows are ALIVE" do
    ingest!(%{
      capability: "weaver.all_alive.check",
      authority: "otel-weaver-v2",
      status: "ALIVE",
      executed: true,
      exit_code: 0,
      subject: "commit-1",
      detail: nil
    })

    regressions =
      CapabilityLivenessRegressions.detect()
      |> Enum.filter(&(&1.capability == "weaver.all_alive.check"))

    assert regressions == []
  end

  test "detect/1 returns a real regression entry after a real ALIVE row is followed by a real non-ALIVE row" do
    ingest!(%{
      capability: "weaver.regressed.check",
      authority: "otel-weaver-v2",
      status: "ALIVE",
      executed: true,
      exit_code: 0,
      subject: "commit-was-alive",
      detail: nil
    })

    ingest!(%{
      capability: "weaver.regressed.check",
      authority: "otel-weaver-v2",
      status: "BLOCKED",
      executed: true,
      exit_code: 1,
      subject: "commit-now-blocked",
      detail: nil
    })

    [regression] =
      CapabilityLivenessRegressions.detect()
      |> Enum.filter(&(&1.capability == "weaver.regressed.check"))

    assert regression.was.status == "ALIVE"
    assert regression.was.subject == "commit-was-alive"
    assert regression.now.status == "BLOCKED"
    assert regression.now.subject == "commit-now-blocked"
  end
end
