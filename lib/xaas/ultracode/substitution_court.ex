defmodule Xaas.Ultracode.SubstitutionCourt do
  @moduledoc """
  Qualification court for provider/transport interchangeable parts.

  This consumes the ecosystem interchangeable-parts law at the XaaS runtime
  boundary. Provider and transport are orthogonal topology dimensions. Neither
  participates in semantic WorkOrder identity or manufactures authority.

  A substitution is admitted only when:
  * both passports are exact-subject and content-digest bound;
  * both qualification receipts pass and are replay-bound;
  * the part dimension is unchanged (:provider or :transport);
  * consequence and receipt schemas are conserved;
  * the replacement authority ceiling is no greater than the original and
    never includes DO.

  The court is SELECT-only. Execution remains in the existing Lease ->
  Xaas.Actuation kernel and transport remains in Xaas.Tunnel/RemoteRelay.
  """

  @sha256 ~r/^sha256:[0-9a-f]{64}$/
  @subject ~r/^[^\s@]+\/[^\s@]+@[0-9a-f]{40}$/
  @allowed_authorities MapSet.new([:observe, :select, :construct])

  defmodule WorkIdentity do
    @enforce_keys [
      :work_order_id,
      :exact_subject,
      :origin_authority,
      :consequence_schema_digest,
      :receipt_schema_digest,
      :execution_manifest_digest
    ]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule QualificationReceipt do
    @enforce_keys [:receipt_digest, :verifier_evidence_digest, :replay_digest, :passed]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule PartPassport do
    @enforce_keys [
      :part_id,
      :kind,
      :exact_subject,
      :part_digest,
      :producer_digest,
      :consequence_schema_digest,
      :receipt_schema_digest,
      :authority_ceiling,
      :qualification_receipt
    ]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  @type kind :: :provider | :transport

  @spec qualify(WorkIdentity.t(), PartPassport.t(), PartPassport.t()) ::
          {:ok, map()} | {:error, atom()}
  def qualify(%WorkIdentity{} = work, %PartPassport{} = original, %PartPassport{} = replacement) do
    with :ok <- validate_work(work),
         :ok <- validate_passport(original),
         :ok <- validate_passport(replacement),
         :ok <- same_kind(original, replacement),
         :ok <- preserve_consequence(work, original, replacement),
         :ok <- preserve_receipt_schema(work, original, replacement),
         :ok <- conserve_authority(original, replacement) do
      payload = %{
        schema: "xaas.interchangeable-part-substitution/1",
        work_identity_digest: work_identity_digest(work),
        kind: original.kind,
        original_part: original.part_id,
        original_subject: original.exact_subject,
        replacement_part: replacement.part_id,
        replacement_subject: replacement.exact_subject,
        consequence_schema_digest: work.consequence_schema_digest,
        receipt_schema_digest: work.receipt_schema_digest,
        authority_ceiling: canonical_authority(replacement.authority_ceiling),
        qualification_receipts: [
          original.qualification_receipt.receipt_digest,
          replacement.qualification_receipt.receipt_digest
        ],
        authority: "NONE",
        grants_do_authority: false
      }

      {:ok, Map.put(payload, :receipt_digest, digest(payload))}
    end
  end

  @doc """
  Semantic work identity deliberately excludes provider and transport topology.
  """
  @spec work_identity_digest(WorkIdentity.t()) :: String.t()
  def work_identity_digest(%WorkIdentity{} = work) do
    work
    |> Map.from_struct()
    |> digest()
  end

  @doc """
  Topology identity includes qualified provider + transport passports while
  retaining the separately-computable semantic work identity.
  """
  @spec topology_digest(WorkIdentity.t(), PartPassport.t(), PartPassport.t()) :: String.t()
  def topology_digest(%WorkIdentity{} = work, %PartPassport{kind: :provider} = provider, %PartPassport{kind: :transport} = transport) do
    digest(%{
      work_identity_digest: work_identity_digest(work),
      provider: {provider.part_id, provider.exact_subject, provider.part_digest},
      transport: {transport.part_id, transport.exact_subject, transport.part_digest}
    })
  end

  @doc """
  Public admission of a single part passport (kind, exact subject, content
  digests, qualification receipt digests, authority ceiling without DO).

  This is the one passport law; other courts (e.g.
  `Xaas.Ultracode.SbbRealization`) call it instead of re-implementing it.
  """
  @spec validate_part(PartPassport.t()) :: :ok | {:error, atom()}
  def validate_part(%PartPassport{} = passport), do: validate_passport(passport)
  def validate_part(_), do: {:error, :implementation_passport_missing}

  defp validate_work(work) do
    cond do
      blank?(work.work_order_id) -> {:error, :work_order_identity_missing}
      not valid_subject?(work.exact_subject) -> {:error, :work_subject_not_exact}
      blank?(work.origin_authority) -> {:error, :origin_authority_missing}
      not digest?(work.consequence_schema_digest) -> {:error, :consequence_schema_digest_invalid}
      not digest?(work.receipt_schema_digest) -> {:error, :receipt_schema_digest_invalid}
      not digest?(work.execution_manifest_digest) -> {:error, :execution_manifest_digest_invalid}
      true -> :ok
    end
  end

  defp validate_passport(%PartPassport{} = passport) do
    with :ok <- validate_kind(passport.kind),
         :ok <- validate_passport_identity(passport),
         :ok <- validate_authority(passport.authority_ceiling),
         :ok <- validate_qualification_receipt(passport.qualification_receipt) do
      :ok
    end
  end

  defp validate_kind(kind) when kind in [:provider, :transport], do: :ok
  defp validate_kind(_), do: {:error, :part_kind_invalid}

  defp validate_passport_identity(passport) do
    cond do
      blank?(passport.part_id) -> {:error, :part_identity_missing}
      not valid_subject?(passport.exact_subject) -> {:error, :part_subject_not_exact}
      not digest?(passport.part_digest) -> {:error, :part_digest_invalid}
      not digest?(passport.producer_digest) -> {:error, :producer_digest_invalid}
      not digest?(passport.consequence_schema_digest) -> {:error, :part_consequence_schema_digest_invalid}
      not digest?(passport.receipt_schema_digest) -> {:error, :part_receipt_schema_digest_invalid}
      true -> :ok
    end
  end

  defp validate_qualification_receipt(%QualificationReceipt{} = receipt) do
    cond do
      receipt.passed != true -> {:error, :qualification_not_pass}
      not digest?(receipt.receipt_digest) -> {:error, :qualification_receipt_digest_invalid}
      not digest?(receipt.verifier_evidence_digest) -> {:error, :verifier_evidence_digest_invalid}
      not digest?(receipt.replay_digest) -> {:error, :qualification_replay_digest_invalid}
      true -> :ok
    end
  end

  defp validate_qualification_receipt(_), do: {:error, :qualification_receipt_missing}

  defp validate_authority(authorities) when is_list(authorities) do
    set = MapSet.new(authorities)

    cond do
      length(authorities) != MapSet.size(set) -> {:error, :authority_ceiling_ambiguous}
      MapSet.member?(set, :do) -> {:error, :do_authority_laundering}
      not MapSet.subset?(set, @allowed_authorities) -> {:error, :authority_ceiling_invalid}
      true -> :ok
    end
  end

  defp validate_authority(_), do: {:error, :authority_ceiling_invalid}

  defp same_kind(%PartPassport{kind: kind}, %PartPassport{kind: kind}), do: :ok
  defp same_kind(_, _), do: {:error, :part_kind_mismatch}

  defp preserve_consequence(work, original, replacement) do
    if original.consequence_schema_digest == work.consequence_schema_digest and
         replacement.consequence_schema_digest == work.consequence_schema_digest do
      :ok
    else
      {:error, :consequence_schema_drift}
    end
  end

  defp preserve_receipt_schema(work, original, replacement) do
    if original.receipt_schema_digest == work.receipt_schema_digest and
         replacement.receipt_schema_digest == work.receipt_schema_digest do
      :ok
    else
      {:error, :receipt_schema_drift}
    end
  end

  defp conserve_authority(original, replacement) do
    original_set = MapSet.new(original.authority_ceiling)
    replacement_set = MapSet.new(replacement.authority_ceiling)

    if MapSet.subset?(replacement_set, original_set),
      do: :ok,
      else: {:error, :authority_ceiling_increase}
  end

  defp canonical_authority(authorities), do: authorities |> Enum.map(&Atom.to_string/1) |> Enum.sort()

  defp valid_subject?(value), do: is_binary(value) and Regex.match?(@subject, value)
  defp digest?(value), do: is_binary(value) and Regex.match?(@sha256, value)
  defp blank?(value), do: not is_binary(value) or String.trim(value) == ""

  defp digest(value) do
    canonical =
      value
      |> canonical_term()
      |> :erlang.term_to_binary()

    "sha256:" <> (:crypto.hash(:sha256, canonical) |> Base.encode16(case: :lower))
  end

  defp canonical_term(value) when is_struct(value), do: value |> Map.from_struct() |> canonical_term()
  defp canonical_term(value) when is_map(value), do: value |> Enum.map(fn {k, v} -> {k, canonical_term(v)} end) |> Enum.sort()
  defp canonical_term(value) when is_list(value), do: Enum.map(value, &canonical_term/1)
  defp canonical_term(value) when is_tuple(value), do: value |> Tuple.to_list() |> Enum.map(&canonical_term/1) |> List.to_tuple()
  defp canonical_term(value), do: value
end
