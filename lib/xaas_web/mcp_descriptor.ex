defmodule XaasWeb.McpDescriptor do
  @moduledoc """
  Per-capability metadata for `Xaas`'s MCP+A2A surface:
  observation scope, mutation scope, authority requirement, reversibility,
  cost, and receipt semantics -- the real implementation of
  v2030:MCPCapabilityDescriptor (docs/ontology/vision-2030.ttl) for this
  surface's full capability list (both exposedVia "mcp" and "a2a" rows).

  Regenerate with:

      cd ~/ggen_igniter && mix ggen_igniter.sync \\
        --ontology /Users/sac/xaas/priv/ggen_igniter/mcp_a2a/xaas-surface.ttl \\
        --query spec=/Users/sac/xaas/priv/ggen_igniter/mcp_a2a/surface.rq \\
        --query caps=/Users/sac/xaas/priv/ggen_igniter/mcp_a2a/capabilities.rq \\
        --template /Users/sac/xaas/priv/ggen_igniter/mcp_a2a/templates/mcp_descriptor.eex \\
        --out /Users/sac/xaas/lib/xaas_web/mcp_descriptor.ex
  """

  @capabilities %{
    :list_books => %{
      name: "List books",
      description: "List books for a grade band (HDDL task: MCP-INSPECT-CATALOG)",
      exposed_via: :mcp,
      observation_scope: :read_only,
      mutation_scope: :none,
      requires_authority: false,
      reversible: true,
      receipt_semantics: :none,
      ash_action: "Xaas.Library.list_books/1"
    },
    :books_by_grade_band => %{
      name: "Books by grade band",
      description: "Filter books by grade band",
      exposed_via: :mcp,
      observation_scope: :read_only,
      mutation_scope: :none,
      requires_authority: false,
      reversible: true,
      receipt_semantics: :none,
      ash_action: "Xaas.Library.books_by_grade_band/1"
    },
    :active_curations_for_grade => %{
      name: "Active curations for grade",
      description: "List active curated collections for a grade band",
      exposed_via: :mcp,
      observation_scope: :read_only,
      mutation_scope: :none,
      requires_authority: false,
      reversible: true,
      receipt_semantics: :none,
      ash_action: "Xaas.Library.active_curations_for_grade/1"
    },
    :browse => %{
      name: "Browse books",
      description:
        "List books for a grade band as a given user actor (HDDL task: MCP-INSPECT-CATALOG)",
      exposed_via: :a2a,
      observation_scope: :read_only,
      mutation_scope: :none,
      requires_authority: false,
      reversible: true,
      receipt_semantics: :none,
      ash_action: nil
    },
    :checkout => %{
      name: "Checkout a book",
      description:
        "Borrow a book as a given user actor (HDDL task: A2A-SIMULATE-USER-CIRCULATION / checkout-book)",
      exposed_via: :a2a,
      observation_scope: :read_write,
      mutation_scope: :consequential,
      requires_authority: true,
      reversible: true,
      receipt_semantics: :sealed_receipt,
      ash_action: nil
    },
    :"hddl-plan" => %{
      name: "HDDL Plan Inspection",
      description:
        "Inspect the formal HDDL compound tasks, methods, and epistemic receipts for Next Read",
      exposed_via: :a2a,
      observation_scope: :read_only,
      mutation_scope: :none,
      requires_authority: false,
      reversible: true,
      receipt_semantics: :none,
      ash_action: nil
    }
  }

  @doc "Full descriptor list, e.g. for an MCP `tools/list` or A2A agent-card response."
  @spec capabilities() :: %{atom() => map()}
  def capabilities, do: @capabilities

  @doc "Descriptor for one capability id, or `:error` if unregistered."
  @spec describe(atom()) :: {:ok, map()} | :error
  def describe(capability_id), do: Map.fetch(@capabilities, capability_id)

  @doc """
  Real, fail-closed authority check: an unregistered capability id is
  treated as requiring authority (returns true), per xaas's own
  deny-by-default policy doctrine -- never silently permissive for a
  capability this descriptor doesn't know about.
  """
  @spec requires_authority?(atom()) :: boolean()
  def requires_authority?(capability_id) do
    case describe(capability_id) do
      {:ok, %{requires_authority: r}} -> r
      :error -> true
    end
  end
end
