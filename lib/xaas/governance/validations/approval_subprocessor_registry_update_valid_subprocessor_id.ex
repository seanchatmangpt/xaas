defmodule Xaas.Governance.Validations.ApprovalSubprocessorRegistryUpdateValidSubprocessorId do
  @moduledoc """
  Real ID-shape validation, ported verbatim from platform-console's
  `parseRecord` in `app/api/subprocessors/route.ts`:
  `/^[-._a-zA-Z0-9]+$/` (ConfigMap-key-safe sub-processor id).
  """
  use Ash.Resource.Validation

  @id_regex ~r/^[-._a-zA-Z0-9]+$/

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :subprocessor_id) do
      id when is_binary(id) and id != "" ->
        if Regex.match?(@id_regex, id) do
          :ok
        else
          {:error,
           field: :subprocessor_id,
           message: "must be ConfigMap-key-safe (letters, digits, '-', '_', '.')"}
        end

      _ ->
        {:error, field: :subprocessor_id, message: "is required"}
    end
  end
end
