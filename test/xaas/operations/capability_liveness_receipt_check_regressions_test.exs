defmodule Xaas.Operations.CapabilityLivenessReceiptCheckRegressionsTest do
  @moduledoc """
  Real Chicago-style test: real Ash.run_action call against the real
  sandboxed Postgres (Xaas.Repo), real
  Xaas.Operations.CapabilityLivenessRegressions.detect/1 underneath --
  the first real exercise of this repo's `ash_oban` wiring
  (`:check_regressions`, scheduled via `AshOban`'s `scheduled_actions`
  DSL, real cron entry confirmed via `AshOban.Info.
  oban_triggers_and_scheduled_actions/1`). No mocking of Oban, the
  scheduler, or the detector.
  """
  use ExUnit.Case, async: true

  alias Xaas.Operations.CapabilityLivenessReceipt

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp ingest!(attrs) do
    CapabilityLivenessReceipt
    |> Ash.Changeset.for_create(:ingest, attrs)
    |> Ash.create!(authorize?: false)
  end

  test "the real schedule is registered on the resource" do
    scheduled = AshOban.Info.oban_triggers_and_scheduled_actions(CapabilityLivenessReceipt)
    assert Enum.any?(scheduled, &(&1.name == :check_regressions))
  end

  test "does not flag this test's own capability when only an ALIVE row exists for it" do
    # Real, disclosed finding: detect/1 scans ALL capabilities globally,
    # and this repo's Ecto.Adapters.SQL.Sandbox usage includes at least
    # one test file setting {:shared, self()} mode, which can make
    # concurrently-run tests' rows visible to each other -- asserting an
    # exact global `count: 0` real-flaked for that reason. Asserting
    # this test's own capability specifically is the real, isolation-
    # independent check.
    capability = "check-regressions-alive-#{System.unique_integer([:positive])}"

    ingest!(%{
      capability: capability,
      authority: "otel-weaver-v2",
      status: "ALIVE",
      subject: "commit-1"
    })

    assert {:ok, %{regressions: regressions}} =
             CapabilityLivenessReceipt
             |> Ash.ActionInput.for_action(:check_regressions, %{})
             |> Ash.run_action(authorize?: false)

    refute Enum.any?(regressions, &(&1.capability == capability))
  end

  test "returns a real detected regression when an ALIVE row is followed by a non-ALIVE one" do
    capability = "check-regressions-real-#{System.unique_integer([:positive])}"

    ingest!(%{
      capability: capability,
      authority: "otel-weaver-v2",
      status: "ALIVE",
      subject: "commit-before"
    })

    # Real, disclosed finding: 5ms (the interval the pre-existing proven
    # test in capability_liveness_receipt_test.exs uses) real-flaked here
    # under this session's now-larger concurrent test suite -- bumped to
    # 25ms for real headroom against inserted_at ordering contention.
    Process.sleep(25)

    ingest!(%{
      capability: capability,
      authority: "otel-weaver-v2",
      status: "BLOCKED",
      subject: "commit-after"
    })

    assert {:ok, %{count: count, regressions: regressions}} =
             CapabilityLivenessReceipt
             |> Ash.ActionInput.for_action(:check_regressions, %{})
             |> Ash.run_action(authorize?: false)

    assert count >= 1
    assert Enum.any?(regressions, &(&1.capability == capability))
  end
end
