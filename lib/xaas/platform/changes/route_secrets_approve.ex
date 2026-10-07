defmodule Xaas.Platform.Changes.RouteSecretsApprove do
  @moduledoc """
  Wired (W792) to `Xaas.Platform.RouteSecrets`' real `:approve` update
  action, replacing the previously unwired identity shim. Enforcement of the
  maker-checker predicate lives in the paired validation
  (`Xaas.Platform.Validations.RouteSecretsRequiresApprover`) exactly as in
  the Governance house pattern; this change is the action-seam on the
  approve path.
  """
  use Ash.Resource.Change

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context), do: changeset
end
