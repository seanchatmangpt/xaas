defmodule ExNounVerbCli.CapabilityTest do
  use ExUnit.Case, async: true

  alias ExNounVerbCli.Capability
  alias ExNounVerbCli.Capability.{Package, ProofSurface}

  describe "derive_standing/1" do
    test "an empty proof-surface list is :unknown, matching CapabilityPackage::new" do
      package = Package.new("pkg-001", "Graph", "1.0.0", "Graph operations")

      assert Capability.derive_standing(package) == :unknown
      assert Capability.derive_standing([]) == :unknown
    end

    test "all proof surfaces observed, replayed, and receipted is :alive" do
      surfaces = [
        ProofSurface.new("unit-contract", "unit", "receipt:unit:001", true, true),
        ProofSurface.new("e2e-contract", "e2e", "receipt:e2e:001", true, true)
      ]

      assert Capability.derive_standing(surfaces) == :alive
    end

    test "one missing receipt id among otherwise-alive surfaces falls back to :partial_alive" do
      surfaces = [
        ProofSurface.new("unit-contract", "unit", "receipt:unit:001", true, true),
        ProofSurface.new("e2e-contract", "e2e", "", true, true)
      ]

      assert Capability.derive_standing(surfaces) == :partial_alive
    end

    test "one unobserved surface among otherwise-alive surfaces falls back to :partial_alive" do
      surfaces = [
        ProofSurface.new("unit-contract", "unit", "receipt:unit:001", true, true),
        ProofSurface.new("e2e-contract", "e2e", "receipt:e2e:001", false, true)
      ]

      assert Capability.derive_standing(surfaces) == :partial_alive
    end

    test "one unreplayed surface among otherwise-alive surfaces falls back to :partial_alive" do
      surfaces = [
        ProofSurface.new("unit-contract", "unit", "receipt:unit:001", true, true),
        ProofSurface.new("e2e-contract", "e2e", "receipt:e2e:001", true, false)
      ]

      assert Capability.derive_standing(surfaces) == :partial_alive
    end

    test "no proof surfaces alive at all is :blocked" do
      surfaces = [
        ProofSurface.new("unit-contract", "unit", "receipt:unit:001", true, false),
        ProofSurface.new("e2e-contract", "e2e", "", false, false)
      ]

      assert Capability.derive_standing(surfaces) == :blocked
    end
  end

  describe "ProofSurface.alive?/1" do
    test "requires observed, replay_verified, and a non-blank receipt" do
      assert ProofSurface.alive?(ProofSurface.new("n", "unit", "r", true, true))
      refute ProofSurface.alive?(ProofSurface.new("n", "unit", "r", true, false))
      refute ProofSurface.alive?(ProofSurface.new("n", "unit", "r", false, true))
      refute ProofSurface.alive?(ProofSurface.new("n", "unit", "  ", true, true))
    end
  end

  describe "record_proof/2" do
    test "adding one fully-alive proof surface moves an :unknown package to :alive" do
      package = Package.new("pkg-001", "Graph", "1.0.0", "Graph operations")

      assert {:ok, package} =
               Capability.record_proof(
                 package,
                 ProofSurface.new("unit", "unit", "receipt-1", true, true)
               )

      assert package.standing == :alive
      assert package.proof_surfaces == [ProofSurface.new("unit", "unit", "receipt-1", true, true)]
    end

    test "recording an unreplayed proof surface first yields :blocked, then :alive once replayed \
          — mirrors the Rust `package_requires_replay_before_alive` test" do
      package = Package.new("pkg-001", "Graph", "1.0.0", "Graph operations")

      assert {:ok, package} =
               Capability.record_proof(
                 package,
                 ProofSurface.new("unit", "unit", "receipt-1", true, false)
               )

      assert package.standing == :blocked

      assert {:ok, package} =
               Capability.record_proof(
                 package,
                 ProofSurface.new("unit", "unit", "receipt-1", true, true)
               )

      assert package.standing == :alive
    end

    test "re-recording the same name+rung replaces rather than duplicates" do
      package = Package.new("pkg-001", "Graph", "1.0.0", "Graph operations")

      {:ok, package} =
        Capability.record_proof(package, ProofSurface.new("unit", "unit", "r1", true, true))

      {:ok, package} =
        Capability.record_proof(package, ProofSurface.new("unit", "unit", "r2", true, true))

      assert length(package.proof_surfaces) == 1
      assert hd(package.proof_surfaces).receipt == "r2"
    end

    test "refuses a proof surface with a blank name" do
      package = Package.new("pkg-001", "Graph", "1.0.0", "Graph operations")

      assert {:error, _message} =
               Capability.record_proof(package, ProofSurface.new("", "unit", "r1", true, true))
    end

    test "refuses a proof surface with a blank rung" do
      package = Package.new("pkg-001", "Graph", "1.0.0", "Graph operations")

      assert {:error, _message} =
               Capability.record_proof(package, ProofSurface.new("unit", "", "r1", true, true))
    end
  end

  describe "with_default_verb/2" do
    test "a first argument that is not a %Package{} raises FunctionClauseError — the head \
          matches only the real struct, so a wrong-shape input is refused, not silently rebuilt" do
      assert_raise FunctionClauseError,
                   "no function clause matching in ExNounVerbCli.Capability.Package.with_default_verb/2",
                   fn ->
                     Package.with_default_verb(%{id: "pkg-001", name: "Graph"}, "verify")
                   end
    end

    test "binding an empty-string default verb violates the documented contract and is \
          refused by validate/1 with the ported Rust reason" do
      package =
        Package.new("pkg-001", "Graph", "1.0.0", "Graph operations")
        |> Package.with_default_verb("")

      assert package.default_verb == ""
      assert {:error, "Default verb cannot be empty"} = Package.validate(package)
    end
  end

  describe "the receipt-verify worked example (mirrors the Rust README's own example)" do
    test "a package with one fully-alive proof surface reaches :alive" do
      package =
        Package.new(
          "receipt-verify",
          "Receipt Verification",
          "26.7.62",
          "Verifies one admitted execution receipt"
        )
        |> Package.with_default_verb("verify")

      assert package.default_verb == "verify"

      {:ok, package} =
        Capability.record_proof(
          package,
          ProofSurface.new("unit-contract", "unit", "receipt:unit:001", true, true)
        )

      assert package.standing == :alive
    end
  end
end
