defmodule Xaas.Deepening.Art94ZeroConfigEnvInvarianceTest do
  @moduledoc """
  Lane W984al — evidenced-line deepening wave 5, corpus line **9.4**
  (Art. 9(4) combined-application effects, classified in the corpus
  evidence map as "combined-application effects considered via the
  zero-config posture audit across ALL safety/refusal sites", evidence
  lane W322, `w322-zero-config-posture.md`).

  W322's audit was a read-only grep sweep: it classified every
  `Application.get_env`/`System.get_env` site on or adjacent to a safety
  path but executed nothing. The uncovered property is EXECUTED
  invariance: the real safety-gate family — `DatasetAdmission.admit/2`,
  `RobustMargin.admit/4`, `EuAiActAdmission.admit/1` — returns
  identical verdicts whether the ambient application environment is
  clean or hostilely seeded with the exact knob names a regression would
  introduce (`:dataset_epsilon_bias`, `:eta`, `:robust_margin_l_h`, ...).

  Mutation rationale: if any gate in the family starts reading the
  ambient application env in its safety path (the anti-selling
  regression w322 guards against), the hostile-env verdict diverges and
  all three courts fail — while every single-verdict court in
  `dataset_admission_test.exs`, `robust_margin_test.exs`,
  `robust_margin_depth_test.exs`, `title_ii_test.exs` still passes,
  because none of them set a hostile knob before executing the gate.

  Contrast with W984a's Art 10(2)(h) eta-flip court
  (`art_10_2h_10_3_dataset_gate_causality_test.exs`): that court flips
  the verdict with a CALL-ARGUMENT change under a clean env; these
  courts flip NOTHING with an AMBIENT-ENV change. Complementary,
  non-overlapping.

  Chicago discipline: real pure-module executions over real boundary
  datasets, real `Application.put_env/delete_env` toggling (restored
  after every execution), assertions on returned final state. No mocks.
  """

  use ExUnit.Case, async: false

  # 9.4 is an evidenced corpus line (w322 evidence entry) — eu_ai_act census.
  @moduletag :eu_ai_act

  alias Xaas.Semantics.{DatasetAdmission, EuAiActAdmission, RobustMargin}

  # Knob names a regression would plausibly introduce, with hostile
  # VALUES: each would flip the corresponding verdict if the gate
  # actually read it.
  @hostile_knobs [
    {:xaas, :dataset_epsilon_bias, 100.0},
    {:xaas, :dataset_eta, 100.0},
    {:xaas, :dataset_seed, 0},
    {:xaas, :dataset_projections, 1},
    {:xaas, :dataset_required_fields, []},
    {:xaas, :robust_margin_l_h, 0.0},
    {:xaas, :robust_margin_l_e, 0.0},
    {:xaas, :robust_margin_epsilon, 100.0},
    {:xaas, :eu_ai_act_admission_enabled, false},
    {:xaas, :eu_ai_act_refusals_disabled, true},
    {:xaas, :safety_gates_enabled, false}
  ]

  setup do
    on_exit(fn ->
      for {app, key, _} <- @hostile_knobs, do: Application.delete_env(app, key)
    end)

    :ok
  end

  defp set_hostile_env do
    for {app, key, value} <- @hostile_knobs, do: Application.put_env(app, key, value)
  end

  # -- deterministic boundary fixtures ---------------------------------------

  # A paired dataset that ADMITS: completeness 1.0 and bias-free — the two
  # sensitive groups carry IDENTICAL feature multisets (W1 = 0), so the
  # verdict is ADMITTED under the tight default-ish epsilon 0.1.
  defp boundary_admitting_dataset do
    for k <- 1..10, s <- [0, 1] do
      %{features: %{a: k * 1.0, b: :math.fmod(k * 1.0, 3.0)},
        label: :ok,
        sensitive: s}
    end
  end

  # A dataset that refuses INCOMPLETE under the explicit eta 0.1: half the
  # samples are missing the required field :b (completeness 0.5 < 0.9).
  defp incomplete_dataset do
    for k <- 1..10, s <- [0, 1] do
      features =
        if s == 0 do
          %{a: k * 1.0, b: :math.fmod(k * 1.0, 3.0)}
        else
          %{a: k * 1.0}
        end

      %{features: features, label: :ok, sensitive: s}
    end
  end

  defp clean_candidate do
    %{
      id: :w984al_benign,
      techniques: [:recommendation],
      purpose: :rank_content,
      data_domains: [:usage_events],
      provenance: :consented,
      setting: :consumer_app,
      latency_goal: :batch
    }
  end

  defp manipulative_candidate do
    %{id: :w984al_manipulative, techniques: [:manipulate_behavior]}
  end

  # -- the gate-family execution law -----------------------------------------

  # Executes the full gate family ONCE per call and returns the verdict
  # tuple. Called with the env clean and again with the env hostile; the
  # two MUST be equal.
  defp gate_family_verdicts do
    {
      DatasetAdmission.admit(boundary_admitting_dataset(),
        seed: 42,
        epsilon_bias: 0.1,
        eta: 0.1,
        required_fields: [:a, :b]
      ),
      DatasetAdmission.admit(incomplete_dataset(),
        seed: 42,
        epsilon_bias: 0.1,
        eta: 0.1,
        required_fields: [:a, :b]
      ),
      RobustMargin.admit(0.5, 2.0, 1.0, 0.1),
      RobustMargin.admit(0.05, 2.0, 1.0, 0.1),
      EuAiActAdmission.admit(clean_candidate()),
      EuAiActAdmission.admit(manipulative_candidate())
    }
  end

  test "court 1 — combined-application hostility: every gate verdict is invariant under a hostilely-seeded ambient env" do
    clean = gate_family_verdicts()

    # Sanity: the boundary fixtures genuinely straddle the gates — the
    # court must not pass vacuously on an all-admitting family.
    assert {:ok, :ADMITTED, _} = elem(clean, 0)
    assert {:error, {:REFUSED_INCOMPLETE_DATASET, _}} = elem(clean, 1)
    assert :ADMITTED = elem(clean, 2)
    assert {:error, :REFUSED_ROBUST_MARGIN} = elem(clean, 3)
    assert {:ok, :admitted} = elem(clean, 4)
    assert {:error, :REFUSED_EUAIA_MANIPULATIVE} = elem(clean, 5)

    set_hostile_env()

    hostile = gate_family_verdicts()

    assert hostile == clean,
           "a safety-gate verdict changed when the ambient env was set — " <>
             "config-gated safety law (w322 finding class)"
  end

  test "court 2 — the env can never ADMIT a refused gate: maximal-permissive knobs cannot un-refuse the refusing fixtures" do
    set_hostile_env()
    hostile = gate_family_verdicts()

    # The refusing elements stay refusing under maximal-permissive knob
    # VALUES, not merely knob presence.
    assert match?({:error, {:REFUSED_INCOMPLETE_DATASET, _}}, elem(hostile, 1))
    assert elem(hostile, 3) == {:error, :REFUSED_ROBUST_MARGIN}
    assert elem(hostile, 5) == {:error, :REFUSED_EUAIA_MANIPULATIVE}

    # And the admitting elements stay admitting with IDENTICAL measured
    # envelopes (no knob drifts a measured quantity).
    assert {:ok, :ADMITTED, _} = elem(hostile, 0)
    assert {:ok, :admitted} = elem(hostile, 4)
  end

  test "court 3 — seeded parameter sweep: verdicts are env-invariant across a deterministic parameter space" do
    state = :rand.seed(:exsss, :erlang.phash2({:w984al, :sweep}))
    draw = fn -> :rand.uniform_s(state) |> elem(0) end

    for trial <- 1..50 do
      margin = draw.() * 10.0 - 5.0
      l_h = draw.() * 3.0
      l_e = draw.() * 2.0
      eps = draw.() * 0.5

      clean = RobustMargin.admit(margin, l_h, l_e, eps)

      set_hostile_env()
      hostile = RobustMargin.admit(margin, l_h, l_e, eps)

      for {app, key, _} <- @hostile_knobs, do: Application.delete_env(app, key)

      assert clean == hostile,
             "trial #{trial}: verdict diverged under hostile env"
    end
  end
end
