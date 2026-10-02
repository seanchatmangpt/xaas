defmodule Xaas.Fabric.Failure do
  @moduledoc """
  One failure taxonomy over the heterogeneous refusal shapes of the planes:

    * `AshGraphLaw.Refusal` (`%{class: :refused_admission | :refused_authority | :refused_structure |
      :refused_identity | :blocked_resource | :unsupported}`)
    * `AshAffidavit.call/2` four-way tuples (`{:refused | :trap | :unsupported, %Refusal{class}}`)
    * `AshR2RML.Refusal` (`%{code}`)
    * castle/ash_a2a refusal strings and atoms (`REFUSED...`, `BLOCKED...`)

  Transient vs terminal reuses `Xaas.Ultracode.ProviderMesh.Failure.class/1`: only a
  `:realization_failed` is transient (mapped to `:unavailable`), so only it may fail over.
  """

  alias Xaas.Ultracode.ProviderMesh.Failure, as: MeshFailure

  @type class ::
          :semantic_refusal
          | :authority_refusal
          | :process_invalid
          | :realization_failed
          | :evidence_insufficient
          | :unsupported
          | :capability_unavailable

  @type t :: %{class: class(), transient?: boolean(), source: atom(), detail: term()}

  @spec normalize(term(), atom()) :: t()
  def normalize(raw, source) do
    class = classify(raw)
    %{class: class, transient?: transient?(class), source: source, detail: detail(raw)}
  end

  @doc "True iff the existing provider-mesh classification calls this class transient."
  @spec transient?(class()) :: boolean()
  def transient?(:realization_failed), do: MeshFailure.class(:unavailable) == :transient
  def transient?(_), do: false

  @classes [:semantic_refusal, :authority_refusal, :process_invalid, :realization_failed, :evidence_insufficient, :unsupported, :capability_unavailable]

  defp classify({c, _}) when c in @classes, do: c

  # graphlaw / affidavit refusal structs, matched structurally (no compile-time dependency).
  defp classify({tag, %{class: c}}) when tag in [:refused, :trap, :unsupported, :error],
    do: classify_struct_class(c, tag)

  defp classify(%{class: c}), do: classify_struct_class(c, :error)
  defp classify(%{__struct__: AshR2RML.Refusal}), do: :semantic_refusal
  defp classify({:trap, _}), do: :realization_failed
  defp classify(:unsupported), do: :unsupported
  defp classify(raw) when is_binary(raw) or is_atom(raw) or is_tuple(raw), do: classify_text(inspect(raw))
  defp classify(_), do: :realization_failed

  defp classify_struct_class(c, tag) do
    case c do
      c when c in [:refused_admission, :refused_structure, :refused_input] -> :semantic_refusal
      c when c in [:refused_authority, :refused_identity] -> :authority_refusal
      :blocked_resource -> :realization_failed
      :trap -> :realization_failed
      :unsupported -> :unsupported
      _ -> if tag == :unsupported, do: :unsupported, else: :realization_failed
    end
  end

  defp classify_text(text) do
    cond do
      text =~ "BLOCKED" -> :realization_failed
      text =~ ~r/AUTHORITY|NOT_AUTHORIZED|CERTIFICATE|QUORUM/i -> :authority_refusal
      text =~ "REFUSED" -> :semantic_refusal
      true -> :realization_failed
    end
  end

  defp detail({_tag, %{} = r}), do: detail(r)
  defp detail(%{code: code}), do: code
  defp detail(%{__struct__: _} = s), do: s |> Map.from_struct() |> Map.drop([:raw]) |> inspect(limit: 5)
  defp detail(other), do: other
end
