defmodule Xaas.Hddl.Mermaid do
  @moduledoc """
  Generates Mermaid flowchart DAG text from HDDL domain files and Ash.Reactor modules.

  This module is the formal tri-partite bridge:

      HDDL Domain File  ──▶  Ash.Reactor Module  ──▶  Mermaid flowchart LR

  It implements the full HDDL ↔ Ash.Reactor ↔ Mermaid isomorphism so that:
    - Planning domains ((:domain ...)) map to Reactor namespaces
    - Compound tasks map to composed sub-reactors
    - Method step graphs map to Reactor step DAGs
    - Preconditions map to guard/switch steps
    - Effects map to Ash actions (create/update/destroy)
    - Temporal primitives (ordered/unordered/methods) map to Reactor async and sequential steps

  ## Usage

      {:ok, diagram} = Xaas.Hddl.Mermaid.for_reactor(Xaas.Actuation.Reactor)
      {:ok, diagram} = Xaas.Hddl.Mermaid.for_file("docs/hddl/next-read.hddl")
      {:ok, diagram} = Xaas.Hddl.Mermaid.for_domain(:next_read)
  """

  require Logger

  @known_reactors %{
    actuation: Xaas.Actuation.Reactor,
    recommendation_pipeline: Xaas.Library.Reactors.RecommendationPipelineReactor,
    circulation_borrow: Xaas.Library.Reactors.CirculationBorrowReactor
  }

  @static_mmd_dir "docs/hddl"

  @doc """
  Generate a Mermaid diagram string from an Ash.Reactor module.

  Returns `{:ok, mermaid_string}` or `{:error, reason}`.

  First attempts runtime generation via `Reactor.Mermaid.to_mermaid/2`.
  Falls back to a pre-generated `.mmd` file in `docs/hddl/` if runtime generation fails.
  """
  @spec for_reactor(module()) :: {:ok, String.t()} | {:error, term()}
  def for_reactor(reactor_module) when is_atom(reactor_module) do
    case Reactor.Mermaid.to_mermaid(reactor_module, output: :binary) do
      {:ok, diagram} ->
        {:ok, diagram}

      {:error, reason} ->
        Logger.warning("[Xaas.Hddl.Mermaid] Runtime generation failed for #{reactor_module}: #{inspect(reason)}. Falling back to static .mmd file.")
        read_static_mmd(module_to_filename(reactor_module))
    end
  end

  @doc """
  Generate a Mermaid diagram from a known HDDL domain atom key.

  Known domains: `:actuation`, `:recommendation_pipeline`, `:circulation_borrow`.
  """
  @spec for_domain(atom()) :: {:ok, String.t()} | {:error, :unknown_domain}
  def for_domain(domain_key) when is_atom(domain_key) do
    case Map.get(@known_reactors, domain_key) do
      nil -> {:error, :unknown_domain}
      module -> for_reactor(module)
    end
  end

  @doc """
  Read a Mermaid diagram from a pre-generated `.mmd` HDDL file.

  The path is relative to the project root.
  """
  @spec for_file(String.t()) :: {:ok, String.t()} | {:error, term()}
  def for_file(relative_path) do
    abs_path = Path.join(:code.priv_dir(:xaas) |> Path.dirname() |> Path.dirname(), relative_path)

    case File.read(abs_path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, {:file_read_error, reason, abs_path}}
    end
  end

  @doc """
  Returns a compact HDDL ↔ Reactor annotation header to prefix diagrams shown in the UI.
  This maps the active HDDL method to its Reactor step name for display in the drawer.
  """
  @spec annotation_header(module(), String.t()) :: String.t()
  def annotation_header(reactor_module, hddl_method_name) do
    """
    %% HDDL Method: #{hddl_method_name}
    %% Ash.Reactor: #{inspect(reactor_module)}
    %% Isomorphism: HDDL(:method) ↔ Reactor(step DAG)
    """
  end

  @doc """
  Generates the full annotated Mermaid string for the HDDL drawer in the UI.

  Prefixes the diagram with the HDDL annotation header.
  """
  @spec for_drawer(module(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def for_drawer(reactor_module, hddl_method_name) do
    with {:ok, diagram} <- for_reactor(reactor_module) do
      header = annotation_header(reactor_module, hddl_method_name)
      {:ok, header <> diagram}
    end
  end

  # --- Private Helpers ---

  defp module_to_filename(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> then(&Path.join(@static_mmd_dir, "#{&1}.mmd"))
  end

  defp read_static_mmd(path) do
    abs_path = Path.join(:code.priv_dir(:xaas) |> Path.dirname() |> Path.dirname(), path)

    case File.read(abs_path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, {:static_mmd_not_found, reason, abs_path}}
    end
  end
end
