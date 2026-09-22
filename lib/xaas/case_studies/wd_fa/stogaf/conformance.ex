defmodule Xaas.CaseStudies.WdFa.Stogaf.Conformance do
  @moduledoc false

  @levels [
    %{level: "ST-0", name: "DOCUMENTED", standing: "ALIVE"},
    %{level: "ST-1", name: "ADDRESSABLE", standing: "ALIVE"},
    %{level: "ST-2", name: "LINKED", standing: "ALIVE"},
    %{level: "ST-3", name: "PROVENANCED", standing: "ALIVE"},
    %{level: "ST-4", name: "CONSTRAINED", standing: "ALIVE"},
    %{level: "ST-5", name: "GENERATED", standing: "PARTIAL_ALIVE"},
    %{level: "ST-6", name: "AUTONOMIC", standing: "PARTIAL_ALIVE"},
    %{level: "ST-7", name: "ACTUATED", standing: "UNKNOWN"},
    %{level: "ST-8", name: "CLOSED_LOOP", standing: "UNKNOWN"},
    %{level: "ST-9", name: "LEARNING", standing: "UNKNOWN"}
  ]

  @spec all() :: [map()]
  def all, do: @levels

  @spec current() :: String.t()
  def current, do: "ST-4 CONSTRAINED"

  @spec target() :: String.t()
  def target, do: "ST-6 AUTONOMIC"

  @spec production_unknown_count() :: non_neg_integer()
  def production_unknown_count do
    Enum.count(@levels, fn item ->
      item.level in ["ST-7", "ST-8", "ST-9"] and item.standing == "UNKNOWN"
    end)
  end
end
