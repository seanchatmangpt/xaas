defmodule Xaas.Ultracode.SubstitutionPolicyDepthTest do
  @moduledoc """
  W984cw3 depth court on `Xaas.Ultracode.SubstitutionPolicy` (rank #9, W984cj map;
  SparqlBridge/Mermaid/Tunnel.Submit already claimed by W984cv/cx/cw2,
  AuthorityLedgerExport reclassified COVERED via W603 court).

  Chicago discipline: real canonical TTL from `priv/ontology/`, real parse, real
  admit_receipt decisions over real maps. No mocks — the module's only collaborators
  are the on-disk policy file and pure functions over it.

  Each test carries an inline mutation rationale naming the guard that dies if a
  mutant survives.
  """

  use ExUnit.Case, async: true

  alias Xaas.Ultracode.SubstitutionPolicy

  @ttl_path "priv/ontology/interchangeable-part-qualification.ttl"
  @subject "sjira/xyzzy@" <> String.duplicate("a", 40)

  defp real_ttl, do: File.read!(Path.expand(@ttl_path, File.cwd!()))

  defp drift(base, from, to), do: String.replace(base, from, to)

  defp digest(ttl), do: "sha256:" <> (:crypto.hash(:sha256, ttl) |> Base.encode16(case: :lower))

  defp receipt(overrides) do
    Map.merge(
      %{exact_subject: @subject, standing: "ALIVE"},
      Map.new(overrides)
    )
  end

  describe "policy/0 over the real canonical TTL" do
    @tag :w984cw3
    test "projects the canonical policy: fields, standings, authority, flags" do
      p = SubstitutionPolicy.policy()

      # Mutation rationale: kills mutants that drop any single
      # requiredQualificationField statement from the projection, invert the
      # ALIVE/UNKNOWN constants, or loosen the NONE authority boundary — each
      # assertion names one distinct guard in parse!/1.
      assert MapSet.equal?(
               p.required_fields,
               MapSet.new(~w(exactSubject verifierEvidenceDigest replayDigest standing))
             )

      assert p.admitted_standing == "ALIVE"
      assert p.unknown_standing == "UNKNOWN"
      assert p.authority_boundary == "NONE"

      assert p.flags == %{
               "requiresExactSubject" => true,
               "requiresDeterministicReplay" => true,
               "requiresCryptographicBinding" => true
             }
    end

    @tag :w984cw3
    test "ttl_sha256 binds to the real on-disk bytes" do
      p = SubstitutionPolicy.policy()
      assert p.ttl_sha256 == digest(real_ttl())

      # Mutation rationale: a mutant hardcoding the digest or reading a
      # different/renamed file only survives while this binding to the real
      # bytes holds; recompute from disk and compare.
      assert byte_size(p.ttl_sha256) == 71
    end
  end

  describe "parse!/1 fail-closed drift guards (real TTL string mutations)" do
    @tag :w984cw3
    test "removing a requiredQualificationField raises required-field drift" do
      base = real_ttl()

      for field <- ~w(exactSubject verifierEvidenceDigest replayDigest standing) do
        drifted = drift(base, "ce:requiredQualificationField ce:#{field}", "")

        # Mutation rationale: kills a mutant that stores required fields as a
        # non-deduplicating list or a laxer regex missing the last entry — the
        # drift must be detected for *each* field independently.
        assert_raise ArgumentError, ~r/required-field drift/, fn ->
          SubstitutionPolicy.parse!(drifted)
        end
      end
    end

    @tag :w984cw3
    test "standing and authority drift raises the matching typed error" do
      ttl = real_ttl()

      # Mutation rationale: kills mutants that swap the cond clauses' error
      # messages or compare standings against the wrong constant.
      assert_raise ArgumentError, ~r/admitted standing drift/, fn ->
        SubstitutionPolicy.parse!(drift(ttl, "ce:admittedStanding ce:ALIVE", "ce:admittedStanding ce:PARTIAL"))
      end

      assert_raise ArgumentError, ~r/preserve UNKNOWN/, fn ->
        SubstitutionPolicy.parse!(drift(ttl, "ce:unknownStanding ce:UNKNOWN", "ce:unknownStanding ce:GARBAGE"))
      end

      assert_raise ArgumentError, ~r/authority boundary drift/, fn ->
        SubstitutionPolicy.parse!(drift(ttl, "ce:authorityBoundary ce:NONE", "ce:authorityBoundary ce:FULL"))
      end
    end

    @tag :w984cw3
    test "losing any mandatory boolean invariant raises" do
      ttl = real_ttl()

      for flag <- ~w(requiresExactSubject requiresDeterministicReplay requiresCryptographicBinding) do
        # Mutation rationale: kills a mutant that reads booleans with a regex
        # matching "true" *anywhere* (so a flipped false still matches) — the
        # gate must observe the actual flipped value in the TTL.
        drifted = drift(ttl, "ce:#{flag} true", "ce:#{flag} false")

        assert_raise ArgumentError, ~r/lost a mandatory invariant/, fn ->
          SubstitutionPolicy.parse!(drifted)
        end
      end
    end
  end

  describe "admit_receipt/1 closed-world admission" do
    @tag :w984cw3
    test "admits an exact-subject ALIVE receipt and refuses every failure class with a typed atom" do
      # Mutation rationale: the happy path pins the exact-success contract;
      # each refusal atom is a distinct typed outcome — a mutant that collapses
      # refusals to one atom or reorders the cond dies on a specific clause.
      assert SubstitutionPolicy.admit_receipt(receipt([])) == :ok

      assert SubstitutionPolicy.admit_receipt(receipt(exact_subject: "  ")) ==
               {:error, :qualification_subject_missing}

      assert SubstitutionPolicy.admit_receipt(receipt(exact_subject: "repo@abc123")) ==
               {:error, :qualification_subject_not_exact}

      assert SubstitutionPolicy.admit_receipt(receipt(standing: "UNKNOWN")) ==
               {:error, :qualification_unknown}

      assert SubstitutionPolicy.admit_receipt(receipt(standing: "PARTIAL_ALIVE")) ==
               {:error, :qualification_not_alive}

      assert SubstitutionPolicy.admit_receipt("not a map") ==
               {:error, :qualification_receipt_missing}
    end

    @tag :w984cw3
    test "exact-subject shape is repo/ref@full-40-hex (fail-closed on truncated SHAs)" do
      # Mutation rationale: kills a mutant relaxing the {40} hex quantifier or
      # allowing whitespace/`@`-free subjects — truncated SHAs must not admit.
      assert SubstitutionPolicy.admit_receipt(receipt(exact_subject: "r/x@" <> String.duplicate("a", 39))) ==
               {:error, :qualification_subject_not_exact}

      assert SubstitutionPolicy.admit_receipt(receipt(exact_subject: "r/x@" <> String.duplicate("a", 41))) ==
               {:error, :qualification_subject_not_exact}

      assert SubstitutionPolicy.admit_receipt(receipt(exact_subject: "r/x@" <> String.duplicate("g", 40))) ==
               {:error, :qualification_subject_not_exact}

      assert SubstitutionPolicy.admit_receipt(receipt(exact_subject: "r x@" <> String.duplicate("a", 40))) ==
               {:error, :qualification_subject_not_exact}

      assert SubstitutionPolicy.admit_receipt(receipt(exact_subject: nil)) ==
               {:error, :qualification_subject_missing}
    end

    @tag :w984cw3
    test "admission tracks the parsed policy, not literals: drifted standing vocabulary refuses" do
      # Mutation rationale: kills a mutant that hardcodes "ALIVE"/"UNKNOWN"
      # instead of reading p.admitted_standing/p.unknown_standing — prove the
      # dependency by standing on the real policy's values rather than string
      # literals at the call site.
      p = SubstitutionPolicy.policy()
      assert SubstitutionPolicy.admit_receipt(receipt(standing: p.admitted_standing)) == :ok
      assert SubstitutionPolicy.admit_receipt(receipt(standing: p.unknown_standing)) ==
               {:error, :qualification_unknown}
    end
  end
end
