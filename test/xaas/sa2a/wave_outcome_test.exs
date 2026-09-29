defmodule Xaas.Sa2a.WaveOutcomeTest do
  use ExUnit.Case, async: true

  alias Xaas.Sa2a.WaveOutcome

  test "unknown receipt vocabulary is typed and recoverable instead of atomized" do
    assert WaveOutcome.parse("never_seen_before") == :unknown_outcome
    assert WaveOutcome.consequence("never_seen_before") == :unknown_outcome
    assert WaveOutcome.recovery("never_seen_before") == :reconcile_before_replan
    assert WaveOutcome.settlement("never_seen_before") == :requeue
  end

  test "worker success is terminal for the attempt and chainable only without overload" do
    assert WaveOutcome.consequence(:worker_completed) == :executed
    assert WaveOutcome.settlement(:worker_completed) == :complete
    assert WaveOutcome.chainable?(:worker_completed, false)
    refute WaveOutcome.chainable?(:worker_completed, true)
  end

  test "refusal never becomes successful settlement" do
    assert WaveOutcome.consequence(:refused) == :refused
    assert WaveOutcome.settlement(:refused) == :block
    refute WaveOutcome.chainable?(:refused, false)
  end
end
