defmodule Xaas.Platform.Validations.RouteProjectsBackupsValidProjectName do
  @moduledoc """
  Real non-blank check, ported verbatim from platform-console's
  `POST /api/orgs/[id]/backups` (`orgs/[id]/backups/route.ts`):

      const projectName = typeof body?.projectName === "string" ? body.projectName.trim() : "";
      if (!projectName) {
        return NextResponse.json({ error: "projectName is required" }, { status: 400 });
      }

  NOT ported here: the real cross-tenant guard (the named Project must
  belong to THIS org's own k8s namespace, checked via a live `listProjects()`
  call against the cluster) -- xaas has no k8s Project/namespace model to
  check against yet. This validation only enforces the field-shape half;
  the cross-tenant ownership check is real integration work still owed.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :project_name) do
      name when is_binary(name) ->
        if String.trim(name) == "" do
          {:error, field: :project_name, message: "is required"}
        else
          :ok
        end

      _ ->
        {:error, field: :project_name, message: "is required"}
    end
  end
end
