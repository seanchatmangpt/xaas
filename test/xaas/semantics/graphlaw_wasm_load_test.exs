defmodule Xaas.Semantics.GraphlawWasmLoadTest do
  @moduledoc """
  W644 load-leg probe: witness that priv/graphlaw.wasm loads and executes
  under Wasmex directly — gl_alloc / gl_call (packed u64) / gl_free over a
  real minimal op payload. Transport witness only; grants no execution
  authority (W638 owns the statutory round-trip).

  Artifact identity pinned (W647-rotated binary, reconciled by W650n): 6,657,708 bytes,
  sha256 fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38
  (sidecar: priv/graphlaw.wasm.sha256).
  """

  use ExUnit.Case, async: false

  import Bitwise
  require Logger

  @expected_sha256 "fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38"
  @expected_bytes 6_657_708

  @wasi_allowlist MapSet.new([
                    {"wasi_snapshot_preview1", "clock_time_get"},
                    {"wasi_snapshot_preview1", "environ_get"},
                    {"wasi_snapshot_preview1", "environ_sizes_get"},
                    {"wasi_snapshot_preview1", "fd_write"},
                    {"wasi_snapshot_preview1", "proc_exit"},
                    {"wasi_snapshot_preview1", "random_get"},
                    {"wasi_snapshot_preview1", "sched_yield"}
                  ])

  defp artifact_path do
    Path.expand("priv/graphlaw.wasm", File.cwd!())
  end

  defp start_instance do
    bytes = File.read!(artifact_path())

    {:ok, engine} = Wasmex.Engine.new(%Wasmex.EngineConfig{})
    {:ok, store} = Wasmex.Store.new(nil, engine)
    {:ok, module} = Wasmex.Module.compile(store, bytes)
    imports = stubs_for(Wasmex.Module.imports(module))
    {:ok, pid} = Wasmex.start_link(%{store: store, module: module, imports: imports})
    %{pid: pid, bytes: bytes}
  end

  # Minimal WASI stubs derived from the module's ACTUAL import surface
  # (never allow-all: any import outside the observed seven refuses here).
  defp stubs_for(imports) do
    offenders =
      for {ns, fns} <- imports,
          {name, _} <- fns,
          not MapSet.member?(@wasi_allowlist, {to_string(ns), to_string(name)}) do
        "#{ns}.#{name}"
      end

    assert offenders == [], "imports outside WASI allowlist: #{inspect(offenders)}"

    %{"wasi_snapshot_preview1" =>
        %{
          "clock_time_get" => {:fn, [:i32, :i64, :i32], [:i32], fn _c, _a, _b, _d -> 0 end},
          "environ_get" => {:fn, [:i32, :i32], [:i32], fn _c, _a, _b -> 0 end},
          "environ_sizes_get" => {:fn, [:i32, :i32], [:i32], fn _c, _a, _b -> 0 end},
          "fd_write" => {:fn, [:i32, :i32, :i32, :i32], [:i32], fn _c, _a, _b, _d, _e -> 0 end},
          "proc_exit" => {:fn, [:i32], [], fn _c, _a -> nil end},
          "random_get" => {:fn, [:i32, :i32], [:i32], fn _c, _a, _b -> 0 end},
          "sched_yield" => {:fn, [], [:i32], fn _c -> 0 end}
        }}
  end

  defp alloc(%{pid: pid}, len) do
    {:ok, [ptr]} = Wasmex.call_function(pid, "gl_alloc", [len])
    ptr
  end

  # Best-effort input-buffer release; gl_free also serves dealloc duty.
  defp dealloc(_inst, _ptr, _len), do: :ok

  # gl_call(in_ptr, in_len) -> packed u64 (out_ptr <<< 32) | out_len
  defp gl_call(inst = %{pid: pid}, request, opts \\ []) do
    json = Jason.encode!(request)
    in_ptr = alloc(inst, byte_size(json))

    try do
      {:ok, store, memory} = pid |> Wasmex.store() |> then(fn {:ok, s} -> {:ok, s, elem(Wasmex.memory(pid), 1)} end)
      :ok = Wasmex.Memory.write_binary(store, memory, in_ptr, json)
      timeout = Keyword.get(opts, :timeout, 30_000)
      {:ok, [packed]} = Wasmex.call_function(pid, "gl_call", [in_ptr, byte_size(json)], timeout)

      assert is_integer(packed) and packed >= 0, "gl_call must return a packed u64, got #{inspect(packed)}"

      out_ptr = packed >>> 32
      out_len = packed &&& 0xFFFFFFFF
      bytes = Wasmex.Memory.read_binary(store, memory, out_ptr, out_len)
      {:ok, out_ptr, out_len, bytes}
    after
      dealloc(inst, in_ptr, byte_size(json))
    end
  end

  defp free_output(%{pid: pid}, ptr, len) when len > 0 do
    {:ok, _} = Wasmex.call_function(pid, "gl_free", [ptr, len])
    :ok
  end

  defp free_output(_inst, _ptr, 0), do: :ok

  test "artifact on disk matches the pinned identity" do
    assert File.exists?(artifact_path())
    assert @expected_bytes == File.stat!(artifact_path()).size
    assert @expected_sha256 == :crypto.hash(:sha256, File.read!(artifact_path())) |> Base.encode16(case: :lower)
  end

  test "module loads with WASI-only import surface and required exports" do
    bytes = File.read!(artifact_path())
    {:ok, engine} = Wasmex.Engine.new(%Wasmex.EngineConfig{})
    {:ok, store} = Wasmex.Store.new(nil, engine)
    {:ok, module} = Wasmex.Module.compile(store, bytes)

    imports = Wasmex.Module.imports(module)
    assert MapSet.new(for {ns, fns} <- imports, {n, _} <- fns, do: {to_string(ns), to_string(n)}) |> MapSet.subset?(@wasi_allowlist)

    exports = Wasmex.Module.exports(module)
    for required <- ["gl_alloc", "gl_call", "gl_free", "memory"] do
      assert Map.has_key?(exports, required), "missing export #{required}"
    end
  end

  test "gl_call over op=capabilities returns a real verdict through packed-u64 path" do
    inst = start_instance()
    {:ok, out_ptr, out_len, bytes} = gl_call(inst, %{"op" => "capabilities"})
    assert out_len > 0
    assert String.valid?(bytes), "response bytes must be valid UTF-8"
    {:ok, verdict} = Jason.decode(bytes)
    assert is_map(verdict)

    Logger.info("W644 gl_call capabilities verdict: #{inspect(verdict, limit: 10)}")
    free_output(inst, out_ptr, out_len)
  end

  test "gl_call over op=sniff returns a real verdict (second op, fresh payload)" do
    inst = start_instance()
    {:ok, out_ptr, out_len, bytes} =
      gl_call(inst, %{"op" => "sniff", "text" => "@prefix e: <https://e/> . e:s e:p e:o ."})

    assert out_len > 0
    {:ok, verdict} = Jason.decode(bytes)
    assert is_map(verdict)
    Logger.info("W644 gl_call sniff verdict: #{inspect(verdict, limit: 10)}")
    free_output(inst, out_ptr, out_len)
  end
end
