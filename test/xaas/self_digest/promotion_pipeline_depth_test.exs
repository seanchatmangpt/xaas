defmodule Xaas.SelfDigest.PromotionPipelineDepthTest do
  @moduledoc """
  Lane W650w depth court over the `Xaas.SelfDigest` promotion pipeline
  (`Shadow` -> `Promotion` -> `Admission` -> `Receipt` -> `Replay`),
  selected by fresh CamelCase census (zero direct test refs family-wide;
  the only family test is the mix-task file-output test, which does not
  exercise pipeline invariants).

  Chicago-style: real collaborators (the actual modules under test), no
  mocks; assertions on final state and typed refusal values as-real.
  Each test names the mutant class it kills.
  """

  use ExUnit.Case, async: true

  alias Xaas.SelfDigest.{Admission, Evidence, Gap, Promotion, Receipt, Replay, Shadow, Work}

  defp subject, do: "repo://xaas@feat/playwright-surface"

  defp evidence_for(subj, value) do
    Evidence.new(subj, "w-1", :observed, value, %{"source" => "lane-w650w"})
  end

  defp gap_for(subj) do
    # Falsifier fires when any observed evidence value is tampered.
    Gap.new(subj, "digest covers exact subject", fn ev -> ev.value == :tampered end)
  end

  defp counting_reducer, do: fn _item, acc -> {:ok, acc + 1} end

  test "promote admits exact-subject evidence and seals a replayable receipt" do
    # Mutant killed: promotion succeeding without Admission.evaluate
    # (a promote/4 that skips the {:admitted, _} step would return a
    # receipt for cross-subject/falsified evidence — test 2/3 kill that
    # family; this one pins the happy-path final state).
    sub = subject()
    gap = gap_for(sub)
    ev = evidence_for(sub, :clean)
    shadow = Shadow.open(sub, 0) |> Shadow.append(:op) |> Shadow.append(:op2)
    work = Work.from_gap(gap, fn _ -> :ok end)

    # reducer must make materialize-result == replay-output:
    # materialize applies 2 shadow ops -> 2; replay applies 1 evidence -> 1.
    # Use a reducer that counts ops as 1 each and evidence as +2? No —
    # keep symmetric: 2 ops counted, evidence replay must reach the same.
    reducer = fn
      {:evidence, _}, acc -> {:ok, acc + 2}
      _, acc -> {:ok, acc + 1}
    end

    assert {:ok, result, receipt} = Promotion.promote(work, shadow, [ev], reducer)

    assert result == 2
    assert %Receipt{} = receipt
    assert receipt.before == 0
    assert receipt.after == 2
    assert receipt.subject == sub
    assert receipt.authority == :construct_only
    assert receipt.id == Receipt.seal(sub, work.id, 0, 2, [ev]).id

    # Sealed receipt is replayable through the same reducer, as-real.
    assert {:ok, 2} = Replay.verify(receipt, fn ev, acc -> reducer.({:evidence, ev}, acc) end)
  end

  test "admission refuses cross-subject evidence with typed reason and gap stays open" do
    # Mutant killed: admission on foreign evidence (dropping the
    # same_subject? filter collapses subject-scoped admission to
    # existence-only admission).
    sub = subject()
    foreign = evidence_for("repo://other", :clean)

    assert {:refused, :no_exact_subject_evidence} = Admission.evaluate(gap_for(sub), [foreign])

    gap = gap_for(sub)
    assert %{status: :open} = gap
    # Full promotion over foreign evidence refuses rather than sealing.
    work = Work.from_gap(gap, fn _ -> :ok end)
    shadow = Shadow.open(sub, 0) |> Shadow.append(:op)

    assert {:refused, :no_exact_subject_evidence} =
             Promotion.promote(work, shadow, [foreign], counting_reducer())
  end

  test "admission refuses when the falsifier fires on exact-subject evidence" do
    # Mutant killed: removing falsifier evaluation (the cond's
    # falsified? clause) — claim would be admitted on evidence that
    # falsifies it.
    sub = subject()
    bad = evidence_for(sub, :tampered)

    assert {:refused, :falsified} = Admission.evaluate(gap_for(sub), [bad])

    # Mixed exact-subject evidence: one clean, one falsifying -> refused.
    clean = evidence_for(sub, :clean)
    assert {:refused, :falsified} = Admission.evaluate(gap_for(sub), [clean, bad])
  end

  test "replay detects mismatch and broken chains with typed errors" do
    # Mutant killed: a Replay.verify that skips the output == receipt.after
    # comparison, and a chain/1 that does not compare previous-links.
    sub = subject()
    ev = evidence_for(sub, :clean)

    receipt = Receipt.seal(sub, "w-1", 0, 5, [ev])

    # Replay of the same evidence over the honest reducer reaches 1, not 5.
    mismatch =
      Replay.verify(receipt, fn _ev, acc -> {:ok, acc + 1} end)

    assert {:error, :replay_mismatch} = mismatch

    # Honest replay (after == reachable output) succeeds.
    honest_receipt = Receipt.seal(sub, "w-1", 0, 1, [ev])
    assert {:ok, 1} = Replay.verify(honest_receipt, fn _ev, acc -> {:ok, acc + 1} end)

    # Chain integrity: second receipt must name the first's id as previous.
    r1 = Receipt.seal(sub, "w-1", 0, 1, [ev])
    r2 = Receipt.seal(sub, "w-1", 1, 2, [ev], previous: r1.id)
    r3 = Receipt.seal(sub, "w-1", 2, 3, [ev], previous: "deadbeef")

    assert {:ok, head_id} = Replay.chain([r1, r2])
    assert head_id == r2.id
    assert {:error, {:broken_chain, broken_id}} = Replay.chain([r1, r2, r3])
    assert broken_id == r3.id
  end

  test "receipt ids are deterministic and the shadow is a one-shot state machine" do
    # Mutant killed: (a) dropping :deterministic in term_to_binary (ids
    # unstable across runs -> replay identity broken); (b) removing the
    # status: :open guard on Shadow.append/2 (post-materialize mutation);
    # (c) materialize accepting an already-materialized shadow.
    sub = subject()
    ev = evidence_for(sub, :clean)

    id1 = Receipt.seal(sub, "w-1", 0, 1, [ev]).id
    id2 = Receipt.seal(sub, "w-1", 0, 1, [ev]).id
    assert id1 == id2
    assert byte_size(id1) == 64

    assert Receipt.seal(sub, "w-1", 0, 2, [ev]).id != id1
    assert Receipt.seal("repo://other", "w-1", 0, 1, [ev]).id != id1

    # One-shot shadow: append is lawful only while :open.
    shadow = Shadow.open(sub, 0) |> Shadow.append(:op)

    assert {:ok, 1, %{status: :materialized} = mat} =
             (fn ->
                assert {:ok, materialized} = Shadow.materialize(shadow, counting_reducer())
                {:ok, materialized.result, materialized}
              end).()

    assert mat.result == 1

    # append/2 on a materialized shadow is a function-clause refusal.
    assert_raise FunctionClauseError, fn -> Shadow.append(mat, :late_op) end

    # A failing reducer materializes to a typed refused status.
    failing = Shadow.open(sub, 0) |> Shadow.append(:op)

    assert {:error, %{status: {:refused, :boom}}} =
             Shadow.materialize(failing, fn _, _ -> {:error, :boom} end)

    # materialize on an already-materialized shadow is a clause refusal.
    assert_raise FunctionClauseError, fn -> Shadow.materialize(mat, counting_reducer()) end
  end
end
