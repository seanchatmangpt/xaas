defmodule Xaas.Generation.StragglersCourtW984jvTest do
  @moduledoc """
  W984jv — unclaimed-family stragglers court for `lib/xaas/generation/`,
  going past W984hj's receipt.

  Census result vs W984hj:

  - `DependencyGraph.build/1` happy grouping + `projections_for/2` missing-source
    edge are COVERED (test/xaas/generation_test.exs). Remaining unexercised
    state-bearing branches courted here:
      1. build/1 over the empty manifest (the `%{}` degenerate graph arm).
      2. The `Enum.sort` normalization arm: arrival order in the manifest must
         not leak into the graph (a mutation deleting the sort previously
         survives the suite because the covered fixture arrives pre-sorted).
      3. Duplicate (source, projection) declaration: group_by preserves
         duplicates; the graph must report them faithfully rather than silently
         deduplicating (a mutation adding `Enum.uniq/1` previously survives).
  - `ResidueRegistry` :missing_reason / :file_not_found cond arms and the
    registered?/reason_for hit-arms are structurally unreachable while
    `@entries == []` (no injection seam; the list is a compile-time attribute
    by design — "a human decided this file is a deliberate exception").
    Typed COVERED-VACUOUS, not a test gap; no filler test written.

  Real structs, real graph data, zero mocks. Chicago: assert on final state.
  """

  use ExUnit.Case, async: true

  alias Xaas.Generation.DependencyGraph
  alias Xaas.Generation.Manifest

  describe "DependencyGraph.build/1 empty-manifest arm" do
    test "empty entry list yields the empty graph and [] lookups" do
      # Mutation rationale: a mutation making build/1 crash or return a
      # non-map on [] previously survived — the suite never fed it an
      # empty manifest.
      graph = DependencyGraph.build([])
      assert graph == %{}
      assert DependencyGraph.projections_for(graph, "anything.ttl") == []
    end
  end

  describe "DependencyGraph.build/1 sort-normalization arm" do
    test "arrival order of manifest entries does not leak into the graph" do
      # Mutation rationale: deleting Enum.sort previously survived the
      # covered suite because its fixture arrives pre-sorted (a1 before a2).
      entries =
        Manifest.load([
          %{source_path: "ontology/z.ttl", projection_path: "gen/z2.ex", generator_id: "ggen"},
          %{source_path: "ontology/z.ttl", projection_path: "gen/z1.ex", generator_id: "ggen"},
          %{source_path: "ontology/z.ttl", projection_path: "gen/z3.ex", generator_id: "ggen"}
        ])

      graph = DependencyGraph.build(entries)
      assert DependencyGraph.projections_for(graph, "ontology/z.ttl") == [
               "gen/z1.ex",
               "gen/z2.ex",
               "gen/z3.ex"
             ]
    end
  end

  describe "DependencyGraph.build/1 duplicate-declaration arm" do
    test "duplicate (source, projection) declarations are preserved, not deduplicated" do
      # Mutation rationale: an Enum.uniq injection (silent dedup) previously
      # survived — the suite never declared the same projection twice. The
      # graph is a faithful report of what the manifest declares; dedup is a
      # manifest-layer concern, not a graph-layer one.
      entries =
        Manifest.load([
          %{source_path: "ontology/d.ttl", projection_path: "gen/d1.ex", generator_id: "ggen"},
          %{source_path: "ontology/d.ttl", projection_path: "gen/d1.ex", generator_id: "ggen"}
        ])

      graph = DependencyGraph.build(entries)
      assert DependencyGraph.projections_for(graph, "ontology/d.ttl") == [
               "gen/d1.ex",
               "gen/d1.ex"
             ]
    end
  end
end
