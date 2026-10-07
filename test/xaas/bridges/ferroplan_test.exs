defmodule Xaas.Bridges.FerroplanTest do
  @moduledoc """
  Chicago tests for the ferroplan bridge: real artifact bytes, real digest
  math, real wasm execution where a runtime is loadable. No mocks.
  """

  use ExUnit.Case, async: false

  import Bitwise

  alias Xaas.Bridges.Ferroplan

  @pinned "088d9c3b0306e36123ddc1ee780ad7e9d4bd2ebb54f9726c43f40a2f6d718233"

  setup do
    Ferroplan.purge_cache()
    on_exit(fn -> Ferroplan.purge_cache() end)
    :ok
  end

  describe "artifact/0 digest gate" do
    test "the pinned artifact verifies at the canonical path" do
      assert {:ok, artifact} = Ferroplan.artifact()
      assert artifact.sha256 == @pinned
      assert artifact.path == Ferroplan.artifact_path()
      assert byte_size(artifact.bytes) > 0
      # Real digest math over the real bytes, independent of the bridge.
      assert Base.encode16(:crypto.hash(:sha256, artifact.bytes), case: :lower) == @pinned
    end

    test "tampered bytes refuse with the typed digest mismatch" do
      bytes = File.read!(Ferroplan.artifact_path())
      tampered = mutate(bytes)

      refute Base.encode16(:crypto.hash(:sha256, tampered), case: :lower) == @pinned

      # Judge the tampered bytes through the bridge's own gate — the same gate
      # a wrong byte on disk would hit.
      assert {:refused, refusal} = Ferroplan.verify_bytes(tampered)
      assert refusal.code == :ferroplan_artifact_digest_mismatch
      assert refusal.expected_sha256 == @pinned
      assert refusal.observed_sha256 != @pinned
    end
  end

  describe "metadata/0" do
    test "digest-verified metadata, authority ceiling :none" do
      assert {:ok, meta} = Ferroplan.metadata()
      assert meta.sha256 == @pinned
      assert meta.authority_ceiling == :none
      assert meta.standing == "UNKNOWN"
      assert "fp_alloc" in meta.exports
      assert "fp_call" in meta.exports
      assert "fp_dealloc" in meta.exports
    end
  end

  describe "invoke path" do
    test "runtime availability is a truthful load probe" do
      assert is_boolean(Ferroplan.runtime_available?())
    end

    if Ferroplan.runtime_available?() do
      test "validate/0 runs fond_validate through the pinned engine" do
        assert {:ok, envelope} = Ferroplan.validate()

        assert envelope.authority_ceiling == :none
        assert envelope.provenance.engine_sha256 == @pinned
        assert envelope.provenance.valid in [true, false]
        assert is_map(envelope.response)
      end

      test "invoke/1 runs the version op through the pinned engine" do
        assert {:ok, envelope} = Ferroplan.invoke(%{"op" => "version"})
        assert is_binary(envelope.response["version"])
        assert envelope.provenance.engine_sha256 == @pinned
      end
    else
      test "with no runtime, invoke refuses typed, not degraded" do
        assert {:refused, refusal} = Ferroplan.validate()
        assert refusal.code == :ferroplan_runtime_unavailable

        assert {:refused, refusal} = Ferroplan.invoke(%{"op" => "version"})
        assert refusal.code == :ferroplan_runtime_unavailable
      end
    end
  end

  # Flip one byte deep in the module so the header stays well-formed but the
  # digest moves.
  defp mutate(bytes) do
    index = byte_size(bytes) - 16
    <<prefix::binary-size(^index), last::size(8), suffix::binary>> = bytes
    <<prefix::binary, bxor(last, 0xFF)::size(8), suffix::binary>>
  end
end
