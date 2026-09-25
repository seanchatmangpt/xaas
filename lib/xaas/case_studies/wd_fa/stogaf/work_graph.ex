defmodule Xaas.CaseStudies.WdFa.Stogaf.WorkGraph do
  @moduledoc false

  @orders [
    %{id: "SJ-011", deps: []},
    %{id: "SJ-012", deps: ["SJ-011"]},
    %{id: "SJ-013", deps: ["SJ-012"]},
    %{id: "SJ-014", deps: ["SJ-013"]},
    %{id: "SJ-015", deps: ["SJ-013"]},
    %{id: "SJ-016", deps: ["SJ-015"]},
    %{id: "SJ-017", deps: ["SJ-013", "SJ-014", "SJ-016"]},
    %{id: "SJ-018", deps: ["SJ-017"]},
    %{id: "SJ-019", deps: ["SJ-018"]},
    %{id: "SJ-020", deps: ["SJ-019"]}
  ]

  @spec all() :: [map()]
  def all, do: @orders

  @spec count() :: non_neg_integer()
  def count, do: length(@orders)

  @spec entry() :: String.t()
  def entry, do: "SJ-011"

  @spec terminal() :: String.t()
  def terminal, do: "SJ-020"

  @spec acyclic?() :: boolean()
  def acyclic? do
    ids = MapSet.new(Enum.map(@orders, & &1.id))

    Enum.all?(@orders, fn order ->
      Enum.all?(order.deps, &MapSet.member?(ids, &1))
    end) and no_self_dependencies?()
  end

  defp no_self_dependencies? do
    Enum.all?(@orders, fn order -> order.id not in order.deps end)
  end
end
