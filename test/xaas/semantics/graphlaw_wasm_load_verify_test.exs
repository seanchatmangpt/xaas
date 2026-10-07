defmodule Xaas.Semantics.GraphlawWasmLoadVerifyTest do
  @moduledoc """
  W984dh — independent verification of the W637/W644 load-leg claim:
  does `priv/graphlaw.wasm` (sha256 fc23a292..38, W647-rotated binary; digest rotation disclosed per W650n) load under
  Wasmex with the WASI import surface, and does a minimal `gl_call` round
  trip return a real verdict?

  Deliberately does NOT use `Xaas.Semantics.GraphlawWasm` (W638's adapter,
  in-flight): this test drives raw `Wasmex` directly so the load leg is
  verified independent of the adapter under review.
  """

  use ExUnit.Case, async: false
  import Bitwise

  @artifact Path.expand("../../../priv/graphlaw.wasm", __DIR__)
  @expected_sha "fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38"

  # Exact WASI surface enumerated from the binary's import section
  # (7 functions). Stubs return errno 0 (SUCCESS); proc_exit exits.
  defp stub_imports do
    %{
      "wasi_snapshot_preview1" => %{
        "random_get" => {:fn, [:i32, :i32], [:i32], fn _ctx, _p, _l -> 0 end},
        "environ_get" => {:fn, [:i32, :i32], [:i32], fn _ctx, _p, _l -> 0 end},
        "environ_sizes_get" => {:fn, [:i32, :i32], [:i32], fn _ctx, _a, _b -> 0 end},
        "clock_time_get" => {:fn, [:i32, :i64, :i32], [:i32], fn _ctx, _id, _p, _t -> 0 end},
        "fd_write" =>
          {:fn, [:i32, :i32, :i32, :i32], [:i32], fn _ctx, _fd, _io, _n, _w -> 0 end},
        "proc_exit" => {:fn, [:i32], [], fn _ctx, _code -> exit(:proc_exit_stub) end},
        "sched_yield" => {:fn, [], [:i32], fn _ctx -> 0 end}
      }
    }
  end

  @expected_imports [
    "clock_time_get",
    "environ_get",
    "environ_sizes_get",
    "fd_write",
    "proc_exit",
    "random_get",
    "sched_yield"
  ]

  @required_exports ["memory", "gl_alloc", "gl_call", "gl_free"]

  defp artifact_bytes do
    bytes = File.read!(@artifact)

    assert :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower) == @expected_sha,
           "artifact digest drifted from the W637 pin"

    bytes
  end

  defp boot do
    bytes = artifact_bytes()

    {:ok, engine} = Wasmex.Engine.new(%Wasmex.EngineConfig{})
    {:ok, store} = Wasmex.Store.new(nil, engine)
    {:ok, module} = Wasmex.Module.compile(store, bytes)
    {:ok, pid} = Wasmex.start_link(%{store: store, module: module, imports: stub_imports()})

    {:ok, store} = Wasmex.store(pid)
    {:ok, mem} = Wasmex.memory(pid)
    %{pid: pid, store: store, memory: mem, module: module}
  end

  test "artifact identity matches the W637 pin" do
    artifact_bytes()
  end

  test "import census: exact WASI surface, plus required exports" do
    ctx = boot()

    imports = Wasmex.Module.imports(ctx.module)

    assert %{"wasi_snapshot_preview1" => names} = imports
    assert MapSet.new(Map.keys(names)) == MapSet.new(@expected_imports)
    assert map_size(imports) == 1, "no non-WASI import namespaces allowed"

    exports = Wasmex.Module.exports(ctx.module)

    Enum.each(@required_exports, fn name ->
      assert Map.has_key?(exports, name), "missing export #{name}"
    end)
  end

  test "gl_call round trip returns a real verdict" do
    ctx = boot()
    request = Jason.encode!(%{"op" => "capabilities"})

    assert {:ok, [in_ptr]} = Wasmex.call_function(ctx.pid, "gl_alloc", [byte_size(request)])
    assert :ok = Wasmex.Memory.write_binary(ctx.store, ctx.memory, in_ptr, request)

    assert {:ok, [packed]} =
             Wasmex.call_function(ctx.pid, "gl_call", [in_ptr, byte_size(request)])

    assert is_integer(packed) and packed > 0

    out_ptr = packed >>> 32
    out_len = packed &&& 0xFFFFFFFF
    assert out_ptr > 0
    assert out_len > 0

    resp_bytes = Wasmex.Memory.read_binary(ctx.store, ctx.memory, out_ptr, out_len)
    decoded = Jason.decode!(resp_bytes)

    assert decoded["ok"] == true
    assert is_map_key(decoded, "dialects") or is_map_key(decoded, "engines") or
             map_size(decoded) > 1

    # response buffer is a guest allocation; free it to honor the outstanding cap
    assert {:ok, _} = Wasmex.call_function(ctx.pid, "gl_free", [out_ptr, out_len])
  end

  test "gl_call error leg: malformed request yields typed JSON refusal, not a trap" do
    ctx = boot()
    request = Jason.encode!(%{"op" => "__no_such_op__"})

    assert {:ok, [in_ptr]} = Wasmex.call_function(ctx.pid, "gl_alloc", [byte_size(request)])
    assert :ok = Wasmex.Memory.write_binary(ctx.store, ctx.memory, in_ptr, request)

    assert {:ok, [packed]} =
             Wasmex.call_function(ctx.pid, "gl_call", [in_ptr, byte_size(request)])

    out_ptr = packed >>> 32
    out_len = packed &&& 0xFFFFFFFF

    resp_bytes = Wasmex.Memory.read_binary(ctx.store, ctx.memory, out_ptr, out_len)
    decoded = Jason.decode!(resp_bytes)

    assert decoded["ok"] == false
    assert is_map(decoded["error"])

    assert {:ok, _} = Wasmex.call_function(ctx.pid, "gl_free", [out_ptr, out_len])
  end
end
