defmodule Xaas.Ultracode.ProviderHealth do
  @moduledoc """
  Is the zcode provider able to run a worker right now? One call, one typed
  answer, so the autonomic loop can gate lease issuance on it instead of
  discovering a broken CLI checkout or an old Node one refused epoch at a time
  (the 2026-09-20 wave-1 falsifier: every launch refused in <1ms while the
  campaign kept burning attempts).

  It resolves the CLI dir and Node executable exactly the way
  `Xaas.Ultracode.Dispatch` does (option, then app env
  `:ultracode_dispatch_cli_dir` / `:ultracode_dispatch_node_path`, then the
  default dir / a PATH lookup) and then delegates the contract check to
  `Xaas.Ultracode.ZcodePackage.verify_node/2` -- the package.json admission
  plus a measured `<node> --version`. It grants no authority, starts no worker
  and writes nothing.

      {:ok, %{zcode_version: "3.12.3-26", zcode_bin: "bin/zcode.js", node_version: "26.8.1"}}
      {:error, {:cli_unavailable, path}}
      {:error, {:zcode_package_invalid, path, reason}}
      {:error, {:node_unavailable, "node"}}
      {:error, {:node_version_unreadable, node, "timeout after 5000ms"}}
      {:error, {:node_too_old, node, "20.0.0", ">=22.19.0"}}
  """

  alias Xaas.Ultracode.ZcodePackage

  @type health :: %{zcode_version: String.t(), zcode_bin: String.t(), node_version: String.t()}

  @doc """
  Options: `:cli_dir`, `:node_path` (same fallbacks as `Dispatch.run/1`),
  `:node_version_timeout_ms` (deadline for the `node --version` probe,
  default `ZcodePackage.default_version_timeout_ms/0`), and `:provider`
  (registry key; when the provider's `:ultracode_providers` entry pins a
  `transport` with `:cli_dir`/`:node_path`, that pin sits BETWEEN the
  explicit option and the app-env default in the fallback chain -- a
  provider-specific pin wins over the global env, an explicit option wins
  over everything). The whole call is bounded: a hung node yields
  `{:error, {:node_version_unreadable, node, "timeout after Nms"}}`.
  """
  @spec check(keyword()) :: {:ok, health()} | {:error, term()}
  def check(opts \\ []) do
    transport = transport_pin(opts[:provider])

    cli_dir =
      Keyword.get(opts, :cli_dir) ||
        Keyword.get(transport, :cli_dir) ||
        Application.get_env(:xaas, :ultracode_dispatch_cli_dir, ZcodePackage.default_cli_dir())

    node_path =
      Keyword.get(opts, :node_path) ||
        Keyword.get(transport, :node_path) ||
        Application.get_env(:xaas, :ultracode_dispatch_node_path, nil) ||
        System.find_executable("node")

    with {:ok, pkg} <- ZcodePackage.load(cli_dir),
         {:ok, node_path} <- node_exe(node_path),
         {:ok, found} <-
           ZcodePackage.verify_node(
             pkg,
             node_path,
             Keyword.take(opts, [:node_version_timeout_ms])
           ) do
      {:ok,
       %{
         zcode_version: pkg.version,
         zcode_bin: pkg.bin,
         node_version: ZcodePackage.version_string(found)
       }}
    end
  end

  @doc """
  Lease gate: `:ok` when the provider can run a worker, otherwise
  `{:error, {:provider_unhealthy, typed_reason}}` -- the shape an issuer
  refuses with. When `opts[:provider]` names a provider that is DISABLED in
  the registry, the gate refuses without probing anything (a disabled
  provider is not able to run a worker, by operator order, whatever its CLI
  checkout looks like). An UNKNOWN provider falls through to the transport
  probes (the registry is selection's gate, not health's: an unregistered
  provider keeps the historical probe-only behavior).
  """
  @spec gate(keyword()) :: :ok | {:error, {:provider_unhealthy, term()}}
  def gate(opts \\ []) do
    with :ok <- registry_enabled?(opts[:provider]),
         {:ok, _health} <- check(opts) do
      :ok
    else
      {:error, {:provider_disabled, _} = reason} ->
        {:error, {:provider_unhealthy, reason}}

      {:error, reason} ->
        {:error, {:provider_unhealthy, reason}}
    end
  end

  defp registry_enabled?(nil), do: :ok

  defp registry_enabled?(provider) do
    case Xaas.Ultracode.ProviderRegistry.lookup(provider) do
      {:ok, entry} ->
        if Map.get(entry, :enabled, true) do
          :ok
        else
          {:error, {:provider_disabled, provider}}
        end

      # Unregistered: not health's fence (see `gate/1` doc).
      {:error, {:unknown_provider, _}} ->
        :ok
    end
  end

  # The provider's registry transport pin, when it is a keyword-shaped map.
  # A descriptor-only transport (string or map without :cli_dir/:node_path)
  # contributes nothing.
  defp transport_pin(nil), do: []

  defp transport_pin(provider) do
    case Xaas.Ultracode.ProviderRegistry.lookup(provider) do
      {:ok, %{transport: transport}} when is_map(transport) ->
        Keyword.take(Enum.to_list(transport), [:cli_dir, :node_path])

      _ ->
        []
    end
  end

  defp node_exe(nil), do: {:error, {:node_unavailable, "node"}}

  # Same resolvability check (and same typed refusal) as `Dispatch`.
  defp node_exe(path) when is_binary(path) do
    if System.find_executable(path) || File.exists?(path),
      do: {:ok, path},
      else: {:error, {:node_unavailable, path}}
  end

  defp node_exe(_), do: {:error, {:node_unavailable, "node"}}
end
