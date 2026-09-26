defmodule Xaas.Ultracode.AutonomyEgressTest do
  @moduledoc """
  Qualification of the episode-level OCEL 2.0 ndjson egress and the
  UAR/DCR audit law:

    * the exported log passes the REAL conformance court
      (`Xaas.Telemetry.OcelNdjson.validate_ndjson_file/1` -- the same
      `Xaas.Ultracode.Ocel.Validator` the run export and the emitter sink
      answer to);
    * the CONTRACT object types are declared, and the emitted vocabulary is
      the CONTRACT's (episode-scoped event classes + qualifiers);
    * the RECONSTRUCTED law: derived-inference events carry
      `reconstructed: true`; row-backed lifecycle events do not;
    * determinism: same rows -> byte-identical log;
    * audit: a terminal epoch without a standing receipt is UAR; an epoch
      with two standing receipts is DCR; a clean window is ALIVE.
  """

  use ExUnit.Case, async: false

  require Ash.Query

  alias Xaas.Ultracode.{AutonomyAudit, AutonomyEgress, Epoch, Lease, Receipt, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
    end)

    :ok
  end

  defp semantic_run(provider) do
    Run
    |> Ash.Changeset.for_create(
      :create,
      %{
        goal: "egress qualification.",
        provider: provider,
        work_order_iri: "urn:sj:wo:egress",
        checkpoint_iri: "urn:sj:ckpt:egress",
        graph_digest: "sha256:#{String.duplicate("e", 64)}",
        repository_identity: "seanchatmangpt/xaas",
        base_sha: String.duplicate("f", 40),
        capability_id: "zcode:fix-build",
        execution_policy: :autonomic_wave_attempt
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp running_epoch(run, cycle, subject) do
    Epoch
    |> Ash.Changeset.for_create(
      :create,
      %{run_id: run.id, cycle: cycle, exact_subject: subject, state: :running},
      authorize?: false
    )
    |> Ash.create!()
  end

  defp claim(epoch_id, provider) do
    {:ok, _epoch, token, _run} = Lease.claim_next(provider, "egress-worker", epoch_id: epoch_id)
    token
  end

  defp seal(epoch, outcome, evidence \\ %{}) do
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
    |> Ash.create!(actor: Xaas.SystemAuthority.new(:ultracode_reactor))
  end

  defp mktmp do
    Path.join(System.tmp_dir!(), "autonomy-egress-#{System.unique_integer([:positive])}")
    |> tap(&File.mkdir_p!/1)
  end

  # ------------------------------------------------------------------
  # Egress
  # ------------------------------------------------------------------

  describe "derive_episode_lines/1 + export_episode/2" do
    test "the episode log passes the REAL conformance court and carries the CONTRACT vocabulary" do
      run = semantic_run("egress-a")
      epoch = running_epoch(run, 0, "egress:subject-a")
      token = claim(epoch.id, "egress-a")
      {:ok, _closed, _receipt} = Lease.close(token, "head", :blocked)

      # A second attempt (cycle 1) whose receipt carries the fabric verdict
      # (sealed through the court law: alive requires head + verifier pass).
      epoch2 = running_epoch(run, 1, "egress:subject-a2")

      seal(epoch2, :alive, %{
        "head_verified" => true,
        "fabric_verifier" => %{"status" => "pass"}
      })

      dir = mktmp()
      assert {:ok, path} = AutonomyEgress.export_episode(run, dir)

      assert {:ok, report} = Xaas.Telemetry.OcelNdjson.validate_ndjson_file(path)
      assert report["status"] == "valid"
      assert is_integer(report["event_count"]) and report["event_count"] > 0

      {:ok, lines} = AutonomyEgress.derive_episode_lines(run)

      event_types =
        lines |> Enum.flat_map(& &1["ocel:eventTypes"]) |> Enum.map(& &1["name"]) |> Enum.uniq()

      for required <- ~w(provider.select worker.claim receipt.persist reobserve) do
        assert required in event_types, "missing CONTRACT event #{required}"
      end

      object_types =
        lines |> Enum.flat_map(& &1["ocel:objectTypes"]) |> Enum.map(& &1["name"]) |> MapSet.new()

      declared = object_types

      for t <-
            ~w(Episode Provider Worker WorkerRun Subject Authority Receipt Consequence Evidence WorkOrder) do
        assert t in declared, "declared object types must include #{t}"
      end

      # Qualifiers are the CONTRACT's.
      qualifiers =
        lines
        |> Enum.flat_map(& &1["ocel:events"])
        |> Enum.flat_map(& &1["relationships"])
        |> Enum.map(& &1["qualifier"])
        |> MapSet.new()

      for q <-
            ~w(episode provider worker subject receipt consequence evidence originAuthority input output) do
        assert q in qualifiers, "missing CONTRACT qualifier #{q}"
      end

      # Provider identity appears ONLY as the Provider object (its id IS the
      # provider string) -- never on work orders or receipts.
      work_orders =
        lines
        |> Enum.flat_map(& &1["ocel:objects"])
        |> Enum.filter(&(&1["type"] == "WorkOrder"))

      assert work_orders != []
      refute Enum.any?(work_orders, &Map.has_key?(&1["attributes"], "provider"))
    end

    test "RECONSTRUCTED law: derived inferences are marked, row-backed events are not" do
      run = semantic_run("egress-b")
      epoch = running_epoch(run, 0, "egress:subject-b")
      token = claim(epoch.id, "egress-b")
      {:ok, _closed, _receipt} = Lease.close(token, "head", :partial_alive)

      {:ok, lines} = AutonomyEgress.derive_episode_lines(run)

      events = Enum.flat_map(lines, & &1["ocel:events"])

      assert %{"attributes" => %{"reconstructed" => true}} =
               Enum.find(events, &(&1["type"] == "provider.select"))

      assert %{"attributes" => %{"reconstructed" => true}} =
               Enum.find(events, &(&1["type"] == "reobserve"))

      row_backed = Enum.find(events, &(&1["type"] == "worker.claim"))
      assert row_backed
      refute Map.has_key?(row_backed["attributes"], "reconstructed")

      persisted = Enum.find(events, &(&1["type"] == "receipt.persist"))
      assert persisted
      refute Map.has_key?(persisted["attributes"], "reconstructed")
    end

    test "cancellation is NOT emitted as execution.crash (the receipt.persist :blocked carries it)" do
      run = semantic_run("egress-cancel")
      epoch = running_epoch(run, 0, "egress:subject-cancel")
      token = claim(epoch.id, "egress-cancel")

      assert {:ok, _cancelled, _r} = Lease.cancel(token, :superseded)

      {:ok, lines} = AutonomyEgress.derive_episode_lines(run)
      events = Enum.flat_map(lines, & &1["ocel:events"])

      refute Enum.any?(events, &(&1["type"] == "execution.crash")),
             "a cancelled epoch must not be misnamed as a crash"

      blocked =
        Enum.find(events, fn e ->
          e["type"] == "receipt.persist" and e["attributes"]["outcome"] == "blocked"
        end)

      assert blocked, "the cancellation's :blocked receipt.persist must be present"
    end

    test "DETERMINISM: same rows -> byte-identical log" do
      run = semantic_run("egress-det")
      epoch = running_epoch(run, 0, "egress:subject-det")
      token = claim(epoch.id, "egress-det")
      {:ok, _closed, _r} = Lease.close(token, "head", :partial_alive)

      {:ok, lines1} = AutonomyEgress.derive_episode_lines(run)
      {:ok, lines2} = AutonomyEgress.derive_episode_lines(run)

      assert lines1 == lines2
    end

    test "an unknown run id is typed" do
      assert {:error, :run_not_found} = AutonomyEgress.derive_episode_lines(Ecto.UUID.generate())
    end
  end

  # ------------------------------------------------------------------
  # Audit law: UAR / DCR
  # ------------------------------------------------------------------

  describe "AutonomyAudit.audit/1 (UAR=0, DCR=0)" do
    test "a clean window is ALIVE (receipted actuations, no duplicates)" do
      run = semantic_run("audit-clean")
      epoch = running_epoch(run, 0, "audit:clean")
      token = claim(epoch.id, "audit-clean")
      {:ok, _closed, _r} = Lease.close(token, "head", :partial_alive)

      assert {:ok, report} = AutonomyAudit.audit(since: DateTime.add(DateTime.utc_now(), -60))
      assert report.standing == :alive
      assert report.uar == []
      assert report.dcr == []
      assert report.epochs_audited >= 1
    end

    test "a terminal epoch with NO standing receipt is an UAR (unreceipted actuation)" do
      run = semantic_run("audit-uar")
      running_epoch(run, 0, "audit:uar")

      # Land it terminal through the fabric's own typed refusal path: no
      # standing receipt is sealed by a bare mark_failed on an unclaimed epoch.
      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.read_one!()
      |> then(fn epoch ->
        epoch
        |> Ash.Changeset.for_update(:mark_failed, %{}, authorize?: false)
        |> Ash.update!(actor: Xaas.SystemAuthority.new(:ultracode_reactor))
      end)

      assert {:ok, report} = AutonomyAudit.audit(since: DateTime.add(DateTime.utc_now(), -60))
      assert length(report.uar) == 1, "expected the bare :failed epoch to count as UAR"
      assert report.standing != :alive
    end

    test "an epoch with TWO standing receipts is a DCR (duplicate consequence)" do
      run = semantic_run("audit-dcr")
      epoch = running_epoch(run, 0, "audit:dcr")

      # Close it once through the fabric (receipt 1, epoch terminal), then
      # seal a second standing receipt over the same epoch (the duplicate).
      token = claim(epoch.id, "audit-dcr")
      {:ok, _closed, _r1} = Lease.close(token, "head", :partial_alive)
      seal(epoch, :blocked, %{"head_verified" => false})

      assert {:ok, report} = AutonomyAudit.audit(since: DateTime.add(DateTime.utc_now(), -60))
      assert epoch.id in report.dcr
      assert report.uar == []
      assert match?({:partial_alive, _}, report.standing)
    end

    test "heartbeat-only receipts do NOT satisfy the receipt law (still UAR)" do
      run = semantic_run("audit-heartbeat")
      epoch = running_epoch(run, 0, "audit:heartbeat")

      seal(epoch, :heartbeat)
      _ = epoch

      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.read_one!()
      |> then(fn e ->
        e
        |> Ash.Changeset.for_update(:mark_failed, %{}, authorize?: false)
        |> Ash.update!(actor: Xaas.SystemAuthority.new(:ultracode_reactor))
      end)

      assert {:ok, report} = AutonomyAudit.audit(since: DateTime.add(DateTime.utc_now(), -60))
      assert length(report.uar) == 1
    end
  end
end
