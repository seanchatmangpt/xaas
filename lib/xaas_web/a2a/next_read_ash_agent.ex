defmodule XaasWeb.A2A.NextReadAshAgent do
  @moduledoc """
  Adapter: `AshA2A.Protocol.Agent` behaviour in front of the existing hex-`a2a`
  `XaasWeb.A2A.NextReadUserAgent` dispatch, so the ash_a2a v1 surface
  (`AshA2A.Protocol.Plug`) and the legacy hex `A2A.Plug` share ONE real skill
  surface (same parse/dispatch/run code path), not two drifting copies.

  Delegate of choice: `XaasWeb.A2A.NextReadUserAgentSkills` supplies the card
  skills list (generated, never hand-patched); the real message dispatch is
  `XaasWeb.A2A.NextReadUserAgent.handle_message/2` (hand-written, real Ash reads
  and the CirculationBorrowReactor saga) -- the skills module only owns the
  generated card data, not dispatch. The adapter is the irreducible
  hand-written residue (struct mapping between two agent behaviours); no
  generator applies (explicit UNSUPPORTED(generator-capability) note).

  ## Status: compiles at the current pin; surface BLOCKED on the router seam

  Compiles clean (0 warnings) against the pinned ash_a2a
  `86214551de93fc8ab395f5ed0b84d32922a5d99b` (v26.10.4), where
  `AshA2A.Protocol.Agent` exists with the same callback contract as the
  `07180bd3` head R4 surveyed. (The pre-bump pin `3325032d`, 26.9.28, had NO
  `AshA2A.Protocol.*` modules — verified: zero `defmodule AshA2A.Protocol`
  matches in the old `deps/ash_a2a/lib`.) Remaining seam for the surface to
  go live: the coordinator's `/a2a/v1` mount in router.ex, and the e2e
  courts in `e2e/a2a-v1.spec.cjs` stay BLOCKED until that mount lands.

  ## Coordinator seam: proposed router lines (NOT applied here)

  Replace nothing; add additively inside the existing `/a2a` scope
  (lib/xaas_web/router.ex, after the `/zoe-event` forward, BEFORE the `/`
  catch-all so the catch-all cannot shadow it):

      # ash_a2a v1 surface -- additive mount, same auth floor as the legacy
      # hex A2A.Plug mount. A2A_BASE_URL already honored per r4-a2a.md §5.D.8.
      forward("/v1", AshA2A.Protocol.Plug,
        agent: XaasWeb.A2A.NextReadAshAgent,
        base_url: (System.get_env("A2A_BASE_URL") || "http://localhost:4000/a2a") <> "/v1"
      )

  (i.e. card at `GET /a2a/v1/.well-known/agent-card.json`, JSON-RPC at
  `POST /a2a/v1`, SSE at `POST /a2a/v1` `message/stream`.)

  ## Stacked-auth analysis (for coordinator admission)

  The `/a2a` scope pipes through `[:api, :require_internal_api_token]`, and
  `AshA2A.Protocol.Plug` has its own `AshA2A.Protocol.Plug.Auth` middleware.
  Options considered:

  1. **Double-401 stack (token gate + `AshA2A.Protocol.Plug.Auth` with its own
     schemes/verify)**: a missing/expired token would 401 at the Phoenix
     pipeline before the plug ever sees the request; a valid token but no
     A2A security scheme would then 401 again inside the plug. Two different
     401 shapes (Phoenix pipeline vs JSON-RPC error or plug's WWW-Authenticate),
     confusing for clients, and the TCK conformance verdict was earned against
     the plug's own auth contract. NOT recommended.

  2. **Gate ordering (RECOMMENDED): keep `:require_internal_api_token` as the
     single auth floor, do NOT configure `AshA2A.Protocol.Plug.Auth` schemes
     on the mount.** Verified against plug.ex: `AshA2A.Protocol.Plug` does not
     require `AshA2A.Protocol.Plug.Auth` to run -- Auth is a separate opt-in
     middleware (`schemes:`/`verify:` required opts), and
     `AshA2A.Protocol.Plug.Auth.get_identity/1` simply returns nil when nothing
     stored identity in `conn.private[:a2a][:auth]`. With no Auth middleware
     configured, the plug runs bare: the Phoenix token gate 401s unauthenticated
     requests (fail-closed, INTERNAL_API_TOKEN absent config also fails closed
     per CLAUDE.md), and the plug forwards `context.metadata["a2a.auth"] = nil`
     to the agent, which -- like the legacy NextReadUserAgent -- ignores auth
     identity and does its own explicit `as:<user_id>` persona-grant resolution
     inside message handling. Single 401 shape, one auth floor, zero bypass:
     the token gate is upstream of every plug path including SSE.

  Recommendation: option 2 (single token-gate floor, no second Auth stack).
  The e2e courts in `e2e/a2a-v1.spec.cjs` encode exactly this (401 without
  token, 200 card with token, happy path with token).
  """

  use AshA2A.Protocol.Agent,
    name: "next-read-user",
    description:
      "Simulates a Next Read reader (student) persona, HDDL-grounded; ash_a2a v1 adapter over the shared hex-agent dispatch",
    skills: XaasWeb.A2A.NextReadUserAgentSkills.skills()

  alias AshA2A.Protocol.{Message, Part}

  @impl AshA2A.Protocol.Agent
  def handle_message(%Message{} = message, _context) do
    text = Message.text(message) || ""

    # One skill surface: reuse the hex agent's real dispatch (parse ->
    # actor resolution -> browse/checkout -> CirculationBorrowReactor)
    # rather than duplicating it here.
    case XaasWeb.A2A.NextReadUserAgent.handle_message(A2A.Message.new_user(text), %{}) do
      {:reply, parts} ->
        {:reply, map_parts(parts)}

      {:input_required, parts} ->
        {:input_required, map_parts(parts)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl AshA2A.Protocol.Agent
  def handle_cancel(_context), do: :ok

  defp map_parts(parts) do
    Enum.map(parts, fn
      %A2A.Part.Text{text: text} ->
        Part.Text.new(text)

      %A2A.Part.Data{data: data} ->
        Part.Data.new(data)

      %A2A.Part.File{file: file} ->
        Part.File.new(%AshA2A.Protocol.FileContent{
          name: file.name,
          mime_type: file.mime_type,
          bytes: file.bytes,
          uri: file.uri
        })
    end)
  end
end
