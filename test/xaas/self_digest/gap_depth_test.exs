defmodule Xaas.SelfDigest.GapDepthTest do
  @moduledoc """
  Lane W650h20 depth court over `Xaas.SelfDigest.Gap`.

  W650w's promotion-pipeline court exercises Gap only transitively (a gap is
  constructed and admitted inside promote/4); the module's own state-bearing
  surface — `rank/1` scoring and the `admit/refuse` status transitions — has
  zero direct coverage. This court pins those invariants as-real.

  Chicago-style: real module under test, no mocks, assertions on final
  struct state and typed refusal values as-real. Each test names the
  mutant class it kills.
  """

  use ExUnit.Case, async: true

  alias Xaas.SelfDigest.{Evidence, Gap}

  defp gap(opts \\ []) do
    Gap.new(
      "repo://xaas@gap-surface",
      "claim under court",
      fn ev -> ev.value == :falsified end,
      opts
    )
  end

  defp evidence(value) do
    Evidence.new("repo://xaas@gap-surface", "w-gap-1", :observed, value)
  end

  test "admit binds exact evidence and transitions status :open -> :admitted" do
    # Mutant killed: admit/2 writing evidence but leaving status :open
    # (or vice versa) — promotion would seal receipts over permanently-open
    # gaps and downstream rank/1 would double-count admitted evidence.
    g = gap()

    assert %{status: :open, evidence: []} = g

    admitted = Gap.admit(g, [evidence(:clean)])

    assert admitted.status == :admitted
    assert [%Evidence{value: :clean}] = admitted.evidence
  end

  test "refuse marks a typed status without consuming the gap's evidence slot" do
    # Mutant killed: refuse/2 leaving status :open or {refused, reason} with
    # the reason atom shape changed — Admission refuses only propagate
    # {:refused, reason} tuples; a status-shape drift would break that
    # contract silently at promote time.
    g = Gap.refuse(gap(), :no_exact_subject_evidence)

    assert g.status == {:refused, :no_exact_subject_evidence}
    assert g.evidence == []
  end

  test "rank is priority*100 + 5*evidence - 10*dependencies, nils coerced to zero" do
    # Mutant killed: rank/1 crashing or misweighting on nil evidence/
    # dependencies (fresh Gap.new defaults) — ordering of the work graph
    # would silently invert for never-admitted gaps.
    fresh = gap(priority: 3, dependencies: [:dep1])
    assert Gap.rank(fresh) == 3 * 100 + 0 * 5 - 1 * 10

    loaded = gap(priority: 1, dependencies: [:d1, :d2]) |> Gap.admit([evidence(:a), evidence(:b)])
    assert Gap.rank(loaded) == 1 * 100 + 2 * 5 - 2 * 10

    # nil priority (struct default when built directly) does not crash.
    nil_gap = %Gap{gap(priority: nil) | evidence: nil, dependencies: nil}
    assert Gap.rank(nil_gap) == 0
  end

  test "rank ordering prefers high priority and evidence, penalizes dependencies" do
    # Mutant killed: sign flips in any rank/1 term — e.g. rewarding
    # dependencies (+10) would reorder the work graph so blocked gaps
    # outrank their unblockers.
    high_priority = gap(priority: 2, dependencies: [:d1])
    evidence_heavy = gap(priority: 0) |> Gap.admit([evidence(:a), evidence(:b), evidence(:c)])
    dependency_heavy = gap(priority: 1, dependencies: [:d1, :d2, :d3])

    scores = [high_priority, evidence_heavy, dependency_heavy] |> Enum.map(&Gap.rank/1)

    assert scores == [2 * 100 - 1 * 10, 3 * 5, 1 * 100 - 3 * 10]
    assert high_priority |> Gap.rank() > dependency_heavy |> Gap.rank()
    assert dependency_heavy |> Gap.rank() > evidence_heavy |> Gap.rank()
  end

  test "admit replaces (not appends to) the gap's evidence set" do
    # Mutant killed: admit/2 accumulating (evidence ++ old_evidence) —
    # replay of an admitted gap would re-adjudicate stale evidence and
    # rank/1 would inflate per re-admission.
    ev1 = evidence(:first)
    ev2 = evidence(:second)
    once = Gap.admit(gap(), [ev1])
    twice = Gap.admit(once, [ev2])

    assert twice.evidence == [ev2]
    assert length(twice.evidence) == 1
  end
end
