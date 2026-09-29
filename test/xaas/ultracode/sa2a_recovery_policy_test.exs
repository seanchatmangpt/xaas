defmodule Xaas.Ultracode.SA2ARecoveryPolicyTest do
  use ExUnit.Case, async: true

  alias Xaas.Ultracode.RecoveryPolicy

  test "local scheduling policy consumes SA2A consequence classification" do
    assert RecoveryPolicy.decide(:worker_completed, false) == :chain
    assert RecoveryPolicy.decide(:refused, false) == :await_cron
    assert RecoveryPolicy.decide(:never_seen_before, false) == :await_cron
    assert RecoveryPolicy.decide(:worker_completed, true) == :backoff
  end
end
