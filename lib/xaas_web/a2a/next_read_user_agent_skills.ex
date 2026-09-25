defmodule XaasWeb.A2A.NextReadUserAgentSkills do
  @moduledoc """
  Generated A2A skills list for `NextReadUserAgent`, from
  priv/ggen_igniter/mcp_a2a/xaas-surface.ttl's ema:Capability rows with
  ema:exposedVia "a2a" or "both". Regenerate with:

      cd ~/ggen_igniter && mix ggen_igniter.sync \\
        --ontology /Users/sac/xaas/priv/ggen_igniter/mcp_a2a/xaas-surface.ttl \\
        --query spec=/Users/sac/xaas/priv/ggen_igniter/mcp_a2a/surface.rq \\
        --query caps=/Users/sac/xaas/priv/ggen_igniter/mcp_a2a/a2a_capabilities.rq \\
        --template /Users/sac/xaas/priv/ggen_igniter/mcp_a2a/templates/a2a_skills.eex \\
        --out /Users/sac/xaas/lib/xaas_web/a2a/next_read_user_agent_skills.ex

  Edit XaasWeb.A2A.NextReadUserAgent (real dispatch) directly; do NOT edit
  this file -- it is fully regenerated, never hand-patched.
  """

  @skills [
    %{
      id: "browse",
      name: "Browse books",
      description:
        "List books for a grade band as a given user actor (HDDL task: MCP-INSPECT-CATALOG)",
      tags: ["next-read", "library", "hddl"]
    },
    %{
      id: "checkout",
      name: "Checkout a book",
      description:
        "Borrow a book as a given user actor (HDDL task: A2A-SIMULATE-USER-CIRCULATION / checkout-book)",
      tags: ["next-read", "library", "hddl"]
    },
    %{
      id: "hddl-plan",
      name: "HDDL Plan Inspection",
      description:
        "Inspect the formal HDDL compound tasks, methods, and epistemic receipts for Next Read",
      tags: ["next-read", "hddl", "calculus"]
    }
  ]

  @doc "The real skills list for use in `use A2A.Agent, skills: ...`."
  @spec skills() :: [map()]
  def skills, do: @skills
end
