defmodule Xaas.ZcodePlugin.GallWorkContractTest do
  use ExUnit.Case, async: true

  @moduledoc """
  The gall-work contract, both directions.

  `priv/zcode_plugin/gall-work.contract.json` (contract_version 1) is the
  shared fixture between this repo and zcode-cli: byte-identical in both
  repositories (zcode-cli pins it at `test/fixtures/gall-work.contract.json`),
  with each side's test suite pinning the exact sha256. A change to the
  contract must land in BOTH repos in the same wave; either pin failing means
  cross-repo drift, which is exactly what this court exists to catch.

  The contract binds the native `zcode gall-work` lifecycle (claim -> persist
  -> construct -> close over the execution fabric's MCP surface) to the XaaS
  dispatch side:

    * `scripts/xaas-glm-failover-dispatcher.sh`'s semantic path invokes
      `gall-work --lease <descriptor>` with `XAAS_WORKER=1`/`XAAS_LEASE_CWD`.
    * `Xaas.Ultracode.Dispatch` plans the same native protocol for semantic
      runs and keeps the generic `/xaas` prompt ONLY for non-semantic waves.
    * there is NO `/xaas claim_next` fallback for the semantic dispatch: an
      old CLI exits non-zero and the dispatch is classified failed.
  """

  @contract_path "priv/zcode_plugin/gall-work.contract.json"

  # Byte-identity pin: the sha256 of the shared fixture. Both repos' tests
  # assert this exact digest; update BOTH in the same wave when the contract
  # changes (bump contract_version with it).
  @contract_sha256 "390c9a3b8677fb9b0a408e6072d32868fd45901b9fdaa4ab62ec7603b6040f6a"

  test "the shared fixture is byte-identical to the pinned cross-repo digest" do
    assert File.exists?(@contract_path), "the contract fixture is missing from priv/zcode_plugin"

    text = File.read!(@contract_path)
    assert :crypto.hash(:sha256, text) |> Base.encode16(case: :lower) == @contract_sha256
  end

  test "declares contract_version 1 and the exact dispatcher-facing argv" do
    contract = contract()

    assert contract["contract"] == "gall-work"
    assert contract["contract_version"] == 1
    assert contract["command"]["name"] == "zcode gall-work"

    assert contract["command"]["argv"] == [
             "gall-work",
             "--worker-id",
             "<worker_id>",
             "--epoch-id",
             "<epoch_uuid>",
             "--cwd",
             "<abs_cwd>",
             "--json"
           ]

    assert contract["command"]["argv_lease_form"] == [
             "gall-work",
             "--lease",
             "<descriptor.json>",
             "--json"
           ]

    assert contract["command"]["descriptor_schema"] == "gall.work-lease/1"
  end

  test "binds the fabric tool surface, outcome vocabulary and exit codes" do
    contract = contract()
    tools = contract["fabric"]["tools"]

    assert MapSet.new(Map.keys(tools)) ==
             MapSet.new(["claim_next", "heartbeat", "close_candidate", "refuse"])

    claim = tools["claim_next"]
    assert claim["arguments"]["provider"] == "zcode"

    assert MapSet.new(claim["result_fields"]) ==
             MapSet.new([
               "lease_token",
               "lease_expires_at",
               "epoch_id",
               "cycle",
               "exact_subject",
               "goal",
               "worktree",
               "verifier_suite"
             ])

    assert contract["fabric"]["outcome_vocabulary"] == [
             "alive",
             "partial_alive",
             "blocked",
             "build_broken",
             "unsupported",
             "refused"
           ]

    assert MapSet.new(Map.keys(contract["exit_codes"])) ==
             MapSet.new(["0", "1", "2", "65", "142"])
  end

  test "encodes the no-fallback law, the gate env, and the goal-off-argv transport" do
    contract = contract()

    assert contract["no_fallback_law"] =~ "/xaas claim_next"
    assert contract["goal_transport"] =~ "NEVER"
    assert contract["env"]["XAAS_WORKER"] == "1"
    assert contract["env"]["XAAS_LEASE_CWD"] == "<abs_cwd>"

    # The failover classification the dispatcher applies to the worker's
    # output must stay greppable (the same patterns the boundary classifies).
    assert contract["failover_grep"] =~ "1302"
    assert contract["failover_grep"] =~ "429"
  end

  defp contract do
    @contract_path |> File.read!() |> Jason.decode!()
  end
end
