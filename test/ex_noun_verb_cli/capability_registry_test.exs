defmodule ExNounVerbCli.CapabilityRegistryTest do
  use ExUnit.Case, async: true

  alias ExNounVerbCli.Capability.{Package, ProofSurface}
  alias ExNounVerbCli.CapabilityRegistry

  describe "add_package/2" do
    test "refuses duplicate ids, mirroring the real Rust registry_refuses_duplicate_ids test" do
      registry = CapabilityRegistry.new()
      package = Package.new("pkg-001", "TestPkg", "1.0.0", "Test")

      assert {:ok, registry} = CapabilityRegistry.add_package(registry, package)
      assert {:error, message} = CapabilityRegistry.add_package(registry, package)
      assert message =~ "Package already exists: pkg-001"
    end

    test "refuses an invalid package before checking for duplicates" do
      registry = CapabilityRegistry.new()
      package = %{Package.new("pkg-001", "TestPkg", "1.0.0", "Test") | id: ""}

      assert {:error, message} = CapabilityRegistry.add_package(registry, package)
      assert message =~ "Package ID cannot be empty"
    end
  end

  describe "update_package/2" do
    test "refuses a package not already present" do
      registry = CapabilityRegistry.new()
      package = Package.new("pkg-001", "TestPkg", "1.0.0", "Test")

      assert {:error, message} = CapabilityRegistry.update_package(registry, package)
      assert message =~ "Package not found: pkg-001"
    end

    test "replaces an existing package" do
      registry = CapabilityRegistry.new()
      package = Package.new("pkg-001", "TestPkg", "1.0.0", "Test")
      {:ok, registry} = CapabilityRegistry.add_package(registry, package)

      {:ok, package} =
        ExNounVerbCli.Capability.record_proof(
          package,
          ProofSurface.new("unit", "unit", "r1", true, true)
        )

      assert {:ok, registry} = CapabilityRegistry.update_package(registry, package)
      assert CapabilityRegistry.get(registry, "pkg-001").standing == :alive
    end
  end

  describe "remove_package/2, get/2, contains?/2, count/1, empty?/1" do
    test "real state transitions" do
      registry = CapabilityRegistry.new()
      assert CapabilityRegistry.empty?(registry)

      {:ok, registry} =
        CapabilityRegistry.add_package(registry, Package.new("pkg-001", "P", "1", "d"))

      refute CapabilityRegistry.empty?(registry)
      assert CapabilityRegistry.count(registry) == 1
      assert CapabilityRegistry.contains?(registry, "pkg-001")
      assert %Package{id: "pkg-001"} = CapabilityRegistry.get(registry, "pkg-001")

      assert {:ok, registry} = CapabilityRegistry.remove_package(registry, "pkg-001")
      assert CapabilityRegistry.empty?(registry)
      assert {:error, _} = CapabilityRegistry.remove_package(registry, "pkg-001")
    end
  end

  describe "remove_package/2 negative paths" do
    test "refuses an id that was never registered, naming it in the error" do
      registry = CapabilityRegistry.new()

      {:ok, registry} =
        CapabilityRegistry.add_package(registry, Package.new("pkg-001", "P", "1", "d"))

      assert {:error, message} = CapabilityRegistry.remove_package(registry, "ghost-pkg")
      assert message =~ "Package not found: ghost-pkg"
      # The refusal must not partially mutate the registry.
      assert CapabilityRegistry.count(registry) == 1
      assert CapabilityRegistry.contains?(registry, "pkg-001")
    end

    test "raises FunctionClauseError when the registry argument has the wrong shape" do
      assert_raise FunctionClauseError, fn ->
        CapabilityRegistry.remove_package(%{packages: %{}}, "pkg-001")
      end
    end
  end

  describe "dependency_order/1 -- ported dependency-closure resolution logic" do
    test "is closed and stable, mirroring the real Rust dependency_order_is_closed_and_stable test" do
      registry = CapabilityRegistry.new()

      {:ok, registry} =
        CapabilityRegistry.add_package(registry, Package.new("core", "Core", "1", "Core"))

      cli = Package.new("cli", "CLI", "1", "CLI") |> Package.with_dependency("core")
      {:ok, registry} = CapabilityRegistry.add_package(registry, cli)

      assert CapabilityRegistry.dependency_order(registry) == {:ok, ["core", "cli"]}
    end

    test "refuses a missing dependency id" do
      registry = CapabilityRegistry.new()
      cli = Package.new("cli", "CLI", "1", "CLI") |> Package.with_dependency("missing-core")
      {:ok, registry} = CapabilityRegistry.add_package(registry, cli)

      assert {:error, message} = CapabilityRegistry.dependency_order(registry)
      assert message =~ "Capability dependency not found: missing-core"
    end

    test "refuses a real dependency cycle" do
      registry = CapabilityRegistry.new()

      a = Package.new("a", "A", "1", "d") |> Package.with_dependency("b")
      b = Package.new("b", "B", "1", "d") |> Package.with_dependency("a")

      # Bypass add_package's validate (dependency ids don't need to exist yet
      # to insert), inserting both halves of the cycle directly so the cycle
      # is real once dependency_order walks it.
      registry = %{registry | packages: %{"a" => a, "b" => b}}

      assert {:error, message} = CapabilityRegistry.dependency_order(registry)
      assert message =~ "Capability dependency cycle detected at:"
    end
  end

  describe "Package.with_dependency/2" do
    test "adds a dependency once and keeps the list sorted" do
      package =
        Package.new("cli", "CLI", "1", "CLI")
        |> Package.with_dependency("zeta")
        |> Package.with_dependency("alpha")
        |> Package.with_dependency("alpha")

      assert package.dependencies == ["alpha", "zeta"]
    end
  end

  describe "Package.validate/1" do
    test "refuses a blank default_verb" do
      package = %{Package.new("pkg", "P", "1", "d") | default_verb: ""}
      assert {:error, message} = Package.validate(package)
      assert message =~ "Default verb cannot be empty"
    end

    test "refuses :alive standing with no proof surfaces" do
      package = %{Package.new("pkg", "P", "1", "d") | standing: :alive}
      assert {:error, message} = Package.validate(package)
      assert message =~ "ALIVE standing requires observed and replayed proof surfaces"
    end

    test "accepts a genuinely alive package" do
      {:ok, package} =
        ExNounVerbCli.Capability.record_proof(
          Package.new("pkg", "P", "1", "d"),
          ProofSurface.new("unit", "unit", "r1", true, true)
        )

      assert Package.validate(package) == :ok
    end
  end
end
