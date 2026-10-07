defmodule Xaas.Witness.AuditChainInvariantTest do
  @moduledoc """
  Lane W984bn — deepening court over `Xaas.Witness.AuditChain` (Def 4.2 /
  Thm 4.1), complements `audit_chain_test.exs` (W984p's art-26.1 surface).

  Chicago discipline: real chains built via the public append/2 + verify_chain/2
  contract, assertions on returned verdicts — no mocks, no process.

  Mutation rationale per test: each test names the implementation mutation
  (line-level change in lib/xaas/witness/audit_chain.ex) that only this test
  kills.
  """

  use ExUnit.Case, async: true

  alias Xaas.Witness.AuditChain

  defp attrs(i) do
    %{
      actuation_id: "act-#{i}",
      payload_digest: :crypto.hash(:sha256, "payload-#{i}") |> Base.encode16(case: :lower)
    }
  end

  defp build_chain(n) do
    Enum.reduce(0..(n - 1), {:ok, [], nil}, fn i, {:ok, chain, _} ->
      AuditChain.append(chain, attrs(i))
    end)
    |> elem(1)
  end

  defp tamper_payload(chain, k),
    do: List.update_at(chain, k, fn r -> %{r | payload_digest: String.duplicate("f", 64)} end)

  describe "multi-link chains (3+ receipts) localize tamper at each position" do
    # Mutation rationale: kills any mutation of walk/4's successor-consistency
    # clause (`rest != [] and hd(rest).prev_hash != h`) that would under-report
    # payload tampers at interior positions (reporting k-1 or :head instead of k).
    test "interior payload tamper at EVERY position 0..n-2 attributes exactly k" do
      n = 6

      for k <- 0..(n - 2) do
        chain = build_chain(n) |> tamper_payload(k)
        assert AuditChain.verify_chain(chain) == {:error, {:tampered, k}},
               "tamper at #{k} mis-attributed"
      end
    end

    # Mutation rationale: kills removal of the expected_head head-check in
    # walk([], prev, _pos, expected_head) — the only clause attributing a
    # last-link content tamper, which is otherwise invisible (documented
    # limitation).
    test "last-link payload tamper attributes :head (with expected_head), not k-1" do
      chain = build_chain(5)
      {:ok, _, head} = AuditChain.append(Enum.drop(chain, -1), attrs(4))

      tampered = tamper_payload(chain, 4)

      assert AuditChain.verify_chain(tampered, expected_head: head) ==
               {:error, {:tampered, :head}}

      # and the untampered prefix+head still verifies :ok
      assert AuditChain.verify_chain(chain, expected_head: head) == :ok
    end
  end

  describe "chain ordering is load-bearing" do
    # Mutation rationale: kills any mutation making walk/4 order-insensitive
    # (e.g. verifying over Enum.sort(chain) or dropping the r.t != pos check).
    test "two adjacent links swapped fail verification at the moved link" do
      chain = build_chain(5)
      swapped = List.replace_at(chain, 1, Enum.at(chain, 2))
                |> List.replace_at(2, Enum.at(chain, 1))

      assert {:error, {:tampered, _}} = AuditChain.verify_chain(swapped)
      refute AuditChain.verify_chain(swapped) == :ok
    end

    # Mutation rationale: kills a verifier that recomputes t as position
    # instead of comparing stored t — a rotated suffix would then falsely
    # verify as a fresh chain.
    test "rotated chain (suffix moved to front) fails: stored t vs position mismatch" do
      chain = build_chain(6)
      rotated = Enum.drop(chain, 3) ++ Enum.take(chain, 3)

      assert {:error, {:tampered, 0}} = AuditChain.verify_chain(rotated)
    end

    # Mutation rationale: kills dropping the prev_hash != prev link check —
    # after a swap the hashes no longer chain, and only this check catches it
    # when t fields are renumbered by the attacker.
    test "swap + attacker renumbers t: still fails on the broken link hash" do
      chain = build_chain(4)
      [a, b, c, d] = chain

      attacked =
        [%{b | t: 0}, %{a | t: 1}, c, d]
        |> Enum.with_index(fn r, i -> %{r | t: i} end)

      assert {:error, {:tampered, _}} = AuditChain.verify_chain(attacked)
    end
  end

  describe "empty / single-link edge behavior" do
    # Mutation rationale: kills mutation of walk([], prev, _pos, expected_head)
    # accepting an empty chain whose prev != root, or the check_truncation
    # nil clause.
    test "empty chain: :ok; with wrong expected_head: {:tampered, :head}" do
      assert AuditChain.verify_chain([]) == :ok
      assert AuditChain.verify_chain([], expected_head: AuditChain.root_hash()) == :ok
      assert AuditChain.verify_chain([], expected_head: String.duplicate("1", 64)) ==
               {:error, {:tampered, :head}}
    end

    # Mutation rationale: pins the documented unsigned-head limitation — a
    # verifier that quietly adds a default expected_head would break replay of
    # historical chains; one that drops the head check entirely would accept
    # last-link tampers even when a head IS supplied.
    test "single link: content tamper invisible without head, caught with head" do
      {:ok, chain, head} = AuditChain.append([], attrs(0))

      assert AuditChain.verify_chain(chain) == :ok

      tampered = tamper_payload(chain, 0)
      assert AuditChain.verify_chain(tampered) == :ok
      assert AuditChain.verify_chain(tampered, expected_head: head) ==
               {:error, {:tampered, :head}}
    end

    test "single link prev_hash must be the root — non-root prev_hash fails at 0" do
      {:ok, [r], _} = AuditChain.append([], attrs(0))
      bad = [%{r | prev_hash: String.duplicate("9", 64)}]

      assert AuditChain.verify_chain(bad) == {:error, {:tampered, 0}}
    end
  end

  describe "cross-subject isolation" do
    # Mutation rationale: kills any shared/module-level mutable state or
    # global accumulator in verify/walk (leaks between chains would flip
    # chain B's verdict after chain A fails). Chicago: two real independent
    # chains, no isolation trickery.
    test "tampering chain A does not affect chain B's verdict" do
      chain_a = build_chain(5)
      chain_b = build_chain(5)

      assert AuditChain.verify_chain(chain_b) == :ok
      tampered_a = tamper_payload(chain_a, 2)
      assert {:error, {:tampered, 2}} = AuditChain.verify_chain(tampered_a)

      # B re-verifies :ok after A's failure — verdicts are pure per-subject.
      assert AuditChain.verify_chain(chain_b) == :ok

      # and B's identity is unchanged: same head hash recomputation
      {:ok, _, head_b} =
        Enum.reduce(chain_b, {:ok, [], nil}, fn r, {:ok, c, _} ->
          AuditChain.append(c, %{actuation_id: r.actuation_id, payload_digest: r.payload_digest,
                                 sig_slot: r.sig_slot, sig: r.sig})
        end)

      assert AuditChain.verify_chain(chain_b, expected_head: head_b) == :ok
    end
  end

  describe "replay determinism" do
    # Mutation rationale: kills any nondeterminism source (MapSet iteration,
    # Process.get, time/hash randomization) inside hash_receipt/2 or walk/4 —
    # two verifies of the same subject must give byte-identical verdicts.
    test "verify_chain x2 on same subject yields identical verdicts (ok and error paths)" do
      chain = build_chain(8)
      assert AuditChain.verify_chain(chain) == AuditChain.verify_chain(chain)
      assert AuditChain.verify_chain(chain) == :ok

      {:ok, _, head} =
        Enum.reduce(chain, {:ok, [], nil}, fn r, {:ok, c, _} ->
          AuditChain.append(c, %{actuation_id: r.actuation_id, payload_digest: r.payload_digest,
                                 sig_slot: r.sig_slot, sig: r.sig})
        end)

      assert AuditChain.verify_chain(chain, expected_head: head) ==
               AuditChain.verify_chain(chain, expected_head: head)

      tampered = chain |> tamper_payload(3)

      v1 = AuditChain.verify_chain(tampered)
      v2 = AuditChain.verify_chain(tampered)
      assert v1 == v2
      assert v1 == {:error, {:tampered, 3}}
    end

    test "independent rebuilds of the same logical chain are hash-identical (replayable)" do
      c1 = build_chain(7)
      c2 = build_chain(7)

      assert Enum.map(c1, &{&1.t, &1.payload_digest, &1.prev_hash}) ==
             Enum.map(c2, &{&1.t, &1.payload_digest, &1.prev_hash})

      assert AuditChain.verify_chain(c1) == AuditChain.verify_chain(c2)
    end
  end
end
