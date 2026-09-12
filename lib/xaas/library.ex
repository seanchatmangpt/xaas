defmodule Xaas.Library do
  @moduledoc """
  Domain module for Library management (Books, Checkouts, Holds, Curations, RecommendationLogs, PersonaGrants)
  grounded in Schema.org, BIBO, PROV ontologies and formal HDDL Task Calculus (docs/hddl/next-read.hddl).
  """
  use Ash.Domain,
    otp_app: :xaas,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain, AshAi]

  admin do
    show? true
  end

  # Exposed to the Ash AI MCP server (router.ex `/mcp` scope). Read-only
  # query actions only -- no create/update/destroy tools -- mapping directly to
  # the HDDL `MCP-INSPECT-CATALOG` compound task.
  # Preconditions and access rules are enforced by each resource's Ash policies.
  tools do
    tool :list_books, Xaas.Library.Book, :read
    tool :books_by_grade_band, Xaas.Library.Book, :by_grade_band
    tool :active_curations_for_grade, Xaas.Library.Curation, :active_for_grade
  end

  resources do
    resource Xaas.Library.Book
    resource Xaas.Library.Checkout
    resource Xaas.Library.HoldRequest
    resource Xaas.Library.Curation
    resource Xaas.Library.RecommendationLog
    resource Xaas.Library.School
    resource Xaas.Library.PersonaGrant
  end
end
