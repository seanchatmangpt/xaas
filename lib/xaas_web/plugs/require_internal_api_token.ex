defmodule XaasWeb.Plugs.RequireInternalApiToken do
  @moduledoc """
  Real auth gate for `/internal-api` and `/api` (found genuinely missing
  by an adversarial review of this session's work: both prefixes had
  zero auth plug, reachable by anyone with network access to the host).

  ## Real, investigated exposure posture (not assumed)

  `config/runtime.exs` binds the production `XaasWeb.Endpoint` to
  `ip: {0, 0, 0, 0, 0, 0, 0, 0}` (real-read, line ~102) and `fly.toml`'s
  `[http_service]` block declares only `internal_port = 4000` and
  `force_https = true` -- no private-only/6PN-only restriction anywhere in
  that file. `config/dev.exs` binds to `127.0.0.1` only (real-read, line
  64) -- local dev is genuinely not reachable off-host. So: this route is
  localhost-only in dev, but real-network-reachable (any client that can
  reach the Fly-assigned public hostname) whenever this app is actually
  deployed via `fly deploy`, which is exactly the premise a token-rotation
  story has to take seriously.

  ## Real two-tier bearer check (rotation-capable, dev-mode preserved)

  1. First: hash the presented bearer token and look it up against
     `Xaas.Governance.InternalApiToken` via `Xaas.Governance.
     InternalApiTokenAuth.verify/1` (real hashed-token resource, adapted
     from the existing, previously-unused `AuditExportToken` pattern in
     this codebase -- see that module's own moduledoc for the full
     rationale and the real, disclosed reason it has no HTTP routes).
     A matching, non-revoked, non-expired row authorizes the request
     regardless of `INTERNAL_API_TOKEN`'s state -- this is the real
     rotation/per-caller-revocation path a flat env var never had.
  2. Fallback: the original real, constant-time-compared bearer check
     against `INTERNAL_API_TOKEN` (real env var, same pattern as
     `DEV_DB_PASSWORD`/`CLOAK_KEY` elsewhere in this repo -- never
     hardcoded, never committed). Preserved unchanged so local dev (and
     any already-provisioned deployment that has not yet minted a rotated
     token) keeps working exactly as before -- this resource is additive,
     never a breaking replacement.

  If the env var itself is unset AND no bearer token matches an active
  `InternalApiToken` row, every request is real-rejected with 503 (fail
  closed, not fail open) -- same fail-closed floor as before this change,
  now covering both credential paths, not just the env var.

  ## Real per-org actor resolution (this pass) -- the customer-submission seam

  When a request authenticates via a DB-backed `InternalApiToken` that
  carries a real `org_id` (see that resource's own moduledoc), this plug
  loads the real `Xaas.Accounts.Org` row for real (never just the raw id)
  and attaches it to `conn.assigns[:current_org]` -- the single source of
  truth the new `POST /internal-api/execution/runs` surface (and the
  org-scoped `GET .../receipts` read) key on for "which org made this
  request." This is a real AUTHENTICATED fact (derived from the token that
  already passed the hash/revocation/expiry check above), never a
  client-asserted header like `X-Org-Id` (`XaasWeb.Plugs.ResolveOrgActor`'s
  own moduledoc discloses exactly why that header is not a real boundary
  against an untrusted external caller).

  `conn.assigns[:current_org]` is `nil` for both remaining tiers -- a
  request authenticated via the legacy shared `INTERNAL_API_TOKEN` env var,
  and a DB token with no `org_id` -- so both keep their current, broader
  "internal/admin" access exactly as before this pass; this is additive,
  not a breaking change to any existing route or test.
  """

  import Plug.Conn

  alias Xaas.Accounts.Org
  alias Xaas.Governance.InternalApiToken
  alias Xaas.Governance.InternalApiTokenAuth

  def init(opts), do: opts

  def call(conn, _opts) do
    case authenticate(conn) do
      {:ok, current_org} -> assign(conn, :current_org, current_org)
      {:error, :unauthorized} -> unauthorized(conn)
      {:error, :misconfigured} -> misconfigured(conn)
    end
  end

  defp authenticate(conn) do
    case bearer_token(conn) do
      {:ok, token} ->
        case InternalApiTokenAuth.verify(token) do
          {:ok, internal_api_token} -> {:ok, resolve_org(internal_api_token)}
          :error -> authenticate_via_env(token)
        end

      :error ->
        # No usable bearer header at all -- still must honor the real
        # fail-closed misconfiguration signal for an unset env var, same
        # as before this change (real-preserved, not just approximated):
        # every request 503s when the operator never set the fallback
        # token either.
        case System.get_env("INTERNAL_API_TOKEN") do
          nil -> {:error, :misconfigured}
          _ -> {:error, :unauthorized}
        end
    end
  end

  defp authenticate_via_env(token) do
    case System.get_env("INTERNAL_API_TOKEN") do
      nil ->
        {:error, :misconfigured}

      expected_token ->
        if Plug.Crypto.secure_compare(token, expected_token) do
          # Legacy shared-token tier: no real per-org identity exists to
          # attach, same "internal/admin" tier as before this pass.
          {:ok, nil}
        else
          {:error, :unauthorized}
        end
    end
  end

  # A DB token with no org_id is the same "internal/admin" tier as the
  # legacy env-var path -- no org to resolve, `nil` (not an error).
  defp resolve_org(%InternalApiToken{org_id: nil}), do: nil

  defp resolve_org(%InternalApiToken{org_id: org_id}) do
    case Ash.get(Org, org_id, authorize?: false) do
      {:ok, %Org{} = org} -> org
      {:error, _} -> nil
    end
  end

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when byte_size(token) > 0 -> {:ok, token}
      _ -> :error
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(401)
    |> Phoenix.Controller.json(%{
      error: "unauthorized",
      detail: "missing or invalid Bearer token"
    })
    |> halt()
  end

  defp misconfigured(conn) do
    conn
    |> put_status(503)
    |> Phoenix.Controller.json(%{
      error: "internal_api_misconfigured",
      detail: "INTERNAL_API_TOKEN is not set on the server"
    })
    |> halt()
  end
end
