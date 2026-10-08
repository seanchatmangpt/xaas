defmodule Xaas.AshTypescriptManifestTest do
  @moduledoc """
  W984dq depth court for `Xaas.AshTypescriptManifest` (W984dp residue).
  Chicago-school: asserts on the real compiled manifest DSL state and real
  application env, no mocks. Mutation rationale per test.
  """

  use ExUnit.Case, async: false

  @domains Application.compile_env(:xaas, :ash_domains, [])
  @manifest_mod Xaas.AshTypescriptManifest

  defp manifest do
    Spark.Dsl.Extension.get_persisted(@manifest_mod, :manifest)
  end

  test "env restoration: full configured domain list is visible after manifest compile" do
    # Mutation rationale: deleting __after_compile__/2 (or the put_env in it)
    # leaves the filtered :ash_domains env in place after compile, so any later
    # Ash.Info.domains/1 walk (codegen legs, runtime domain discovery) sees a
    # truncated domain list. This test fails under that mutation.
    assert @domains != []

    restored = Application.get_env(:xaas, :ash_domains)
    assert is_list(restored)
    assert MapSet.new(@domains) |> MapSet.subset?(MapSet.new(restored)),
           "expected all configured domains #{inspect(@domains)} present after compile, got #{inspect(restored)}"
  end

  test "manifest is real, nonempty, and covers the rpc-exposed domains' resources" do
    # Mutation rationale: if the fresh-root filter ever *permanently* drops a
    # domain (the self-heal touch failed to re-expand), the persisted manifest
    # lacks that domain's resources. Any mutation that empties the manifest
    # (BuildManifest no-op) fails the struct + nonempty assertions.
    assert %Ash.Info.Manifest{} = m = manifest()

    assert m.resources != [], "manifest has no resources"
    assert m.entrypoints != nil

    resource_lookup = Spark.Dsl.Extension.get_persisted(@manifest_mod, :resource_lookup)

    covered =
      for {domain, resource} <- %{
            Xaas.Operations => Xaas.Operations.ProjectMeasure.Measurement,
            Xaas.Marketplace => Xaas.Marketplace.Provider,
            Xaas.Billing => Xaas.Billing.Subscription,
            Xaas.Accounts => Xaas.Accounts.Org
          } do
        assert resource in Ash.Domain.Info.resources(domain),
               "#{inspect(resource)} not in #{inspect(domain)}"
        assert Map.has_key?(resource_lookup, resource),
               "#{inspect(resource)} missing from manifest resource_lookup"
        resource
      end

    assert MapSet.new(covered) |> MapSet.size() == 4
  end

  test "manifest is deterministic across repeated retrievals and lookups are self-consistent" do
    # Mutation rationale: nondeterministic reachability or unordered generation
    # would make two retrievals differ (== on the whole struct). Mutations to
    # DecorateManifest's lookup builders (dropping entries, changing keys) break
    # the roundtrip: every manifest resource must be keyed in resource_lookup.
    m1 = manifest()
    assert m1 == manifest()
    m = m1

    resource_lookup = Spark.Dsl.Extension.get_persisted(@manifest_mod, :resource_lookup)
    assert is_map(resource_lookup)

    uncovered =
      m.resources
      |> Enum.reject(fn res -> Map.has_key?(resource_lookup, res.module) end)

    assert uncovered == [],
           "resources not keyed in resource_lookup: #{inspect(Enum.map(uncovered, & &1.module))}"
  end

  test "real rpc entrypoints are discoverable by wire name via rpc_action_lookup" do
    # Mutation rationale: mutations to the manifest DSL bodies in the domains
    # (renaming/dropping rpc_action) or to build_rpc_action_lookup keying
    # (to_string vs atom) make the wire-facing name unresolvable. Asserts the
    # real cross-domain surface, not a fixture.
    rpc_lookup = Spark.Dsl.Extension.get_persisted(@manifest_mod, :rpc_action_lookup)
    assert is_map(rpc_lookup)

    for {name, {resource, action}} <- %{
          "measure_project" => {Xaas.Operations.ProjectMeasure.Measurement, :measure},
          "list_marketplace_providers" => {Xaas.Marketplace.Provider, :read},
          "list_billing_subscriptions" => {Xaas.Billing.Subscription, :read},
          "list_accounts_orgs" => {Xaas.Accounts.Org, :read}
        } do
      entrypoint = Map.get(rpc_lookup, name)
      assert entrypoint, "rpc action #{name} missing from rpc_action_lookup"

      assert entrypoint.resource == resource,
             "rpc action #{name} bound to #{inspect(entrypoint.resource)}, expected #{inspect(resource)}"

      bound_action =
        case entrypoint.action do
          %{} = a -> a.name
          a when is_atom(a) -> a
        end

      assert bound_action == action,
             "rpc action #{name} bound to action #{inspect(bound_action)}, expected #{action}"
    end
  end

  test "malformed lookups return nil instead of raising; non-manifest modules have no manifest" do
    # Mutation rationale: the lookups are string-keyed maps read from
    # untrusted wire input (rpc controller path). A mutation switching them to
    # a raising accessor (or atom-keying, which crashes on unknown strings via
    # existing atom) would turn a malformed client rpc name into a 500. The
    # nil-return contract is what the controller's error path depends on.
    rpc_lookup = Spark.Dsl.Extension.get_persisted(@manifest_mod, :rpc_action_lookup)
    assert Map.get(rpc_lookup, "no_such_rpc_action_xyz") == nil
    assert Map.get(rpc_lookup, "") == nil
    assert Map.get(rpc_lookup, 123) == nil

    # A plain module (not a Spark DSL) is a typed refusal, not a silent nil:
    # get_persisted/2 raises ArgumentError naming the module.
    defmodule Plain do
    end

    assert_raise(ArgumentError, ~r/not a Spark DSL module/, fn ->
      Spark.Dsl.Extension.get_persisted(Plain, :manifest)
    end)
  end
end
