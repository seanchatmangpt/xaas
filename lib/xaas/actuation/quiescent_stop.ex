defmodule Xaas.Actuation.QuiescentStop do
  @moduledoc """
  Emergency-stop (Art. 14(4)(e)) surface over the lawful actuation kernel.

  Theorem 5.2: `u_stop` drives the system to a quiescent safe equilibrium with a
  typed receipt. The quiescent attractor is realized as a monotone stopped-state
  invariant: once the subject is driven to the quiescent status (`:suspended`
  for a `Xaas.Marketplace.Provider`), the stop surface admits no further
  actuation for that subject — same key replays idempotently, a fresh key
  refuses typed, and no new DO occurs.

  The stop is issued through `Xaas.Actuation.run/4` (`:actuate_status`, guarded
  by `Xaas.Actuation.Validations.ReactorContext`), so it inherits the same
  admission court, idempotency ledger, and sealed receipt as every other
  consequential DO — no side channel.

  ## Receipt contract

      {:ok, %{stopped_at, target: :quiescent, authority: ctx}}  # first stop
      {:ok, %{already_stopped: true}}                           # same key again
      {:error, :REFUSED_STOP_AUTHORITY}                         # missing authority (fail-closed)
      {:error, :idempotency_key_required}                       # missing idempotency key
      {:error, :REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT}         # fresh key, already-stopped subject
  """

  alias Xaas.Operations.ActuationIntent

  require Ash.Query

  @quiescent_status :suspended

  @spec execute(module(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(resource, opts) when is_atom(resource) and is_list(opts) do
    authority = Keyword.get(opts, :authority, %{})
    idempotency_key = Keyword.get(opts, :idempotency_key)

    cond do
      not (is_binary(idempotency_key) and idempotency_key != "") ->
        {:error, :idempotency_key_required}

      not authority_admitted?(authority) ->
        {:error, :REFUSED_STOP_AUTHORITY}

      true ->
        case find_intent(idempotency_key) do
          %ActuationIntent{} ->
            # Same key: the stop already happened. Idempotent replay of the
            # receipt identity, no new DO.
            {:ok, %{already_stopped: true}}

          nil ->
            if stopped?(resource, Keyword.get(opts, :subject_id)) do
              # Monotone attractor: a stopped subject admits no new stop DO.
              {:error, :REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT}
            else
              do_stop(resource, opts)
            end
        end
    end
  end

  defp do_stop(resource, opts) do
    case Xaas.Actuation.run(
           resource,
           :actuate_status,
           %{status: @quiescent_status},
           subject_id: Keyword.get(opts, :subject_id),
           idempotency_key: Keyword.get(opts, :idempotency_key),
           actor: Keyword.get(opts, :actor),
           tenant: Keyword.get(opts, :tenant),
           authorize?: false,
           authority: Keyword.fetch!(opts, :authority)
         ) do
      {:ok, %{status: :succeeded} = envelope} ->
        {:ok,
         %{
           stopped_at: Map.get(envelope.receipt, :completed_at) || DateTime.utc_now(),
           target: :quiescent,
           authority: Keyword.fetch!(opts, :authority)
         }}

      {:ok, %{status: refused_or_failed} = envelope}
      when refused_or_failed in [:refused, :failed] ->
        {:error, {refused_or_failed, envelope.error}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_intent(idempotency_key) do
    case Ash.read_one(
           Ash.Query.filter(ActuationIntent, idempotency_key == ^idempotency_key),
           authorize?: false
         ) do
      {:ok, intent} -> intent
      {:error, reason} -> raise "quiescent stop ledger read failed: #{inspect(reason)}"
    end
  end

  defp stopped?(resource, subject_id) do
    case Ash.get(resource, subject_id, authorize?: false) do
      {:ok, record} -> record.status == @quiescent_status
      {:error, _} -> false
    end
  end

  defp authority_admitted?(%{kind: kind} = authority) when is_binary(kind) and kind != "" do
    case Map.get(authority, :source) do
      source when is_binary(source) and source != "" -> true
      _ -> false
    end
  end

  defp authority_admitted?(_), do: false
end
