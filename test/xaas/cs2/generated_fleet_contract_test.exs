defmodule Xaas.CS2.GeneratedFleetContractTest do
  @moduledoc """
  W650h9 depth court for Xaas.CS2.GeneratedFleetContract (recensus top-15,
  unclaimed). Real invariants over the data-only admission predicate:
  contract shape and accepts?/1 subject+work_id gating. Mutation rationale
  per test.
  """

  use ExUnit.Case, async: true

  alias Xaas.CS2.GeneratedFleetContract

  describe "contract/0" do
    test "binds the exact canonical admission shape" do
      # Mutation rationale: kills any drift in the generated binding (subject,
      # work_id, ceiling, provenance) — this map is the admission contract
      # other repos read.
      assert %{
               subject: "RFC-CS2-001",
               campaign: "CS2-CHICAGO",
               producer: "seanchatmangpt/ggen",
               pack: "cs2-fleet-contract",
               consumer: "xaas",
               upstream_consumer: "ash_a2a",
               work_id: "CS2-WRK-013",
               authority_ceiling: :construct,
               requires_exact_subject: true,
               requires_provenance: true,
               requires_receipt_replay: true
             } = GeneratedFleetContract.contract()
    end
  end

  describe "accepts?/1" do
    test "accepts the canonical work id with atom keys" do
      # Mutation rationale: kills the subject/work_id equality checks both
      # degrading to true.
      assert GeneratedFleetContract.accepts?(%{subject: "RFC-CS2-001", work_id: "CS2-WRK-013"})
    end

    test "accepts string-keyed packets and the historical work id CS2-WRK-012" do
      # Mutation rationale: kills Map.get falling back only to one key type
      # (string-keyed producers rejected) and removing "CS2-WRK-012" from the
      # accepted set.
      assert GeneratedFleetContract.accepts?(%{"subject" => "RFC-CS2-001", "work_id" => "CS2-WRK-012"})
    end

    test "rejects wrong subject or wrong work id even when the other matches" do
      # Mutation rationale: kills `and` degrading to `or` — a foreign subject
      # riding a valid work id (or vice versa) must not be admitted.
      refute GeneratedFleetContract.accepts?(%{subject: "RFC-OTHER", work_id: "CS2-WRK-013"})
      refute GeneratedFleetContract.accepts?(%{subject: "RFC-CS2-001", work_id: "CS2-WRK-999"})
    end

    test "rejects non-map packets as false, not a crash" do
      # Mutation rationale: kills deleting the catch-all head (would raise
      # FunctionClauseError for atoms/lists/nil).
      refute GeneratedFleetContract.accepts?(:atom)
      refute GeneratedFleetContract.accepts?([%{subject: "RFC-CS2-001"}])
      refute GeneratedFleetContract.accepts?(nil)
    end
  end
end
