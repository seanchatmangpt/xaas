defmodule Xaas.SelfDigest.WorkDepthTest do
  @moduledoc """
  Lane W650h20 depth court over `Xaas.SelfDigest.Work`.

  W650w's promotion-pipeline court constructs a Work only as an argument to
  promote/4; the module's own state-bearing surface — stable-id derivation
  from the gap, acceptance := falsifier binding, and authority defaulting —
  has zero direct coverage. This court pins those invariants as-real.

  Chicago-style: real module under test, no mocks, assertions on final
  struct state. Each test names the mutant class it kills.
  """

  use ExUnit.Case, async: true

  alias Xaas.SelfDigest.{Gap, Work}

  defp gap(subject, claim) do
    Gap.new(subject, claim, fn ev -> ev.value == :falsified end)
  end

  defp construct, do: fn _work -> {:ok, :built} end

  test "from_gap derives subject, acceptance, and construct_only authority from the gap" do
    # Mutant killed: from_gap/2 dropping the acceptance := gap.falsifier
    # binding (or defaulting authority to something broader) — work orders
    # would carry a weaker (or no) acceptance surface and acquire
    # authority the gap never admitted.
    g = gap("repo://xaas@work-surface", "derived work identity")
    w = Work.from_gap(g, construct())

    assert %Work{} = w
    assert w.subject == "repo://xaas@work-surface"
    assert w.gap == g
    assert w.acceptance == g.falsifier
    assert is_function(w.construct, 1)
    assert w.authority == :construct_only
    assert w.state == :ready
  end

  test "stable id is a deterministic digest of (subject, claim) only" do
    # Mutant killed: stable_id digesting mutable fields (priority,
    # dependencies, evidence status) — the same logical work order would
    # change identity across census/admission state transitions, breaking
    # subject-keyed demand dedup.
    g1 = gap("repo://xaas@work-surface", "same claim")
    g2 = %Gap{gap("repo://xaas@work-surface", "same claim") | priority: 9}
    g3 = gap("repo://xaas@work-surface", "same claim") |> Gap.admit([])

    w1 = Work.from_gap(g1, construct())
    w2 = Work.from_gap(g2, construct())
    w3 = Work.from_gap(g3, construct())

    assert w1.id == w2.id
    assert w1.id == w3.id
    assert String.starts_with?(w1.id, "work-")
    assert String.length(w1.id) == 16 + String.length("work-")
  end

  test "different claims on the same subject mint different work ids" do
    # Mutant killed: stable_id hashing a constant or dropping the claim
    # term — distinct work orders would collide on one id and demand
    # storage keyed by work id would dedup two different orders.
    w1 = Work.from_gap(gap("repo://xaas@work-surface", "claim A"), construct())
    w2 = Work.from_gap(gap("repo://xaas@work-surface", "claim B"), construct())

    assert w1.id != w2.id
  end

  test "explicit id option overrides the stable derivation" do
    # Mutant killed: the id option being ignored (Keyword.get default
    # regression) — callers needing a caller-controlled id (e.g. exact-SHA
    # work orders) would silently get a digest instead.
    w = Work.from_gap(gap("repo://xaas@work-surface", "claim"), construct(), id: "work-custom-1")

    assert w.id == "work-custom-1"
  end

  test "construct is stored unadulterated and callable against the work" do
    # Mutant killed: from_gap wrapping/altering the construct fn arity or
    # currying it differently — the pipeline's promote/4 court relies on
    # the construct being exactly the 1-arity fn the caller provided.
    g = gap("repo://xaas@work-surface", "callable construct")
    w = Work.from_gap(g, fn work -> {:ran, work} end)

    assert {:ran, ^w} = w.construct.(w)
  end
end
