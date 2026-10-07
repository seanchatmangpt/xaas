defmodule Xaas.Bridges.Ferroplan do
  @moduledoc """
  Ferroplan bridge: digest-verified access to the pinned FOND/HTN planner WASM
  artifact (`ferroplan-wasm`, wasm32-wasip1 target, fp_alloc/fp_call/fp_dealloc
  JSON ABI).

  The bridge never trusts the bytes: the artifact is read from its canonical
  path under the ferroplan sibling checkout and its sha256 is judged against
  the pin court's digest before anything else happens. A missing or mutated
  artifact is a fail-closed typed refusal
  (`:ferroplan_artifact_digest_mismatch`) — never a degraded pass.

  Invoke path: the WASM module is compiled once per verified digest (cached in
  `:persistent_term`) and each invoke instantiates a fresh WASI store and
  instance, then speaks the fp JSON ABI (request in, packed `(out_ptr << 32) |
  out_len` out, response freed via `fp_dealloc`).

  Runtime seam: xaas reaches `Wasmex` only as a transitive dependency today
  (via `ash_graphlaw` -> wasmex). It is not a declared xaas dep in mix.exs —
  that edit is the coordinator's seam. When no wasm runtime is loadable, the
  bridge stays digest-verified and metadata-only, and every invoke returns the
  typed refusal `:ferroplan_runtime_unavailable`.

  Bridges never authorize: `authority_ceiling` is `:none`, standing stays
  `"UNKNOWN"` until a receipt from observed execution backs it.
  """

  import Bitwise

  # Pin court digest (W45): sha256 of the pinned registry artifact.
  @pinned_sha256 "088d9c3b0306e36123ddc1ee780ad7e9d4bd2ebb54f9726c43f40a2f6d718233"

  # Canonical artifact path in the ferroplan sibling checkout (read-only).
  @artifact_path Path.expand(
                   "../../../../ferroplan/crates/ferroplan-wasm/registry/ferroplan_wasm.wasm",
                   __DIR__
                 )

  @required_exports ["fp_alloc", "fp_call", "fp_dealloc", "memory"]

  # fp_call packs the response as (out_ptr << 32) | out_len; a signed i64 view
  # of the same bits comes back negative from Wasmex.
  @u64 0x1_0000_0000_0000_0000
  @u32_mask 0xFFFF_FFFF

  # The registry's own example (op-examples.json), used by the trivial
  # plan-validate smoke call. Byte-stable so the envelope is reproducible.
  @example_problem ~s({"states":[{"id":"s0"},{"id":"g","facts":["done"]}],"initial_states":["s0"],"goal":{"facts":["done"]},"transitions":[{"action":"flip","from":"s0","to":"g","probability_ppm":500000},{"action":"flip","from":"s0","to":"s0","probability_ppm":500000}]})

  @example_plan %{
    "planning_type" => "fond",
    "solved" => true,
    "steps" => [],
    "policy" => [
      %{
        "state" => "s0",
        "action" => "flip",
        "outcomes" => [
          %{"state" => "g", "probability_ppm" => 500_000},
          %{"state" => "s0", "probability_ppm" => 500_000}
        ]
      }
    ],
    "decomposition" => [],
    "notes" => []
  }

  @typedoc "Typed refusal carried by every failure path of this bridge."
  @type refused :: {:refused, %{required(:code) => atom(), optional(atom()) => term()}}

  @doc "The pinned artifact digest (pin court, W45)."
  @spec pinned_sha256() :: String.t()
  def pinned_sha256, do: @pinned_sha256

  @doc "The canonical artifact path in the ferroplan checkout."
  @spec artifact_path() :: String.t()
  def artifact_path, do: @artifact_path

  @doc "Exports the pinned module must provide (fp JSON ABI)."
  @spec required_exports() :: [String.t()]
  def required_exports, do: @required_exports

  @doc """
  Reads the artifact and verifies its digest against the pin. Fail-closed: a
  missing or unreadable artifact is the same typed refusal as a mutated one.
  """
  @spec artifact() :: {:ok, %{path: String.t(), bytes: binary(), sha256: String.t()}} | refused()
  def artifact do
    case File.read(@artifact_path) do
      {:ok, bytes} -> verify_bytes(bytes)
      {:error, reason} -> unreadable_refusal(reason)
    end
  end

  @doc """
  Judges arbitrary bytes against the pin — the exact gate `artifact/0` applies
  to the file. Returns `{:ok, %{path, bytes, sha256}}` only for pinned bytes.
  """
  @spec verify_bytes(binary()) ::
          {:ok, %{path: String.t(), bytes: binary(), sha256: String.t()}} | refused()
  def verify_bytes(bytes) when is_binary(bytes) do
    digest = sha256(bytes)

    if digest == @pinned_sha256 do
      {:ok, %{path: @artifact_path, bytes: bytes, sha256: digest}}
    else
      {:refused,
       %{
         code: :ferroplan_artifact_digest_mismatch,
         message: "artifact digest does not match the pin court pin",
         expected_sha256: @pinned_sha256,
         observed_sha256: digest,
         path: @artifact_path
       }}
    end
  end

  defp sha256(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)

  defp unreadable_refusal(reason) do
    {:refused,
     %{
       code: :ferroplan_artifact_digest_mismatch,
       message: "artifact unreadable at the canonical path (fail-closed)",
       expected_sha256: @pinned_sha256,
       reason: :file.format_error(reason),
       path: @artifact_path
     }}
  end

  @doc """
  Whether a wasm runtime is loadable in this vm. xaas does not declare wasmex
  in mix.exs (coordinator seam); today it is reachable transitively via
  ash_graphlaw, so this is a load probe, never an assumption.
  """
  @spec runtime_available?() :: boolean()
  def runtime_available? do
    Code.ensure_loaded?(Wasmex.Store) and Code.ensure_loaded?(Wasmex.Module) and
      Code.ensure_loaded?(Wasmex.Memory)
  end

  @doc """
  Digest-verified metadata about the pinned artifact (no wasm invocation).
  Refuses with the digest-mismatch envelope when the bytes are not the pin.
  """
  @spec metadata() :: {:ok, map()} | refused()
  def metadata do
    with {:ok, %{path: path, bytes: bytes, sha256: digest}} <- artifact(),
         {:ok, meta} <- describe_module(bytes) do
      {:ok,
       %{
         subject: Xaas.Bridges.subject(),
         authority_ceiling: :none,
         standing: "UNKNOWN",
         path: path,
         sha256: digest,
         exports: meta.exports,
         imports: meta.imports
       }}
    end
  end

  @doc """
  Runs one trivial plan-validate call through the pinned engine: the
  `fond_validate` op over the registry's own example problem/plan. Digest is
  verified first; a missing wasm runtime refuses with
  `:ferroplan_runtime_unavailable`.
  """
  @spec validate(keyword()) :: {:ok, map()} | refused()
  def validate(opts \\ []) when is_list(opts) do
    with {:ok, %{sha256: digest}} <- artifact(),
         :ok <- require_runtime(),
         {:ok, entry} <- compiled_module(digest) do
      request = %{
        "op" => "fond_validate",
        "problem" => @example_problem,
        "plan" => @example_plan
      }

      case call_abi(entry, request) do
        {:ok, response} ->
          envelope =
            Xaas.Bridges.envelope(Xaas.Bridges.subject(), "ferroplan fond_validate", :observed)

          {:ok,
           envelope
           |> Map.put(:provenance, %{
             engine_sha256: digest,
             op: response["op"] || "fond_validate",
             valid: response["valid"]
           })
           |> Map.put(:evidence_ref, "ferroplan.fp_call:fond_validate")
           |> Map.put(:response, response)}

        {:refused, _} = refused ->
          refused
      end
    else
      {:refused, _} = refused -> refused
    end
  end

  @doc """
  Runs one arbitrary op against the verified engine: `invoke(%{"op" => ...})`.
  Same admission order as `validate/1` — digest, runtime, then ABI.
  """
  @spec invoke(map()) :: {:ok, map()} | refused()
  def invoke(request) when is_map(request) do
    with {:ok, %{sha256: digest}} <- artifact(),
         :ok <- require_runtime(),
         {:ok, entry} <- compiled_module(digest) do
      case call_abi(entry, request) do
        {:ok, response} ->
          envelope =
            Xaas.Bridges.envelope(
              Xaas.Bridges.subject(),
              "ferroplan #{request["op"] || "fp_call"}",
              :observed
            )

          {:ok,
           envelope
           |> Map.put(:provenance, %{engine_sha256: digest, op: request["op"]})
           |> Map.put(:evidence_ref, "ferroplan.fp_call:#{request["op"] || "raw"}")
           |> Map.put(:response, response)}

        {:refused, _} = refused ->
          refused
      end
    else
      {:refused, _} = refused -> refused
    end
  end

  @doc "Drops the cached compiled module (test/ops hook)."
  @spec purge_cache() :: :ok
  def purge_cache do
    for {{__MODULE__, :compiled, _} = key, _} <- :persistent_term.get() do
      :persistent_term.erase(key)
    end

    :ok
  end

  # ---------------------------------------------------------------------
  # Runtime gate
  # ---------------------------------------------------------------------

  defp require_runtime do
    if runtime_available?() do
      :ok
    else
      {:refused,
       %{
         code: :ferroplan_runtime_unavailable,
         message:
           "no wasm runtime is loadable in this vm (wasmex is a transitive dep; " <>
             "declaring it in xaas mix.exs is the coordinator seam)",
         expected_sha256: @pinned_sha256
       }}
    end
  end

  # ---------------------------------------------------------------------
  # Compile + cache
  # ---------------------------------------------------------------------

  defp compiled_module(digest) do
    case :persistent_term.get({__MODULE__, :compiled, digest}, nil) do
      %{module: _module, engine: engine} = entry ->
        if engine_alive?(engine) do
          {:ok, Map.put(entry, :wasm_sha256, digest)}
        else
          :persistent_term.erase({__MODULE__, :compiled, digest})
          compile_and_cache(digest)
        end

      nil ->
        compile_and_cache(digest)
    end
  end

  defp engine_alive?(%Wasmex.Engine{}), do: true
  defp engine_alive?(_), do: false

  defp compile_and_cache(digest) do
    with {:ok, %{bytes: bytes}} <- artifact(),
         {:ok, engine} <- Wasmex.Engine.new(%Wasmex.EngineConfig{}),
         {:ok, store} <- Wasmex.Store.new(nil, engine),
         {:ok, module} <- Wasmex.Module.compile(store, bytes) do
      entry = %{
        wasm_sha256: digest,
        engine: engine,
        module: module,
        imports: Wasmex.Module.imports(module),
        exports: Wasmex.Module.exports(module)
      }

      :persistent_term.put({__MODULE__, :compiled, digest}, entry)
      {:ok, entry}
    else
      {:refused, _} = refused ->
        refused

      {:error, reason} ->
        {:refused,
         %{
           code: :ferroplan_engine_compile_failed,
           message: "pinned wasm bytes did not compile",
           expected_sha256: digest,
           reason: inspect(reason, limit: 5)
         }}
    end
  rescue
    error ->
      {:refused,
       %{
         code: :ferroplan_engine_compile_failed,
         message: "pinned wasm bytes did not compile",
         expected_sha256: digest,
         reason: Exception.message(error)
       }}
  end

  # ---------------------------------------------------------------------
  # The fp JSON ABI transaction (fresh WASI store + instance per invoke)
  # ---------------------------------------------------------------------

  defp call_abi(%{engine: engine, module: module}, request) do
    try do
      with {:ok, body} <- encode_request(request),
           {:ok, store, pid} <- instantiate(engine, module),
           {:ok, memory} <- Wasmex.memory(pid),
           {:ok, response} <- transact(store, memory, pid, body) do
        {:ok, response}
      else
        {:error, reason} ->
          {:refused,
           %{
             code: :ferroplan_abi_failure,
             message: "fp ABI transaction failed",
             reason: inspect(reason, limit: 5)
           }}
      end
    rescue
      error ->
        {:refused,
         %{
           code: :ferroplan_abi_failure,
           message: "fp ABI transaction failed",
           reason: Exception.message(error)
         }}
    catch
      :exit, reason ->
        {:refused,
         %{
           code: :ferroplan_abi_failure,
           message: "fp ABI transaction exited",
           reason: inspect(reason, limit: 5)
         }}
    after
      :ok
    end
  end

  defp encode_request(request) do
    case Jason.encode(request) do
      {:ok, body} ->
        {:ok, body}

      {:error, reason} ->
        {:refused,
         %{
           code: :ferroplan_abi_failure,
           message: "request not JSON-encodable: " <> Exception.message(reason)
         }}
    end
  end

  defp instantiate(engine, module) do
    memory_limits = %Wasmex.StoreLimits{
      memory_size: 512 * 1024 * 1024,
      table_elements: 4096,
      instances: 4,
      memories: 4,
      tables: 4
    }

    with {:ok, store} <- Wasmex.Store.new_wasi(%Wasmex.Wasi.WasiOptions{}, memory_limits, engine),
         {:ok, pid} <- start_instance(store, module) do
      {:ok, store, pid}
    end
  end

  defp start_instance(store, module) do
    Wasmex.start_link(%{store: store, module: module})
  catch
    :exit, reason -> {:error, reason}
  end

  defp transact(store, memory, pid, body) do
    len = byte_size(body)

    with {:ok, [ptr]} <- call_raw(pid, "fp_alloc", [len]),
         :ok <- Wasmex.Memory.write_binary(store, memory, ptr, body),
         {:ok, [packed]} <- call_raw(pid, "fp_call", [ptr, len]) do
      # fp_call consumes the request buffer; free only the response.
      {out_ptr, out_len} = unpack_result(packed)

      if out_ptr == 0 or out_len == 0 do
        {:refused,
         %{code: :ferroplan_abi_failure, message: "fp_call returned an empty result slot"}}
      else
        response = Wasmex.Memory.read_binary(store, memory, out_ptr, out_len)
        _ = call_raw(pid, "fp_dealloc", [out_ptr, out_len])
        decode_response(response)
      end
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp call_raw(pid, fun, params) do
    Wasmex.call_function(pid, fun, params, 30_000)
  catch
    :exit, reason -> {:error, reason}
  end

  defp unpack_result(packed) when is_integer(packed) do
    unsigned = if packed < 0, do: packed + @u64, else: packed
    {unsigned >>> 32 &&& @u32_mask, unsigned &&& @u32_mask}
  end

  defp decode_response(bytes) when is_binary(bytes) do
    if String.valid?(bytes) do
      case Jason.decode(bytes) do
        {:ok, %{} = response} ->
          {:ok, response}

        {:ok, _other} ->
          {:refused, %{code: :ferroplan_abi_failure, message: "response is not a JSON object"}}

        {:error, reason} ->
          {:refused,
           %{
             code: :ferroplan_abi_failure,
             message: "response not decodable: " <> Exception.message(reason)
           }}
      end
    else
      {:refused, %{code: :ferroplan_abi_failure, message: "response is not valid UTF-8"}}
    end
  end

  defp describe_module(bytes) do
    with {:ok, engine} <- Wasmex.Engine.new(%Wasmex.EngineConfig{}),
         {:ok, store} <- Wasmex.Store.new(nil, engine),
         {:ok, module} <- Wasmex.Module.compile(store, bytes) do
      {:ok,
       %{
         exports: Wasmex.Module.exports(module) |> Map.keys() |> Enum.sort(),
         imports: Wasmex.Module.imports(module) |> Map.keys() |> Enum.sort()
       }}
    end
  rescue
    error ->
      {:refused,
       %{
         code: :ferroplan_engine_compile_failed,
         message: "artifact bytes did not compile as a wasm module",
         reason: Exception.message(error)
       }}
  end
end
