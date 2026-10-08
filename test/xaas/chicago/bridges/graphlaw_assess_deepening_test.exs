defmodule Xaas.Chicago.Bridges.GraphlawAssessDeepeningTest do
  @moduledoc """
  Lane W983b — graphlaw bridge deepening beyond the limit gates (W976/W981k own
  limits). Four courts on real seams the existing `graphlaw_test.exs` suite
  does not cover:

    1. refusal envelope integrity — every reachable refusal path returns the
       documented envelope (base `Xaas.Bridges.envelope/4` fields intact, plus
       `code`/`class`/`broken_term`/`refusal_name` verbatim from the engine
       limit row);
    2. idempotency — the same claim assessed twice yields byte-identical
       verdicts (`term_to_binary` equality, no ambient state leak);
    3. dead-engine isolation — `:host_not_started` (host layer verdict, no DB
       rows) vs. DB limit-row exceedance (catalog verdict) are DISTINCT typed
       outcomes on the same dead server, never conflated;
    4. registry-to-catalog consistency — every limit row
       `Registry.engine_limits/0` exposes has a Catalog counterpart with
       matching scope, and matches the raw graphlaw registry JSON (independent
       source) name-for-name and value-for-value — a drift tripwire.

  Chicago-style: real sandboxed Postgres rows, real bridge calls, real
  registry file. No mocks.
  """

  use ExUnit.Case, async: false

  require Ash.Query

  alias Xaas.Bridges
  alias Xaas.Bridges.Graphlaw
  alias Xaas.Bridges.Registry
  alias Xaas.Graphlaw.Catalog
  alias Xaas.Graphlaw.EngineLimit
  alias Xaas.Graphlaw.LimitGate

  @dead_server :l7_graphlaw_host_never_started
  @subject Bridges.subject()

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_limit(attrs) do
    EngineLimit
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!()
  end

  defp abi_depth_limit(value, refusal_name \\ "state_quads") do
    create_limit(%{
      name: "max_json_depth",
      value: value,
      scope: "abi",
      source: "src/abi.rs",
      unit: "count",
      refusal_name: refusal_name
    })
  end

  ## Court 1: refusal envelope integrity

  describe "refusal envelope integrity" do
    test "limit-gate refusal path returns the documented envelope, refusal_name verbatim" do
      abi_depth_limit(64)

      assert {:refused, refusal} =
               Graphlaw.assess(LimitGate.nest(64), server: @dead_server, subject: @subject)

      # base envelope fields intact
      assert refusal.subject == @subject
      assert refusal.claim == "graphlaw purchase policy"
      assert refusal.state == :refused
      assert refusal.authority_ceiling == :none
      assert refusal.standing == "UNKNOWN"

      # typed refusal payload, verbatim from the engine limit row
      assert refusal.code == :limit_exceeded
      assert refusal.class == :refused_admission
      assert refusal.broken_term == :mu_on_O
      assert refusal.refusal_name == "state_quads"
      assert refusal.limit == "max_json_depth"
      assert refusal.limit_value == 64
      assert is_binary(refusal.message) and refusal.message != ""
    end

    test "n3 byte-limit refusal path returns the same envelope shape" do
      # A tiny n3-scope term limit: every rendered facts line exceeds it, so
      # the refusal comes from the n3 arm of gate_engine_limits, not the abi
      # depth arm.
      create_limit(%{
        name: "n3_max_term_bytes",
        value: 10,
        scope: "n3",
        source: "src/n3.rs",
        unit: "count",
        refusal_name: "n3_term_too_large"
      })

      assert {:refused, refusal} =
               Graphlaw.assess(%{"amount" => 1500, "limit" => 500},
                 server: @dead_server,
                 subject: @subject
               )

      assert refusal.code == :limit_exceeded
      assert refusal.class == :refused_admission
      assert refusal.broken_term == :mu_on_O
      assert refusal.refusal_name == "n3_term_too_large"
      assert refusal.limit == "n3_max_term_bytes"
      assert refusal.limit_value == 10
      assert refusal.subject == @subject
      assert refusal.state == :refused
      assert refusal.authority_ceiling == :none
    end

    test "engine refusal passthrough path keeps the base envelope and the host's own fields" do
      # No limit rows: the gate admits (fail-open), the engine dispatch runs,
      # the dead host returns its own typed refusal — the third reachable
      # refusal shape at this seam.
      assert {:refused, refusal} =
               Graphlaw.assess(%{"amount" => 1500, "limit" => 500},
                 server: @dead_server,
                 subject: @subject
               )

      assert refusal.subject == @subject
      assert refusal.claim == "graphlaw purchase policy"
      assert refusal.state == :refused
      assert refusal.authority_ceiling == :none
      assert refusal.standing == "UNKNOWN"

      assert refusal.code == :host_not_started
      assert refusal.class == :blocked_resource
      assert refusal.broken_term == :R_missing_consequence

      # The limit-gate-only keys are absent on this path — the envelope does
      # not invent limit fields it did not enforce.
      refute Map.has_key?(refusal, :limit)
      refute Map.has_key?(refusal, :refusal_name)
    end
  end

  ## Court 2: idempotency

  describe "idempotency (no ambient state leak)" do
    test "the same claim assessed twice yields byte-identical verdicts (limit refusal path)" do
      abi_depth_limit(64)
      claim = LimitGate.nest(64)

      {:refused, first} = Graphlaw.assess(claim, server: @dead_server, subject: @subject)
      {:refused, second} = Graphlaw.assess(claim, server: @dead_server, subject: @subject)

      assert first == second
      assert :erlang.term_to_binary(first) == :erlang.term_to_binary(second)
    end

    test "the same claim assessed twice yields byte-identical verdicts (dead-host passthrough)" do
      claim = %{"amount" => 1500, "limit" => 500}

      {:refused, first} = Graphlaw.assess(claim, server: @dead_server, subject: @subject)
      {:refused, second} = Graphlaw.assess(claim, server: @dead_server, subject: @subject)

      assert {:refused, first} == {:refused, second}
      assert :erlang.term_to_binary(first) == :erlang.term_to_binary(second)
      assert first.code == :host_not_started
    end

    test "fact rendering is pure: same claim, same facts bytes" do
      claim = %{"amount" => 1500, "limit" => 500, "approved" => false}

      a = Graphlaw.purchase_facts(claim, @subject)
      b = Graphlaw.purchase_facts(claim, @subject)

      assert a == b
      assert byte_size(a) == byte_size(b)
      assert :erlang.term_to_binary(a) == :erlang.term_to_binary(b)
    end
  end

  ## Court 3: dead-engine isolation — distinct typed outcomes, never conflated

  describe "dead-engine isolation" do
    test "DB limit-row exceedance and host-not-started are DISTINCT verdicts on the same dead server" do
      claim = LimitGate.nest(64)

      # Path A — catalog verdict: a real recorded exceedance refuses at the
      # gate, the engine is never reached.
      abi_depth_limit(64)

      assert {:refused, limit_refusal} =
               Graphlaw.assess(claim, server: @dead_server, subject: @subject)

      assert limit_refusal.code == :limit_exceeded
      assert limit_refusal.class == :refused_admission
      assert limit_refusal.broken_term == :mu_on_O

      # Path B — host verdict: with the row gone, the same claim on the same
      # dead server falls through to the engine dispatch and the host layer's
      # own refusal.
      Ash.destroy!(abi_depth_limit_row())

      assert {:refused, host_refusal} =
               Graphlaw.assess(claim, server: @dead_server, subject: @subject)

      assert host_refusal.code == :host_not_started
      assert host_refusal.class == :blocked_resource
      assert host_refusal.broken_term == :R_missing_consequence

      # Explicit non-conflation: code, class, and broken_term all differ.
      assert limit_refusal.code != host_refusal.code
      assert limit_refusal.class != host_refusal.class
      assert limit_refusal.broken_term != host_refusal.broken_term
    end

    test "row absence never surfaces as a database error at the bridge seam" do
      # The DB-independence contract: with zero abi rows the gate admits
      # (fail-open) and the refusal is the host layer's — never an Ecto/Ash
      # error tuple or raise leaking out of assess/2.
      assert [] = Registry.engine_limits()

      result =
        Graphlaw.assess(%{"amount" => 10, "limit" => 5}, server: @dead_server, subject: @subject)

      assert {:refused, refusal} = result
      assert refusal.code == :host_not_started
    end
  end

  ## Court 4: registry-to-catalog drift tripwire

  describe "registry-to-catalog consistency" do
    test "every registry limit has a catalog counterpart with matching scope, matching the raw registry JSON" do
      path = Catalog.default_registry_path()
      assert File.exists?(path), "graphlaw capability registry not found at #{path}"

      {:ok, _counts} = Catalog.ingest(path)

      raw = path |> File.read!() |> Jason.decode!()
      raw_limits = raw["limits"] || %{}
      raw_meta = raw["limit_meta"] || %{}

      registry_limits = Registry.engine_limits()
      assert is_list(registry_limits) and registry_limits != []

      catalog_abi = Catalog.limits_by_scope(LimitGate.scope())
      catalog_names = Map.new(catalog_abi, &{&1.name, &1})

      for limit <- registry_limits do
        # Catalog counterpart, same scope.
        assert %EngineLimit{} = Map.get(catalog_names, limit.name)
        assert limit.scope == LimitGate.scope()

        # Independent source: the raw registry JSON carries the same name and
        # value, and its meta scope agrees.
        assert Map.has_key?(raw_limits, limit.name)
        assert raw_limits[limit.name] == limit.value

        meta = raw_meta[limit.name] || %{}
        assert meta["scope"] == limit.scope
        assert Map.get(meta, "refusal_name") == limit.refusal_name
      end
    end

    test "registry limit surface is well-formed: unique names, non-negative integer values" do
      {:ok, _} = Catalog.ingest(Catalog.default_registry_path())

      limits = Registry.engine_limits()
      names = Enum.map(limits, & &1.name)

      assert names == Enum.uniq(names)

      for limit <- limits do
        assert is_integer(limit.value) and limit.value >= 0
        assert is_binary(limit.name)
        assert limit.scope == "abi"
      end
    end
  end

  defp abi_depth_limit_row do
    Xaas.Graphlaw.EngineLimit
    |> Ash.Query.filter(name == "max_json_depth" and scope == "abi")
    |> Ash.read!()
    |> List.first()
  end
end
