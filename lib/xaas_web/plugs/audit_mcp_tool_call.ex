defmodule XaasWeb.Plugs.AuditMcpToolCall do
  @moduledoc """
  Real, minimal fix for the closed ERRC item "close the `/mcp`
  actor-resolution gap": `Xaas.Library.Book`/`Curation` reads are
  `policy action_type(:read) do authorize_if always() end`
  (`book.ex:134-139`, `curation.ex:66-71`) and `:resolve_org_actor` is a
  confirmed no-op on `/mcp` traffic (see the real finding documented at
  `XaasWeb.Router`'s `/mcp` scope, `router.ex:66-95`) -- no actor/tenant
  is ever set for an MCP caller. Cycle 0138 correctly blocked a full
  tenant-filter redesign of the read policy as scope creep; the smallest
  real fix is observability, not a policy change: this plug writes one
  real `Xaas.Operations.AuditLogEntry` row per `/mcp` HTTP request,
  recording the bearer-token-derived caller identity, before the request
  is forwarded into `AshAi.Mcp.Router`. The read policy itself
  (`authorize_if always()`) is deliberately left untouched.

  ## Caller identity

  This repo has no per-user identity on `/mcp` requests (same
  "no per-user identity on the request path" limitation
  `Xaas.Operations.AuditLogEntry`'s own moduledoc and
  `XaasWeb.Plugs.ResolveOrgActor`'s moduledoc already document for
  `/api`). The one real, available identifying signal on this path is
  the bearer token itself -- this plug hashes it (SHA-256, hex) so the
  audit row identifies "which token" without persisting the literal
  secret in a queryable table. This mirrors
  `Xaas.Library.Changes.WriteActorResolutionAudit`'s "best-effort caller
  identity" precedent on the sibling A2A pipeline (a different feature,
  a different pipeline, but the identical convention: audit what is
  knowable now, don't block on a full identity system).

  ## Placement

  Must run after `:require_internal_api_token` (so only requests
  carrying a validated bearer token reach here) and before
  `AshAi.Mcp.Router` is forwarded to, so every real MCP invocation is
  audited exactly once regardless of which of the 3 registered tools
  (`list_books`, `books_by_grade_band`, `active_curations_for_grade`) is
  ultimately called -- the plug audits the HTTP call itself rather than
  instrumenting each tool individually, since `AshAi.Mcp.Router` is a
  vendored `forward`, not code this repo owns to wrap per-tool.

  A failed audit write is logged and does NOT halt or fail the real
  request -- the same non-blocking-audit stance
  `Xaas.Library.Changes.WriteActorResolutionAudit`'s moduledoc states
  for its own failure mode, for the identical reason: an audit-log
  outage must not become a de facto denial-of-service for legitimate
  MCP reads.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    caller_id = caller_id(conn)

    case Xaas.Operations.AuditLogEntry
         |> Ash.Changeset.for_create(
           :create,
           %{
             actor_id: caller_id,
             actor_description: "mcp caller #{caller_id}",
             action: "mcp.tool_call.invoked",
             resource_type: "McpRequest",
             resource_id: conn.request_path,
             occurred_at: DateTime.utc_now(),
             metadata: %{
               "caller_id" => caller_id,
               "method" => conn.method,
               "path" => conn.request_path,
               "query_string" => conn.query_string
             }
           },
           authorize?: false
         )
         |> Ash.create() do
      {:ok, _entry} ->
        conn

      {:error, error} ->
        Logger.warning(
          "AuditMcpToolCall: failed to write audit_log_entry for /mcp caller #{caller_id}: #{inspect(error)}"
        )

        conn
    end
  end

  # Real, best-effort caller identity: a SHA-256 hex digest of the
  # validated bearer token (validated by `:require_internal_api_token`,
  # which always runs first in the `/mcp` pipeline -- see
  # `router.ex`'s `/mcp` scope). Hashed rather than stored raw so the
  # audit log itself never becomes a second place the literal secret
  # lives. Falls back to "unknown" only if this plug were ever reached
  # without a bearer header, which the pipeline ordering above prevents
  # in production.
  defp caller_id(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when byte_size(token) > 0 ->
        "token:" <> (:crypto.hash(:sha256, token) |> Base.encode16(case: :lower) |> binary_part(0, 16))

      _ ->
        "unknown"
    end
  end
end
