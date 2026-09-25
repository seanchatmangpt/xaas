defmodule Xaas.Ultracode.OcelConformanceTest do
  @moduledoc """
  Qualification for `Xaas.Ultracode.OcelConformance` -- the batch OCEL 2.0
  conformance court over a whole campaign's runs.

  Chicago-style, per this repo's discipline: real Runs/Epochs/Receipts
  written through real Ash actions into the sandboxed Postgres, a real
  ndjson campaign ledger in a real tmp dir, and the REAL
  `OcelEgress.export_run/2` + `Ocel.Validator.validate_file/1` pair for
  every judged run. The one seam is the documented `:export`
  fault-injection opt (the exact seam shape `Learn.campaign_facts/2`
  uses), handing the REAL validator a corrupt export to prove a judged
  RED -- and an export-failure seam to prove the fail-closed
  refusal-to-judge path. The mix task's exit codes are pinned through
  its pure `exit_status/1` (halting paths are observed out-of-test,
  this repo's `Mix.Tasks.Xaas.RunValidateTaskTest` precedent).
  """

  use ExUnit.Case, async: true

  require Ash.Query

  @moduletag :ultracode

  alias Xaas.Ultracode.{Campaign, Epoch, OcelConformance, Receipt, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # ------------------------------------------------------------------
  # All-valid campaign: 100% conformant, deterministic order
  # ------------------------------------------------------------------

  test "an all-valid campaign reports every run valid, campaign row last" do
    dir = tmp_dir()
    {run_a, _epoch_a} = closed_run!("aps-autonomic:ocel-conf-alpha#1", :alive)
    {run_b, _epoch_b} = failed_run!("aps-autonomic:ocel-conf-beta#1", :refused)
    campaign = campaign_row!("conformance qualification, all valid")

    ledger =
      write_ledger!(dir, [
        %{"event" => "campaign_start", "ts" => iso(~U[2026-09-22T09:00:00Z]), "repo" => "aps"},
        attempt_start("ocel-conf-alpha", 1, run_a.id),
        attempt_start("ocel-conf-beta", 1, run_b.id)
      ])

    assert {:ok, report} = OcelConformance.campaign(campaign.id, ledger: ledger)

    campaign_id = campaign.id

    assert %{
             campaign_id: ^campaign_id,
             ledger: ^ledger,
             ledger_present: true,
             named: 3,
             valid: 3,
             total: 3,
             status: :conformant
           } = report

    # Deterministic order: ledger attempt order, campaign row last.
    assert Enum.map(report.runs, & &1.run_id) == [run_a.id, run_b.id, campaign.id]

    # Every judged run flowed through the REAL validator (real counts).
    # The un-started campaign row legally emits ZERO events (an explicit
    # empty list is valid; the Run object is still there).
    Enum.each(report.runs, fn run ->
      assert %{status: :valid, events: events, objects: objects} = run
      assert is_integer(events) and events >= 0
      assert is_integer(objects) and objects >= 1
    end)

    # The attempt runs carry real epochs/receipts; the un-started campaign
    # row still emits its run object (zero events is explicitly legal).
    assert Enum.at(report.runs, 0).objects > Enum.at(report.runs, 2).objects
  end

  test "the campaign row itself must be a campaign row (marker law)" do
    {plain_run, _epoch} = closed_run!("aps-autonomic:ocel-conf-plain#1", :alive)
    plain_id = plain_run.id

    # The refusal names the id string (audit's `{:not_a_campaign, id}` shape).
    assert {:error, {:not_a_campaign, ^plain_id}} =
             OcelConformance.campaign(plain_run.id, ledger: Path.join(tmp_dir(), "l.ndjson"))

    assert {:error, :campaign_not_found} =
             OcelConformance.campaign("00000000-0000-4000-8000-00000000dead",
               ledger: Path.join(tmp_dir(), "l.ndjson")
             )
  end

  # ------------------------------------------------------------------
  # One corrupted export: a JUDGED red naming the violation
  # ------------------------------------------------------------------

  test "one corrupted export is a judged violation; the rest stays valid" do
    dir = tmp_dir()
    {run_ok, _} = closed_run!("aps-autonomic:ocel-conf-ok#1", :alive)
    {run_corrupt, _} = closed_run!("aps-autonomic:ocel-conf-corrupt#1", :alive)
    campaign = campaign_row!("conformance qualification, one corrupt")

    ledger =
      write_ledger!(dir, [
        attempt_start("ocel-conf-ok", 1, run_ok.id),
        attempt_start("ocel-conf-corrupt", 1, run_corrupt.id)
      ])

    # The documented fault-injection seam (Learn's exact shape): corrupt
    # ONLY the named run's export; the REAL validator judges the file.
    corrupt = fn run_id, tmp_dir ->
      with {:ok, path} <- Xaas.Ultracode.OcelEgress.export_run(run_id, tmp_dir) do
        doc =
          path
          |> File.read!()
          |> JSON.decode!()
          |> Map.update!("ocel:events", fn events ->
            [
              %{
                "id" => "worker_launched:#{run_id}",
                "type" => "worker_launched",
                "time" => "2026-09-22T10:00:00Z",
                "attributes" => %{},
                "relationships" => []
              }
              | events
            ]
          end)

        File.write!(path, JSON.encode!(doc))
        {:ok, path}
      end
    end

    seam = fn run_id, tmp_dir ->
      if run_id == run_corrupt.id do
        corrupt.(run_id, tmp_dir)
      else
        Xaas.Ultracode.OcelEgress.export_run(run_id, tmp_dir)
      end
    end

    assert {:ok, report} =
             OcelConformance.campaign(campaign.id,
               ledger: ledger,
               export: seam
             )

    assert report.status == :violations
    assert report.total == 3
    assert report.valid == 2

    assert %{status: :violations, violations: violations} =
             Enum.find(report.runs, &(&1.run_id == run_corrupt.id))

    assert [%{path: path, reason: reason} | _] = violations
    assert path =~ ~r{ocel:events\[\d+\]\.type}
    assert reason == "'worker_launched' not declared in ocel:eventTypes"

    # The other two runs are still judged valid -- per-run pass/fail.
    assert %{status: :valid} = Enum.find(report.runs, &(&1.run_id == run_ok.id))
    assert %{status: :valid} = Enum.find(report.runs, &(&1.run_id == campaign.id))
  end

  # ------------------------------------------------------------------
  # :max_runs -- deterministic bounded prefix, honestly named
  # ------------------------------------------------------------------

  test "max_runs judges a deterministic prefix and names the unjudged remainder" do
    dir = tmp_dir()
    {run_a, _} = closed_run!("aps-autonomic:ocel-conf-max-a#1", :alive)
    {run_b, _} = closed_run!("aps-autonomic:ocel-conf-max-b#1", :alive)

    campaign = campaign_row!("conformance qualification, bounded")

    ledger =
      write_ledger!(dir, [
        attempt_start("ocel-conf-max-a", 1, run_a.id),
        attempt_start("ocel-conf-max-b", 1, run_b.id)
      ])

    assert {:ok, report} =
             OcelConformance.campaign(campaign.id, ledger: ledger, max_runs: 1)

    assert report.named == 3
    assert report.total == 1
    assert Enum.map(report.runs, & &1.run_id) == [run_a.id]
    assert report.valid == 1
    assert report.status == :conformant

    assert {:ok, report2} =
             OcelConformance.campaign(campaign.id, ledger: ledger, max_runs: 2)

    assert Enum.map(report2.runs, & &1.run_id) == [run_a.id, run_b.id]
    assert report2.total == 2 and report2.valid == 2

    # Same input, same bound -> byte-identical judgment (determinism).
    assert {:ok, report_again} =
             OcelConformance.campaign(campaign.id, ledger: ledger, max_runs: 2)

    assert report_again.runs == report2.runs
  end

  test "max_runs must be a positive integer" do
    dir = tmp_dir()
    campaign = campaign_row!("conformance qualification, bad bound")
    ledger = write_ledger!(dir, [])

    assert {:error, {:bad_opt, :max_runs, 0}} =
             OcelConformance.campaign(campaign.id, ledger: ledger, max_runs: 0)

    assert {:error, {:bad_opt, :max_runs, -3}} =
             OcelConformance.campaign(campaign.id, ledger: ledger, max_runs: -3)
  end

  # ------------------------------------------------------------------
  # Fail-closed: ledger absence, corruption, export failure
  # ------------------------------------------------------------------

  test "an absent ledger refuses the whole judgment" do
    campaign = campaign_row!("conformance qualification, no ledger")
    missing = Path.join(tmp_dir(), "absent.ndjson")

    assert {:error, {:ledger_not_found, ^missing}} =
             OcelConformance.campaign(campaign.id, ledger: missing)
  end

  test "a corrupt ledger line refuses the whole judgment with its location" do
    campaign = campaign_row!("conformance qualification, corrupt ledger")
    path = Path.join(tmp_dir(), "corrupt.ndjson")

    File.write!(
      path,
      Jason.encode!(%{"event" => "campaign_start"}) <> "\n" <> "{not json at all" <> "\n"
    )

    assert {:error, {:malformed_ledger, ^path, 2, _reason}} =
             OcelConformance.campaign(campaign.id, ledger: path)
  end

  test "an attempt_start without a string run_id is a broken census fact" do
    campaign = campaign_row!("conformance qualification, broken census")
    path = Path.join(tmp_dir(), "broken.ndjson")

    File.write!(
      path,
      Jason.encode!(%{"event" => "attempt_start", "data" => %{"item" => "x"}}) <> "\n"
    )

    assert {:error, {:malformed_ledger_event, "attempt_start", %{"item" => "x"}}} =
             OcelConformance.campaign(campaign.id, ledger: path)
  end

  test "an export failure refuses the whole judgment (never a silent pass)" do
    dir = tmp_dir()
    {run_a, _} = closed_run!("aps-autonomic:ocel-conf-exp-a#1", :alive)
    {run_missing, _} = closed_run!("aps-autonomic:ocel-conf-exp-b#1", :alive)
    campaign = campaign_row!("conformance qualification, export failure")

    ledger =
      write_ledger!(dir, [
        attempt_start("ocel-conf-exp-a", 1, run_a.id),
        attempt_start("ocel-conf-exp-b", 1, run_missing.id),
        # A run id that exists nowhere: the REAL egress refuses it.
        attempt_start("ocel-conf-ghost", 1, "00000000-0000-4000-8000-00000000dead")
      ])

    assert {:error, {:run_export_failed, "00000000-0000-4000-8000-00000000dead", :run_not_found}} =
             OcelConformance.campaign(campaign.id, ledger: ledger)
  end

  # ------------------------------------------------------------------
  # Bounded tmpdir usage: clean per run, parent removed on return
  # ------------------------------------------------------------------

  test "the throwaway tmpdir is removed when the call returns" do
    dir = tmp_dir()
    {run_a, _} = closed_run!("aps-autonomic:ocel-conf-tmp#1", :alive)
    campaign = campaign_row!("conformance qualification, tmpdir")
    ledger = write_ledger!(dir, [attempt_start("ocel-conf-tmp", 1, run_a.id)])
    parent = Path.join(dir, "exports")

    assert {:ok, %{status: :conformant}} =
             OcelConformance.campaign(campaign.id, ledger: ledger, tmp_dir: parent)

    refute File.exists?(parent)
  end

  # ------------------------------------------------------------------
  # Single-run mode
  # ------------------------------------------------------------------

  test "run/1: a valid run is judged valid; an unknown run refuses" do
    {run, _} = closed_run!("aps-autonomic:ocel-conf-single#1", :alive)

    assert {:ok, %{run_id: run_id, status: :valid, events: events, objects: objects}} =
             OcelConformance.run(run.id)

    assert run_id == run.id
    assert events >= 1 and objects >= 1

    assert {:error, {:run_export_failed, "00000000-0000-4000-8000-00000000dead", :run_not_found}} =
             OcelConformance.run("00000000-0000-4000-8000-00000000dead")
  end

  # ------------------------------------------------------------------
  # The mix task's pure exit-code contract (halt observed out-of-test)
  # ------------------------------------------------------------------

  test "exit_status/1: 0 only when everything is valid; 1 on violations; 2 when blocked" do
    assert Mix.Tasks.Xaas.Ultracode.OcelConformance.exit_status({:ok, :conformant}) == 0
    assert Mix.Tasks.Xaas.Ultracode.OcelConformance.exit_status({:ok, :violations}) == 1

    assert Mix.Tasks.Xaas.Ultracode.OcelConformance.exit_status({:error, :campaign_not_found}) ==
             2

    assert Mix.Tasks.Xaas.Ultracode.OcelConformance.exit_status(
             {:error, {:run_export_failed, "r", :run_not_found}}
           ) == 2
  end

  # ------------------------------------------------------------------
  # Fixtures: real rows through real Ash actions, real ndjson ledger
  # (the Learn test's builder shapes, trimmed to what this court reads)
  # ------------------------------------------------------------------

  defp closed_run!(subject, outcome, evidence \\ alive_evidence()) do
    {run, epoch} = new_run!(subject)

    epoch =
      epoch
      |> Ash.Changeset.for_update(:start, %{}, authorize?: false)
      |> Ash.update!()
      |> Ash.Changeset.for_update(:complete, %{final_head: "ocel-conf-final-head"},
        authorize?: false
      )
      |> Ash.update!()

    _receipt = seal!(epoch, outcome, evidence)
    {run, epoch}
  end

  defp failed_run!(subject, outcome, evidence \\ %{"refusal_reason" => "worker_no_close"}) do
    {run, epoch} = new_run!(subject)

    epoch =
      epoch
      |> Ash.Changeset.for_update(:start, %{}, authorize?: false)
      |> Ash.update!()
      |> Ash.Changeset.for_update(:mark_failed, %{}, authorize?: false)
      |> Ash.update!()

    _receipt = seal!(epoch, outcome, evidence)
    {run, epoch}
  end

  # :alive requires the qualifying court (`AliveRequiresCourt` on `:seal`).
  defp alive_evidence, do: %{"head_verified" => true, "fabric_verifier" => %{"status" => "pass"}}

  defp seal!(epoch, outcome, evidence) do
    Receipt
    |> Ash.Changeset.for_create(
      :seal,
      %{
        epoch_id: epoch.id,
        subject: epoch.exact_subject,
        outcome: outcome,
        evidence: evidence,
        sealed_at: DateTime.utc_now()
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp new_run!(subject) do
    run =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "OcelConformance qualification.", provider: "zcode-ocel-conformance-test"},
        authorize?: false
      )
      |> Ash.create!()

    run =
      run
      |> Ash.Changeset.for_update(:start, %{exact_subject: subject}, authorize?: false)
      |> Ash.update!()

    {:ok, [epoch]} =
      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(exact_subject == ^subject)
      |> Ash.read(authorize?: false)

    {run, epoch}
  end

  defp campaign_row!(goal_suffix) do
    Run
    |> Ash.Changeset.for_create(
      :create,
      %{
        goal: "#{Campaign.goal_marker()} #{goal_suffix}",
        provider: "zcode-ocel-conformance-test"
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp write_ledger!(dir, events) do
    path = Path.join(dir, "ledger.ndjson")
    File.mkdir_p!(dir)
    File.write!(path, Enum.map_join(events, "\n", &Jason.encode!/1) <> "\n")
    path
  end

  defp attempt_start(item, attempt, run_id) do
    %{
      "event" => "attempt_start",
      "ts" => iso(~U[2026-09-22T10:00:00Z]),
      "data" => %{"item" => item, "attempt" => attempt, "run_id" => run_id}
    }
  end

  defp iso(dt), do: DateTime.to_iso8601(dt)

  defp tmp_dir do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-ocel-conformance-test-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    ExUnit.Callbacks.on_exit({__MODULE__, dir}, fn -> File.rm_rf(dir) end)
    dir
  end
end
