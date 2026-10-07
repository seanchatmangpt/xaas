defmodule Xaas.Wasm4pmSerdeSurfacePinTest do
  @moduledoc """
  Lane W673 — contract pin over the sibling wasm4pm `eu_gate` crate's serde
  surface.

  Backlog item from the W509->W652 defect class: `title_iv_v_test.exs` used to
  assert against wasm4pm crate source literals ("ADMITTED" etc.); the wasm4pm
  serde rename (`rename_all = "SCREAMING_SNAKE_CASE"`) broke those source-
  literal assertions silently. W652 repaired the consumer test to attribute-
  level asserts. This pin prevents recurrence the other direction: if the
  crate's serde field names / attributes that xaas's eu_ai_act suite depends
  on move or disappear, it fails HERE with a typed message naming the
  consuming xaas test — not there, obscurely.

  Chicago-style: real `File.read!/1` of the sibling checkout at
  `/Users/sac/wasm4pm`, content assertions only, no mocks.
  """

  use ExUnit.Case

  # Genuine evidenced line: this surface IS the Art. 55.1.d cybersecurity-gate
  # evidence (corpus "55.1.a"/"55.1.d" EVIDENCED entries cite
  # /Users/sac/wasm4pm/crates/eu_gate + docs/sjira/v26.10.6/plans/w509-wasi-gate.md;
  # title_iv_v_test.exs line ~320). Hence the tag is load-bearing, not decorative.
  @moduletag :eu_ai_act

  @crate_dir "/Users/sac/wasm4pm/crates/eu_gate"
  @lib_path Path.join(@crate_dir, "src/lib.rs")
  @main_path Path.join(@crate_dir, "src/main.rs")

  # Typed failure requires the subject to exist; absence is a pin failure,
  # not a skip (the eu_ai_act suite already treats this crate as evidence).
  defp read_lib do
    if File.exists?(@lib_path) do
      File.read!(@lib_path)
    else
      flunk("""
      WASM4PM_EU_GATE_MISSING (W673 pin)
      Subject: #{@lib_path}
      Consuming tests that depend on this surface:
        test/eu_ai_act/title_iv_v_test.exs (W509/W652 verdict-contract asserts)
        test/eu_ai_act/title_ii_test.exs (@wasi_crate path pin)
        test/eu_ai_act/title_iii_test.exs (W509 Art. 55.1.d evidenced path)
      """)
    end
  end

  # --- serde field-name pins (consumers: title_iv_v runtime JSON contract) ---

  # title_iv_v_test.exs asserts `{"verdict":"ADMITTED"}` and
  # "REFUSED_REQUIRED_FIELD_MISSING" on the BINARY's stdout. The binary's JSON
  # is produced by serde from this enum. tag="verdict" + SCREAMING_SNAKE_CASE
  # is exactly what renders those two strings; renaming either changes the
  # wire contract xaas asserts.
  test "Verdict enum serde tagging pins the wire verdict strings" do
    lib = read_lib()

    for attr <- [
          ~s(tag = "verdict"),
          ~s(rename_all = "SCREAMING_SNAKE_CASE"),
          "pub enum Verdict",
          "Admitted",
          "Refused"
        ] do
      assert lib =~ attr,
             "WASM4PM_SERDE_SURFACE_DRIFT (W673 pin): #{inspect(attr)} missing from #{@lib_path} — " <>
               "test/eu_ai_act/title_iv_v_test.exs asserts the JSON verdict wire strings " <>
               "(\"verdict\":\"ADMITTED\", \"REFUSED_REQUIRED_FIELD_MISSING\") that this " <>
               "serde attribute/variant renders. If this moved intentionally, update BOTH sides."
    end
  end

  # The wire code strings come from RefusalCode::as_str/1 match arms today;
  # the serde rename_all on RefusalCode is the durable attribute that keeps
  # deserialization of xaas-side fixtures aligned with the wire codes.
  test "RefusalCode enum pins the typed refusal-code vocabulary" do
    lib = read_lib()

    # Every refusal code the xaas suite (title_iv_v, receipt w509) exercises
    # or cites. as_str/1 is the wire renderer; the variant set is the contract.
    codes = [
      "REFUSED_REQUIRED_FIELD_MISSING",
      "REFUSED_ENUM_VIOLATION",
      "REFUSED_RANGE_VIOLATION",
      "REFUSED_FORBIDDEN_FIELD",
      "REFUSED_INFRASTRUCTURE_FAULT"
    ]

    for code <- codes do
      assert lib =~ code,
             "WASM4PM_REFUSAL_CODE_DRIFT (W673 pin): #{code} missing from #{@lib_path} — " <>
               "test/eu_ai_act/title_iv_v_test.exs (and receipt w509-wasi-gate.md) treat this " <>
               "as the gate's typed refusal vocabulary. A rename here is a wire-contract break."
    end

    assert lib =~ "pub enum RefusalCode",
           "WASM4PM_SERDE_SURFACE_DRIFT (W673 pin): pub enum RefusalCode missing from #{@lib_path}"
  end

  # title_iv_v_test.exs writes rules JSON:
  #   %{"rules" => [%{"type" => "required", "field" => "id"}]}
  # That wire shape is serde-deserialized by Rule/RuleSet. Pin the exact tag
  # attribute and per-rule payload field names.
  test "Rule/RuleSet serde shape pins the rules-JSON contract xaas writes" do
    lib = read_lib()

    for attr <- [
          ~s(tag = "type"),
          ~s(rename_all = "snake_case"),
          "pub enum Rule",
          "pub struct RuleSet",
          "pub rules:",
          "field: String",
          "values: Vec<Value>",
          "min: f64",
          "max: f64"
        ] do
      assert lib =~ attr,
             "WASM4PM_RULES_CONTRACT_DRIFT (W673 pin): #{inspect(attr)} missing from #{@lib_path} — " <>
               "test/eu_ai_act/title_iv_v_test.exs writes rules JSON " <>
               "%{\"rules\" => [%{\"type\" => \"required\", \"field\" => ...}]} against this serde " <>
               "shape. If a rule field renamed, the xaas runtime assert breaks obscurely."
    end
  end

  # The CLI contract xaas's System.cmd/3 test depends on: two positional args,
  # verdict on stdout, exit 0 always (trap -> typed refusal, not crash).
  test "main.rs pins the CLI contract (2 args, stdout verdict, exit 0)" do
    assert File.exists?(@main_path),
           "WASM4PM_EU_GATE_MAIN_MISSING (W673 pin): #{@main_path} — " <>
             "test/eu_ai_act/title_iv_v_test.exs System.cmd/3 runtime asserts depend on it"

    main = File.read!(@main_path)

    for snippet <- [
          "evaluate_checked",
          ~S("{\"verdict\":\"REFUSED\",\"code\":\"REFUSED_INFRASTRUCTURE_FAULT\"}")
        ] do
      assert main =~ snippet,
             "WASM4PM_CLI_CONTRACT_DRIFT (W673 pin): #{inspect(snippet)} missing from #{@main_path} — " <>
               "the fail-closed stdout fallback and the evaluate_checked entry point are what make " <>
               "the xaas CLI test's exit-0 + stdout-verdict asserts lawful."
    end
  end

  # Cross-pin: the serde attributes the W652-repaired consumer asserts are the
  # same ones pinned here — if wasm4pm changes them, update title_iv_v AND
  # this pin together (one decision, two sites, named here).
  test "W652-consumed attributes stay in lockstep with the consumer test" do
    lib = read_lib()

    assert lib =~ ~s(rename_all = "SCREAMING_SNAKE_CASE"),
           "WASM4PM_SERDE_SURFACE_DRIFT (W673 pin): rename_all attribute moved — " <>
             "test/eu_ai_act/title_iv_v_test.exs:~180 asserts exactly " <>
             "~s(rename_all = \"SCREAMING_SNAKE_CASE\") and 'pub enum Verdict'."
  end
  @doc false
  def crate_dir, do: @crate_dir
end
