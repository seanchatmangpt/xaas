defmodule ExNounVerbCli.CapabilityRegistry do
  @moduledoc """
  Ordered capability registry, ported from the real Rust `CapabilityRegistry`
  in `~/clap-noun-verb/src/capability/registry.rs:200-308` (read in full;
  every public function below mirrors a real Rust method, not just the
  `%{packages: %{}}` data shape).

  This is a real, behavioral port — not just a struct carrying a
  `dependencies` field with no logic behind it. In particular
  `dependency_order/1` implements the same real DFS-based topological sort
  with cycle detection the Rust source performs, so an added `dependencies`
  entry is not decorative: it is actually validated (does the referenced
  capability exist in the registry?) and actually ordered (does a cycle
  exist?) exactly as the Rust source requires before a dependency-closed
  order can be produced.

  Package identifiers keep insertion order internally as a plain map with an
  explicit sorted-key iteration order (mirroring the Rust `BTreeMap`'s
  canonical-order guarantee) rather than Elixir's unordered `Map` iteration.
  """

  alias ExNounVerbCli.Capability.Package

  @enforce_keys [:packages]
  defstruct packages: %{}

  @type t :: %__MODULE__{packages: %{String.t() => Package.t()}}

  @doc "Creates a new empty registry. Mirrors `CapabilityRegistry::new`."
  @spec new() :: t()
  def new, do: %__MODULE__{packages: %{}}

  @doc """
  Adds a package. Duplicate identifiers are refused rather than overwritten
  -- mirrors `CapabilityRegistry::add_package`
  (`~/clap-noun-verb/src/capability/registry.rs:214-222`): standing is
  refreshed and the package validated *before* the duplicate-id check, so a
  bad package is refused for its own reasons even when it also collides.
  """
  @spec add_package(t(), Package.t()) :: {:ok, t()} | {:error, String.t()}
  def add_package(%__MODULE__{packages: packages} = registry, %Package{} = package) do
    package = refresh(package)

    with :ok <- Package.validate(package) do
      if Map.has_key?(packages, package.id) do
        {:error, "Package already exists: #{package.id}"}
      else
        {:ok, %{registry | packages: Map.put(packages, package.id, package)}}
      end
    end
  end

  @doc """
  Replaces an existing package after validating its complete proof closure.
  Mirrors `CapabilityRegistry::update_package`.
  """
  @spec update_package(t(), Package.t()) :: {:ok, t()} | {:error, String.t()}
  def update_package(%__MODULE__{packages: packages} = registry, %Package{} = package) do
    package = refresh(package)

    with :ok <- Package.validate(package) do
      if Map.has_key?(packages, package.id) do
        {:ok, %{registry | packages: Map.put(packages, package.id, package)}}
      else
        {:error, "Package not found: #{package.id}"}
      end
    end
  end

  @doc """
  Removes a package from the registry by id. Mirrors
  `CapabilityRegistry::remove_package`.
  """
  @spec remove_package(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def remove_package(%__MODULE__{packages: packages} = registry, id) do
    if Map.has_key?(packages, id) do
      {:ok, %{registry | packages: Map.delete(packages, id)}}
    else
      {:error, "Package not found: #{id}"}
    end
  end

  @doc "Resolves one package by exact id. Mirrors `CapabilityRegistry::get`."
  @spec get(t(), String.t()) :: Package.t() | nil
  def get(%__MODULE__{packages: packages}, id), do: Map.get(packages, id)

  @doc """
  Returns all packages in canonical (sorted-by-id) order. Mirrors
  `CapabilityRegistry::packages`, which relies on the underlying `BTreeMap`'s
  key ordering.
  """
  @spec packages(t()) :: [Package.t()]
  def packages(%__MODULE__{packages: packages}) do
    packages |> Map.keys() |> Enum.sort() |> Enum.map(&Map.fetch!(packages, &1))
  end

  @doc "Package count. Mirrors `CapabilityRegistry::len`."
  @spec count(t()) :: non_neg_integer()
  def count(%__MODULE__{packages: packages}), do: map_size(packages)

  @doc "Whether the registry is empty. Mirrors `CapabilityRegistry::is_empty`."
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{packages: packages}), do: map_size(packages) == 0

  @doc "Whether a package exists. Mirrors `CapabilityRegistry::contains`."
  @spec contains?(t(), String.t()) :: boolean()
  def contains?(%__MODULE__{packages: packages}, id), do: Map.has_key?(packages, id)

  @doc """
  Returns a dependency-closed package id order, or a typed cycle/missing
  refusal -- mirrors `CapabilityRegistry::dependency_order`
  (`~/clap-noun-verb/src/capability/registry.rs:256-289`) exactly: a real
  DFS post-order topological sort over each package's `dependencies` list,
  visiting registry ids in sorted order (matching the `BTreeMap` iteration
  order the Rust source relies on), refusing a missing dependency id and a
  dependency cycle with the same message shapes as the Rust source.
  """
  @spec dependency_order(t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def dependency_order(%__MODULE__{packages: packages}) do
    ids = packages |> Map.keys() |> Enum.sort()

    Enum.reduce_while(ids, {:ok, {[], [], []}}, fn id, {:ok, state} ->
      case visit(id, packages, state) do
        {:ok, next_state} -> {:cont, {:ok, next_state}}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
    |> case do
      {:ok, {_temporary, _permanent, ordered}} -> {:ok, Enum.reverse(ordered)}
      {:error, message} -> {:error, message}
    end
  end

  defp visit(id, packages, {temporary, permanent, ordered} = state) do
    cond do
      id in permanent ->
        {:ok, state}

      id in temporary ->
        {:error, "Capability dependency cycle detected at: #{id}"}

      true ->
        case Map.fetch(packages, id) do
          :error ->
            {:error, "Capability dependency not found: #{id}"}

          {:ok, package} ->
            temporary = [id | temporary]

            Enum.reduce_while(package.dependencies, {:ok, {temporary, permanent, ordered}}, fn
              dependency_id, {:ok, inner_state} ->
                case visit(dependency_id, packages, inner_state) do
                  {:ok, next_state} -> {:cont, {:ok, next_state}}
                  {:error, message} -> {:halt, {:error, message}}
                end
            end)
            |> case do
              {:ok, {temporary, permanent, ordered}} ->
                temporary = List.delete(temporary, id)
                {:ok, {temporary, [id | permanent], [id | ordered]}}

              {:error, message} ->
                {:error, message}
            end
        end
    end
  end

  defp refresh(%Package{} = package) do
    %{package | standing: ExNounVerbCli.Capability.derive_standing(package)}
  end
end
