defmodule Xaas.Ultracode.RemoteRelay do
  @moduledoc """
  Transport contract for remote Ultracode workers.

  This module is deliberately not a second actuation API. It validates ordered
  relay envelopes, binds them to one execution manifest, and derives stable
  idempotency keys. Consequential execution still routes through the existing
  Lease -> Xaas.Actuation.run/4 kernel.
  """

  defmodule Envelope do
    @enforce_keys [:command_id, :epoch_id, :task_id, :sequence, :intent_digest, :exact_subject, :verb]
    @type t :: %__MODULE__{
            command_id: String.t(),
            epoch_id: String.t(),
            task_id: String.t(),
            sequence: pos_integer(),
            intent_digest: String.t(),
            exact_subject: String.t(),
            verb: atom(),
            issued_at: integer() | nil,
            expires_at: integer() | nil,
            execution_manifest_digest: String.t() | nil,
            authority_ref: String.t() | nil,
            channel: :control | :observe
          }

    defstruct [
      :command_id,
      :epoch_id,
      :task_id,
      :sequence,
      :intent_digest,
      :exact_subject,
      :verb,
      :issued_at,
      :expires_at,
      :execution_manifest_digest,
      :authority_ref,
      channel: :control
    ]
  end

  defmodule State do
    @enforce_keys [:execution_manifest_digest]
    @type t :: %__MODULE__{
            execution_manifest_digest: String.t(),
            session_id: String.t() | nil,
            worker_id: String.t() | nil,
            last_acknowledged_sequence: non_neg_integer(),
            seen_command_ids: [String.t()],
            dedup_limit: pos_integer()
          }

    defstruct [
      :execution_manifest_digest,
      :session_id,
      :worker_id,
      last_acknowledged_sequence: 0,
      seen_command_ids: [],
      dedup_limit: 1024
    ]
  end

  @type failure_class :: :permanent | :transient | :ambiguous

  @spec new_state(keyword()) :: State.t()
  def new_state(opts) do
    digest = Keyword.fetch!(opts, :execution_manifest_digest)

    if not is_binary(digest) or digest == "" do
      raise ArgumentError, "execution_manifest_digest must be non-empty"
    end

    %State{
      execution_manifest_digest: digest,
      session_id: Keyword.get(opts, :session_id),
      worker_id: Keyword.get(opts, :worker_id),
      dedup_limit: max(1, Keyword.get(opts, :dedup_limit, 1024))
    }
  end

  @spec admit(State.t(), Envelope.t(), integer()) ::
          {:ok, State.t()} | {:replay, State.t()} | {:error, atom()}
  def admit(%State{} = state, %Envelope{} = envelope, now_ms \\ System.system_time(:millisecond)) do
    with :ok <- validate_envelope(envelope),
         :ok <- validate_expiry(envelope, now_ms),
         :ok <- validate_manifest(state, envelope),
         :ok <- validate_authority_shape(envelope) do
      cond do
        envelope.command_id in state.seen_command_ids ->
          {:replay, state}

        envelope.sequence <= state.last_acknowledged_sequence ->
          {:replay, state}

        envelope.sequence != state.last_acknowledged_sequence + 1 ->
          {:error, :sequence_gap}

        true ->
          {:ok, state}
      end
    end
  end

  @spec acknowledge(State.t(), Envelope.t()) :: {:ok, State.t()} | {:error, atom()}
  def acknowledge(%State{} = state, %Envelope{} = envelope) do
    if envelope.sequence == state.last_acknowledged_sequence + 1 do
      ids =
        [envelope.command_id | state.seen_command_ids]
        |> Enum.uniq()
        |> Enum.take(state.dedup_limit)

      {:ok,
       %{
         state
         | last_acknowledged_sequence: envelope.sequence,
           seen_command_ids: ids
       }}
    else
      {:error, :ack_sequence_mismatch}
    end
  end

  @doc """
  Bind relay retry identity to the existing XaaS idempotency seam.

  A caller may not substitute a different idempotency key.
  """
  @spec bind_actuation_idempotency(Envelope.t(), map()) :: {:ok, map()} | {:error, atom()}
  def bind_actuation_idempotency(%Envelope{verb: :actuate} = envelope, args) when is_map(args) do
    case Map.get(args, "idempotency_key") || Map.get(args, :idempotency_key) do
      nil ->
        {:ok, Map.put(args, "idempotency_key", envelope.command_id)}

      key when key == envelope.command_id ->
        {:ok, args}

      _ ->
        {:error, :idempotency_key_mismatch}
    end
  end

  def bind_actuation_idempotency(%Envelope{}, args) when is_map(args), do: {:ok, args}

  @spec classify_transport_failure(term()) :: failure_class()
  def classify_transport_failure(reason) when reason in [:unauthorized, :forbidden, :invalid_token],
    do: :permanent

  def classify_transport_failure(reason)
      when reason in [:timeout, :closed, :econnreset, :econnrefused, :dns],
      do: :transient

  def classify_transport_failure(_reason), do: :ambiguous

  defp validate_envelope(%Envelope{} = envelope) do
    required = [
      envelope.command_id,
      envelope.epoch_id,
      envelope.task_id,
      envelope.intent_digest,
      envelope.exact_subject
    ]

    cond do
      Enum.any?(required, &(not is_binary(&1) or &1 == "")) -> {:error, :invalid_envelope}
      not is_integer(envelope.sequence) or envelope.sequence < 1 -> {:error, :invalid_sequence}
      envelope.channel not in [:control, :observe] -> {:error, :invalid_channel}
      true -> :ok
    end
  end

  defp validate_expiry(%Envelope{expires_at: nil}, _now), do: :ok

  defp validate_expiry(%Envelope{expires_at: expires_at}, now)
       when is_integer(expires_at) and expires_at >= now,
       do: :ok

  defp validate_expiry(%Envelope{expires_at: _}, _now), do: {:error, :command_expired}

  defp validate_manifest(%State{execution_manifest_digest: expected}, %Envelope{
         execution_manifest_digest: expected
       }),
       do: :ok

  defp validate_manifest(%State{}, %Envelope{}), do: {:error, :execution_manifest_drift}

  defp validate_authority_shape(%Envelope{verb: :actuate, channel: :control, authority_ref: ref})
       when is_binary(ref) and ref != "",
       do: :ok

  defp validate_authority_shape(%Envelope{verb: :actuate}), do: {:error, :authority_ref_required}
  defp validate_authority_shape(%Envelope{}), do: :ok
end
