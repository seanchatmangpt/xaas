defmodule Xaas.Ultracode.Validations.VerifierSuiteRegistered do
  @moduledoc """
  A `Run` may only name a verifier suite the operator has registered in
  `config :xaas, :ultracode_verifier_suites`. Names are looked up, never
  interpreted: an unknown name is a typed `unknown_verifier_suite` error (a 400
  on the HTTP surface), so a caller can neither invent a suite nor learn what a
  suite runs. `nil` is legal and keeps today's behavior (no fabric verifier).
  """

  use Ash.Resource.Validation

  alias Xaas.Ultracode.Verifier

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :verifier_suite) do
      nil ->
        :ok

      name ->
        if Verifier.registered?(name) do
          case Verifier.admission(name) do
            :ok ->
              :ok

            {:quarantined, reason} ->
              {:error,
               field: :verifier_suite, message: "suite_unhealthy:" <> reason_token(reason)}
          end
        else
          {:error, field: :verifier_suite, message: "unknown_verifier_suite"}
        end
    end
  end

  defp reason_token({:unhealthy, verdict}), do: "unhealthy_" <> to_string(verdict)
  defp reason_token(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp reason_token(_), do: "unknown"
end
