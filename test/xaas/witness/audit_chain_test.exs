defmodule Xaas.Witness.AuditChainTest do
  use ExUnit.Case, async: true

  alias Xaas.Witness.AuditChain

  defp receipt_attrs(i, opts \\ []) do
    %{
      actuation_id: "act-#{i}",
      payload_digest: :crypto.hash(:sha256, "payload-#{i}") |> Base.encode16(case: :lower),
      sig_slot: Keyword.get(opts, :sig_slot, "slot-#{i}"),
      sig: Keyword.get(opts, :sig)
    }
  end

  defp build_chain(n, opts \\ []) do
    Enum.reduce(0..(n - 1), {:ok, [], nil}, fn i, {:ok, chain, _} ->
      AuditChain.append(chain, receipt_attrs(i, opts))
    end)
    |> elem(1)
  end

  describe "append/2" do
    test "appends N receipts with sequential t and correct head hash" do
      {:ok, chain, head} = AuditChain.append([], receipt_attrs(0))
      assert length(chain) == 1
      assert hd(chain).t == 0
      assert hd(chain).prev_hash == AuditChain.root_hash()

      {:ok, chain, head2} = AuditChain.append(chain, receipt_attrs(1))
      assert length(chain) == 2
      assert Enum.map(chain, & &1.t) == [0, 1]
      assert head2 == AuditChain.hash_receipt(Enum.at(chain, 1), head)
    end

    test "rejects non-binary payload_digest" do
      assert {:error, :invalid_receipt_attrs} =
               AuditChain.append([], %{actuation_id: "x", payload_digest: 42})
    end

    test "first receipt links to H_0 root" do
      {:ok, [r], _} = AuditChain.append([], receipt_attrs(0))
      assert r.prev_hash == String.duplicate("0", 64)
    end
  end

  describe "verify_chain/1" do
    test "appended N -> :ok" do
      chain = build_chain(25)
      assert AuditChain.verify_chain(chain) == :ok
    end

    test "empty chain is :ok" do
      assert AuditChain.verify_chain([]) == :ok
    end

    test "tamper payload at k -> {:error, {:tampered, k}} exactly" do
      chain = build_chain(10)

      k = 4
      tampered = List.update_at(chain, k, fn r -> %{r | payload_digest: String.duplicate("f", 64)} end)

      assert AuditChain.verify_chain(tampered) == {:error, {:tampered, k}}
    end

    test "tamper prev_hash at k -> detected at the (k-1,k) link" do
      chain = build_chain(10)
      k = 2

      tampered = List.update_at(chain, k, fn r -> %{r | prev_hash: String.duplicate("a", 64)} end)

      # Hash-chain detection semantics: a junk prev_hash at k breaks the
      # (k-1, k) link from the k-1 side (indistinguishable, without a known
      # head, from content tamper of k-1), so the verifier reports the first
      # broken link k-1. Content (payload) tamper at k IS attributed exactly
      # to k via the successor-consistency check — see the payload test.
      assert AuditChain.verify_chain(tampered) == {:error, {:tampered, k - 1}}
    end

    test "reorder (index mismatch) detected at the moved link" do
      chain = build_chain(6)
      [a, b | rest] = chain
      shuffled = [b, a | rest]

      assert {:error, {:tampered, _}} = AuditChain.verify_chain(shuffled)
    end

    test "truncated chain detected with expected_length" do
      chain = build_chain(8)
      cut = Enum.take(chain, 5)

      assert AuditChain.verify_chain(cut, expected_length: 8) ==
               {:error, {:truncated, 8}}

      # without the hint, a valid prefix verifies
      assert AuditChain.verify_chain(cut) == :ok
    end

    test "last-link payload tamper caught via expected_head" do
      {:ok, chain, head} =
        Enum.reduce(0..5, {:ok, [], nil}, fn i, {:ok, c, _} ->
          AuditChain.append(c, receipt_attrs(i))
        end)

      n = length(chain)
      tampered = List.update_at(chain, n - 1, fn r -> %{r | payload_digest: String.duplicate("d", 64)} end)

      assert AuditChain.verify_chain(tampered, expected_head: head) ==
               {:error, {:tampered, :head}}

      assert AuditChain.verify_chain(tampered) == :ok
    end

    test "rejecting sig callback -> :invalid_signature" do
      chain = build_chain(3, sig: fn _receipt -> false end)
      assert AuditChain.verify_chain(chain) == {:error, :invalid_signature}
    end

    test "accepting sig callback (unsigned mode default) -> :ok" do
      chain = build_chain(3, sig: fn _receipt -> true end)
      assert AuditChain.verify_chain(chain) == :ok
    end
  end

  describe "determinism" do
    test "same receipts -> same hashes" do
      c1 = build_chain(12)
      c2 = build_chain(12)

      hashes1 = Enum.map(c1, &AuditChain.hash_receipt(&1, &1.prev_hash))
      hashes2 = Enum.map(c2, &AuditChain.hash_receipt(&1, &1.prev_hash))

      assert hashes1 == hashes2
      assert AuditChain.verify_chain(c1) == AuditChain.verify_chain(c2)
    end
  end

  describe "martingale/1 (Theorem 4.1 — validity monotone)" do
    test "untampered chain: all ones" do
      chain = build_chain(15)
      assert AuditChain.martingale(chain) == List.duplicate(1, 15)
    end

    test "tamper at k: M_t = 1 for t < k, 0 for t >= k — monotone non-increasing" do
      n = 20
      k = 7

      chain =
        build_chain(n)
        |> List.update_at(k, fn r -> %{r | payload_digest: String.duplicate("e", 64)} end)

      m = AuditChain.martingale(chain)
      assert length(m) == n
      assert Enum.take(m, k) == List.duplicate(1, k)
      assert Enum.drop(m, k) == List.duplicate(0, n - k)
    end

    test "property: over stream iteration M_t is monotone non-increasing" do
      for n <- 1..30, k <- (n > 0 && Enum.to_list(0..(n - 1)) || [0]) do
        chain =
          build_chain(n)
          |> List.update_at(k, fn r -> %{r | prev_hash: String.duplicate("b", 64)} end)

        m = AuditChain.martingale(chain)
        drops = Enum.zip(m, tl(m) ++ [0]) |> Enum.count(fn {a, b} -> b > a end)
        assert drops == 0, "M_t increased at n=#{n}, k=#{k}: #{inspect(m)}"
      end
    end

    test "property: untampered chains always all-ones (non-vacuous base case)" do
      for n <- 1..30 do
        assert AuditChain.martingale(build_chain(n)) == List.duplicate(1, n)
      end
    end
  end
end
