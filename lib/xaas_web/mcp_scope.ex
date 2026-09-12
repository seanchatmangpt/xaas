defmodule XaasWeb.McpScope do
  @moduledoc """
  Generated MCP router scope for `Xaas`, from
  priv/ggen_igniter/mcp_a2a/xaas-surface.ttl. Mount in your router:

      import XaasWeb.McpScope

      # This surface names an audit plug (XaasWeb.Plugs.AuditMcpToolCall).
      # `plug` is only valid inside a named `pipeline do ... end` block in
      # Phoenix's router DSL, never directly inside `scope` -- this macro
      # cannot inject a pipeline declaration from a scope call site, so
      # define (or confirm you already have) this pipeline yourself and
      # add its name to pipe_through below, the same way xaas's own real
      # router.ex:37 defines `pipeline :audit_mcp_tool_call do plug
      # XaasWeb.Plugs.AuditMcpToolCall end` and references it by name:
      #
      #   pipeline :audit_mcp_tool_call do
      #     plug XaasWeb.Plugs.AuditMcpToolCall
      #   end

      scope "/mcp" do
        pipe_through([:api, :require_internal_api_token, :resolve_org_actor, :audit_mcp_tool_call])
        XaasWeb.McpScope.mount()
      end

  Real tools exposed: `:list_books`, `:books_by_grade_band`, `:active_curations_for_grade`.

  NOTE: this macro's own `mount/0` body does NOT wire the audit plug --
  `plug` is invalid inside `scope`. The `:audit_mcp_tool_call` pipeline
  above (which you must define) is what actually applies it, via
  `pipe_through`, exactly as shown.

  Regenerate with:

      cd ~/ggen_igniter && mix ggen_igniter.sync \\
        --ontology /Users/sac/xaas/priv/ggen_igniter/mcp_a2a/xaas-surface.ttl \\
        --query spec=/Users/sac/xaas/priv/ggen_igniter/mcp_a2a/surface.rq \\
        --query caps=/Users/sac/xaas/priv/ggen_igniter/mcp_a2a/mcp_capabilities.rq \\
        --template /Users/sac/xaas/priv/ggen_igniter/mcp_a2a/templates/mcp_scope.eex \\
        --out /Users/sac/xaas/lib/xaas_web/mcp_scope.ex
  """

  defmacro mount do
    quote do
      forward("/", AshAi.Mcp.Router,
        tools: [:list_books, :books_by_grade_band, :active_curations_for_grade],
        protocol_version_statement: "2024-11-05",
        otp_app: :xaas
      )
    end
  end
end
