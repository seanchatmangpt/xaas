defmodule Xaas.Sjira.GovernanceRoute do
  @moduledoc """
  Route-level manufacture and replay of sJira governance obligations.

  This module composes Xaas.Sjira.GovernanceObligation; it never grants
  authority and never actuates. A route receipt proves only which obligation
  identities and standings were observed for one subject.
  """

  alias Xaas.Sjira.GovernanceObligation

  defmodule Receipt do
    @moduledoc false
    @enforce_keys [
      :subject_ref,
      :obligation_digests,
      :standing_counts,
      :disposition_counts,
      :ready_for_do_count,
      :digest
    ]
    defstruct [
      :subject_ref,
      :obligation_digests,
      :standing_counts,
      :disposition_counts,
      :ready_for_do_count,
      :digest
    ]

    @type t :: %__MODULE__{
            subject_ref: String.t(),
            obligation_digests: tuple(),
            standing_counts: map(),
            disposition_counts: map(),
            ready_for_do_count: non_neg_integer(),
            digest: String.t()
          }
  end

  @spec compile([map()], keyword()) ::
          {:ok, [GovernanceObligation.t()], Receipt.t()} | {:refused, map()}
  def compile(gate_results, opts) when is_list(gate_results) and is_list(opts) do
    subject_ref = Keyword.get(opts, :subject_ref)

    cond do
      not is_binary(subject_ref) or subject_ref == "" ->
        {:refused, refusal("SUBJECT_REF_REQUIRED", %{subject_ref: subject_ref})}

      gate_results == [] ->
        {:refused, refusal("GATE_RESULTS_REQUIRED", %{subject_ref: subject_ref})}

      true ->
        with {:ok, obligations} <- compile_all(gate_results, subject_ref),
             :ok <- refuse_duplicate_identities(obligations),
             :ok <- verify_all(obligations) do
          {:ok, obligations, receipt(subject_ref, obligations)}
        end
    end
  end

  def compile(_other, _opts),
    do: {:refused, refusal("GATE_RESULTS_MUST_BE_LIST", %{})}

  @spec replay([GovernanceObligation.t()], Receipt.t()) ::
          {:ok, Receipt.t()} | {:refused, map()}
  def replay(obligations, %Receipt{} = observed) when is_list(obligations) do
    with :ok <- refuse_duplicate_identities(obligations),
         :ok <- verify_all(obligations),
         :ok <- same_subject(obligations, observed.subject_ref) do
      expected = receipt(observed.subject_ref, obligations)

      if expected.digest == observed.digest and expected == observed do
        {:ok, observed}
      else
        {:refused,
         refusal("GOVERNANCE_ROUTE_RECEIPT_MISMATCH", %{
           expected_digest: expected.digest,
           observed_digest: observed.digest
         })}
      end
    end
  end

  @spec receipt(String.t(), [GovernanceObligation.t()]) :: Receipt.t()
  def receipt(subject_ref, obligations)
      when is_binary(subject_ref) and is_list(obligations) do
    obligation_digests = Enum.map(obligations, & &1.digest) |> List.to_tuple()

    standing_counts =
      obligations
      |> Enum.frequencies_by(& &1.standing)
      |> Enum.into(%{}, fn {key, count} -> {Atom.to_string(key), count} end)

    disposition_counts = Enum.frequencies_by(obligations, & &1.disposition)
    ready_for_do_count = Enum.count(obligations, & &1.ready_for_do)

    body = {
      subject_ref,
      obligation_digests,
      standing_counts,
      disposition_counts,
      ready_for_do_count
    }

    %Receipt{
      subject_ref: subject_ref,
      obligation_digests: obligation_digests,
      standing_counts: standing_counts,
      disposition_counts: disposition_counts,
      ready_for_do_count: ready_for_do_count,
      digest: digest(body)
    }
  end

  defp compile_all(gate_results, subject_ref) do
    gate_results
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {gate_result, index}, {:ok, acc} ->
      case GovernanceObligation.compile_gate(gate_result, subject_ref: subject_ref) do
        {:ok, obligations} ->
          {:cont, {:ok, acc ++ obligations}}

        {:refused, reason} ->
          {:halt,
           {:refused,
            refusal("GATE_COMPILATION_REFUSED", %{
              gate_index: index,
              cause: reason
            })}}
      end
    end)
  end

  defp verify_all(obligations) do
    obligations
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {obligation, index}, :ok ->
      case GovernanceObligation.replay(obligation) do
        {:ok, _} ->
          {:cont, :ok}

        {:refused, reason} ->
          {:halt,
           {:refused,
            refusal("OBLIGATION_REPLAY_REFUSED", %{
              obligation_index: index,
              cause: reason
            })}}
      end
    end)
  end

  defp refuse_duplicate_identities(obligations) do
    ids = Enum.map(obligations, & &1.obligation_id)

    duplicates =
      ids
      |> Enum.frequencies()
      |> Enum.filter(fn {_id, count} -> count > 1 end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()

    if duplicates == [] do
      :ok
    else
      {:refused, refusal("DUPLICATE_OBLIGATION_IDENTITY", %{identities: duplicates})}
    end
  end

  defp same_subject(obligations, subject_ref) do
    foreign =
      obligations
      |> Enum.reject(&(&1.subject_ref == subject_ref))
      |> Enum.map(& &1.obligation_id)

    if foreign == [] do
      :ok
    else
      {:refused,
       refusal("GOVERNANCE_ROUTE_SUBJECT_MISMATCH", %{
         subject_ref: subject_ref,
         foreign_obligations: foreign
       })}
    end
  end

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp refusal(code, detail) do
    %{
      "standing" => "REFUSED(#{code})",
      "reason" => code,
      "detail" => detail
    }
  end
end
