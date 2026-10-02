defmodule Xaas.Chicago do
  @moduledoc """
  Consumer facade over the Chicago projections (resolution R4,
  `docs/sjira/v26.10.1/RESOLUTIONS.md`).

  This is the projection side only: it reads, validates and serves the four
  rendered JSON artifacts under `priv/chicago/`. It never folds runtime state
  — L5 folds `Xaas.Ultracode.*` / `Xaas.Ocel.*` observations itself — and it
  never promotes standing: every value served here is what the machine
  projection says, which is `"UNKNOWN"` until a real receipt binds observed
  execution (R8).

  Every public function returns `{:ok, value}` or
  `{:refused, {:chicago_*, reason}}` — the surface fails closed when
  `priv/chicago/` is absent (nothing is rendered yet) or a projection fails
  identity validation (`Xaas.Chicago.Projection`).
  """

  alias Xaas.Chicago.{Case, Layer, Projection, Subject, View}

  @priv_relative "priv/chicago"

  @doc "The exact Chicago subject literal."
  @spec subject :: {:ok, String.t()}
  def subject, do: {:ok, Subject.literal()}

  @doc "The machine projection (R2 schema), validated."
  def machine, do: load(:machine)

  @doc "The verification matrix projection, validated."
  def verification, do: load(:verification)

  @doc "The executive narrative projection, validated."
  def executive, do: load(:executive)

  @doc "The replay manifest projection, validated."
  def replay, do: load(:replay)

  @doc "All contract layers in contract order (machine projection)."
  @spec layers :: {:ok, [map]} | {:refused, {atom, term}}
  def layers do
    with {:ok, m} <- machine(), do: {:ok, Layer.list(m)}
  end

  @doc "One contract layer by id (atom or string)."
  @spec layer(atom | String.t()) :: {:ok, map} | {:refused, {atom, term}}
  def layer(id) do
    with {:ok, m} <- machine(), do: Layer.fetch(m, id)
  end

  @doc "The 10 contract layer slugs in presentation order."
  @spec required_layers :: {:ok, [Layer.id()]}
  def required_layers, do: {:ok, Layer.required_ids()}

  @doc "All candidate cases from the machine projection."
  @spec cases :: {:ok, [map]} | {:refused, {atom, term}}
  def cases do
    with {:ok, m} <- machine(), do: {:ok, Case.list(m)}
  end

  @doc "One candidate case by id, e.g. `\"CHI-CASE-001\"`."
  @spec case(String.t()) :: {:ok, map} | {:refused, {atom, term}}
  # `case` is an Elixir special form: the name is bound via unquote so the
  # R4-mandated `Xaas.Chicago.case/1` exists; callers use the remote call.
  def unquote(:case)(id) do
    with {:ok, m} <- machine(), do: Case.fetch(m, id)
  end

  @doc "L6 drill-down view (subject, business outcome, 10 layers)."
  defdelegate drill_down, to: View

  @doc """
  Drop the memoized DEFAULT-path projections and reload (the invalidation scope
  of this facade — fixture/explicit-path memos are untouched, so concurrent
  readers of other paths are never disturbed). Returns the reloaded machine
  result. Call after the render task writes new artifacts.
  """
  @spec reload :: {:ok, map} | {:refused, {atom, term}}
  def reload do
    for type <- [:machine, :verification, :executive, :replay] do
      Projection.clear_memo(type, path_for(type))
    end

    machine()
  end

  @doc "Load one projection type by default path (memoized)."
  @spec load(atom) :: {:ok, map} | {:refused, {atom, term}}
  def load(type) when type in [:machine, :verification, :executive, :replay] do
    Projection.load_memoized(type, path_for(type))
  end

  @doc "Load one projection type from an explicit path (memoized per path)."
  @spec load_projection(atom, String.t()) :: {:ok, map} | {:refused, {atom, term}}
  def load_projection(type, path) when type in [:machine, :verification, :executive, :replay] do
    Projection.load_memoized(type, path)
  end

  @doc "Default path of a projection artifact (release- and dev-safe resolution)."
  @spec path_for(atom) :: String.t()
  def path_for(type) when type in [:machine, :verification, :executive, :replay] do
    file = "chicago.#{type}.json"
    cwd = Path.join([File.cwd!(), @priv_relative, file])

    candidates =
      case safe_app_dir() do
        {:ok, dir} -> [Path.join([dir, @priv_relative, file]), cwd]
        :error -> [cwd]
      end

    Enum.find(candidates, &File.exists?/1) || hd(candidates)
  end

  # The :xaas app spec is absent outside a booted mix/release context; the
  # facade degrades to the working tree instead of raising.
  defp safe_app_dir do
    {:ok, Application.app_dir(:xaas)}
  rescue
    _ -> :error
  end
end
