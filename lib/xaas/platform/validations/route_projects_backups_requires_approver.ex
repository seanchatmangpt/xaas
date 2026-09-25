defmodule Xaas.Platform.Validations.RouteProjectsBackupsRequiresApprover do
  use Ash.Resource.Validation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def validate(_changeset, _opts, _context) do
    :ok
  end
end
