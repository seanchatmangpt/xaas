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
      {:error, :REFUSED_STOP_CLAIM_CONTENTION}                  # concurrent fresh-key claim lost, winner not yet quiescent

  ## Concurrent-stop arbitration (W984ct)

  Two concurrent stops that pass the pre-DO checks before either commits are
  arbitrated by intent-ledger uniqueness — the same exactly-once primitive the
  kernel uses for idempotency — via a subject-scoped claim intent
  (`quiescent-stop:<resource>:<subject_id>`). The claim row is a genuine stop
  intent for the same resource/action/subject/input; its derived key makes the
  ledger's unique identity arbitrate the race:

  - exactly one racer's claim insert commits → it performs the stop DO;
  - the loser's insert fails on `unique_idempotency_key` → it re-checks the
    attractor under a bounded wait: once the winner's DO lands, the loser
    refuses typed `:REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT`; if the winner's
    DO does not land within the window, the loser refuses typed
    `:REFUSED_STOP_CLAIM_CONTENTION`.

  A claim left `:failed` by a failed stop attempt is taken over by the next
  stop so a failed stop cannot strand the subject behind a dead claim.
  """


  alias Xaas.Operations.ActuationIntent
  alias Xaas.Semantics.Registry

  require Ash.Query

  @quiescent_status :suspended

  @claim_action "actuate_status"
  @claim_wait_attempts 40
  @claim_wait_interval_ms 25

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
    case claim_stop(resource, opts) do
      :claimed ->
        run_stop(resource, opts)

      {:lost, :quiescent} ->
        {:error, :REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT}

      {:lost, :contended} ->
        {:error, :REFUSED_STOP_CLAIM_CONTENTION}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # W984ct (W984cf-2 fix): concurrent fresh-key stops on one subject are
  # arbitrated by intent-ledger uniqueness — the kernel's own exactly-once
  # primitive. The claim row is a genuine stop intent for the same
  # resource/action/subject/input; its subject-scoped derived key makes the
  # ledger's `unique_idempotency_key` identity arbitrate the race: exactly one
  # claim insert commits and only the claim holder performs the stop DO. A
  # claim left `:failed`/`:refused` by a failed stop attempt is taken over by
  # the next stop so a failed stop cannot strand the subject.
  defp claim_stop(resource, opts) do
    subject_id = Keyword.get(opts, :subject_id)

    if is_nil(subject_id) do
      # No subject to claim against; the kernel still binds the DO itself.
      :claimed
    else
      case Ash.create(ActuationIntent, claim_attrs(resource, opts, subject_id),
             action: :admit,
             authorize?: false
           ) do
        {:ok, _claim} ->
          :claimed

        {:error, _claim_error} ->
          # Unique violation: another authority holds the claim. Take over a
          # dead claim, otherwise re-check the attractor under a bounded wait.
          case Ash.read_one(
                 Ash.Query.filter(ActuationIntent, idempotency_key == ^claim_key(resource, subject_id)),
                 authorize?: false
               ) do
            {:ok, %ActuationIntent{status: status} = claim}
            when status in [:failed, :refused] ->
              case Ash.update(claim, %{status: :admitted}, action: :transition, authorize?: false) do
                {:ok, _} -> :claimed
                {:error, _} -> lose_claim(resource, subject_id)
              end

            {:ok, %ActuationIntent{}} ->
              lose_claim(resource, subject_id)

            _ ->
              {:error, :REFUSED_STOP_CLAIM_CONTENTION}
          end
      end
    end
  end

  defp lose_claim(resource, subject_id) do
    if await_quiescent?(resource, subject_id),
      do: {:lost, :quiescent},
      else: {:lost, :contended}
  end

  defp await_quiescent?(resource, subject_id) do
    if stopped?(resource, subject_id) do
      true
    else
      Enum.any?(1..@claim_wait_attempts, fn _ ->
        Process.sleep(@claim_wait_interval_ms)
        stopped?(resource, subject_id)
      end)
    end
  end

  defp claim_key(resource, subject_id),
    do: "quiescent-stop:" <> inspect(resource) <> ":" <> to_string(subject_id)

  defp claim_attrs(resource, opts, subject_id) do
    with {:ok, projection} <- Registry.admit(resource) do
      projection_hash = Registry.hash(projection)
      input = %{status: @quiescent_status}

      %{
        idempotency_key: claim_key(resource, subject_id),
        resource_module: inspect(resource),
        action: @claim_action,
        subject_id: to_string(subject_id),
        ontology_class_iri: projection.classes |> List.first() |> to_string(),
        ontology_projection_hash: projection_hash,
        input_hash: fingerprint(input, projection_hash),
        actor_ref: actor_ref(Keyword.get(opts, :actor)),
        tenant_ref: to_string(Keyword.get(opts, :tenant)),
        authority: Keyword.get(opts, :authority, %{}),
        input: input,
        status: :admitted
      }
    end
  end

  defp fingerprint(input, projection_hash) do
    :crypto.hash(:sha256, :erlang.term_to_binary({input, projection_hash}))
    |> Base.encode16(case: :lower)
  end

  defp actor_ref(nil), do: nil

  defp actor_ref(actor) do
    if is_binary(actor), do: actor, else: inspect(actor)
  end

  defp run_stop(resource, opts) do
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

      # W984cf-1 (W984ct fix): a same-key racer that passes the pre-DO
      # `find_intent` window reaches the kernel, which replays the sealed
      # intent as `{:ok, %{status: :replayed, replay?: true}}` — the identical
      # stop DO already landed. The honest loser outcome is the idempotent
      # replay `{:ok, %{already_stopped: true}}`, not a CaseClauseError.
      {:ok, %{status: :replayed}} ->
        {:ok, %{already_stopped: true}}

      {:ok, %{status: refused_or_failed} = envelope}
      when refused_or_failed in [:refused, :failed] ->
        release_claim(resource, opts)
        {:error, {refused_or_failed, envelope.error}}

      {:error, reason} ->
        release_claim(resource, opts)
        {:error, reason}
    end
  end

  # A failed stop DO must not strand the subject behind an `:admitted` claim —
  # mark the claim dead so the next stop's takeover leg can proceed.
  defp release_claim(resource, opts) do
    subject_id = Keyword.get(opts, :subject_id)

    with %ActuationIntent{} = claim <-
           claim_row(resource, subject_id),
         {:ok, _} <-
           Ash.update(claim, %{status: :failed}, action: :transition, authorize?: false) do
      :ok
    else
      _ -> :ok
    end
  end

  defp claim_row(resource, subject_id) do
    case Ash.read_one(
           Ash.Query.filter(ActuationIntent, idempotency_key == ^claim_key(resource, subject_id)),
           authorize?: false
         ) do
      {:ok, claim} -> claim
      {:error, _} -> nil
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
