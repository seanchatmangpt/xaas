defmodule Xaas.Witness.AuditChain do
  @moduledoc """
  Dissertation Ch4, Definition 4.2 + Theorem 4.1 — cryptographic audit chain.

  Honest crypto (w405): SHA-256 over JCS-canonical JSON (RFC 8785), reusing
  the `Jcs` dependency already used by
  `Xaas.Deployment.ReleaseSnapshot.portable_digest/1`
  (lib/xaas/deployment/release_snapshot.ex:356). BLAKE3 is NOT present in
  `lib/` and is NOT added — upgrade path only, no NIF.

  Definition 4.2:
    R_t = %{t, actuation_id, payload_digest, prev_hash, sig_slot}
    H_t = SHA256(JCS(R_t) <> H_{t-1}),  H_0 = root (64 hex zeros)

  Each receipt's `prev_hash` stores H_{t-1} (the chain hash, not its own
  content hash). Consequently a CONTENT tamper of receipt k breaks the
  link equation at k+1; exact attribution of the tampered receipt index k
  is achieved by the successor-consistency check:
    receipt k is valid iff (a) r_k.prev_hash == H_{k-1} recomputed over the
    verified prefix, AND (b) either r_{k+1}.prev_hash == H_k recomputed over
    r_k, or k is the last link and an `expected_head` is given and matches
    (a last link without a known head hash is unverifiable by content —
    documented limitation; mitigate with `expected_head`).

  `sig` is an optional (receipt -> boolean) verify callback; `nil` (the
  default) is UNSIGNED MODE, documented as such. ML-DSA wiring is lane
  W510. Pure functions over a list (Chicago: real data, no process).
  """

  @root_hash String.duplicate("0", 64)
  @hash_hex ~r/^[0-9a-f]{64}$/

  defstruct [:t, :actuation_id, :payload_digest, :prev_hash, :sig_slot, :sig]

  @type t :: %__MODULE__{
          t: non_neg_integer(),
          actuation_id: term(),
          payload_digest: String.t(),
          prev_hash: String.t(),
          sig_slot: term(),
          sig: (t() -> boolean()) | nil
        }

  @doc "H_0 - the chain root (64 hex zeros)."
  def root_hash, do: @root_hash

  @doc """
  Append a receipt to the chain. Returns {:ok, chain, head_hash}.
  """
  def append(chain, %{actuation_id: aid, payload_digest: d} = attrs)
      when is_list(chain) and is_binary(d) do
    t = length(chain)
    prev = prev_hash(chain)

    receipt = %__MODULE__{
      t: t,
      actuation_id: aid,
      payload_digest: d,
      prev_hash: prev,
      sig_slot: Map.get(attrs, :sig_slot),
      sig: Map.get(attrs, :sig)
    }

    {:ok, chain ++ [receipt], hash_receipt(receipt, prev)}
  end

  def append(_chain, _attrs), do: {:error, :invalid_receipt_attrs}

  @doc """
  Recompute every link. Returns :ok, or:

    * {:error, {:tampered, k}} - first tampered receipt index, exact
    * {:error, {:truncated, n}} - expected_length: n opt and a shorter chain
    * {:error, :invalid_signature} - a receipt's sig callback rejects it
    * {:error, {:tampered, :head}} - expected_head opt given and the final
      recomputed chain hash does not match it
  """
  def verify_chain(chain, opts \\ []) when is_list(chain) do
    expected_length = Keyword.get(opts, :expected_length)
    expected_head = Keyword.get(opts, :expected_head)

    with :ok <- check_truncation(chain, expected_length),
         :ok <- walk(chain, @root_hash, 0, expected_head) do
      :ok
    end
  end

  defp check_truncation(_chain, nil), do: :ok
  defp check_truncation(chain, n) when length(chain) < n, do: {:error, {:truncated, n}}
  defp check_truncation(_chain, _n), do: :ok

  # One forward pass. For each receipt r at pos k:
  #   (a) r.prev_hash == H_{k-1} recomputed over the verified prefix
  #   (b) successor stored prev_hash == H_k recomputed over r (or head check
  #       at the end via expected_head)
  defp walk([], prev, _pos, expected_head) do
    if expected_head != nil and expected_head != prev do
      {:error, {:tampered, :head}}
    else
      :ok
    end
  end

  defp walk([r | rest], prev, pos, expected_head) do
    h = hash_receipt(r, prev)

    cond do
      r.t != pos ->
        {:error, {:tampered, pos}}

      r.prev_hash != prev ->
        {:error, {:tampered, pos}}

      not valid_payload_digest?(r) ->
        {:error, {:tampered, pos}}

      sig_rejects?(r) ->
        {:error, :invalid_signature}

      rest != [] and hd(rest).prev_hash != h ->
        {:error, {:tampered, pos}}

      true ->
        walk(rest, h, pos + 1, expected_head)
    end
  end

  @doc """
  The martingale observable (Theorem 4.1): M_k = 1 iff receipt k is valid
  under the same (a)+(b) conditions as verify_chain/2, 0 from the first
  tampered receipt onward - monotone non-increasing over stream iteration.
  """
  def martingale(chain) when is_list(chain) do
    {rev, _prev, _latch} =
      chain
      |> Enum.with_index()
      |> Enum.reduce({[], @root_hash, false}, fn {r, pos}, {acc, prev, tampered} ->
        m =
          cond do
            tampered ->
              0

            r.t != pos or r.prev_hash != prev ->
              0

            true ->
              successor_ok? = successor_ok?(chain, pos, r)
              if successor_ok?, do: 1, else: 0
          end

        {[m | acc], hash_receipt(r, prev), tampered or m == 0}
      end)

    Enum.reverse(rev)
  end

  defp successor_ok?(chain, pos, r) do
    case Enum.at(chain, pos + 1) do
      nil -> true
      succ -> succ.prev_hash == hash_receipt(r, r.prev_hash)
    end
  end

  defp valid_payload_digest?(%__MODULE__{payload_digest: d}) do
    is_binary(d) and Regex.match?(@hash_hex, d)
  end

  defp sig_rejects?(%__MODULE__{sig: nil}), do: false
  defp sig_rejects?(%__MODULE__{sig: fun} = r) when is_function(fun, 1), do: fun.(r) != true
  defp sig_rejects?(_), do: false

  defp prev_hash([]), do: @root_hash

  defp prev_hash(chain) do
    last = List.last(chain)
    hash_receipt(last, prev_hash(Enum.drop(chain, -1)))
  end

  @doc """
  H_t = SHA256(JCS(R_t) <> H_{t-1}). Receipt fields are JCS-encoded as a
  map with string keys; the sig callback is excluded (verifier, not
  receipt content).
  """
  def hash_receipt(%__MODULE__{} = r, prev) when is_binary(prev) do
    canonical =
      Jcs.encode(%{
        "actuation_id" => encode_term(r.actuation_id),
        "payload_digest" => r.payload_digest,
        "prev_hash" => r.prev_hash,
        "sig_slot" => encode_term(r.sig_slot),
        "t" => r.t
      })

    :crypto.hash(:sha256, canonical <> prev) |> Base.encode16(case: :lower)
  end

  defp encode_term(bin) when is_binary(bin), do: bin
  defp encode_term(int) when is_integer(int), do: int
  defp encode_term(nil), do: nil
  defp encode_term(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp encode_term(other), do: Base.encode64(:erlang.term_to_binary(other, [:deterministic]))
end
