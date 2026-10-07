defmodule Xaas.Governance.Checks.FreezeWindowActive do
  require Ash.Query

  @moduledoc """
  SPEC-18 (W765-GAP-D, W905 backlog; lane W969b design-wave 2): real
  runtime consumer gate on an active change-freeze window.

  Until this check existed, the only freeze-window enforcement anywhere
  in the codebase was
  `Xaas.Governance.Validations.ApprovalFreezeOverrideFreezeWindowExists`
  and
  `Xaas.Governance.Validations.AuditExportTokenNoActiveFreezeWindow` —
  the override-filing path and the audit-export mint path only. The
  deploy-class `:approve` actions the receipts name as the freeze's real
  subjects ran ungated: an org with an active
  `Xaas.Governance.FreezeWindow` could approve a
  `Xaas.Governance.ApprovalDeploymentQuarantine` release or an
  `Xaas.Governance.ApprovalEnvironmentPromote` promotion straight
  through an active freeze.

  Wired (as `forbid_if`) onto two deploy-class `:approve` actions:
  `ApprovalDeploymentQuarantine :approve` and
  `ApprovalEnvironmentPromote :approve`. NOT wired onto `:create` or
  `:read` — a freeze governs promoting/approving INTO production, not
  filing or reading a request, and `:revoke`-class actions must stay
  available during a freeze (same scope discipline as
  `AuditExportTokenNoActiveFreezeWindow`'s moduledoc).

  ## Semantics (fail-closed)

  `forbid_if {FreezeWindowActive, []}` is TRUE (forbidden) when:

  - an active `FreezeWindow` exists for the subject record's org
    (`starts_at <= now <= ends_at`), AND
  - no lawful emergency path out exists: either the window does not
    allow emergency overrides (`allow_emergency_override: false`), or
    the window allows them but no APPROVED
    `Xaas.Governance.ApprovalFreezeOverride` row references the window
    (`approved_by` non-nil; a filed-but-unapproved override does not
    lift the freeze).

  A freeze-window lookup that errors refuses (fail-closed), mirroring
  `AuditExportTokenNoActiveFreezeWindow`'s real fail-closed read.

  Deliberately a `forbid_if` inside the existing `:approve` bypass (not
  a plain `authorize_unless`), so the existing `ActorOrgMatches` /
  `SystemActor` gates stay intact (Chesterton fence) — see the wiring in
  the two resources.
  """

  use Ash.Policy.SimpleCheck

  alias Xaas.Governance.ApprovalFreezeOverride
  alias Xaas.Governance.FreezeWindow

  @impl true
  def describe(_opts),
    do:
      "an active change-freeze window for this org is in force and no approved emergency override lifts it"

  @impl true
  def match?(_actor, %{subject: subject}, _opts) do
    org_id = org_id_for(subject)

    case org_id do
      nil ->
        # No org to check: not a freeze subject.
        false

      _ ->
        active_window(org_id)
    end
  end

  def match?(_actor, _context, _opts), do: false

  defp org_id_for(%Ash.Changeset{action_type: :update} = changeset) do
    case changeset.data do
      %{org_id: org_id} -> org_id
      _ -> nil
    end
  end

  defp org_id_for(%{org_id: org_id}), do: org_id
  defp org_id_for(_), do: nil

  defp active_window(org_id) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    case FreezeWindow
         |> Ash.Query.filter(org_id == ^org_id and starts_at <= ^now and ends_at >= ^now)
         |> Ash.read(authorize?: false) do
      {:ok, []} ->
        false

      {:ok, [window | _]} ->
        # Active window found: forbidden unless the emergency path out is
        # real (window allows overrides AND an APPROVED override row
        # references this exact window).
        if window.allow_emergency_override do
          not override_granted?(window)
        else
          true
        end

      {:error, _} ->
        # Fail closed: an unresolvable freeze lookup refuses the approve.
        true
    end
  end

  defp override_granted?(window) do
    case ApprovalFreezeOverride
         |> Ash.Query.filter(freeze_window_id == ^window.id and not is_nil(approved_by))
         |> Ash.read(authorize?: false) do
      {:ok, [_ | _]} -> true
      {:ok, []} -> false
      {:error, _} -> false
    end
  end
end
