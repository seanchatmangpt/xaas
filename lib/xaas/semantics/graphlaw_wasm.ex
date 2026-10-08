defmodule Xaas.Semantics.GraphlawWasm do
  import Bitwise

  @moduledoc """
  Wasmex host transport for the graphlaw WASM kernel (primitive J: one
  executable law, many runtimes).

  Modeled on the generated surface of
  `ggen-marketplace/packs/beam-wasmex-host-pack/templates/wasm_host.ex.tmpl`
  (packed_u64 out-mode, WASI-allowlist admission). Not generator output: the
  graphlaw surface is hand-bound because W637's artifact identity is
  receipt-carried, not manifest-carried.

  ## Guest ABI contract (this module is its mirror image)

  * Exports: `gl_alloc(len) -> ptr`, `gl_free(ptr, len)` (frees both the
    input and the output buffer), `gl_call(in_ptr, in_len) -> packed`, plus
    the exported linear memory `memory`.
  * Payload: UTF-8 JSON over linear memory.
  * Return mode: `packed_u64` — `gl_call(in_ptr, in_len) -> packed`, one u64
    holding `(out_ptr <<< 32) | out_len`.
  * Imports: `wasi_snapshot_preview1` only, judged against a hard allowlist
    (`@wasi_allowlist`); instantiation runs on wasmex's REAL WASI store
    (`Wasmex.Store.new_wasi/1`), never zero-value stubs (stubs trap on real
    op:"law"/op:"shacl" workloads — W640 finding (c)). Anything outside the
    namespace or the list is an `:import_surface_mismatch` refusal.

  ## Receipt identity

  `artifact_digest/0` is the host-authoritative SHA-256 over the artifact
  bytes, pinned by (in order): `:expected_sha256` opt, Application env
  `:xaas, :graphlaw_wasm_sha256`, then `priv/graphlaw.wasm.sha256`
  (the pin W637's receipt carries). Startup fails closed
  (`:digest_unpinned`) when no pin source exists.

  ## Refusals

  Every rejected operation returns `{:error, %Xaas.Actuation.Refusal{}}` with
  `:code` one of `:digest_unpinned`, `:digest_mismatch`, `:invalid_wasm`,
  `:import_surface_mismatch`, `:missing_export`, `:file_unreadable`,
  `:invalid_encoding`, `:resource_limit`, `:abi_failure`, `:call_trapped`,
  `:call_timeout`, `:invalid_json`, `:malformed_response`.
  (`Xaas.Refusal` does not exist in lib/; the real typed refusal shape is
  `Xaas.Actuation.Refusal` — Splode, fields `:code`/`:detail`, class
  `:forbidden` — so refusals are indistinguishable from policy outcomes in the
  durable ledger.)
  """

  alias Xaas.Actuation.Refusal

  @alloc_export "gl_alloc"
  @free_export "gl_free"
  @call_export "gl_call"
  @memory_export "memory"
  @artifact_path Path.expand("../../../priv/graphlaw.wasm", __DIR__)
  @pin_path Path.expand("../../../priv/graphlaw.wasm.sha256", __DIR__)
  # Watchdog: a graphlaw invocation must answer within 15ms or be refused.
  @call_timeout_ms 15
  @max_request_bytes 1_048_576
  @max_response_bytes 1_048_576

  # Hard WASI allowlist: the graphlaw kernel (wasm32-wasip1) may import only
  # these wasi_snapshot_preview1 functions, with exactly these signatures.
  @wasi_allowlist [
    {"wasi_snapshot_preview1", "fd_write", [:i32, :i32, :i32, :i32], [:i32]},
    {"wasi_snapshot_preview1", "fd_read", [:i32, :i32, :i32, :i32], [:i32]},
    {"wasi_snapshot_preview1", "clock_time_get", [:i32, :i64, :i32], [:i32]},
    {"wasi_snapshot_preview1", "random_get", [:i32, :i32], [:i32]},
    {"wasi_snapshot_preview1", "environ_sizes_get", [:i32, :i32], [:i32]},
    {"wasi_snapshot_preview1", "environ_get", [:i32, :i32], [:i32]},
    {"wasi_snapshot_preview1", "args_sizes_get", [:i32, :i32], [:i32]},
    {"wasi_snapshot_preview1", "proc_exit", [:i32], []},
    {"wasi_snapshot_preview1", "fd_close", [:i32], [:i32]},
    {"wasi_snapshot_preview1", "fd_seek", [:i32, :i64, :i32, :i32], [:i32]},
    {"wasi_snapshot_preview1", "fd_fdstat_get", [:i32, :i32], [:i32]},
    {"wasi_snapshot_preview1", "sched_yield", [], [:i32]}
  ]

  @external_resource @pin_path
  # W984cy4 compile-freeze SLA unblock (disclosed): pin_from_file/0 is a
  # defp below and not callable from a module attribute; inline the same
  # expression here.
  @compile_time_pin (
    case File.read(@pin_path) do
      {:ok, content} -> content |> String.trim() |> String.split() |> List.first()
      {:error, _} -> nil
    end
  )

  @typedoc "A started Wasmex instance plus the artifact digest it was started from."
  @type instance :: %{
          pid: pid(),
          artifact_digest: String.t(),
          artifact_path: String.t()
        }

  @doc "The default artifact path (`priv/graphlaw.wasm`) this module boots from."
  @spec artifact_path() :: String.t()
  def artifact_path, do: @artifact_path

  @doc "Boots an instance from `priv/graphlaw.wasm` under the digest pin."
  @spec start() :: {:ok, instance()} | {:error, Refusal.t()}
  def start, do: start(@artifact_path)

  @doc "Boots an instance from the artifact at `path` under the digest pin."
  @spec start(String.t()) :: {:ok, instance()} | {:error, Refusal.t()}
  def start(path) when is_binary(path), do: start(path, [])

  @doc """
  Admits (digest pin -> compile -> WASI-allowlist import surface -> required
  exports) and boots the artifact at `path` on a REAL WASI store
  (`Wasmex.Store.new_wasi/1` — wasmex's native `wasi_snapshot_preview1`
  implementation, not zero-value stubs). Instantiating on zero-value stubs
  TRAPS on real op:"shacl"/op:"law" workloads (witnessed by the W640
  differential court, receipt finding (c)); the stubs path is retired. The
  import judge still judges the module's real import surface against
  `@wasi_allowlist` before boot.

  Options:

    * `:expected_sha256` — hex (optionally `sha256:`-prefixed), or `:unpinned`
      (test escape hatch only; never the default). Default order: this opt,
      Application env `:xaas, :graphlaw_wasm_sha256`, then
      `priv/graphlaw.wasm.sha256`; no pin source => `:digest_unpinned`.
    * `:required_exports` — override list of export names.
  """
  @spec start(String.t(), keyword()) :: {:ok, instance()} | {:error, Refusal.t()}
  def start(path, opts) when is_binary(path) and is_list(opts) do
    with {:ok, bytes} <- read_bytes(path),
         :ok <- verify_digest(bytes, pin_for(opts)),
         {:ok, store} <- wasi_store(),
         {:ok, module} <- module_compile(store, bytes),
         :ok <- judge_imports(Wasmex.Module.imports(module), opts),
         :ok <- judge_exports(module, opts),
         {:ok, pid} <- Wasmex.start_link(%{store: store, module: module, imports: %{}}) do
      {:ok, %{pid: pid, artifact_digest: digest(bytes), artifact_path: path}}
    end
  end

  @doc "Host-authoritative digest: lower-hex SHA-256 over the artifact bytes."
  @spec digest(binary()) :: String.t()
  def digest(bytes) when is_binary(bytes) do
    :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
  end

  @doc """
  Digest-verification hook. `pin` is hex or `sha256:`-prefixed hex; `:unpinned`
  always passes (test escape hatch); `nil` refuses `:digest_unpinned`.
  """
  @spec verify_digest(binary(), String.t() | :unpinned | nil) :: :ok | {:error, Refusal.t()}
  def verify_digest(_bytes, :unpinned), do: :ok

  def verify_digest(bytes, pin) when is_binary(pin) do
    expected = strip_prefix(pin)
    actual = digest(bytes)

    if Plug.Crypto.secure_compare(expected, actual) do
      :ok
    else
      {:error,
       refuse(:digest_mismatch, "artifact digest does not match the pin", %{
         expected: pin,
         actual: actual
       })}
    end
  end

  def verify_digest(_bytes, nil) do
    {:error,
     refuse(:digest_unpinned, "no artifact digest pin (opts, Application env, or pin file)", %{
       pin_path: @pin_path
     })}
  end

  @doc """
  Zero-unapproved-WASI-import judge: every import must be
  `wasi_snapshot_preview1` AND on the hard allowlist (`@wasi_allowlist`),
  with an exact signature match. Anything else is an
  `:import_surface_mismatch` refusal.
  """
  @spec judge_imports(%{optional(term()) => term()}, keyword()) ::
          :ok | {:error, Refusal.t()}
  def judge_imports(imports, opts \\ []) do
    allow =
      MapSet.new(wasi_allowlist(opts), fn {ns, name, params, results} ->
        {ns, name, params, results}
      end)

    offenders =
      for {ns, functions} <- imports,
          {name, type} <- functions,
          not MapSet.member?(allow, {to_string(ns), to_string(name), params_of(type), results_of(type)}) do
        "#{ns}.#{name}"
      end

    case Enum.uniq(offenders) do
      [] ->
        :ok

      unexpected ->
        {:error,
         refuse(:import_surface_mismatch, "imports outside the WASI allowlist", %{
           unexpected: Enum.sort(unexpected)
         })}
    end
  end

  @doc """
  Real call of `gl_call` with `request` (JSON-encoded here) through the
  guest's ptr/len packed-u64 ABI: gl_alloc -> Memory.write_binary -> gl_call
  -> unpack (out_ptr <<< 32 | out_len) -> read_binary -> gl_free in strict
  after. Returns `{:ok, response_map}` on a decoded JSON object, else
  `{:error, %Refusal{}}`.
  """
  @spec invoke(instance(), map(), keyword()) :: {:ok, map()} | {:error, Refusal.t()}
  def invoke(%{pid: pid}, request, opts \\ []) when is_map(request) do
    guard(fn ->
      with {:ok, json} <- encode(request, opts),
           {:ok, store, memory} <- store_and_memory(pid) do
        with_buffer(pid, byte_size(json), fn in_ptr ->
          case write(store, memory, in_ptr, json) do
            :ok ->
              # graphlaw ABI: gl_call CONSUMES the input buffer, so the host
              # must not gl_free it after a completed call.
              result = invoke_packed(pid, store, memory, @call_export, in_ptr, byte_size(json), opts)
              {:consumed, result}

            {:error, _} = error ->
              {:not_consumed, error}
          end
        end)
      end
    end)
  end

  @doc """
  Input-buffer ownership contract, exposed as a public seam so courts can drive
  the raise/exit cleanup paths with real collaborators (no mocks): allocates
  `len` bytes in the guest via `gl_alloc`, runs `fun.(ptr)`, and guarantees the
  input buffer is deallocated on every non-consumed exit path (pre-call
  failure, raise, exit) while a guest-consumed buffer is never double-freed.
  `fun` must return `{:consumed, result} | {:not_consumed, result}`.
  """
  @spec with_input_buffer(instance(), pos_integer(), (integer() -> {:consumed, term()} | {:not_consumed, term()})) ::
          term()
  def with_input_buffer(%{pid: pid}, len, fun) when is_integer(len) and len >= 0,
    do: with_buffer(pid, len, fun)

  # -- admission -----------------------------------------------------------

  defp read_bytes(path) do
    case File.read(path) do
      {:ok, bytes} ->
        {:ok, bytes}

      {:error, reason} ->
        {:error,
         refuse(:file_unreadable, "artifact unreadable", %{path: path, reason: inspect(reason)})}
    end
  end

  # Real WASI implementation (wasmex native wasi_snapshot_preview1), not
  # zero-value stubs — see start/2 doc. Real wasi store is required for the
  # op:"law"/op:"shacl" workloads the product path runs.
  defp wasi_store do
    case Wasmex.Store.new_wasi(%Wasmex.Wasi.WasiOptions{}) do
      {:ok, store} ->
        {:ok, store}

      {:error, reason} ->
        {:error,
         refuse(:invalid_wasm, "wasi store unavailable", %{reason: inspect(reason, limit: 5)})}
    end
  end

  defp pin_for(opts) do
    case Keyword.fetch(opts, :expected_sha256) do
      {:ok, pin} ->
        pin

      :error ->
        Application.get_env(:xaas, :graphlaw_wasm_sha256) || @compile_time_pin
    end
  end

  defp module_compile(store, bytes) do
    case Wasmex.Module.compile(store, bytes) do
      {:ok, module} ->
        {:ok, module}

      {:error, reason} ->
        {:error,
         refuse(:invalid_wasm, "artifact bytes did not compile as a WebAssembly module", %{
           reason: inspect(reason, limit: 5)
         })}
    end
  rescue
    error ->
      {:error,
       refuse(:invalid_wasm, "artifact bytes did not compile as a WebAssembly module", %{
         reason: inspect(error, limit: 5)
       })}
  end

  defp wasi_allowlist(opts) do
    case Keyword.get(opts, :import_allowlist) do
      nil -> @wasi_allowlist
      list when is_list(list) -> list
    end
  end

  # wasmex 0.15 import type shape: {:fn, params, results}
  defp params_of({:fn, params, _results}), do: Enum.map(params, &wasmex_type_atom/1)
  defp params_of(%{params: params}), do: Enum.map(params, &wasmex_type_atom/1)
  defp params_of(_), do: []

  defp results_of({:fn, _params, results}), do: Enum.map(results, &wasmex_type_atom/1)
  defp results_of(%{results: results}), do: Enum.map(results, &wasmex_type_atom/1)
  defp results_of(_), do: []

  defp wasmex_type_atom(t) when t in [:i32, :i64, :f32, :f64], do: t
  defp wasmex_type_atom(_), do: :i32

  defp judge_exports(module, opts) do
    exports = Wasmex.Module.exports(module)

    required =
      Keyword.get_lazy(opts, :required_exports, fn ->
        [@memory_export, @alloc_export, @free_export, @call_export]
      end)

    missing = Enum.reject(required, &Map.has_key?(exports, &1))

    case missing do
      [] ->
        :ok

      _ ->
        {:error,
         refuse(:missing_export, "artifact lacks required exports", %{
           missing: missing,
           required: required
         })}
    end
  end

  # -- transport internals -------------------------------------------------

  # A dead/overloaded Wasmex GenServer exits the caller; surface a refusal.
  defp guard(fun) do
    fun.()
  catch
    :exit, {:timeout, _} ->
      {:error,
       refuse(:call_timeout, "graphlaw invocation exceeded the watchdog", %{
         timeout_ms: @call_timeout_ms
       })}

    :exit, reason ->
      {:error, refuse(:call_trapped, "wasm instance unavailable", %{exit: inspect(reason)})}
  end

  defp timeout(opts), do: Keyword.get(opts, :timeout, @call_timeout_ms)

  defp encode(request, opts) do
    max = Keyword.get(opts, :max_request_bytes, @max_request_bytes)

    case Jason.encode(request) do
      {:ok, json} when byte_size(json) > max ->
        {:error,
         refuse(:resource_limit, "request exceeds max_request_bytes", %{
           limit: max,
           actual: byte_size(json)
         })}

      {:ok, json} ->
        {:ok, json}

      {:error, error} ->
        {:error,
         refuse(:invalid_encoding, "request is not encodable as UTF-8 JSON", %{
           error: inspect(error)
         })}
    end
  rescue
    error ->
      {:error,
       refuse(:invalid_encoding, "request is not encodable as UTF-8 JSON", %{
         error: inspect(error)
       })}
  end

  defp store_and_memory(pid) do
    with {:ok, store} <- Wasmex.store(pid),
         {:ok, memory} <- Wasmex.memory(pid) do
      {:ok, store, memory}
    else
      other ->
        {:error, refuse(:abi_failure, "wasm store/memory unavailable", %{result: inspect(other)})}
    end
  end

  defp write(store, memory, ptr, bytes) do
    case Wasmex.Memory.write_binary(store, memory, ptr, bytes) do
      :ok ->
        :ok

      other ->
        {:error,
         refuse(:abi_failure, "writing request into wasm memory failed", %{result: inspect(other)})}
    end
  rescue
    error ->
      {:error,
       refuse(:abi_failure, "writing request into wasm memory failed", %{error: inspect(error)})}
  end

  defp read(store, memory, ptr, len) do
    case Wasmex.Memory.read_binary(store, memory, ptr, len) do
      bytes when is_binary(bytes) ->
        {:ok, bytes}

      other ->
        {:error, refuse(:abi_failure, "reading wasm memory failed", %{result: inspect(other)})}
    end
  rescue
    error ->
      {:error, refuse(:abi_failure, "reading wasm memory failed", %{error: inspect(error)})}
  end

  # Allocates `len` bytes, runs `fun.(ptr) -> {:consumed, result} |
  # {:not_consumed, result}`, and deallocs the input buffer on EVERY
  # non-consumed exit path: pre-call failure, raise, or host-side exit. The
  # graphlaw guest frees the request buffer itself inside `gl_call`, so a host
  # gl_free after a completed call would be a double free.
  #
  # Leak-window fix (seam-deploy lane, 2026-10-08): before this change only the
  # returned-{:not_consumed,_} path deallocated; a raise (or exit) out of
  # `fun.(ptr)` propagated with the input buffer still allocated. The cleanup
  # is now exception-safe and re-raises/re-exits with the original payload so
  # the outer `guard/1` still classifies exits (`:call_timeout`/`:call_trapped`)
  # unchanged.
  defp with_buffer(pid, len, fun) do
    case alloc(pid, len) do
      {:ok, ptr} ->
        {ownership, result} =
          try do
            fun.(ptr)
          rescue
            exception ->
              safe_dealloc(pid, ptr, len)
              reraise exception, __STACKTRACE__
          catch
            :exit, reason ->
              safe_dealloc(pid, ptr, len)
              exit(reason)
          end

        if ownership == :not_consumed do
          safe_dealloc(pid, ptr, len)
        end

        result

      {:error, _} = error ->
        error
    end
  end

  defp alloc(pid, len) do
    case Wasmex.call_function(pid, @alloc_export, [len]) do
      {:ok, [ptr]} when is_integer(ptr) and ptr >= 0 ->
        {:ok, ptr}

      other ->
        {:error,
         refuse(:abi_failure, "gl_alloc failed", %{len: len, result: inspect(other)})}
    end
  end

  defp safe_dealloc(pid, ptr, len) do
    Wasmex.call_function(pid, @free_export, [ptr, len])
    :ok
  catch
    :exit, _ -> :ok
  end

  defp invoke_packed(pid, store, memory, export_name, in_ptr, in_len, opts) do
    max_out = Keyword.get(opts, :max_response_bytes, @max_response_bytes)

    case Wasmex.call_function(pid, export_name, [in_ptr, in_len], timeout(opts)) do
      {:ok, [packed]} when is_integer(packed) and packed >= 0 ->
        out_ptr = packed >>> 32
        out_len = packed &&& 0xFFFFFFFF

        result = read_response(store, memory, out_ptr, out_len, max_out)

        case {result, free_output(pid, out_ptr, out_len)} do
          {{:ok, _} = ok, :ok} -> ok
          {{:ok, _}, {:error, _} = free_error} -> free_error
          {error, _} -> error
        end

      {:ok, other} ->
        {:error,
         refuse(:malformed_response, "gl_call must return exactly one packed u64", %{
           result: inspect(other)
         })}

      {:error, reason} ->
        {:error,
         refuse(:call_trapped, "gl_call trapped", %{
           export: export_name,
           reason: inspect(reason)
         })}
    end
  end

  defp free_output(_pid, _ptr, 0), do: :ok

  defp free_output(pid, ptr, len) do
    case Wasmex.call_function(pid, @free_export, [ptr, len]) do
      {:ok, _} ->
        :ok

      other ->
        {:error, refuse(:abi_failure, "gl_free failed", %{result: inspect(other)})}
    end
  end

  defp read_response(_store, _memory, _ptr, len, max) when len > max do
    {:error,
     refuse(:resource_limit, "response exceeds max_response_bytes", %{limit: max, actual: len})}
  end

  defp read_response(store, memory, ptr, len, _max) do
    with {:ok, bytes} <- read_output(store, memory, ptr, len) do
      decode_response(bytes)
    end
  end

  defp read_output(_store, _memory, _ptr, 0), do: {:ok, ""}

  defp read_output(store, memory, ptr, len), do: read(store, memory, ptr, len)

  defp decode_response(bytes) do
    if String.valid?(bytes) do
      case Jason.decode(bytes) do
        {:ok, map} when is_map(map) ->
          {:ok, map}

        {:ok, other} ->
          {:error, refuse(:malformed_response, "response is not a JSON object", %{value: inspect(other)})}

        {:error, reason} ->
          {:error, refuse(:invalid_json, "response is not valid JSON", %{reason: inspect(reason)})}
      end
    else
      {:error, refuse(:invalid_encoding, "response is not valid UTF-8", %{})}
    end
  end

  defp strip_prefix("sha256:" <> rest), do: rest
  defp strip_prefix(pin), do: pin

  defp refuse(code, message, details) do
    Refusal.new(code, Map.put(details, :message, message))
  end
end
