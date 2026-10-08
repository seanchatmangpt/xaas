defmodule Xaas.Airo.PinDriftTest do
  @moduledoc """
  W981w — AIRo pin-drift court. Runs docs/airo/pin_drift_check.exs (real git
  rev-parse / merge-base against every ledger row's repo) and asserts the
  ledger's drift reality matches the receipted drift table.

  DRIFT is not itself a failure: a row whose recorded SHA diverged must be
  listed in @receipted_drift (docs/sjira/v26.10.6/plans/w981w-airo-pin-court-followup.md).
  Any new, vanished, or changed drift row fails this test and forces a receipt
  update.
  """

  use ExUnit.Case, async: false

  @script Path.expand("../../../docs/airo/pin_drift_check.exs", __DIR__)
  @expected_rows 21

  # Receipted drift (W981w, 2026-10-07): repo => recorded (old) SHA at pin time.
  # Update this map AND the receipt together whenever the check reports a change.
  # W984gt (2026-10-07): the single W981w drift row (beam4pm/vendor/ggen-marketplace,
  # recorded 6e4de976…) RESOLVED — the submodule is back at its recorded pin, the
  # full check reports drift=0 — so the map is empty. Re-add entries only from the
  # real output of docs/airo/pin_drift_check.exs.
  @receipted_drift %{}

  test "pin drift check script runs and reports all ledger rows" do
    assert File.exists?(@script), "missing #{@script}"

    {out, 0} = System.cmd("elixir", [@script], stderr_to_stdout: true)
    report = Jason.decode!(out)

    assert report["rows_checked"] == @expected_rows,
           "ledger row count changed (#{report["rows_checked"]}); update @expected_rows and the receipt"

    assert report["counts"]["missing"] == 0, "a ledger repo vanished from disk"
  end

  test "every DRIFT row is receipted, every receipted drift row still drifts" do
    {out, 0} = System.cmd("elixir", [@script], stderr_to_stdout: true)
    report = Jason.decode!(out)

    actual_drift =
      report["results"]
      |> Enum.filter(&(&1["status"] == "DRIFT"))
      |> Map.new(&{&1["repo"], &1["recorded"]})

    unreported = Map.drop(actual_drift, Map.keys(@receipted_drift))

    assert unreported == %{},
           "UNREPORTED drift (update receipt + @receipted_drift): #{inspect(unreported)}"

    stale_receipts =
      @receipted_drift
      |> Enum.filter(fn {repo, old_sha} ->
        actual_drift[repo] != old_sha
      end)
      |> Map.new()

    assert stale_receipts == %{},
           "receipted drift no longer matches reality (row resolved or old SHA changed): #{inspect(stale_receipts)}"
  end

  test "non-drift rows are CURRENT or ANCESTOR with recorded SHA present in history" do
    {out, 0} = System.cmd("elixir", [@script], stderr_to_stdout: true)
    report = Jason.decode!(out)

    for r <- report["results"], r["status"] in ["CURRENT", "ANCESTOR"] do
      assert Regex.match?(~r/^[0-9a-f]{40}$/, r["recorded"])
      assert Regex.match?(~r/^[0-9a-f]{40}$/, r["head"] || "")
    end
  end
end
