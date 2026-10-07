defmodule Xaas.Semantics.OversightGovernanceTest do
  @moduledoc """
  Chicago tests for `Xaas.Semantics.OversightGovernance` (lane W537).

  No mocks: the real module over the real repo tree. Every cited path is
  verified to exist on disk; determinism is asserted by structural equality
  across repeated calls; honesty is asserted by requiring typed OPEN_GAP
  entries to be present (not hidden).
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.OversightGovernance

  @repo_root File.cwd!()

  describe "cited_paths/0" do
    test "every cited path exists on disk under the repo root" do
      for path <- OversightGovernance.cited_paths() do
        assert File.exists?(Path.join(@repo_root, path)),
               "cited path does not exist: #{path}"
      end
    end

    test "covers the receipt, witness, emitter, and ash_onetime prune/reap machinery" do
      paths = OversightGovernance.cited_paths()
      assert "lib/xaas/actuation.ex" in paths
      assert "lib/xaas/witness/certified_receipt.ex" in paths
      assert "lib/xaas/telemetry/ocel_ash_emitter.ex" in paths
      assert "deps/ash_onetime/lib/mix/tasks/ash_onetime.prune.ex" in paths
      assert "deps/ash_onetime/lib/mix/tasks/ash_onetime.reap.ex" in paths
    end
  end

  describe "retention_policy/0" do
    test "returns the typed Art. 26.6 structure" do
      assert {:ok, policy} = OversightGovernance.retention_policy()
      assert policy.actuation_receipts == :permanent_durable_rows
      assert policy.ephemeral_artifacts == :lane_lease_cleanup
      assert is_list(policy.source) and policy.source != []
    end

    test "every source path exists on disk" do
      {:ok, policy} = OversightGovernance.retention_policy()
      for path <- policy.source do
        assert File.exists?(Path.join(@repo_root, path)), "missing source: #{path}"
      end
    end

    test "is deterministic" do
      assert OversightGovernance.retention_policy() == OversightGovernance.retention_policy()
    end
  end

  describe "worker_notification/0 carries the honest OPEN_GAP" do
    test "typed structure with emitter + egress paths that exist" do
      assert {:ok, wn} = OversightGovernance.worker_notification()
      assert wn.article == "Art. 26.7"
      assert wn.channel == :receipt_corpus_plus_ocel_events
      assert File.exists?(Path.join(@repo_root, wn.notification_record.emitter.path))
      for e <- wn.notification_record.egress do
        assert File.exists?(Path.join(@repo_root, e.path))
      end
    end

    test "incident reporting is typed OPEN_GAP, not hidden" do
      {:ok, wn} = OversightGovernance.worker_notification()
      assert {:OPEN_GAP, details} = wn.incident_reporting
      assert details.item =~ "3.49"
      assert details.basis != ""
      assert File.exists?(Path.join(@repo_root, details.cite))
    end

    test "is deterministic" do
      assert OversightGovernance.worker_notification() == OversightGovernance.worker_notification()
    end
  end

  describe "fria/0" do
    test "deployer-class FRIA with per-right evidence citations that exist" do
      assert {:ok, fria} = OversightGovernance.fria()
      assert fria.assessment_class == :deployer
      assert match?([_ | _], fria.rights)

      for r <- fria.rights do
        assert is_atom(r.right)
        assert is_binary(r.article) and r.article != ""
        assert is_binary(r.protection) and r.protection != ""
        assert r.status in [:EVIDENCED, :OPEN_GAP]

        for e <- r.evidence do
          assert File.exists?(Path.join(@repo_root, e.path)),
                 "FRIA evidence path does not exist: #{e.path}"
          assert is_binary(e.basis) and e.basis != ""
        end
      end
    end

    test "non-discrimination cites the W502 bias gate" do
      {:ok, fria} = OversightGovernance.fria()
      r = Enum.find(fria.rights, &(&1.right == :non_discrimination))
      assert r.status == :EVIDENCED
      assert Enum.any?(r.evidence, &(&1.basis == "REFUSED_BIAS_THRESHOLD"))
    end

    test "due process cites typed refusals + replayable receipts"  do
      {:ok, fria} = OversightGovernance.fria()
      r = Enum.find(fria.rights, &(&1.right == :due_process))
      assert r.status == :EVIDENCED
      paths = Enum.map(r.evidence, & &1.path)
      assert "lib/xaas/actuation.ex" in paths
      assert "lib/xaas/witness/certified_receipt.ex" in paths
    end

    test "privacy entry asserts zero-PII admission over the Art. 5 profile" do
      {:ok, fria} = OversightGovernance.fria()
      r = Enum.find(fria.rights, &(&1.right == :privacy))
      assert r.status == :EVIDENCED
      assert Enum.any?(r.evidence, fn e ->
               e.path == "lib/xaas/semantics/eu_ai_act_admission.ex" and
                 e.basis =~ "never inspects free text"
             end)
    end

    test "honest limitation: serious-incident authority channel is typed OPEN_GAP" do
      {:ok, fria} = OversightGovernance.fria()
      r = Enum.find(fria.rights, &(&1.right == :access_to_effective_remedy_authority_channel))
      assert r.status == :OPEN_GAP
      assert Enum.any?(r.evidence, &(&1.basis =~ "no incident surface"))
    end

    test "is deterministic" do
      assert OversightGovernance.fria() == OversightGovernance.fria()
    end
  end

  describe "ai_literacy/0 (Art. 4.1)" do
    test "structured measures with real, existing evidence paths" do
      assert {:ok, lit} = OversightGovernance.ai_literacy()
      assert match?([_ | _], lit.measures)
      assert lit.audience == "operators/oversight personnel"

      for m <- lit.measures do
        assert is_binary(m.name) and m.name != ""
        assert File.exists?(Path.join(@repo_root, m.evidence_path)),
               "ai_literacy evidence path does not exist: #{m.evidence_path}"
        assert is_binary(m.basis) and m.basis != ""
      end

      for p <- lit.source do
        assert File.exists?(Path.join(@repo_root, p)), "missing source: #{p}"
      end
    end

    test "cites the CRO loop and the executable-regulation suite" do
      {:ok, lit} = OversightGovernance.ai_literacy()
      paths = Enum.map(lit.measures, & &1.evidence_path)
      assert "docs/cro/CRO-LOOP.md" in paths
      assert "test/eu_ai_act/README.md" in paths
    end

    test "is deterministic" do
      assert OversightGovernance.ai_literacy() == OversightGovernance.ai_literacy()
    end
  end

  describe "fria_schedule/0 (Art. 27.1.b)" do
    test "period/trigger schedule with existing evidence paths" do
      assert {:ok, sched} = OversightGovernance.fria_schedule()
      assert sched.period == "per-wave"
      assert sched.trigger == "corpus drift falsifier"

      for p <- sched.evidence do
        assert File.exists?(Path.join(@repo_root, p)), "missing evidence: #{p}"
      end
    end

    test "is deterministic" do
      assert OversightGovernance.fria_schedule() == OversightGovernance.fria_schedule()
    end
  end

  describe "fria_oversight_description/0 (Art. 27.1.e)" do
    test "description + controls with real, existing cited paths" do
      assert {:ok, desc} = OversightGovernance.fria_oversight_description()
      assert match?([_ | _], desc.description)
      assert Enum.all?(desc.description, &is_binary/1)

      for c <- desc.controls do
        assert File.exists?(Path.join(@repo_root, c)), "missing control: #{c}"
      end

      assert "lib/xaas/semantics/counterfactual.ex" in desc.controls
      assert "lib/xaas/semantics/admission_attribution.ex" in desc.controls
    end

    test "is deterministic" do
      assert OversightGovernance.fria_oversight_description() ==
               OversightGovernance.fria_oversight_description()
    end
  end
end
