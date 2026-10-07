defmodule Xaas.Governance.Validations.ApprovalNotAlreadyApproved do
  @moduledoc """
  Maker-checker state guard shared by the 4 non-global-multitenancy
  Governance `Approval*` resources' `:approve` actions (W740, gap 1 from
  `docs/sjira/v26.10.6/plans/w722-governance-deepening.md`): a second
  `:approve` on an already-approved row is a typed
  `Ash.Error.Invalid.InvalidAttribute` refusal on `approved_by`, never a
  silent `approved_by` overwrite.

  Same "already X" idiom as
  `Xaas.Governance.Validations.AuditExportTokenNotAlreadyRevoked` (and the
  Billing `newly_approved?/2` pre-change-state checks): read the real
  pre-update value via `Ash.Changeset.get_data/2` and refuse when it is
  already set. Validations run before changes, so this is a real
  state-machine guard, not a change-order trick.

  Note: this makes the ledger-charge sibling
  (`Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage`'s
  `newly_approved?/2` defense-in-depth) unreachable on a second approve --
  the refusal fires first -- while leaving its in-action rollback behavior
  for a failed first approve untouched.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_data(changeset, :approved_by) do
      nil -> :ok
      "" -> :ok
      _ -> {:error, field: :approved_by, message: "has already been approved -- cannot re-approve"}
    end
  end
end
