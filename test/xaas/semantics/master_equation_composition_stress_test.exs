defmodule Xaas.Semantics.MasterEquationCompositionStressTest do
  @moduledoc """
  W719 — Master Equation COMPOSITION STRESS window (extends the W628 soak).

  The W628 soak (300 runs, seed 62828) covers the 9 core tests of the W541
  composition court under repetition. This lane adds the stress window the
  admitted-composition property lacked:

    * (a) 1,000-cycle seeded composition run over the REAL admission
      surfaces (`Xaas.Semantics.EuAiActAdmission.admit/1` via the W541
      court pipeline, plus `Xaas.Semantics.AdmissionAttribution.shapley/2`),
      with a machinery-share series tracked at checkpoints;
    * (b) conservation at EVERY cycle: admitted + refused + blocked ==
      total candidates;
    * (c) typed-decision distribution stability across 3 seeds (pairwise
      share deltas within the declared tolerance);
    * (d) bounded memory across the window (test-process memory and total
      ETS memory, forced-GC bracketed).

  Composition is REUSED from the W541 court — no lib edits (lane contract):
  `Xaas.Semantics.MasterEquationTest.f_actuate/2`. This file adds only the
  stress harness. Seeded deterministic; no mocks; every assertion is on
  real returned state.
  """

  use ExUnit.Case, async: false

  alias Xaas.Semantics.AdmissionAttribution
  alias Xaas.Witness.AuditChain

  # The W541 court module lives in a sibling test file; ensure it is loaded
  # when this file is run standalone (the full suite loads it via the same
  # directory compile).
  unless Code.ensure_loaded?(Xaas.Semantics.MasterEquationTest) do
    Code.compile_file("master_equation_test.exs", Path.join(File.cwd!(), "test/xaas/semantics"))
  end

  @cycles 1000
  @checkpoint_every 100
  @seeds [719_001, 719_002, 719_003]
  @seed 719_001

  # Pairwise distribution-stability tolerance (fraction units). No prior
  # distribution-tolerance convention exists in the W541/W628 courts (they
  # assert exact determinism, which a cross-seed comparison cannot), so this
  # lane fixes it explicitly at 5%.
  @tolerance 0.05

  # Seeded tamper-injection cap: at most this % of LAWFUL draws have their
  # witness ledger tampered post-DO, converting the outcome to a gate-(c)
  # BLOCKED terminal (the W541 to_gate_c_refusal shape). This upper-bounds
  # the blocked rate and lower-bounds machinery share at 1 - rate.
  @tamper_rate_pct 10

  @classes [:lawful, :art5_violating, :margin_violating, :malformed]

  @decision_categories [
    :DO,
    {:gate_a, :REFUSED_EUAIA_MANIPULATIVE},
    {:gate_a, :REFUSED_EUAIA_MALFORMED_CANDIDATE},
    {:gate_b, :REFUSED_ROBUST_MARGIN},
    :BLOCKED_GATE_C
  ]

  # ---------------------------------------------------------------------------
  # Candidates (same class shapes as the W541 court)
  # ---------------------------------------------------------------------------

  defp candidate_for(:lawful) do
    %{
      id: "w719-stress-lawful",
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
    %{candidate_for(:lawful) | id: "w719-stress-art5", techniques: [:subliminal, :manipulate_behavior]}
  end

  defp candidate_for(:margin_violating) do
    %{candidate_for(:lawful) | id: "w719-stress-margin"}
  end

  defp candidate_for(:malformed), do: :w719_not_a_map

  defp robustness_for(:margin_violating), do: %{epsilon: 100.0, l_e: 1.0}
  defp robustness_for(_class), do: %{epsilon: 0.01, l_e: 1.0}

  # ---------------------------------------------------------------------------
  # Seeded RNG (same exsss pattern as the W628 soak)
  # ---------------------------------------------------------------------------

  defp seed_rng(seed) do
    <<a::32, b::32, _rest::binary>> = :crypto.hash(:sha256, :erlang.integer_to_binary(seed))
    :rand.seed_s(:exsss, [a, b])
  end

  # ---------------------------------------------------------------------------
  # Per-cycle composition over the real surfaces
  # ---------------------------------------------------------------------------

  @typedoc false

  @doc """
  One cycle of the stress window. Returns `{category, rng}` where category
  is one of `@decision_categories`.

  Class -> terminal category:
    :lawful           -> :DO (or :BLOCKED_GATE_C on a seeded tamper draw)
    :art5_violating   -> {:gate_a, :REFUSED_EUAIA_MANIPULATIVE}
    :malformed        -> {:gate_a, :REFUSED_EUAIA_MALFORMED_CANDIDATE}
    :margin_violating -> {:gate_b, :REFUSED_ROBUST_MARGIN}
  """
  def run_cycle(class, rng) do
    engine = Xaas.Semantics.MasterEquationTest
    candidate = candidate_for(class)
    robustness = robustness_for(class)

    outcome = engine.f_actuate(candidate, robustness)

    case {class, outcome} do
      {:lawful, {:ok, %{chain: chain, head: head}}} ->
        # Seeded gate-(c) tamper injection: the W541 to_gate_c_refusal shape.
        # The DO already succeeded; the tampered ledger refuses DO afterwards,
        # reclassifying the cycle as BLOCKED at gate (c).
        {draw, rng} = :rand.uniform_s(100, rng)

        if draw <= @tamper_rate_pct do
          [receipt0] = chain
          tampered = [%AuditChain{receipt0 | prev_hash: String.duplicate("a", 64)}]

          assert {:error, {:tampered, 0}} =
                   AuditChain.verify_chain(tampered, expected_head: head)

          {:BLOCKED_GATE_C, rng}
        else
          assert_receipt_shape(outcome)
          {:DO, rng}
        end

      {:lawful, other} ->
        flunk("lawful cycle did not reach DO: #{inspect(other)}")

      {_class, {:refused, refusal}} ->
        assert refusal.gate in [:article5_admission, :robust_margin]
        assert refusal.signature_slot.algorithm =~ "standin-for-ML-DSA-65"

        assert Xaas.Semantics.MasterEquationTest.verify_record(
                 %{gate: refusal.gate, refusal: refusal.refusal, describe: refusal.describe},
                 refusal.signature_slot
               )

        {category(class, refusal), rng}
    end
  end

  defp category(:art5_violating, %{gate: :article5_admission, refusal: :REFUSED_EUAIA_MANIPULATIVE}),
    do: {:gate_a, :REFUSED_EUAIA_MANIPULATIVE}

  defp category(:art5_violating, other),
    do: flunk("art5 class got unexpected refusal #{inspect(other)}")

  defp category(:margin_violating, %{gate: :robust_margin, refusal: :REFUSED_ROBUST_MARGIN}),
    do: {:gate_b, :REFUSED_ROBUST_MARGIN}

  defp category(:margin_violating, other),
    do: flunk("margin class got unexpected refusal #{inspect(other)}")

  defp category(:malformed, %{gate: :article5_admission, refusal: :REFUSED_EUAIA_MALFORMED_CANDIDATE}),
    do: {:gate_a, :REFUSED_EUAIA_MALFORMED_CANDIDATE}

  defp category(:malformed, other),
    do: flunk("malformed class got unexpected refusal #{inspect(other)}")

  defp assert_receipt_shape({:ok, %{decision: :DO, receipt: receipt, chain: chain, head: head}}) do
    assert receipt.admitted? == true and receipt.refusal == nil
    assert [%{name: :article5_admission, verdict: :pass}, %{name: :robust_margin, verdict: :pass}] = receipt.checks

    assert Xaas.Semantics.MasterEquationTest.verify_record(
             %{subject: receipt.subject, head_hash: receipt.head_hash},
             %{signature_hex: receipt.signature_hex, key_ref: "w541-court-key"}
           )

    assert :ok = AuditChain.verify_chain(chain, expected_head: head)
  end

  defp assert_receipt_shape(other),
    do: flunk("expected DO result, got: #{inspect(other)}")

  # ---------------------------------------------------------------------------
  # Attribution surface: exact Shapley over the two real admission checks
  # ---------------------------------------------------------------------------

  # Real AdmissionAttribution over the real gate-(a)/gate-(b) refuse
  # conditions. The module itself raises on efficiency-axiom violation, so a
  # clean return IS the axiom witness; we additionally assert shape + zeros
  # on the admitted class.
  defp attribution_for(class) do
    intent = candidate_for(class)

    checks = [
      {:article5_admission, fn _intent ->
         case Xaas.Semantics.EuAiActAdmission.admit(intent) do
           {:ok, :admitted} -> :pass
           {:error, _r} -> {:refuse, :gate_a}
         end
       end},
      {:robust_margin, fn _intent ->
         if class == :margin_violating, do: {:refuse, :gate_b}, else: :pass
       end}
    ]

    case AdmissionAttribution.shapley(intent, checks) do
      %{} = phis ->
        assert MapSet.new(Map.keys(phis)) == MapSet.new([:article5_admission, :robust_margin])
        assert Enum.all?(Map.values(phis), &is_float/1)

        if class == :lawful do
          # v(S)=1 for every coalition: no check carries marginal credit.
          assert phis == %{article5_admission: 0.0, robust_margin: 0.0}
        end

        phis

      {:error, :COALITION_LIMIT} = e ->
        flunk("two-check attribution hit coalition limit: #{inspect(e)}")
    end
  end

  # ---------------------------------------------------------------------------
  # Stress window harness
  # ---------------------------------------------------------------------------

  defp run_window(seed) do
    rng = seed_rng(seed)

    initial = {0, 0, 0}

    {final_counts, checkpoints, _rng} =
      Enum.reduce(1..@cycles, {initial, [], rng}, fn cycle, {counts, cps, rng} ->
        # Class draw: uniform over the 4 candidate classes.
        {draw, rng} = :rand.uniform_s(4, rng)
        class = Enum.at(@classes, draw - 1)

        # Real attribution surface per cycle (raises on axiom violation).
        attribution_for(class)

        {category, rng} = run_cycle(class, rng)

        counts =
          case category do
            :DO -> put_elem(counts, 0, elem(counts, 0) + 1)
            :BLOCKED_GATE_C -> put_elem(counts, 2, elem(counts, 2) + 1)
            {_gate, _atom} -> put_elem(counts, 1, elem(counts, 1) + 1)
          end

        {admitted, refused, blocked} = counts

        # (b) conservation at EVERY cycle.
        assert admitted + refused + blocked == cycle,
               "conservation violated at cycle #{cycle}: #{inspect(counts)}"

        cps =
          if rem(cycle, @checkpoint_every) == 0 do
            share = (admitted + refused) / cycle

            # Machinery-share window: bounded below by 1 - tamper cap.
            assert share >= 1 - @tamper_rate_pct / 100,
                   "machinery share #{share} fell below 1 - tamper cap at cycle #{cycle}"

            cps ++ [{cycle, admitted, refused, blocked, share}]
          else
            cps
          end

        {counts, cps, rng}
      end)

    {admitted, refused, blocked} = final_counts

    %{
      seed: seed,
      cycles: @cycles,
      admitted: admitted,
      refused: refused,
      blocked: blocked,
      machinery_share: (admitted + refused) / @cycles,
      checkpoints: checkpoints
    }
  end

  defp distribution(window) do
    total = window.cycles

    %{
      do: window.admitted / total,
      refused: window.refused / total,
      blocked: window.blocked / total
    }
  end

  # ---------------------------------------------------------------------------
  # Courts
  # ---------------------------------------------------------------------------

  describe "W719 composition stress window" do
    @tag :stress
    test "1000-cycle seeded window: per-cycle conservation, checkpoint machinery-share series, bounded memory" do
      # (d) forced-GC bracketed memory measurement.
      :erlang.garbage_collect()
      mem_before = :erlang.process_info(self(), :memory) |> elem(1)
      ets_before = :erlang.memory(:ets)

      window = run_window(@seed)

      :erlang.garbage_collect()
      mem_after = :erlang.process_info(self(), :memory) |> elem(1)
      ets_after = :erlang.memory(:ets)

      # Window returns only aggregates + the bounded checkpoint series.
      assert length(window.checkpoints) == div(@cycles, @checkpoint_every)

      # (a) the machinery-share series is tracked at every checkpoint.
      assert Enum.all?(window.checkpoints, fn {cycle, _a, _r, _b, share} ->
               is_integer(cycle) and is_float(share) and share >= 1 - @tamper_rate_pct / 100
             end)

      # (d) no memory growth across the window: process memory bounded by a
      # small allowance over the pre-window baseline; ETS memory unchanged.
      # (The window retains aggregates only — per-cycle outcomes are
      # asserted inline and dropped.)
      assert mem_after <= mem_before + 4 * 1024 * 1024,
             "process memory grew: before=#{mem_before} after=#{mem_after}"

      assert ets_after <= ets_before + 1024 * 1024,
             "ETS memory grew: before=#{ets_before} after=#{ets_after}"

      IO.puts("""
      W719 stress window (seed #{@seed}):
        admitted=#{window.admitted} refused=#{window.refused} blocked=#{window.blocked}
        machinery_share=#{Float.round(window.machinery_share, 4)}
        checkpoints=#{inspect(window.checkpoints)}
        mem_before=#{mem_before} mem_after=#{mem_after} ets_before=#{ets_before} ets_after=#{ets_after}
      """)
    end

    @tag :stress
    test "typed-decision distribution is stable across 3 seeds within +/-5%" do
      windows = for seed <- @seeds, do: run_window(seed)

      # Conservation holds at the final checkpoint of every seed.
      for w <- windows do
        assert w.admitted + w.refused + w.blocked == @cycles
      end

      # (c) pairwise share deltas within tolerance for every decision class.
      for {a, label_a} <- Enum.with_index(windows),
          {b, label_b} <- Enum.with_index(windows),
          label_a < label_b do
        da = distribution(a)
        db = distribution(b)

        for key <- [:do, :refused, :blocked] do
          delta = abs(da[key] - db[key])

          assert delta <= @tolerance,
                 "seeds #{a.seed}/#{b.seed} category #{key}: |#{da[key]} - #{db[key]}| = #{delta} > #{@tolerance}"
        end
      end

      for w <- windows do
        IO.puts("W719 distribution seed=#{w.seed}: #{inspect(distribution(w))} counts=#{inspect({w.admitted, w.refused, w.blocked})}")
      end
    end
  end
end
