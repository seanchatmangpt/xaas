defmodule Xaas.Semantics.FerroplanAiroPinTest do
  @moduledoc """
  W693 — pins the ferroplan AIRo risk-description surface
  (`/Users/sac/ferroplan/docs/airo-risk-description.ttl` @ main c03787687)
  against the claims recorded in
  docs/cro/artifacts/airo-wiring-ledger-verification-w668.md:

    * bare parse = 34 triples
    * union with the canonical AIRo 1.0 vocabulary = 592 triples (34 + 558)
    * the TTL cites vocabulary sha256 6274d2d8…, which is byte-identical to
      xaas's vendored priv/semantic/airo/airo.ttl (W600 pin)
    * every repo-relative path cited in the TTL exists in the ferroplan tree
    * key AIRo classes/properties used are declared in the vocabulary

  Chicago-style: real files, real sha256, real rdflib subprocess (the same
  /tmp/airo-venv toolchain check_airo.sh uses). No mocks.
  """

  use ExUnit.Case, async: false

  @fp_root "/Users/sac/ferroplan"
  @fp_ttl_relpath "docs/airo-risk-description.ttl"
  @fp_ttl_path Path.join(@fp_root, @fp_ttl_relpath)
  @canonical_aio_path Path.join(Path.expand("../../..", __DIR__), "priv/semantic/airo/airo.ttl")
  @cached_vocab_path "/tmp/airo.ttl"

  # TTL's own header citation, verified against the canonical vendor file.
  @vocab_sha256 "6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469"
  @fp_ttl_sha256 "27fd0cb808c1974b20d9259153a011c453913c0bbc2c2b43f5c2c14d464d4e08"

  # Ledger claims (w668 verification, ferroplan row w638).
  @expected_bare_triples 34
  @expected_union_triples 592

  @python "/tmp/airo-venv/bin/python"

  @key_classes ~w(AISystem AIProvider RiskSource RiskControl Risk)
  @key_properties ~w(hasRisk hasRiskControl isProvidedBy hasLikelihood hasSeverity hasConsequence mitigatesRiskConcept)

  defp sha256!(path) do
    path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  end

  defp rdflib_count!(paths) do
    script_path =
      Path.join(System.tmp_dir!(), "w693-rdflib-count-#{:erlang.unique_integer([:positive])}.py")

    File.write!(script_path, """
    import sys, rdflib
    g = rdflib.Graph()
    for p in sys.argv[1:]:
        g.parse(p, format="turtle")
    print(len(g))
    """)

    on_exit(fn -> File.rm(script_path) end)

    case System.cmd(@python, [script_path | paths], stderr_to_stdout: true) do
      {out, 0} ->
        case Integer.parse(String.trim(out)) do
          {n, ""} -> n
          _ -> flunk("rdflib subprocess printed non-integer output: #{inspect(out)}")
        end

      {out, code} ->
        flunk("rdflib subprocess failed (exit #{code}): #{out}")
    end
  end

  describe "ferroplan AIRo description pin" do
    test "TTL exists on the canonical ferroplan checkout" do
      assert File.exists?(@fp_ttl_path), "missing #{@fp_ttl_path}"
    end

    test "TTL byte-hash matches the W693 pin" do
      actual = sha256!(@fp_ttl_path)

      assert actual == @fp_ttl_sha256,
             "ferroplan airo-risk-description.ttl drift: expected #{@fp_ttl_sha256}, got #{actual}"
    end

    test "bare parse yields the ledger's 34 triples" do
      assert rdflib_count!([@fp_ttl_path]) == @expected_bare_triples
    end

    test "union with the canonical vocabulary yields the ledger's 592 triples" do
      assert rdflib_count!([@fp_ttl_path, @canonical_aio_path]) == @expected_union_triples
    end

    test "vocabulary cited in the TTL header is byte-identical to xaas's vendored airo.ttl" do
      assert sha256!(@canonical_aio_path) == @vocab_sha256,
             "canonical vendored airo.ttl no longer matches the hash cited by the ferroplan TTL"

      assert sha256!(@cached_vocab_path) == @vocab_sha256,
             "/tmp/airo.ttl vocab cache drifted from the canonical vendored copy"
    end

    test "every repo-relative path cited in the TTL exists in the ferroplan tree" do
      content = File.read!(@fp_ttl_path)

      paths =
        Regex.scan(~r/(?:crates|\.github|justfile|scripts)[^ \t\r\n)",;]*/, content)
        |> Enum.map(fn [p] -> Regex.replace(~r/:[0-9]+$/, Regex.replace(~r/\.$/, p, ""), "") end)
        |> Enum.uniq()
        |> Enum.sort()

      assert paths != [], "no cited paths found in the TTL (citation grounding vacuous)"

      for p <- paths do
        assert File.exists?(Path.join(@fp_root, p)), "cited path missing in ferroplan: #{p}"
      end
    end

    test "key AIRo classes and properties used are declared in the canonical vocabulary" do
      vocab = File.read!(@canonical_aio_path)

      for term <- @key_classes ++ @key_properties do
        assert String.contains?(vocab, "airo##{term}"),
               "airo:#{term} not declared in the canonical vocabulary"
      end
    end

    test "TTL actually uses the fp-airo ontology and both risk/both control individuals" do
      content = File.read!(@fp_ttl_path)

      for individual <- ~w(FerroplanSystem FerroplanProvider RiskUnreachableGoalPlanning RiskPlanNonDeterminism ControlBackwardSafeSet ControlReachabilityCourt ControlForbiddenOpMask ControlStrongCyclicSolver) do
        assert String.contains?(content, "fp-airo:#{individual}"),
               "TTL missing fp-airo:#{individual}"
      end
    end
  end
end
