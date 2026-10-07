defmodule Xaas.EUAIAct.EyerunWireDeepeningTest do
  @moduledoc """
  Lane W706 — eyerun_wasi binary wire-contract deepening for Art. 55.1.d
  (cybersecurity gate; corpus line "EUAI-ACT 55.1.d").

  W653b built the real release binary and drove it from
  `title_iv_v_test.exs` (the `deepening("55.1.d")` block), but no dedicated
  court pinned the END-TO-END WIRE CONTRACT: exact stdout JSON, typed refusal
  codes, exit-code discipline, and determinism. This court does exactly that.

  Chicago-style: every case is a REAL `System.cmd/3` subprocess run of the
  real ADMITTED/REFUSED binary over real fixture files — no mocks, no stubs,
  no source-literal reads (that is W673's pin's job; this court exercises
  the BEHAVIOR).
  """

  use ExUnit.Case, async: true

  @moduletag :eu_ai_act

  # Binary leg per W653b receipt: real release build, symlinked at the
  # path title_iv_v reads. The primary path is the W653b target; the w509
  # symlink location is the fallback both consumers standardize on.
  @binary_candidates [
    "/tmp/w653b-target/release/eyerun_wasi",
    "/tmp/w509-target/release/eyerun_wasi"
  ]

  @w653b_receipt "docs/sjira/v26.10.6/plans/w653b-binary-leg.md"

  # -- setup -----------------------------------------------------------------

  setup do
    binary = Enum.find(@binary_candidates, &File.exists?/1)

    assert binary, """
    W706_EYERUN_BINARY_MISSING: no eyerun_wasi binary found at any of
    #{inspect(@binary_candidates)}.

    The W653b receipt (#{@w653b_receipt}) documents the real release build:
      cd /Users/sac/wasm4pm/crates/eu_gate && \
        CARGO_TARGET_DIR=/tmp/w653b-target cargo build --release
    Rebuild it and rerun — this court never skips silently.
    """

    dir = System.tmp_dir!()
    uid = System.unique_integer([:positive])
    rules_path = Path.join(dir, "w706-rules-#{uid}.json")
    cand_path = Path.join(dir, "w706-cand-#{uid}.json")

    File.write!(rules_path, Jason.encode!(%{"rules" => [%{"type" => "required", "field" => "id"}]}))

    on_exit(fn ->
      File.rm(rules_path)
      File.rm(cand_path)
    end)

    {:ok, binary: binary, rules: rules_path, cand: cand_path}
  end

  # -- real subprocess harness ------------------------------------------------

  defp run_gate(binary, rules, cand), do: System.cmd(binary, [rules, cand])

  defp write_candidate(cand, body), do: File.write!(cand, body)

  # -- (a) satisfying candidate → ADMITTED on stdout --------------------------

  @tag :w706_admitted
  test "satisfying candidate yields {\"verdict\":\"ADMITTED\"} on stdout", %{
    binary: binary,
    rules: rules,
    cand: cand
  } do
    write_candidate(cand, Jason.encode!(%{"id" => "W706-001"}))

    {out, exit_code} = run_gate(binary, rules, cand)

    assert exit_code == 0
    assert String.trim_trailing(out) == ~s({"verdict":"ADMITTED"})
  end

  # -- (b) required-field-absent → typed refusal -------------------------------

  @tag :w706_refused_field
  test "required-field-absent candidate yields REFUSED_REQUIRED_FIELD_MISSING", %{
    binary: binary,
    rules: rules,
    cand: cand
  } do
    write_candidate(cand, Jason.encode!(%{"note" => "required field absent"}))

    {out, exit_code} = run_gate(binary, rules, cand)

    assert exit_code == 0
    assert %{"verdict" => "REFUSED", "code" => "REFUSED_REQUIRED_FIELD_MISSING"} =
             Jason.decode!(out)
  end

  # -- (c) malformed JSON → fail-closed infrastructure fault -------------------

  @tag :w706_malformed
  test "malformed JSON candidate yields fail-closed REFUSED_INFRASTRUCTURE_FAULT", %{
    binary: binary,
    rules: rules,
    cand: cand
  } do
    write_candidate(cand, ~S({"broken))

    {out, exit_code} = run_gate(binary, rules, cand)

    assert exit_code == 0
    assert %{"verdict" => "REFUSED", "code" => "REFUSED_INFRASTRUCTURE_FAULT"} =
             Jason.decode!(out)
  end

  # -- (d) exit-code discipline: always 0, verdict in stdout -------------------

  @tag :w706_exit_discipline
  test "exit code is 0 on every case; verdicts live in stdout (fail-closed stdout contract)",
       %{binary: binary, rules: rules, cand: cand} do
    cases = [
      {"satisfying", Jason.encode!(%{"id" => "W706-EXIT"})},
      {"missing-field", Jason.encode!(%{"other" => 1})},
      {"malformed", ~S({"broken)}
    ]

    for {label, body} <- cases do
      write_candidate(cand, body)
      {out, exit_code} = run_gate(binary, rules, cand)

      assert exit_code == 0, "case #{label}: expected exit 0, got #{exit_code}"
      assert out =~ ~s("verdict"), "case #{label}: stdout must carry the verdict JSON"
      assert Map.fetch!(Jason.decode!(out), "verdict") in ["ADMITTED", "REFUSED"]
    end
  end

  # -- (e) determinism ×3 per case ---------------------------------------------

  @tag :w706_determinism
  test "each case is byte-identical across three independent runs", %{
    binary: binary,
    rules: rules,
    cand: cand
  } do
    cases = [
      {"satisfying", Jason.encode!(%{"id" => "W706-DET"}), ~s({"verdict":"ADMITTED"})},
      {"missing-field", Jason.encode!(%{"other" => 1}), nil},
      {"malformed", ~S({"broken), nil}
    ]

    for {label, body, _expected} <- cases do
      write_candidate(cand, body)

      runs =
        for _n <- 1..3 do
          {out, exit_code} = run_gate(binary, rules, cand)
          {String.trim_trailing(out), exit_code}
        end

      assert length(Enum.uniq(runs)) == 1,
             "case #{label}: nondeterministic wire output across 3 runs: #{inspect(runs)}"

      [{trimmed_out, exit_code}] = Enum.uniq(runs)
      assert exit_code == 0
      assert %{"verdict" => verdict} = Jason.decode!(trimmed_out)
      assert verdict in ["ADMITTED", "REFUSED"]
    end
  end
end
