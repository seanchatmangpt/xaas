defmodule Xaas.Chicago.Bridges.BridgesTest do
  @moduledoc """
  Subject identity and envelope law for the Chicago bridges (RESOLUTIONS R2/R8).
  """

  use ExUnit.Case, async: true

  alias Xaas.Bridges

  test "subject is the exact R2 literal, byte-stable" do
    assert Bridges.subject() == "urn:chicago:agentic-payment:purchase-001"
  end

  test "envelope carries the R8 defaults: UNKNOWN standing, :none ceiling, no evidence" do
    envelope = Bridges.envelope(Bridges.subject(), "some claim", :observed)

    assert envelope.authority_ceiling == :none
    assert envelope.standing == "UNKNOWN"
    assert envelope.evidence_ref == nil
    assert envelope.receipt_ref == nil
    assert envelope.subject == "urn:chicago:agentic-payment:purchase-001"
    assert envelope.claim == "some claim"
    assert envelope.state == :observed
    assert envelope.provenance == %{}
  end

  test "head_sha resolves the canonical checkout HEAD without spawning a process" do
    sha = Bridges.head_sha()

    assert is_binary(sha)
    assert String.match?(sha, ~r/^[0-9a-f]{40}$/)
  end

  test "head_sha returns nil for a nonexistent git dir instead of guessing" do
    assert Bridges.head_sha("/tmp/definitely-not-a-git-dir-l7") == nil
  end
end
