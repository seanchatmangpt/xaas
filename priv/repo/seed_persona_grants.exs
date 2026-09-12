# Real Xaas.Library.PersonaGrant dev fixtures for the `full_grant_enforcement`
# cycle (see docs/vision/vision-2030-2026-09-09-0020.md).
#
# Run as:
#
#     mix run priv/repo/seed_persona_grants.exs
#
# Creates (or reuses, idempotently) 3 real `users` rows via the identical
# direct-SQL insert pattern `Xaas.DevSeeds.get_or_create_dev_reader/0` uses
# (the applied `users` table predates `Xaas.Accounts.User`'s
# `school_id`/`grade_level` attributes, same documented drift), then grants
# `caller_id: "internal_api_token"` an active `Xaas.Library.PersonaGrant`
# for the FIRST TWO of those users only.
#
# The THIRD user id is deliberately left ungranted -- this is the intended
# "avatar" / impersonation-attempt fixture for the A2A endpoint
# (`XaasWeb.A2A.NextReadUserAgent`): POSTing a message beginning
# `as:<3rd-user-id> ...` to `/a2a` must be denied by
# `resolve_actor/2` (no active `PersonaGrant` row binds
# `"internal_api_token"` to that user id) and must produce a real
# `Xaas.Operations.AuditLogEntry` row with `metadata["outcome"] == "denied"`.
# Do NOT add a grant for this third id -- that is the fixture's entire point.

alias Xaas.Library.PersonaGrant

caller_id = "internal_api_token"

get_or_create_user = fn email ->
  case Xaas.Repo.query!("SELECT id FROM users WHERE email = $1::citext", [email]) do
    %{rows: [[id]]} ->
      id

    %{rows: []} ->
      # Same fixed dev bcrypt hash `Xaas.DevSeeds` uses for its dev reader
      # (password "password123456", dev-only, never a real credential).
      hash = "$2b$12$k1Y2sQeYQhK5m1F0xXqzUuJ8y2rN3wJt0nQKk1Z1eZ5C4h1qYw8Sa"

      %{rows: [[id]]} =
        Xaas.Repo.query!(
          "INSERT INTO users (id, email, hashed_password) VALUES (gen_random_uuid(), $1::citext, $2) RETURNING id",
          [email, hash]
        )

      id
  end
end

granted_user_1_id = get_or_create_user.("persona-grant-1@example.test")
granted_user_2_id = get_or_create_user.("persona-grant-2@example.test")
ungranted_user_id = get_or_create_user.("persona-ungranted@example.test")

ensure_grant = fn user_id ->
  case PersonaGrant.active_for(caller_id, user_id, authorize?: false) do
    {:ok, [_ | _]} ->
      :already_granted

    {:ok, []} ->
      PersonaGrant.grant(caller_id, user_id, "seed_persona_grants", authorize?: false)
  end
end

ensure_grant.(granted_user_1_id)
ensure_grant.(granted_user_2_id)

IO.puts("""
Seeded real Xaas.Library.PersonaGrant fixtures:
  caller_id:            #{caller_id}
  granted persona 1:    #{granted_user_1_id} (persona-grant-1@example.test)
  granted persona 2:    #{granted_user_2_id} (persona-grant-2@example.test)
  UNGRANTED persona:    #{ungranted_user_id} (persona-ungranted@example.test)

Negative-case fixture: POST an A2A message starting "as:#{ungranted_user_id} ..."
to /a2a -- resolve_actor/2 must deny it (no active PersonaGrant row) and
write an AuditLogEntry with metadata["outcome"] == "denied".
""")
