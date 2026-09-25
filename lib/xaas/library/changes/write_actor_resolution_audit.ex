defmodule Xaas.Library.Changes.WriteActorResolutionAudit do
  @moduledoc """
  Real, reusable write helper for auditing A2A/MCP persona-actor resolution
  decisions, following the identical `after_action`, non-bang
  `Ash.create/2`, `authorize?: false` pattern established by
  `Xaas.Governance.Changes.WriteAuditLogEntry` for approval writes.

  This is a plain function module rather than an `Ash.Resource.Change`
  because `NextReadUserAgent.resolve_actor/2` is a plain function, not an
  Ash changeset pipeline -- there is no changeset to hang `Ash.Resource
  .Change.change/3` off of. The call site builds and submits the identical
  `Ash.Changeset.for_create/3` |> `Ash.create/2` sequence directly, via
  `write/1` below, so the write logic itself is not duplicated across call
  sites even though it isn't wired through the `change` DSL.

  Per `Xaas.Operations.AuditLogEntry`'s own documented "best-effort caller
  identity" semantics, `actor_id`/`resource_id` here are the *claimed* user
  id (the identity asserted by the A2A `as:<user_id>` command), not
  necessarily a verified one -- that is exactly what makes an "outcome":
  "denied" row meaningful: it records who was *claimed* to be acted as, even
  though the claim was rejected.
  """

  @doc """
  Writes one real `Xaas.Operations.AuditLogEntry` row recording an actor
  resolution decision. `outcome` is `"allowed"` or `"denied"`. Returns
  `{:ok, entry}` / `{:error, error}` -- callers decide whether a failed
  audit write should block the resolution itself (Ash `after_action`
  callers should propagate `{:error, _}` to roll back; this module's own
  callers are plain functions and log + continue, since an audit-write
  failure must not be able to silently upgrade a denied impersonation
  attempt into an allowed one, nor block a legitimate one).
  """
  @spec write(%{
          caller_id: String.t(),
          user_id: String.t() | nil,
          outcome: String.t()
        }) :: {:ok, struct()} | {:error, term()}
  def write(%{caller_id: caller_id, user_id: user_id, outcome: outcome})
      when outcome in ["allowed", "denied"] do
    action = "a2a.actor_resolution.#{outcome}"

    Xaas.Operations.AuditLogEntry
    |> Ash.Changeset.for_create(
      :create,
      %{
        actor_id: user_id,
        actor_description: "a2a caller #{caller_id} claiming user #{user_id}",
        action: action,
        resource_type: "PersonaGrant",
        resource_id: to_string(user_id),
        occurred_at: DateTime.utc_now(),
        metadata: %{
          "caller_id" => caller_id,
          "claimed_user_id" => user_id,
          "outcome" => outcome
        }
      },
      authorize?: false
    )
    |> Ash.create()
  end
end
