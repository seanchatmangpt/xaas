defmodule Xaas.Repo.Migrations.AddDomainSolverToAutofdePlannerCandidates do
  @moduledoc """
  Adds optional `domain`/`solver` override columns to
  `autofde_planner_candidates`, needed so `Xaas.Operations.AutofdePlannerCandidate`'s
  `request_candidate` action can be invoked with a real, non-PDDLDomain
  domain (e.g. "Maze") instead of always sending the hardcoded
  domain="PDDLDomain"/solver="Astar" pair.

  Hand-written and scoped to only this resource's real, needed change --
  `mix ash_postgres.generate_migrations` also picked up pre-existing,
  unrelated schema drift (autofde_planner_match_requests/
  autofde_planner_cache_stats_requests/autofde_planner_cache_hotset_requests
  table creation, platform_webhooks/tokens encrypted-column renames) that
  predates this task and is out of scope here.
  """

  use Ecto.Migration

  def up do
    alter table(:autofde_planner_candidates) do
      add :domain, :text
      add :solver, :text
    end
  end

  def down do
    alter table(:autofde_planner_candidates) do
      remove :solver
      remove :domain
    end
  end
end
