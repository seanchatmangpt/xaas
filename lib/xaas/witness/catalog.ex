defmodule Xaas.Witness.Catalog do
  @moduledoc """
  Context for the witness surface. Ingests affidavit's mutation baseline
  JSON plus signing-surface metadata into `Xaas.Witness` resources, and
  records verification results on ingested receipts.
  """

  require Ash.Query

  alias Xaas.Witness.CertifiedReceipt
  alias Xaas.Witness.VerificationKey

  @supported_algorithms %{
    "ES256" => :es256,
    "Ed25519" => :ed25519,
    "ES256K" => :es256k,
    "ES256K_RECOVERABLE" => :es256k,
    "ML-DSA-65" => :ml_dsa65,
    "ML_DSA65" => :ml_dsa65
  }

  @doc """
  Ingests an affidavit mutation baseline plus signing-surface metadata.

  `input` is a map with:

    * `:baseline` -- decoded `mutations/BASELINE.json` map, or a path to
      the file (raw file bytes are what get hashed);
    * `:signing_surface` -- list of signing-surface vectors (e.g. rows of
      affidavit's `crypto_trust_kat.json` corpus: `%{"algorithm" => ...,
      "message_hex" => ..., "signature_hex" => ..., "public_key_hex" => ...}`).

  For each supported signing-surface vector: registers a
  `VerificationKey` (kid derived deterministically from algorithm + key
  material, idempotent on kid) and a `CertifiedReceipt` over the
  baseline's `subject_commit`, with `payload_hash_hex` = SHA-256 of the
  baseline's canonical JSON encoding (or of the raw file bytes when a
  path is given). Vectors whose algorithm is outside the admitted enum
  are returned under `:skipped` with the reason -- never silently
  dropped.
  """
  def ingest(input) when is_list(input), do: ingest(Map.new(input))

  def ingest(%{} = input) do
    raw_baseline = input[:baseline] || input["baseline"]
    vectors = input[:signing_surface] || input["signing_surface"] || []
    baseline = fetch_baseline(raw_baseline)

    subject =
      baseline["subject_commit"] ||
        raise ArgumentError, "baseline is missing subject_commit"

    baseline_hash = baseline_payload_hash(raw_baseline)

    with {:ok, keys} <- register_keys(vectors),
         {:ok, receipts} <- ingest_receipts(subject, baseline_hash, vectors) do
      {:ok,
       %{
         subject: subject,
         payload_hash_hex: baseline_hash,
         keys: keys,
         receipts: receipts,
         skipped: skipped(vectors)
       }}
    end
  end

  @doc """
  Records a verification result on a receipt. Write-once: an attempt to
  re-record on an already-verified receipt is refused.
  """
  def record_verification(%CertifiedReceipt{} = receipt, verified?, at \\ DateTime.utc_now()) do
    receipt
    |> Ash.Changeset.for_update(:record_verification, %{},
      context: %{verification_result: verified?, verified_at: at}
    )
    |> Ash.update()
  end

  @doc "Lists ingested receipts filtered to one admitted algorithm."
  def list_by_algorithm(algorithm) when is_atom(algorithm) do
    CertifiedReceipt
    |> Ash.Query.filter(algorithm: algorithm)
    |> Ash.read!()
  end

  # -- internals ---------------------------------------------------------

  defp fetch_baseline(%{} = baseline), do: baseline
  defp fetch_baseline(path) when is_binary(path), do: path |> File.read!() |> Jason.decode!()

  defp baseline_payload_hash(%{} = baseline), do: baseline |> Jason.encode!() |> sha256_hex()
  defp baseline_payload_hash(path) when is_binary(path), do: path |> File.read!() |> sha256_hex()

  defp sha256_hex(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)

  defp ingest_receipts(subject, _baseline_hash, vectors) do
    vectors
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {vector, index}, {:ok, acc} ->
      case algorithm_for(vector) do
        {:ok, algorithm} ->
          attrs = %{
            subject: "#{subject}:#{algorithm}:#{index}",
            payload_hash_hex: sha256_hex(vector["message_hex"] || ""),
            algorithm: algorithm,
            signature_hex: vector["signature_hex"] || "",
            verifying_key_hex: vector["public_key_hex"] || ""
          }

          case Ash.create(CertifiedReceipt, attrs, action: :ingest) do
            {:ok, receipt} ->
              {:cont, {:ok, [receipt | acc]}}

            # already ingested (subject, payload_hash) is unique: idempotent
            {:error, _error} ->
              case existing_receipt(attrs) do
                nil -> {:halt, {:error, {:ingest_refused, index, attrs.subject}}}
                receipt -> {:cont, {:ok, [receipt | acc]}}
              end
          end

        :skip ->
          {:cont, {:ok, acc}}
      end
    end)
    |> case do
      {:ok, receipts} -> {:ok, Enum.reverse(receipts)}
      other -> other
    end
  end

  defp register_keys(vectors) do
    vectors
    |> Enum.reduce_while({:ok, MapSet.new()}, fn vector, {:ok, seen} ->
      case algorithm_for(vector) do
        {:ok, algorithm} ->
          material = vector["public_key_hex"] || ""
          kid = kid(algorithm, material)

          if MapSet.member?(seen, kid) do
            {:cont, {:ok, seen}}
          else
            case Ash.create(VerificationKey, %{
                   kid: kid,
                   algorithm: algorithm,
                   key_material_hex: material
                 }) do
              {:ok, _key} ->
                {:cont, {:ok, MapSet.put(seen, kid)}}

              # already registered by an earlier ingest: idempotent on kid
              {:error, error} ->
                if key_exists?(kid) do
                  {:cont, {:ok, MapSet.put(seen, kid)}}
                else
                  {:halt, {:error, {:key_registration_refused, kid, error}}}
                end
            end
          end

        :skip ->
          {:cont, {:ok, seen}}
      end
    end)
    |> case do
      {:ok, _seen} -> {:ok, :registered}
      other -> other
    end
  end

  defp existing_receipt(attrs) do
    CertifiedReceipt
    |> Ash.Query.filter(subject: attrs.subject)
    |> Ash.read!()
    |> Enum.find(&(&1.payload_hash_hex == attrs.payload_hash_hex))
  end

  defp key_exists?(kid) do
    VerificationKey
    |> Ash.Query.filter(kid: kid)
    |> Ash.read!()
    |> Enum.any?()
  end

  defp algorithm_for(vector) do
    case Map.fetch(@supported_algorithms, vector["algorithm"] || "") do
      {:ok, algorithm} -> {:ok, algorithm}
      :error -> :skip
    end
  end

  defp kid(algorithm, material) do
    "#{algorithm}-" <> binary_part(sha256_hex("#{algorithm}:#{material}"), 0, 16)
  end

  defp skipped(vectors) do
    vectors
    |> Enum.with_index()
    |> Enum.flat_map(fn {vector, index} ->
      case algorithm_for(vector) do
        :skip -> [{index, vector["algorithm"], :algorithm_not_in_admitted_enum}]
        {:ok, _} -> []
      end
    end)
  end
end
