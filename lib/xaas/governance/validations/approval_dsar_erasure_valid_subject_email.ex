defmodule Xaas.Governance.Validations.ApprovalDsarErasureValidSubjectEmail do
  @moduledoc """
  Real email-shape validation, ported verbatim from platform-console's
  `EMAIL_RE` in `app/api/privacy/request-erasure/route.ts`:
  `/^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/`.
  """
  use Ash.Resource.Validation

  @email_regex ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :subject_email) do
      email when is_binary(email) ->
        if Regex.match?(@email_regex, email) do
          :ok
        else
          {:error, field: :subject_email, message: "must be a valid email"}
        end

      _ ->
        {:error, field: :subject_email, message: "is required and must be a valid email"}
    end
  end
end
