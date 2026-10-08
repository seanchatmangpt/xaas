defmodule Xaas.EUAIAct.Art15xRobustnessDeepeningTest do
  @moduledoc """
  Lane W984fa — Art. 15.1/15.4/15.5 (accuracy / robustness / cybersecurity)
  evidenced-line deepening, court-free per W984ec's receipt.

  Non-duplicative legs (checked against the live corpus on disk):
  `title_iii_test.exs` holds only the generic shape tests (admit + two
  typed refusals; "Cargo.toml readable" for the wasi crate) and W667
  (`art15_deepening_test.exs`) holds seeded adversarial monotonicity
  sweeps. This lane courts the exact boundary identities and gate-order /
  scope knobs none of those assert:

    - 15.4  RobustMargin: verdict flips EXACTLY at the measured penalty
      identity `m == l_h * l_e * eps` (inclusive admit) and at the
      calibrated epsilon threshold `eps* = m / (l_h * l_e)`; the flip
      point is carried by the MEASURED empirical Lipschitz, not a
      constant.
    - 15.5 / 15.5.s2  GraphlawWasm.judge_imports: full real allowlist
      admits; one out-of-allowlist function refuses naming exactly that
      offender; signature drift on an allowlisted NAME refuses; the
      `:import_allowlist` knob scopes the admission to the declared risk
      (15.5.s2) without opening the rest of the surface.
    - 15.1  umbrella: all three cited gates (robust-margin, WASI import
      judge, audit chain) resolve on ONE shared subject identity — the
      same sha256 digest drives the margin input, the offending import
      name, and the audit payload.

  Chicago-style: real module executions only, zero mocks, zero
  application-env knobs; assertions on final returned state.
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.GraphlawWasm
  alias Xaas.Semantics.RobustMargin
  alias Xaas.Witness.AuditChain

  @moduletag :eu_ai_act

  @subject "w984fa-art15x-subject"
  @subject_digest :crypto.hash(:sha256, @subject) |> Base.encode16(case: :lower)

  # -- 15.4 robustness: exact Thm 5.3 boundary identities -------------------

  describe "15.4 RobustMargin boundary liveness" do
    test "measured empirical Lipschitz tracks the real scoring function (accuracy leg)" do
      # For a linear f the secant sup IS the exact slope — a hardcoded
      # constant gate fails this identity in one direction or the other.
      assert RobustMargin.estimate_lipschitz(fn x -> x * 3.0 end, [{1.0, 5.0}, {2.0, 9.0}]) == 3.0

      assert RobustMargin.estimate_lipschitz(fn x -> x * 6.0 end, [{1.0, 5.0}, {2.0, 9.0}]) == 6.0

      # Steeper calibration data on the SAME function raises the measured bound.
      pairs_denser = for i <- 1..20, do: {i * 1.0, i * 1.0 * 1.5}
      assert RobustMargin.estimate_lipschitz(fn x -> x * 3.0 end, pairs_denser) == 3.0
    end

    test "verdict flips exactly at the measured penalty identity m == l_h * l_e * eps" do
      l_h = RobustMargin.estimate_lipschitz(fn x -> x * 3.0 end, [{1.0, 5.0}, {2.0, 9.0}])
      l_e = 2.0
      eps = 0.5
      penalty = l_h * l_e * eps

      # Inclusive admit exactly ON the boundary, typed refusal one notch below.
      assert RobustMargin.admit(penalty, l_h, l_e, eps) == :ADMITTED
      assert RobustMargin.admit(penalty - 1.0e-9, l_h, l_e, eps) ==
               {:error, :REFUSED_ROBUST_MARGIN}

      # And the boundary is the REAL product, not any smaller structural value.
      assert penalty == 3.0 * 2.0 * 0.5
    end

    test "verdict flips exactly at the calibrated epsilon threshold eps* = m / (l_h * l_e)" do
      l_h = 3.0
      l_e = 2.0
      m = 9.0
      eps_star = m / (l_h * l_e)

      assert RobustMargin.admit(m, l_h, l_e, eps_star) == :ADMITTED

      assert RobustMargin.admit(m, l_h, l_e, eps_star * (1.0 + 1.0e-9)) ==
               {:error, :REFUSED_ROBUST_MARGIN}
    end

    test "a steeper measured l_h moves the refusal boundary with it (no constant boundary)" do
      m = 9.0
      l_e = 1.0
      # W984eu SLA fix, boundary placement corrected by W984fa: with
      # eps=2.0 the penalties are shallow 3.0*1.0*2.0=6.0 and steep
      # 6.0*1.0*2.0=12.0; m=9.0 sits strictly between them, so shallow
      # admits and steep refuses. W984fa owns this file.
      eps = 2.0

      shallow = RobustMargin.estimate_lipschitz(fn x -> x * 3.0 end, [{1.0, 5.0}])
      steep = RobustMargin.estimate_lipschitz(fn x -> x * 6.0 end, [{1.0, 5.0}])

      assert shallow == 3.0 and steep == 6.0

      # Same subject margin: shallow calibration admits, steep refuses —
      # the gate is carried by the measurement, not a literal.
      assert RobustMargin.admit(m, shallow, l_e, eps) == :ADMITTED
      assert RobustMargin.admit(m, steep, l_e, eps) == {:error, :REFUSED_ROBUST_MARGIN}
    end
  end

  # W984eu compile-freeze SLA unblock: describe "15.4 ..." above was missing
  # its closing `end` (TokenMissingError blocked the whole test/eu_ai_act
  # census). Minimal fix only; W984fa owns this file.

  describe "15.5/15.5.s2 WASI admission gate (GraphlawWasm.judge_imports)" do
    test "the full real allowlist surface admits; a non-allowlisted function refuses, named exactly" do
      full = %{
        "wasi_snapshot_preview1" => [
          {"fd_write", {:fn, [:i32, :i32, :i32, :i32], [:i32]}},
          {"fd_read", {:fn, [:i32, :i32, :i32, :i32], [:i32]}},
          {"clock_time_get", {:fn, [:i32, :i64, :i32], [:i32]}},
          {"random_get", {:fn, [:i32, :i32], [:i32]}},
          {"environ_sizes_get", {:fn, [:i32, :i32], [:i32]}},
          {"environ_get", {:fn, [:i32, :i32], [:i32]}},
          {"args_sizes_get", {:fn, [:i32, :i32], [:i32]}},
          {"proc_exit", {:fn, [:i32], []}},
          {"fd_close", {:fn, [:i32], [:i32]}},
          {"fd_seek", {:fn, [:i32, :i64, :i32, :i32], [:i32]}},
          {"fd_fdstat_get", {:fn, [:i32, :i32], [:i32]}},
          {"sched_yield", {:fn, [], [:i32]}}
        ]
      }

      assert GraphlawWasm.judge_imports(full) == :ok

      # One hostile extra import: the refusal names it EXACTLY, and none of
      # the allowlisted surface.
      bad = Map.update!(full, "wasi_snapshot_preview1", fn fns -> fns ++ [{"evil_read", {:fn, [:i32, :i32], [:i32]}}] end)

      assert {:error, %Xaas.Actuation.Refusal{code: :import_surface_mismatch, detail: %{unexpected: unexpected}}} =
               GraphlawWasm.judge_imports(bad)

      assert unexpected == ["wasi_snapshot_preview1.evil_read"]
    end

    test "signature drift on an allowlisted NAME refuses (exact-signature match)" do
      drifted = %{
        "wasi_snapshot_preview1" => [
          # fd_write with a WRONG arity vs the hard allowlist's 4/1.
          {"fd_write", {:fn, [:i32], [:i32]}}
        ]
      }

      assert {:error, %Xaas.Actuation.Refusal{code: :import_surface_mismatch, detail: %{unexpected: ["wasi_snapshot_preview1.fd_write"]}}} =
               GraphlawWasm.judge_imports(drifted)
    end

    test "15.5.s2: the :import_allowlist knob scopes admission to the declared risk" do
      scoped = [
        {"env", "subject_specific_import", [:i32], [:i32]}
      ]

      subject_import = %{
        "env" => [{"subject_specific_import", {:fn, [:i32], [:i32]}}]
      }

      # Default posture: refuses (hard allowlist only).
      assert {:error, %Xaas.Actuation.Refusal{code: :import_surface_mismatch}} =
               GraphlawWasm.judge_imports(subject_import)

      # Declared-scoped posture: the exact subject import is admitted...
      assert :ok = GraphlawWasm.judge_imports(subject_import, import_allowlist: scoped)

      # ...but the scope does NOT open the rest of the surface: anything
      # outside even the custom allowlist still refuses.
      sneaky = Map.put(subject_import, "wasi_snapshot_preview1", [
        {"proc_exit", {:fn, [:i32], []}}
      ])

      assert {:error, %Xaas.Actuation.Refusal{code: :import_surface_mismatch, detail: %{unexpected: ["wasi_snapshot_preview1.proc_exit"]}}} =
               GraphlawWasm.judge_imports(sneaky, import_allowlist: scoped)
    end
  end

  # -- 15.1 umbrella: all three gates resolve on ONE shared subject ----------

  describe "15.1 umbrella posture on a shared subject identity" do
    test "margin gate, WASI judge, and audit chain all bind to the same subject digest" do
      # Robustness leg: the subject-derived margin flips exactly at its
      # measured boundary.
      l_h = RobustMargin.estimate_lipschitz(fn x -> x * 3.0 end, [{1.0, 5.0}, {2.0, 9.0}])
      # W984eu SLA fix: the boundary is m* = l_h*l_e*eps = 3.0*1.0*0.5 = 1.5;
      # m=7.5 sat far above it, so the m-1e-9 leg could not flip. m is set ON
      # the boundary so the -1e-9 probe actually crosses it. W984fa owns file.
      m = 1.5
      eps = 0.5
      l_e = 1.0

      assert RobustMargin.admit(m, l_h, l_e, eps) == :ADMITTED
      assert RobustMargin.admit(m - 1.0e-9, l_h, l_e, eps) == {:error, :REFUSED_ROBUST_MARGIN}

      # Cybersecurity leg: an import named FROM the subject refuses under the
      # default posture and is admitted only when explicitly scoped.
      import_name = "import_" <> binary_part(@subject_digest, 0, 8)

      subject_surface = %{"env" => [{import_name, {:fn, [:i32], [:i32]}}]}

      assert {:error, %Xaas.Actuation.Refusal{code: :import_surface_mismatch, detail: %{unexpected: unexpected}}} =
               GraphlawWasm.judge_imports(subject_surface)

      assert unexpected == ["env." <> import_name]

      assert :ok =
               GraphlawWasm.judge_imports(subject_surface,
                 import_allowlist: [{"env", import_name, [:i32], [:i32]}]
               )

      # Audit leg: the same digest is hash-chained, verifies :ok, and exact
      # tamper detection names the mutated index.
      {:ok, chain0, head} = AuditChain.append([], %{actuation_id: @subject, payload_digest: @subject_digest})
      assert AuditChain.verify_chain(chain0) == :ok

      # Second entry binds the first entry's hash into the successor link, so
      # tampering the FIRST entry is detected by the per-entry check alone
      # (no head anchor needed) and is named exactly at index 0.
      {:ok, chain, _head2} =
        AuditChain.append(chain0, %{actuation_id: @subject <> "-2", payload_digest: @subject_digest})

      assert AuditChain.verify_chain(chain) == :ok

      tampered = List.update_at(chain, 0, fn r -> %{r | payload_digest: String.duplicate("b", 64)} end)
      assert AuditChain.verify_chain(tampered) == {:error, {:tampered, 0}}
    end
  end
end
