defmodule Xaas.Platform.Validations.RouteOrgsCustomDomainValidHostname do
  @moduledoc """
  Real DNS-hostname-shape validation, ported verbatim from
  platform-console's `isValidCustomDomainHostname` used by
  `app/api/orgs/[id]/custom-domain/route.ts`'s POST handler: at least two
  dot-separated RFC 1123 labels (e.g. `console.customer.com`), each label
  alphanumeric/hyphen, not starting or ending with a hyphen.
  """
  use Ash.Resource.Validation

  @label ~r/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/i

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :hostname) do
      hostname when is_binary(hostname) ->
        labels = String.split(hostname, ".")

        if length(labels) >= 2 and Enum.all?(labels, &Regex.match?(@label, &1)) do
          :ok
        else
          {:error,
           field: :hostname,
           message: "is not a valid DNS hostname (need at least two dot-separated RFC 1123 labels)"}
        end

      _ ->
        {:error, field: :hostname, message: "is required and must be a valid DNS hostname"}
    end
  end
end
