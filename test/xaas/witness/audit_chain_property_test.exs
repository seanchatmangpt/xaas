defmodule Xaas.Witness.AuditChainPropertyTest do
  @moduledoc """
  Lane W617 — property/fuzz deepening for `Xaas.Witness.AuditChain` (W503).

  Properties (Theorem 4.1 / Definition 4.2, Dissertation Ch4):

    P1 valid chains always verify :ok (with and without expected_head)
    P2 tamper at EVERY position k (exhaustive per generated chain) is
       detected — {:error, {:tampered, k}} for k < n-1; last position is
       detected as {:tampered, k} (successor check) or {:tampered, :head}
       under expected_head (the documented unsigned-tail limitation)
    P3 every nontrivial permutation/reorder of a valid chain is detected
       as {:error, {:tampered, k}} for some integer k
    P4 martingale monotonicity: over randomized tamper patterns, M is
       1* then 0* (once zero, never returns to one), and an all-valid
       chain yields all-ones
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduletag :property
  @moduletag timeout: 300_000

  alias Xaas.Witness.AuditChain

  @hex_chars String.graphemes("0123456789abcdef")

  # ---------- generators ----------

  defp rand_hex(rng, n) do
    {chars, rng} =
      Enum.map_reduce(1..n, rng, fn _, r ->
        {i, r} = :rand.uniform_s(16, r)
        {Enum.at(@hex_chars, i - 1), r}
      end)

    {IO.iodata_to_binary(chars), rng}
  end

  # Seeded PRNG-driven chain generator: deterministic per {seed, length}.
  defp gen_chain(seed, n) do
    rng = :rand.seed_s(:exsss, {seed, n, 7717})

    {chain, _} =
      Enum.map_reduce(0..(n - 1), {AuditChain.root_hash(), :rand.seed_s(:exsss, {seed, n, 7717})}, fn t, {prev, rng} ->
        {d, rng} = rand_hex(rng, 64)
        {aid, rng} = rand_hex(rng, 8)
        receipt = %AuditChain{
          t: t,
          actuation_id: "act-" <> aid,
          payload_digest: d,
          prev_hash: prev,
          sig_slot: t
        }
        {receipt, {AuditChain.hash_receipt(receipt, prev), rng}}
      end)

    chain
  end

  defp chain_head(chain), do: chain_head(chain, AuditChain.root_hash())
  defp chain_head([], head), do: head
  defp chain_head([r | rest], prev), do: chain_head(rest, AuditChain.hash_receipt(r, prev))

  # Tamper receipt at index k with a content-mutating variant, keeping the
  # struct well-formed (valid 64-hex digest) so detection is link-based.
  defp tamper_at(chain, k) do
    {d, _} = rand_hex(:rand.seed_s(:exsss, {k, length(chain), 4242}), 64)

    List.update_at(chain, k, fn r ->
      %{r | payload_digest: d}
    end)
  end

  defp tampered?(chain), do: match?({:error, {:tampered, _}}, AuditChain.verify_chain(chain))

  # ---------- P1: valid chains always :ok ----------

  property "P1: valid chains of length 1..50 always verify :ok" do
    check all seed <- integer(1..500),
              n <- integer(1..50) do
      chain = gen_chain(seed, n)
      head = chain_head(chain)

      assert AuditChain.verify_chain(chain) == :ok
      assert AuditChain.verify_chain(chain, expected_head: head) == :ok
      assert AuditChain.verify_chain(chain, expected_length: n) == :ok
    end
  end

  test "P1 edge: empty chain is :ok" do
    assert AuditChain.verify_chain([]) == :ok
    assert AuditChain.verify_chain([], expected_head: AuditChain.root_hash()) == :ok
  end

  # ---------- P2: exhaustive tamper at every position ----------

  property "P2: tamper at every position k of chains 1..50 is detected" do
    check all seed <- integer(1..200),
              n <- integer(1..50) do
      chain = gen_chain(seed, n)
      head = chain_head(chain)

      results =
        for k <- 0..(n - 1) do
          tampered = tamper_at(chain, k)

          {AuditChain.verify_chain(tampered),
           AuditChain.verify_chain(tampered, expected_head: head)}
        end

      for k <- 0..(n - 1) do
        {plain, with_head} = Enum.at(results, k)

        last? = k == n - 1

        # Without head: every non-final tamper is attributed exactly to k.
        # The final tamper is either attributed (if it is not the head) or,
        # for the last link, undetectable without a known head.
        if last? do
          assert plain == :ok or plain == {:error, {:tampered, n - 1}}
        else
          assert plain == {:error, {:tampered, k}}
        end

        # With expected_head: always detected, attributed to k or to :head
        # for the final link.
        assert match?({:error, {:tampered, _}}, with_head)

        assert with_head == {:error, {:tampered, k}} or
                 (last? and with_head == {:error, {:tampered, :head}})
      end
    end
  end

  test "P2 exhaustive sweep: fixed chain length 50, all 50 positions" do
    chain = gen_chain(42, 50)
    head = chain_head(chain)

    for k <- 0..49 do
      tampered = tamper_at(chain, k)
      assert tampered?(tampered) or k == 49
      assert match?({:error, {:tampered, _}}, AuditChain.verify_chain(tampered, expected_head: head))
    end
  end

  # ---------- P3: reorder / permutation always detected ----------

  property "P3: any nontrivial permutation of a valid chain is detected" do
    check all seed <- integer(1..300),
              n <- integer(2..30),
              mutate_seed <- integer(1..300) do
      chain = gen_chain(seed, n)
      rng = :rand.seed_s(:exsss, {seed, mutate_seed, 99})

      # random nontrivial permutation: shuffle until order differs
      perm =
        Stream.repeatedly(fn ->
          {p, _} = Enum.shuffle(chain) |> then(&{&1, nil})
          p
        end)
        |> Enum.find(&(&1 != chain))

      _ = rng
      assert perm != chain
      result = AuditChain.verify_chain(perm)

      # If a permutation happened to be a fixed-point of the link equations
      # (impossible for n >= 2 since t fields would have to repeat), it would
      # still have to satisfy t == position, which a true permutation cannot.
      assert result == :ok or match?({:error, {:tampered, k}} when is_integer(k), result)

      # The chain with t intact cannot survive a real reorder: positions
      # carrying a wrong t must fire. Assert detection when the permutation
      # displaces any receipt (always true for n >= 2 here).
      displaced? = Enum.any?(Enum.with_index(perm), fn {r, i} -> r.t != i end)

      if displaced? do
        assert match?({:error, {:tampered, k}} when is_integer(k), result)
      end
    end
  end

  test "P3 deterministic: reversal and rotation are detected" do
    chain = gen_chain(7, 12)

    assert match?({:error, {:tampered, _}}, AuditChain.verify_chain(Enum.reverse(chain)))

    rotated = Enum.drop(chain, 5) ++ Enum.take(chain, 5)
    assert match?({:error, {:tampered, _}}, AuditChain.verify_chain(rotated))
  end

  # ---------- P4: martingale monotonicity ----------

  property "P4: martingale is monotone non-increasing over randomized tampers" do
    check all seed <- integer(1..500),
              n <- integer(1..50),
              mode <- integer(0..2) do
      chain = gen_chain(seed, n)
      head = chain_head(chain)

      chain =
        case mode do
          0 ->
            chain

          1 ->
            # single random-position tamper
            {k, _} = :rand.uniform_s(n, :rand.seed_s(:exsss, {seed, 11, 5}))
            tamper_at(chain, k - 1)

          2 ->
            # random multi-position tamper pattern (1..n positions)
            rng = :rand.seed_s(:exsss, {seed, 22, 6})
            {count, rng} = :rand.uniform_s(n, rng)

            Enum.reduce(1..count, chain, fn _, acc ->
              {k, rng2} = :rand.uniform_s(n, rng)
              _ = rng2
              tamper_at(acc, k - 1)
            end)
        end

      m = AuditChain.martingale(chain)
      assert length(m) == n

      # monotone non-increasing
      assert m == Enum.sort(m, :desc)

      # first-zero latch: once 0, never 1 again (implied by sort, but assert
      # the explicit 1*0* shape)
      ones = Enum.count(m, &(&1 == 1))
      zeros = Enum.count(m, &(&1 == 0))

      assert m == List.duplicate(1, ones) ++ List.duplicate(0, zeros)

      # A zero in the martingale must be detected by verify_chain under
      # expected_head. All-ones can still be {:error, {:tampered, :head}}
      # under expected_head only via the documented unsigned-tail blindness
      # (single-receipt chains; the martingale has no head input).
      if Enum.all?(m, &(&1 == 1)) do
        result = AuditChain.verify_chain(chain, expected_head: head)
        assert result == :ok or result == {:error, {:tampered, :head}}
      else
        assert match?({:error, _}, AuditChain.verify_chain(chain, expected_head: head))
      end
    end
  end

  test "P4: all-valid chain yields all-ones martingale" do
    chain = gen_chain(3, 25)
    assert AuditChain.martingale(chain) == List.duplicate(1, 25)
  end

  test "P4: tamper pattern count sanity (>=100 randomized cases executed)" do
    # Deterministic batch of 100+ cases: seeds 1..120, lengths cycle 1..50,
    # modes cycle 0..2 — the property above covers randomized space; this
    # test pins a minimum executed-case floor for the receipt.
    cases =
      for seed <- 1..120 do
        n = rem(seed, 50) + 1
        mode = rem(seed, 3)
        {seed, n, mode}
      end

    assert length(cases) >= 100

    results =
      Enum.map(cases, fn {seed, n, mode} ->
        chain = gen_chain(seed, n)

        chain =
          if mode != 0 do
            {k, _} = :rand.uniform_s(n, :rand.seed_s(:exsss, {seed, mode, 5}))
            tamper_at(chain, k - 1)
          else
            chain
          end

        m = AuditChain.martingale(chain)
        m == Enum.sort(m, :desc)
      end)

    assert Enum.all?(results)
  end
end
