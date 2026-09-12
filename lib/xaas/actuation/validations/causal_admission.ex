defmodule Xaas.Actuation.Validations.CausalAdmission do
  @moduledoc """
  Admits structurally evidenced causal-intervention certificates before DO.

  The validation is intentionally narrow: it does not claim to perform causal
  discovery, do-calculus, d-separation, or placebo analysis itself. Those belong
  to dedicated causal verifiers. This boundary only admits a certificate when
  the caller explicitly marks causal identification as required and supplies
  the evidence identities needed to replay that external verification.

  Existing deterministic domain actions remain unchanged when no `causal`
  declaration is present in the authority evidence envelope.
  """

  use Ash.Resource.Validation

  @strategies ~w(rct iv backdoor frontdoor observational_assumptions)
  @evidence_fields ~w(verifier dag_proof_hash assumptions_hash placebo_result_hash falsifier)

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    authority = Ash.Changeset.get_attribute(changeset, :authority) || %{}

    case Map.get(authority, "causal") do
      nil ->
        :ok

      %{} = causal ->
        validate_causal(causal)

      _other ->
        refusal("causal admission declaration must be a map")
    end
  end

  defp validate_causal(%{"required" => false}), do: :ok

  defp validate_causal(%{"required" => true} = causal) do
    missing =
      Enum.reject(@evidence_fields, fn field ->
        non_empty_string?(Map.get(causal, field))
      end)

    cond do
      Map.get(causal, "status") != "admitted" ->
        refusal("causal admission required but certificate status is not admitted")

      Map.get(causal, "strategy") not in @strategies ->
        refusal(
          "unsupported causal identification strategy: #{inspect(Map.get(causal, "strategy"))}"
        )

      missing != [] ->
        refusal("causal admission certificate missing evidence: #{Enum.join(missing, ", ")}")

      true ->
        :ok
    end
  end

  defp validate_causal(_causal) do
    refusal("causal admission declaration must include boolean required")
  end

  defp non_empty_string?(value), do: is_binary(value) and String.trim(value) != ""

  defp refusal(message), do: {:error, field: :authority, message: message}
end
