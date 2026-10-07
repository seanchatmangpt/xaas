defmodule Xaas.Semantics.GraphlawWasmTest do
  @moduledoc """
  W638 court for `Xaas.Semantics.GraphlawWasm` (Wasmex unification Phase 2).

  Real collaborators throughout: the actual W637 `priv/graphlaw.wasm` artifact
  (sha256 fc23a292..., W647-rotated; see W650n receipt) drives the round-trip, zero-leak, digest and import
  legs; a minimal hand-built spin guest with the same packed-u64 ABI
  (test/support/graphlaw_spin_guest.rs) drives only the watchdog leg, where a
  statutory-speed guest cannot lose the race against the 15ms watchdog by
  construction.
  """

  use ExUnit.Case, async: false

  alias Xaas.Actuation.Refusal
  alias Xaas.Semantics.GraphlawWasm

  @artifact "priv/graphlaw.wasm"
  @pin "priv/graphlaw.wasm.sha256"
  @spin_guest "test/support/graphlaw_spin_guest.rs"
  @spin_guest_wasm "/tmp/w638-graphlaw-spin-guest.wasm"
  @receipt_digest "fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38"

  setup_all do
    {:ok, artifact} = GraphlawWasm.start(@artifact)
    %{artifact: artifact}
  end

  @tag :w638
  test "statutory round trip: capabilities request echoes a JSON object through gl_call", %{artifact: inst} do
    assert {:ok, response} = GraphlawWasm.invoke(inst, %{"op" => "capabilities"})
    assert is_map(response)
    # graphlaw ABI: success is always {"ok": true, ...}.
    assert response["ok"] == true
  end

  @tag :w638
  test "zero-leak: 100 real invokes all succeed (guest outstanding-buffer cap holds)", %{artifact: inst} do
    results = for _ <- 1..100, do: GraphlawWasm.invoke(inst, %{"op" => "capabilities"})

    failures = Enum.filter(results, &match?({:error, _}, &1))
    assert failures == []
  end

  @tag :w638
  test "digest-mismatch refusal: wrong pin fails closed at admission" do
    wrong = String.duplicate("ab", 32)

    assert {:error,
            %Refusal{code: :digest_mismatch, detail: %{expected: ^wrong, actual: actual}}} =
             GraphlawWasm.start(@artifact, expected_sha256: wrong)

    assert String.length(actual) == 64
  end

  @tag :w638
  test "digest-unpinned refusal: nil pin fails closed" do
    assert {:error, %Refusal{code: :digest_unpinned}} =
             GraphlawWasm.start(@artifact, expected_sha256: nil)
  end

  @tag :w638
  test "installed pin matches the W637 receipt digest" do
    assert File.exists?(@artifact)
    assert File.exists?(@pin)

    assert @pin |> File.read!() |> String.trim() |> String.split() |> List.first() == @receipt_digest
    assert GraphlawWasm.digest(File.read!(@artifact)) == @receipt_digest
  end

  @tag :w638
  test "import judge admits the real WASI surface and refuses injected offenders" do
    {:ok, bytes} = File.read(@artifact)
    {:ok, engine} = Wasmex.Engine.new(%Wasmex.EngineConfig{})
    {:ok, store} = Wasmex.Store.new(nil, engine)
    {:ok, module} = Wasmex.Module.compile(store, bytes)

    imports = Wasmex.Module.imports(module)
    assert imports != %{}
    assert GraphlawWasm.judge_imports(imports) == :ok

    offenders = %{"env" => %{"evil_import" => {:fn, [], []}}}

    assert {:error,
            %Refusal{code: :import_surface_mismatch, detail: %{unexpected: ["env.evil_import"]}}} =
             GraphlawWasm.judge_imports(offenders)
  end

  @tag :w638
  test "watchdog: a guest that spins past 15ms is refused :call_timeout" do
    spin_wasm = build_spin_guest!()
    File.write!(@spin_guest_wasm, spin_wasm)

    assert {:ok, inst} =
             GraphlawWasm.start(@spin_guest_wasm, expected_sha256: GraphlawWasm.digest(spin_wasm))

    assert {:error, %Refusal{code: :call_timeout}} =
             GraphlawWasm.invoke(inst, %{"op" => "capabilities"})
  end

  @tag :w638
  test "missing-export refusal" do
    {:ok, bytes} = File.read(@artifact)

    assert {:error, %Refusal{code: :missing_export}} =
             GraphlawWasm.start(@artifact,
               expected_sha256: GraphlawWasm.digest(bytes),
               required_exports: ["memory", "gl_alloc", "gl_call", "gl_free", "gl_nonexistent"]
             )
  end

  # -- fixtures ------------------------------------------------------------

  # Chicago discipline: the spin guest is a real compiled wasm artifact, not a
  # mock — rustc emits it once and the bytes are cached by source hash.
  defp build_spin_guest! do
    cache = @spin_guest_wasm
    source_hash = :crypto.hash(:sha256, File.read!(@spin_guest))

    cached? =
      case File.read(cache) do
        {:ok, wasm} ->
          # First 32 bytes of a wasm module are header + code; identity is the
          # source hash kept alongside: simplest is to rebuild when the
          # sidecar hash differs.
          match?({:ok, ^source_hash}, File.read(cache <> ".sha256"))

        {:error, _} ->
          false
      end

    if cached? do
      File.read!(cache)
    else
      {_, 0} =
        System.cmd("rustc", [
          "--target",
          "wasm32-unknown-unknown",
          "--crate-type=cdylib",
          "-O",
          @spin_guest,
          "-o",
          cache
        ])

      File.write!(cache <> ".sha256", source_hash)
      File.read!(cache)
    end
  end
end
