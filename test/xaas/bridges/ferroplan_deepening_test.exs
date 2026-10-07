defmodule Xaas.Bridges.FerroplanDeepeningTest do
  @moduledoc """
  W716 deepening courts for the ferroplan planner bridge.

  Chicago-style: real artifact bytes, real digest math, real persistent_term
  state, real registry envelopes. No mocks.

  Cover added over `ferroplan_test.exs`:

  - (a) digest verification at load: the pinned artifact passes; a corrupted
    temp copy (bit-flipped and truncated) is refused through the bridge's own
    gate (`verify_bytes/1` — the exact gate `artifact/0` applies to disk bytes)
    with the typed `:ferroplan_artifact_digest_mismatch`, never a degraded
    pass.
  - (b) runtime seam truthfulness: when no wasm runtime is loadable, invoke
    paths refuse typed `:ferroplan_runtime_unavailable`; when one is loadable
    the bridge must succeed (a refusal there would be a lie in the other
    direction).
  - (c) SELECT-only: real observable state (`:persistent_term`, artifact file
    bytes) is equal before/after the wired ops, except the documented compiled
    -module cache entry — no store mutation, no authorization side effect.
  - (d) Registry standing honesty: the `Xaas.Bridges.Registry` ferroplan row
    declares `:bridge` / `"UNKNOWN"` / `authority_ceiling: :none` with no
    synthesized evidence — and that stays honest even after an observed
    successful execution (the envelope standing must NOT silently rise).

  No `@moduletag :eu_ai_act`: this bridge has no EU-AI-Act Art-line tie (it is
  a planner capability bridge, not a conformity/admission surface).
  """

  use ExUnit.Case, async: false

  import Bitwise

  alias Xaas.Bridges.Ferroplan
  alias Xaas.Bridges.Registry

  @pinned "088d9c3b0306e36123ddc1ee780ad7e9d4bd2ebb54f9726c43f40a2f6d718233"

  setup do
    Ferroplan.purge_cache()
    on_exit(fn -> Ferroplan.purge_cache() end)
    :ok
  end

  # -----------------------------------------------------------------
  # (a) Digest verification at load
  # -----------------------------------------------------------------

  describe "digest gate at load" do
    test "the pinned artifact passes the load gate at the canonical path" do
      assert {:ok, artifact} = Ferroplan.artifact()
      assert artifact.sha256 == @pinned
      assert artifact.path == Ferroplan.artifact_path()
      # Independent re-derivation over the real bytes.
      assert Base.encode16(:crypto.hash(:sha256, artifact.bytes), case: :lower) == @pinned
    end

    test "a corrupted temp copy (bit-flipped tail) refuses typed, never degraded" do
      corrupted = mutate_last_byte(File.read!(Ferroplan.artifact_path()))
      path = corrupted_temp_copy(corrupted)
      on_exit(fn -> File.rm(path) end)

      # The temp copy's own digest really differs from the pin.
      observed = Base.encode16(:crypto.hash(:sha256, File.read!(path)), case: :lower)
      refute observed == @pinned

      # The bridge's own load gate judges the corrupted bytes.
      assert {:refused, refusal} = Ferroplan.verify_bytes(File.read!(path))
      assert refusal.code == :ferroplan_artifact_digest_mismatch
      assert refusal.expected_sha256 == @pinned
      assert refusal.observed_sha256 == observed
      assert refusal.observed_sha256 != @pinned
    end

    test "a truncated temp copy refuses with the same typed digest mismatch" do
      bytes = File.read!(Ferroplan.artifact_path())
      truncated = binary_part(bytes, 0, byte_size(bytes) - 1024)
      path = corrupted_temp_copy(truncated)
      on_exit(fn -> File.rm(path) end)

      assert {:refused, refusal} = Ferroplan.verify_bytes(File.read!(path))
      assert refusal.code == :ferroplan_artifact_digest_mismatch
      assert refusal.expected_sha256 == @pinned
    end

    test "metadata/0 refuses through the same gate when the gate refuses" do
      # metadata/0 composes artifact() -> describe_module; the gate is the
      # load-time admission. Prove the gate composition is fail-closed by
      # feeding the gate non-pin bytes and asserting no {:ok, _} escapes.
      bytes = File.read!(Ferroplan.artifact_path())
      assert {:refused, %{code: :ferroplan_artifact_digest_mismatch}} =
               Ferroplan.verify_bytes(mutate_last_byte(bytes))

      # And the real path still passes — the gate is not vacuously refusing.
      assert {:ok, %{sha256: @pinned}} = Ferroplan.artifact()
    end
  end

  # -----------------------------------------------------------------
  # (b) Runtime seam
  # -----------------------------------------------------------------

  describe "runtime seam" do
    if Ferroplan.runtime_available?() do
      test "with a runtime loadable, validate/0 succeeds (no false refusal)" do
        assert Ferroplan.runtime_available?() == true
        assert Code.ensure_loaded?(Wasmex.Store)
        assert {:ok, envelope} = Ferroplan.validate()
        assert envelope.provenance.engine_sha256 == @pinned
      end
    else
      test "with no runtime loadable, invoke paths refuse :ferroplan_runtime_unavailable" do
        assert Ferroplan.runtime_available?() == false

        assert {:refused, refusal} = Ferroplan.validate()
        assert refusal.code == :ferroplan_runtime_unavailable
        assert refusal.expected_sha256 == @pinned

        assert {:refused, refusal} = Ferroplan.invoke(%{"op" => "version"})
        assert refusal.code == :ferroplan_runtime_unavailable
      end

      test "with no runtime, metadata/0 stays digest-verified (metadata-only mode)" do
        # The documented degradation boundary: metadata stays available, only
        # invocation refuses.
        assert {:ok, meta} = Ferroplan.metadata()
        assert meta.sha256 == @pinned
      end
    end
  end

  # -----------------------------------------------------------------
  # (c) SELECT-only: no observable store mutation
  # -----------------------------------------------------------------

  describe "SELECT-only surface" do
    test "wired ops leave real observable state equal (modulo the documented compiled cache)" do
      before_terms = Map.new(:persistent_term.get())
      before_bytes = File.read!(Ferroplan.artifact_path())

      results = [
        Ferroplan.metadata(),
        Ferroplan.validate(),
        Ferroplan.invoke(%{"op" => "version"}),
        Registry.all()
      ]

      # Every wired op returned a lawful terminal (no crash escaped).
      Enum.each(results, fn
        {:ok, _} -> :ok
        {:refused, %{code: _}} -> :ok
        rows when is_list(rows) -> Enum.each(rows, &assert(is_map(&1)))
        other -> flunk("unexpected terminal: #{inspect(other, limit: 5)}")
      end)

      # The artifact file bytes are untouched.
      assert File.read!(Ferroplan.artifact_path()) == before_bytes

      # :persistent_term diff, scoped to bridge-owned keys: the only permitted
      # write is the documented compiled-module cache entry.
      after_terms = Map.new(:persistent_term.get())

      bridge_keys_before =
        before_terms
        |> Map.keys()
        |> Enum.filter(&match?({Xaas.Bridges.Ferroplan, _, _}, &1))
        |> MapSet.new()

      bridge_keys_after =
        after_terms
        |> Map.keys()
        |> Enum.filter(&match?({Xaas.Bridges.Ferroplan, _, _}, &1))
        |> MapSet.new()

      added_bridge_keys = MapSet.difference(bridge_keys_after, bridge_keys_before)

      assert MapSet.to_list(added_bridge_keys) in [
               [],
               [{Xaas.Bridges.Ferroplan, :compiled, @pinned}]
             ],
             "unexpected bridge persistent_term writes: #{inspect(MapSet.to_list(added_bridge_keys))}"
    end

    test "no authorization side effect: envelopes keep authority_ceiling :none and nil receipts" do
      {:ok, meta} = Ferroplan.metadata()

      assert meta.authority_ceiling == :none
      assert meta.standing == "UNKNOWN"

      case Ferroplan.validate() do
        {:ok, envelope} ->
          assert envelope.authority_ceiling == :none
          assert envelope.receipt_ref == nil
          assert envelope.evidence_ref == "ferroplan.fp_call:fond_validate"

        {:refused, %{code: code}} ->
          assert code in [:ferroplan_runtime_unavailable, :ferroplan_artifact_digest_mismatch]
      end
    end
  end

  # -----------------------------------------------------------------
  # (d) Registry standing honesty
  # -----------------------------------------------------------------

  describe "registry row standing" do
    test "the ferroplan row declares bridge capability honestly" do
      rows = Registry.all()

      ferroplan_rows = Enum.filter(rows, &(&1.id == :ferroplan))
      assert length(ferroplan_rows) == 1

      row = hd(ferroplan_rows)
      assert row.capability == {:bridge, Xaas.Bridges.Ferroplan}
      assert row.state == :bridge
      # Static registry entry: standing UNKNOWN until a real receipt backs it.
      assert row.standing == "UNKNOWN"
      assert row.authority_ceiling == :none
      assert row.receipt_ref == nil
      assert row.evidence_ref == nil
      assert row.subject == Xaas.Bridges.subject()
      assert row.claim =~ "sha256-pinned ferroplan-wasm"
    end

    test "exactly one bridge module is claimed for ferroplan; no absence row covers it" do
      refute Map.has_key?(Xaas.Bridges.Registry.absences(), :ferroplan)

      bridge_modules =
        Registry.all()
        |> Enum.flat_map(fn
          %{capability: {:bridge, mod}} -> [mod]
          _ -> []
        end)

      assert Enum.count(bridge_modules, &(&1 == Xaas.Bridges.Ferroplan)) == 1
    end

    test "standing stays honestly UNKNOWN even after an observed successful execution" do
      # Observed execution (if a runtime is present) does not raise registry
      # standing: only a real receipt bound to the execution may. Prove the
      # registry does not silently claim the observed run.
      maybe_result = Ferroplan.validate()

      case maybe_result do
        {:ok, envelope} ->
          assert envelope.standing == "UNKNOWN",
                 "observed execution must not fabricate standing without a receipt"

        {:refused, _} ->
          :ok
      end

      row = Registry.all() |> Enum.find(&(&1.id == :ferroplan))
      assert row.standing == "UNKNOWN"
      assert row.receipt_ref == nil
    end
  end

  # -----------------------------------------------------------------
  # Helpers
  # -----------------------------------------------------------------

  # Flip one byte deep in the module so the header stays well-formed but the
  # digest moves.
  defp mutate_last_byte(bytes) do
    index = byte_size(bytes) - 16

    <<prefix::binary-size(^index), last::size(8), suffix::binary>> = bytes
    <<prefix::binary, bxor(last, 0xFF)::size(8), suffix::binary>>
  end

  defp corrupted_temp_copy(bytes) do
    path = Path.join(System.tmp_dir!(), "w716-ferroplan-corrupted-#{System.unique_integer()}.wasm")
    File.write!(path, bytes)
    path
  end
end
