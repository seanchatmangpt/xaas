defmodule XaasWeb.Plugs.AuthenticateOrg do
  @moduledoc """
  SPEC-04 (W722-GAP-2, W905 backlog; lane W969b design-wave 2): real
  per-org *authentication* (proving, not asserting, which org a caller
  represents), the redesign `XaasWeb.Plugs.ResolveOrgActor`'s own
  moduledoc has disclosed as out-of-scope since its first pass.

  Runs in the `/api` pipeline AFTER `XaasWeb.Plugs.RequireInternalApiToken`
  (which established `conn.assigns[:current_org]` as a real AUTHENTICATED
  org, derived from a hashed `Xaas.Governance.InternalApiToken` bearer
  credential that already passed the hash/revocation/expiry check) and
  BEFORE `XaasWeb.Plugs.ResolveOrgActor` (the caller-asserted
  `X-Org-Id`-resolution step). It promotes the already-authenticated org
  into the Ash actor/tenant binding the Ash multitenancy and policy
  machinery consumes:

  - `conn.assigns[:current_org]` present (org-carrying DB token):
    assigns `conn.assigns[:authenticated_org]` and binds the real Ash
    actor (`%{org_id: org.slug}`) and Ash tenant (`org.slug`) directly
    from the authenticated org — the caller's `X-Org- ResolveOrgActor`'s
    caller-asserted header is no longer the source of the binding.
  - `conn.assigns[:current_org]` nil (legacy shared `INTERNAL_API_TOKEN`
    env-var tier, or an org-less DB token): passthrough, conn unchanged —
    the legacy tier keeps its legacy caller-asserted behavior under
    `ResolveOrgActor` exactly as before (additive, non-breaking).

  Falsifier this plug closes: a request authenticated as org A that
  asserts `X-Org-Id: org-b` must be REFUSED, not honored. The mismatch
  enforcement lives in the demoted `ResolveOrgActor` (see its updated
  moduledoc); this plug only derives the authenticated binding.
  """

  import Plug.Conn

  alias Xaas.Accounts.Org

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_org] do
      %Org{} = org ->
        actor = %{org_id: org.slug}

        conn
        |> assign(:authenticated_org, org)
        |> Ash.PlugHelpers.set_actor(actor)
        |> Ash.PlugHelpers.set_tenant(org.slug)

      _ ->
        conn
    end
  end
end
