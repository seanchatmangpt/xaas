defmodule Xaas.Platform.Changes.RouteProjectsApprove do
  @moduledoc """
  Wired (W792) to `Xaas.Platform.RouteProjects`' real `:approve` update
  action, replacing the previously unwired identity shim. Enforcement of the
  maker-checker predicate lives in the paired validation
  (`Xaas.Platform.Validations.RouteProjectsRequiresApprover`) exactly as in
  the Governance house pattern; this change is the action-seam on the
  approve path. RouteProjects itself remains create-less by construction —
  rows only enter via other carriers; `:approve` operates on existing rows.
  """
  use Ash.Resource.Change

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context), do: changeset
end
