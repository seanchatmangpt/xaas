defmodule Xaas.Semantics.GraphlawWasmSeamTest do
  @moduledoc """
  Seam-deploy court (2026-10-08): the pinned graphlaw WASM kernel
  (`Xaas.Semantics.GraphlawWasm`, digest-pinned to `priv/graphlaw.wasm.sha256`)
  is on the product assess path.

  Prior-lane observation closed here: `Xaas.Semantics.GraphlawWasm` implemented
  the full ABI with 8/8 courts but had ZERO production callers - assess went
  `Xaas.Bridges.Graphlaw.assess/2` -> `AshGraphLaw.law/3` -> `AshGraphLaw.Pool`
  (the dep's own vendored engine, digest 7bb2a7e5), never through the xaas-side
  pinned transport (fc23a292). Two real-engine discriminator legs prove the
  flow: with the pool poisoned via the Application-env pin, assess falls back
  to the legacy dep pool and the envelope names the DEP's engine digest
  (7bb2a7e5); with the pool healthy, the envelope names fc23a292.
  """

  use ExUnit.Case, async: false

  alias Xaas.Bridges.Graphlaw
  alias Xaas.Semantics.GraphlawPool
  alias Xaas.Semantics.GraphlawWasm

  @artifact "priv/graphlaw.wasm"
  @pin_file "priv/graphlaw.wasm.sha256"
  @pin_digest "fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38"
  @dep_digest "7bb2a7e5ebcef7584b0b960451272d56fa75414d76a12138d41e8973e126eee0"

  setup do
    # A later leg poisons the Application-env pin; every leg starts from the
    # on-disk pin.
    Application.delete_env(:xaas, :graphlaw_wasm_sha256)
    :ok = GraphlawPool.reset()
    :ok
  end

  test "pool boots the pinned artifact; digest equals the pin file and the bytes" do
    assert {:ok, %{artifact_digest: sha, artifact_path: path}} = GraphlawPool.info()
    assert sha == @pin_digest
    assert path == GraphlawWasm.artifact_path()
    assert sha == GraphlawWasm.digest(File.read!(@artifact))

    pin_from_file = @pin_file |> File.read!() |> String.trim() |> String.split() |> List.first()
    assert pin_from_file == sha
  end

  test "pool serves op:capabilities through the pinned transport" do
    assert {:ok, %{"ok" => true}} = GraphlawPool.invoke(%{"op" => "capabilities"})
  end

  test "leak fix (raise path): a raise inside the buffer scope deallocs and propagates" do
    {:ok, inst} = GraphlawWasm.start(@artifact)

    assert_raise RuntimeError, "seam-boom", fn ->
      GraphlawWasm.with_input_buffer(inst, 64, fn _ptr ->
        raise "seam-boom"
        {:consumed, :unreachable}
      end)
    end

    # The instance survives: no double free, guest heap not exhausted.
    assert {:ok, %{"ok" => true}} = GraphlawWasm.invoke(inst, %{"op" => "capabilities"})
  end

  test "leak fix (exit path): an exit inside the buffer scope deallocs and re-exits" do
    {:ok, inst} = GraphlawWasm.start(@artifact)
    exit_reason = {:timeout, {__MODULE__, :leg, []}}

    try do
      GraphlawWasm.with_input_buffer(inst, 64, fn _ptr ->
        exit(exit_reason)
        {:consumed, :unreachable}
      end)
      flunk("expected the exit to propagate")
    catch
      :exit, ^exit_reason -> :ok
    end

    # The instance survives.
    assert {:ok, %{"ok" => true}} = GraphlawWasm.invoke(inst, %{"op" => "capabilities"})
  end

  describe "product assess path" do
    test "within-limit purchase is admitted BY THE PINNED ARTIFACT" do
      assert {:ok, admitted} = Graphlaw.assess(%{"amount" => 100, "limit" => 500})
      assert admitted.state == :admitted
      assert admitted.standing == "PARTIAL_ALIVE"
      assert admitted.provenance.receipts >= 1
      # Transport discriminator: the envelope names the xaas pin digest, not
      # the dep pool's vendored engine (7bb2a7e5).
      assert admitted.provenance.engine_sha256 == @pin_digest
      refute admitted.provenance.engine_sha256 == @dep_digest
    end

    test "over-limit without approval is refused BY THE PINNED ARTIFACT" do
      assert {:refused, refusal} = Graphlaw.assess(%{"amount" => 1500, "limit" => 500})
      assert refusal.code == :not_admitted
      assert refusal.class == :refused_admission
    end

    test "poisoned pin: assess falls back to the legacy dep pool (transport discriminator)" do
      Application.put_env(:xaas, :graphlaw_wasm_sha256, String.duplicate("ab", 32))
      :ok = GraphlawPool.reset()

      assert {:ok, admitted} = Graphlaw.assess(%{"amount" => 100, "limit" => 500})
      # The verdict now comes from the DEP's vendored engine.
      assert admitted.provenance.engine_sha256 == @dep_digest
    end

    test "explicit :server opts out of the xaas transport (legacy passthrough)" do
      assert {:refused, refusal} =
               Graphlaw.assess(%{"amount" => 1500, "limit" => 500},
                 server: :l7_graphlaw_host_never_started
               )

      assert refusal.code == :host_not_started
    end
  end
end
