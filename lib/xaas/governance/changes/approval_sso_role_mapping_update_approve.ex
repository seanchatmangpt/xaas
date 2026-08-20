defmodule Xaas.Governance.Changes.ApprovalSsoRoleMappingUpdateApprove do
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def change(changeset, _opts, _context) do
    changeset
  end
end
