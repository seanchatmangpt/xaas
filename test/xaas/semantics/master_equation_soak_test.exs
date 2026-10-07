defmodule Xaas.Semantics.MasterEquationSoakTest do
  @moduledoc """
  W628 — Master Equation determinism SOAK (dissertation Theorem: invariance
  under repetition, beyond W541's x3 court).

  Soak parameters: 100 iterations x 3 candidate classes (lawful /
  Art.5-violating / margin-violating), seeded random interleaving. Per class:

    * every run's result is byte-identical (`==`) to that class's first-run
      baseline — full `{:ok, _} | {:refused, _}` term equality (determinism);
    * every refusal names its exact gate, and the gate atom is one of the
      three lawful gates;
    * every DO receipt's signature slot verifies against its own
      (subject, head_hash) pair, and the per-run chain verifies `:ok`;
    * the full 300-run sequence accumulates every DO payload into ONE
      soak-level AuditChain (the ledger martingale): `verify_chain` over
      the accumulated chain with `expected_length` + `expected_head` is
      `:ok` at the end.

  Composition is REUSED from W541's court module — no pipeline duplication:
  `Xaas.Semantics.MasterEquationTest.f_actuate/2`. This file adds only the
  soak harness and the soak-level ledger. No lib edits (lane contract).
  """

  use ExUnit.Case, async: false

  alias Xaas.Witness.AuditChain

  @iterations 100
  @total_runs @iterations * 3
  @classes [:lawful, :art5_violating, :margin_violating]
  @seed 62_828

  # ---------------------------------------------------------------------------
  # Candidates (same class shapes as the W541 court)
  # ---------------------------------------------------------------------------

  defp candidate_for(:lawful) do
    %{
      id: "w628-soak-lawful",
      purpose: :summarize_public_reports,
      techniques: [:retrieval_augmented_generation],
      data_domains: [:public_documents],
      provenance: :consented,
      setting: :enterprise_internal,
      latency_goal: :batch,
      inferences: [],
      match_token_type: :boolean,
      context_joins: []
    }
  end

  defp candidate_for(:art5_violating) do
    %{candidate_for(:lawful) | id: "w628-soak-art5", techniques: [:subliminal, :manipulate_behavior]}
  end

  defp candidate_for(:margin_violating) do
    %{candidate_for(:lawful) | id: "w628-soak-margin"}
  end

  defp robustness_for(:lawful), do: %{epsilon: 0.01, l_e: 1.0}

  # epsilon = 100 blows the CBF margin at gate (b), as in W541.
  defp robustness_for(:margin_violating), do: %{epsilon: 100.0, l_e: 1.0}
  defp robustness_for(_class), do: %{epsilon: 0.01, l_e: 1.0}

  # ---------------------------------------------------------------------------
  # Seeded random interleaving
  # ---------------------------------------------------------------------------

  # Deterministic class sequence: :rand.bytes_s over an exported seed state,
  # so the 300-run interleaving is fully reproducible from @seed.
  defp class_sequence(seed) do
    # exsss caps the seed-integer list length; derive exactly three 32-bit
    # seed ints deterministically from the integer seed via SHA-256.
    <<a::32, b::32, _rest::binary>> = :crypto.hash(:sha256, :erlang.integer_to_binary(seed))
    rng = :rand.seed_s(:exsss, [a, b])

    {classes, _rng} =
      @classes
      |> List.duplicate(@iterations)
      |> List.flatten()
      |> shuffle_seeded(rng)

    classes
  end

  # Fisher-Yates: draw from the remaining list, thread the rng through.
  defp shuffle_seeded(list, rng) do
    do_shuffle(Enum.reverse(list), [], rng)
  end

  defp do_shuffle([], acc, rng), do: {acc, rng}

  defp do_shuffle(remaining, acc, rng) do
    {j, rng} = :rand.uniform_s(length(remaining), rng)
    {item, rest} = List.pop_at(remaining, j - 1)
    do_shuffle(rest, [item | acc], rng)
  end

  # ---------------------------------------------------------------------------
  # Soak harness
  # ---------------------------------------------------------------------------

  @doc """
  One seeded-random interleaved soak pass. Returns:

      %{
        results: [outcome]           # 300 outcomes in interleaved order
        classes: [atom]              # the seeded class sequence
        soak_chain: [AuditChain.t]   # soak-level ledger (one receipt per DO)
        soak_head: binary            # final chain head
      }
  """
  def run_soak(seed \\ @seed) do
    engine = Xaas.Semantics.MasterEquationTest
    classes = class_sequence(seed)

    {results, {soak_chain, soak_head}} =
      Enum.map_reduce(classes, {[], AuditChain.root_hash()}, fn class, {chain, _head} ->
        candidate = candidate_for(class)
        robustness = robustness_for(class)
        outcome = engine.f_actuate(candidate, robustness)

        # Ledger martingale: every DO payload is bound into the soak-level
        # chain; refusals bind nothing (no actuation, no receipt).
        chain =
          case outcome do
            {:ok, %{receipt: receipt}} ->
              digest =
                Base.encode16(:crypto.hash(:sha256, :erlang.term_to_binary(receipt)), case: :lower)

              {:ok, chain, head} =
                AuditChain.append(chain, %{
                  actuation_id: receipt.subject,
                  payload_digest: digest,
                  sig_slot: %{
                    algorithm: "HMAC-SHA256(w541-disclosed-standin-for-ML-DSA-65)",
                    payload_sha256_hex: digest
                  },
                  sig: fn r -> r.payload_digest == digest end
                })

              {chain, head}

            {:refused, _} ->
              {chain, nil}
          end

        {outcome, chain}
      end)

    # The chain tuple's second element is only meaningful on DO runs; recover
    # the true final head by re-walking with append on a sentinel is wasteful
    # — instead track it explicitly below.
    soak_head = soak_head_of(soak_chain)

    %{results: results, classes: classes, soak_chain: soak_chain, soak_head: soak_head}
  end

  # Recompute the final head exactly as AuditChain does: hash_receipt over
  # the last receipt with its stored prev_hash. AuditChain.hash_receipt/2 is
  # private, but the head is SHA256(JCS(R_t) <> H_{t-1}); rather than
  # reimplement, use the head returned by the last append. Do that via a
  # single re-append of the last receipt's attrs on a truncated chain.
  defp soak_head_of([]), do: AuditChain.root_hash()

  defp soak_head_of(chain) do
    last = List.last(chain)
    prefix = Enum.drop(chain, -1)

    {:ok, _chain, head} =
      AuditChain.append(prefix, %{
        actuation_id: last.actuation_id,
        payload_digest: last.payload_digest,
        sig_slot: last.sig_slot,
        sig: last.sig
      })

    head
  end

  # ---------------------------------------------------------------------------
  # Courts
  # ---------------------------------------------------------------------------

  describe "soak — invariance under repetition (100x3)" do
    test "every run is byte-identical per class; refusals name their gate; every DO receipt verifies" do
      soak = run_soak()
      assert length(soak.results) == @total_runs
      assert length(soak.classes) == @total_runs

      # Every class appears (the seeded interleaving is not degenerate).
      for class <- @classes do
        assert Enum.count(soak.classes, &(&1 == class)) == @iterations
      end

      # Determinism: first run per class is the baseline; every subsequent
      # run of the same class must be byte-identical (full term ==).
      assert_soak_determinism(soak.classes, soak.results)

      # Gate naming + DO receipt verification per class.
      Enum.zip(soak.classes, soak.results)
      |> Enum.each(fn {class, outcome} ->
        case outcome do
          {:ok, %{decision: :DO, receipt: receipt, chain: chain, head: head}} ->
            assert class == :lawful
            assert receipt.admitted? == true and receipt.refusal == nil
            assert [%{name: :article5_admission, verdict: :pass}, %{name: :robust_margin, verdict: :pass}] = receipt.checks

            # Signature slot verifies over the exact (subject, head) pair.
            assert Xaas.Semantics.MasterEquationTest.verify_record(
                     %{subject: receipt.subject, head_hash: receipt.head_hash},
                     %{signature_hex: receipt.signature_hex, key_ref: "w541-court-key"}
                   )

            # The per-run ledger link verifies end to end.
            assert :ok = AuditChain.verify_chain(chain, expected_head: head)

          {:refused, refusal} ->
            assert class in [:art5_violating, :margin_violating]
            assert refusal.gate in [:article5_admission, :robust_margin, :audit_ledger]
            assert refusal.gate != :audit_ledger

            # The refusal names its EXACT gate: Art.5 class refuses at gate (a),
            # margin class passes gate (a) and refuses at gate (b).
            case class do
              :art5_violating ->
                assert refusal.gate == :article5_admission
                assert refusal.refusal == :REFUSED_EUAIA_MANIPULATIVE
                assert [%{name: :article5_admission, verdict: :fail}] = refusal.checks

              :margin_violating ->
                assert refusal.gate == :robust_margin
                assert refusal.refusal == :REFUSED_ROBUST_MARGIN

                assert [%{name: :article5_admission, verdict: :pass},
                        %{name: :robust_margin, verdict: :fail, refusal: :REFUSED_ROBUST_MARGIN}] =
                         refusal.checks
            end

            # Signed refusal: slot present and verifies over the refusal body.
            assert refusal.signature_slot.algorithm =~ "standin-for-ML-DSA-65"

            assert Xaas.Semantics.MasterEquationTest.verify_record(
                     %{gate: refusal.gate, refusal: refusal.refusal, describe: refusal.describe},
                     refusal.signature_slot
                   )
        end
      end)
    end

    test "ledger martingale: the full 300-run sequence's soak chain verifies :ok at the end" do
      soak = run_soak()

      do_count = Enum.count(soak.results, &match?({:ok, _}, &1))
      refute_count = Enum.count(soak.results, &match?({:refused, _}, &1))
      assert do_count == @iterations
      assert refute_count == @iterations * 2
      assert length(soak.soak_chain) == do_count

      assert :ok =
               AuditChain.verify_chain(soak.soak_chain,
                 expected_length: do_count,
                 expected_head: soak.soak_head
               )
    end

    test "determinism holds across independent soak passes with the same seed" do
      soak_a = run_soak(@seed)
      soak_b = run_soak(@seed)

      assert soak_a.results == soak_b.results
      assert soak_a.soak_chain == soak_b.soak_chain
      assert soak_a.soak_head == soak_b.soak_head
    end

    test "a different seed yields a different interleaving but identical per-class outcomes" do
      soak_a = run_soak(@seed)
      soak_b = run_soak(@seed + 1)

      # Interleaving differs...
      assert soak_a.classes != soak_b.classes

      # ...but per-class outcomes are identical to the same baselines.
      for class <- @classes do
        a = outcome_for_class(soak_a, class)
        b = outcome_for_class(soak_b, class)
        assert a == b, "class #{inspect(class)} outcome differs across seeds"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Determinism assertion over interleaved sequences (top-level, not closure)
  # ---------------------------------------------------------------------------

  defp assert_soak_determinism(classes, results) do
    baselines = assert_soak_walk(classes, results, %{})
    # All three classes must have been seen (each has @iterations runs).
    assert map_size(baselines) == 3
  end

  defp assert_soak_walk([], [], baselines), do: baselines

  defp assert_soak_walk([class | ct], [outcome | rt], baselines) do
    case Map.fetch(baselines, class) do
      :error ->
        assert_soak_walk(ct, rt, Map.put(baselines, class, outcome))

      {:ok, baseline} ->
        assert outcome == baseline, "non-determinism in class #{inspect(class)}"
        assert_soak_walk(ct, rt, baselines)
    end
  end

  defp outcome_for_class(soak, class) do
    Enum.zip(soak.classes, soak.results)
    |> Enum.find(fn {c, _} -> c == class end)
    |> elem(1)
  end
end
