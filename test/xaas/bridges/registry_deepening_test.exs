defmodule Xaas.Bridges.RegistryDeepeningTest do
  @moduledoc """
  W767 deepening courts for `Xaas.Bridges.Registry` itself.

  W716 covered the ferroplan bridge engine; this court owns the REGISTRY as
  doctrine surface (connector object ≠ mounted tree). Chicago-style: the real
  compiled registry, real envelope math, no mocks.

  Cover:

  - (a) The declared row set is EXACT: five bridge rows
    (pplan/graphlaw/ex4pm/sa2a/ferroplan) + five typed absences
    (beam4pm/graphlaw_rust/affidavit_cli/ash_r2rml/wasm4pm) — no extra, no
    missing. NOTE: the backlog phrasing ("ferroplan/gymact/ash_a2a rows") does
    not match the live registry; the code is the live ontology and this court
    pins the real contents.
  - (b) State/standing vocabulary validity per the real envelope contract:
    bridges are `:bridge`/`"UNKNOWN"`, absences `:unsupported`/`"UNSUPPORTED"`,
    every row `authority_ceiling: :none`, no synthesized evidence/receipt refs,
    claims name real modules or real absence reasons.
  - (c) Registration refusal: the registry exposes NO mutation API — the full
    public surface is `all/0`, `ids/0`, `absences/0`. Registering an unknown
    bridge kind is structurally impossible (compile-time literal map; no
    register function exists). Typed as a structural guarantee, not a runtime
    refusal: the falsifier is a public mutating function appearing in the
    module's exported surface.
  - (d) Standing-never-silently-upgrades: repeated evaluation returns identical
    standing every time; no registry path accepts a receipt argument or
    mutates the compiled entries, so standing can only change by recompiling
    the module — the "standing becomes non-UNKNOWN only from real receipts
    bound to observed execution (R8)" property is structural here.
  - (e) Determinism: `all/0` is a pure projection — same subject, byte-identical
    envelope fields (modulo map ordering), stable id list across calls.

  No `@moduletag :eu_ai_act`: registry vocabulary surface, no Art-line tie.
  """

  use ExUnit.Case, async: false

  alias Xaas.Bridges.Registry

  @bridge_ids ~w(pplan graphlaw ex4pm sa2a ferroplan)a
  @absence_ids ~w(beam4pm graphlaw_rust affidavit_cli ash_r2rml wasm4pm)a
  @all_ids @bridge_ids ++ @absence_ids

  # -----------------------------------------------------------------
  # (a) exact row set
  # -----------------------------------------------------------------

  describe "declared row set is exact" do
    test "the id set is exactly the ten declared layers, no extra, no missing" do
      ids = Registry.ids()
      assert Enum.sort(ids) == Enum.sort(@all_ids)
      assert length(ids) == 10
      assert MapSet.new(ids) == MapSet.new(@all_ids)
    end

    test "bridge rows are exactly the five real bridges" do
      bridges = Enum.filter(Registry.all(), &match?({:bridge, _}, &1.capability))
      assert Enum.sort(Enum.map(bridges, & &1.id)) == Enum.sort(@bridge_ids)
    end

    test "absence rows are exactly the five typed absences, backed by absences/0" do
      unsupported = Enum.filter(Registry.all(), &match?({:unsupported, _}, &1.capability))
      assert Enum.sort(Enum.map(unsupported, & &1.id)) == Enum.sort(@absence_ids)
      # absences/0 exposes the same five keys with non-empty reasons.
      absences = Registry.absences()
      assert MapSet.new(Map.keys(absences)) == MapSet.new(@absence_ids)
      assert absences |> Map.values() |> Enum.all?(&(is_binary(&1) and &1 != ""))
    end

    test "every capability tuple matches its row id (bridge module exists, absence reason matches)" do
      for row <- Registry.all() do
        case row.capability do
          {:bridge, module} ->
            assert Code.ensure_loaded?(module),
                   "bridge #{row.id} names unloaded module #{inspect(module)}"

          {:unsupported, reason} ->
            assert Registry.absences()[row.id] == reason
        end
      end
    end
  end

  # -----------------------------------------------------------------
  # (b) state/standing vocabulary per the real envelope contract
  # -----------------------------------------------------------------

  describe "state and standing vocabulary" do
    test "bridge rows: state :bridge, standing exactly \"UNKNOWN\"" do
      for row <- Registry.all(),
          match?({:bridge, _}, row.capability) do
        assert row.state == :bridge
        assert row.standing == "UNKNOWN"
      end
    end

    test "absence rows: state :unsupported, standing exactly \"UNSUPPORTED\"" do
      for row <- Registry.all(),
          match?({:unsupported, _}, row.capability) do
        assert row.state == :unsupported
        assert row.standing == "UNSUPPORTED"
      end
    end

    test "standing vocabulary is limited to the rendered R2/R8 strings" do
      allowed = MapSet.new(["UNKNOWN", "UNSUPPORTED"])
      for row <- Registry.all(), do: assert(MapSet.member?(allowed, row.standing))
    end

    test "every row carries the exact Chicago subject, ceiling :none, no synthesized evidence" do
      subject = Xaas.Bridges.subject()

      for row <- Registry.all() do
        assert row.subject == subject
        assert row.authority_ceiling == :none
        assert row.evidence_ref == nil
        assert row.receipt_ref == nil
        assert row.provenance == %{}
        assert is_binary(row.claim) and row.claim != ""
      end
    end
  end

  # -----------------------------------------------------------------
  # (c) registering an unknown bridge kind
  # -----------------------------------------------------------------

  describe "registration surface" do
    test "typed structural gap: the registry exposes no mutation API" do
      exports = Registry.module_info(:exports) |> Enum.map(&elem(&1, 0)) |> MapSet.new()
      # The full public surface is exactly these (plus the implicit module_info
      # pair). Any register/put/update function appearing here would be the
      # falsifier for the "registry is a compile-time literal" claim.
      assert MapSet.subset?(MapSet.new([:all, :ids, :absences]), exports)

      mutating = Enum.filter(exports, fn name ->
        name |> Atom.to_string() |> String.starts_with?(["register", "put", "add", "update", "upsert"])
      end)

      assert mutating == [],
             "unexpected mutating exports on Xaas.Bridges.Registry: #{inspect(mutating)}"
    end

    test "absences map is not extendable through any public path" do
      # absences/0 returns the compiled @absences literal itself; assert there
      # is no setter and the value is stable across calls (not a resettable
      # agent/ets-backed store).
      assert Registry.absences() == Registry.absences()
      assert function_exported?(Registry, :absences, 0)
      refute function_exported?(Registry, :absences, 1)
      refute function_exported?(Registry, :register, 2)
      refute function_exported?(Registry, :register, 3)
    end
  end

  # -----------------------------------------------------------------
  # (d) standing-UNKNOWN-never-silent-upgrade
  # -----------------------------------------------------------------

  describe "standing never silently upgrades" do
    test "repeated evaluation returns identical standing with no receipt source" do
      first = Registry.all()

      for _ <- 1..3 do
        now = Registry.all()
        assert Enum.sort_by(now, & &1.id) == Enum.sort_by(first, & &1.id)
      end

      for row <- first do
        assert row.standing in ["UNKNOWN", "UNSUPPORTED"]
        assert row.receipt_ref == nil, "row #{row.id} grew a receipt without a court"
        assert row.evidence_ref == nil
      end
    end

    test "no registry function arity accepts a receipt/standing argument" do
      # The only entrypoints are 0-arity projections: standing cannot be
      # injected through any registry path — it can change only by recompiling
      # the literal entries, i.e. an admitted code transition, never a runtime
      # silent upgrade. This IS the R8 property, structurally.
      for {name, arity} <- Registry.module_info(:exports),
          name not in [:module_info, :__info__] do
        assert arity == 0, "unexpected non-projection export #{name}/#{arity}"
      end
    end
  end

  # -----------------------------------------------------------------
  # (e) determinism
  # -----------------------------------------------------------------

  describe "determinism" do
    test "all/0 is a pure projection of the compiled entries" do
      a = Registry.all() |> Enum.sort_by(& &1.id)
      b = Registry.all() |> Enum.sort_by(& &1.id)
      assert a == b

      for row <- a do
        # envelope fields byte-stable; only :id/:capability are registry-added
        base = Xaas.Bridges.envelope(row.subject, row.claim, row.state, row.standing)

        assert %{subject: row.subject, claim: row.claim, state: row.state,
                 standing: row.standing, provenance: %{}, evidence_ref: nil,
                 receipt_ref: nil, authority_ceiling: :none} == base
      end
    end

    test "the id list is stable across evaluation order" do
      x = Registry.ids()
      _ = Registry.absences()
      y = Registry.ids()
      assert x == y
    end
  end
end
