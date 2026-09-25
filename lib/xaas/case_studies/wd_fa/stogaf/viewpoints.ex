defmodule Xaas.CaseStudies.WdFa.Stogaf.Viewpoints do
  @moduledoc false

  @viewpoints [
    %{
      id: "fa-engineer",
      view: "FA Morning Brief",
      concern: "what requires engineer judgment now"
    },
    %{
      id: "fa-manager",
      view: "FA Operating Board",
      concern: "queue blockers evidence and throughput"
    },
    %{id: "executive", view: "FA Agent Board Deck", concern: "value risk adoption and decision"},
    %{
      id: "architecture",
      view: "System / Space",
      concern: "canonical state projections authority and reuse"
    },
    %{
      id: "assessment",
      view: "WD Case Study 2 Deck",
      concern: "requirements tradeoffs evidence and delivery"
    }
  ]

  @spec all() :: [map()]
  def all, do: @viewpoints

  @spec count() :: non_neg_integer()
  def count, do: length(@viewpoints)
end
