defmodule Xaas.Actuation do
  @moduledoc """
  Exclusive control-plane API for consequential Ash actions.

  Local Ash consequences use the original single-transaction path:

      ontology projection -> admission -> intent/prepared receipt
        -> synchronous Ash.Reactor DO -> sealed receipt -> replay

  External consequences cannot lawfully pretend a Postgres rollback can undo a remote
  side effect. `prepare_external/4`, `checkpoint_external/2`, and `seal_external/2`
  therefore expose the same admission/receipt kernel as a three-commit protocol:

      durable admission/prepared receipt
        -> durable inert external CONSTRUCT checkpoint
        -> external receipted DO
        -> durable outer seal

  If the outer seal is interrupted, the prepared receipt and construct checkpoint remain
  durable and can be recovered without manufacturing a new consequence identity.
  """

  alias Xaas.Operations.{ActuationIntent, ActuationReceipt}

  @spec run(module(), atom(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run(resource, action, input, opts \\ [])
      when is_atom(resource) and is_atom(action) and is_map(input) do
    with {:ok, inputs} <- inputs(resource, action, input, opts) do
      resources = [resource, ActuationIntent, ActuationReceipt]

      transaction_result =
        Ash.DataLayer.transaction(
          resources,
          fn -> run_reactor_or_rollback(resources, inputs) end,
          nil,
          transaction_metadata(:xaas_reactor_actuation, inputs)
        )

      normalize_transaction_result(transaction_result)
    end
  end

  @doc "Durably admit an external consequence before any remote DO can occur."
  @spec prepare_external(module(), atom(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def prepare_external(resource, action, input, opts \\ [])
      when is_atom(resource) and is_atom(action) and is_map(input) do
    with {:ok, inputs} <- inputs(resource, action, input, opts) do
      resources = [resource, ActuationIntent, ActuationReceipt]

      transaction_result =
        Ash.DataLayer.transaction(
          resources,
          fn ->
            case Xaas.Actuation.Kernel.admit_external(inputs, %{}) do
              {:ok, %{replay?: true} = admission} ->
                %{
                  status: :replayed,
                  replay?: true,
                  result: admission.receipt.result,
                  intent: admission.intent,
                  receipt: admission.receipt,
                  admission: admission
                }

              {:ok, admission} ->
                %{
                  status: :prepared,
                  replay?: false,
                  admission: admission,
                  intent: admission.intent,
                  receipt: admission.receipt
                }

              {:error, reason} ->
                Ash.DataLayer.rollback(resources, {:external_admission_failed, reason})
            end
          end,
          nil,
          transaction_metadata(:xaas_external_prepare, inputs)
        )

      normalize_external_prepare(transaction_result)
    end
  end

  @doc "Durably bind an inert external construct to the already-prepared outer receipt."
  @spec checkpoint_external(map(), map()) :: {:ok, map()} | {:error, term()}
  def checkpoint_external(%{replay?: false} = admission, checkpoint) when is_map(checkpoint) do
    resources = [admission.resource, ActuationIntent, ActuationReceipt]

    result =
      Ash.DataLayer.transaction(
        resources,
        fn ->
          case Xaas.Actuation.Kernel.checkpoint_external(admission, checkpoint) do
            {:ok, updated} -> updated
            {:error, reason} -> Ash.DataLayer.rollback(resources, {:external_checkpoint_failed, reason})
          end
        end,
        nil,
        %{
          type: :custom,
          metadata: %{
            operation: :xaas_external_checkpoint,
            resource: admission.resource,
            action: admission.action,
            idempotency_key: admission.intent.idempotency_key
          }
        }
      )

    unwrap_transaction(result)
  end

  @doc "Seal a previously prepared external admission after its independent receipted DO."
  @spec seal_external(map(), {:ok, term()} | {:error, term()}) :: {:ok, map()} | {:error, term()}
  def seal_external(%{replay?: false} = admission, execution)
      when is_tuple(execution) do
    resources = [admission.resource, ActuationIntent, ActuationReceipt]

    result =
      Ash.DataLayer.transaction(
        resources,
        fn ->
          case Xaas.Actuation.Kernel.seal(%{admission: admission, execution: execution}, %{}) do
            {:ok, envelope} -> envelope
            {:error, reason} -> Ash.DataLayer.rollback(resources, {:external_seal_failed, reason})
          end
        end,
        nil,
        %{
          type: :custom,
          metadata: %{
            operation: :xaas_external_seal,
            resource: admission.resource,
            action: admission.action,
            idempotency_key: admission.intent.idempotency_key
          }
        }
      )

    normalize_transaction_result(result)
  end

  @doc "Return the immutable XaaS Reactor authority context for a persisted admission."
  @spec context(map()) :: map()
  def context(admission) do
    %{
      xaas_actuation: %{
        intent_id: to_string(admission.intent.id),
        receipt_id: to_string(admission.receipt.id),
        ontology_projection_hash: admission.projection_hash,
        idempotency_key: admission.intent.idempotency_key
      }
    }
  end

  defp inputs(resource, action, input, opts) do
    with idempotency_key when is_binary(idempotency_key) and idempotency_key != "" <-
           Keyword.get(opts, :idempotency_key) do
      {:ok,
       %{
         resource: resource,
         action: action,
         input: input,
         subject_id: Keyword.get(opts, :subject_id),
         actor: Keyword.get(opts, :actor),
         tenant: Keyword.get(opts, :tenant),
         authorize?: Keyword.get(opts, :authorize?, true),
         authority: Keyword.get(opts, :authority, %{}),
         idempotency_key: idempotency_key
       }}
    else
      _ -> {:error, :idempotency_key_required}
    end
  end

  defp transaction_metadata(operation, inputs) do
    %{
      type: :custom,
      metadata: %{
        operation: operation,
        resource: inputs.resource,
        action: inputs.action,
        idempotency_key: inputs.idempotency_key
      }
    }
  end

  defp run_reactor_or_rollback(resources, inputs) do
    case Reactor.run(Xaas.Actuation.Reactor, inputs, %{}, async?: false) do
      {:ok, envelope} ->
        envelope

      {:ok, envelope, _completed_reactor} ->
        envelope

      {:error, reason} ->
        Ash.DataLayer.rollback(resources, {:reactor_failed, reason})

      {:halted, reactor} ->
        Ash.DataLayer.rollback(resources, {:reactor_halted, reactor.state})

      other ->
        Ash.DataLayer.rollback(resources, {:unexpected_reactor_result, other})
    end
  end

  defp normalize_external_prepare({:ok, %{status: status} = result})
       when status in [:prepared, :replayed],
       do: {:ok, result}

  defp normalize_external_prepare({:error, reason}), do: {:error, reason}
  defp normalize_external_prepare(other), do: {:error, {:unexpected_external_prepare, other}}

  defp unwrap_transaction({:ok, result}), do: {:ok, result}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}
  defp unwrap_transaction(other), do: {:error, {:unexpected_external_transaction, other}}

  defp normalize_transaction_result({:ok, result}), do: normalize_transaction_result(result)
  defp normalize_transaction_result({:error, reason}), do: {:error, reason}

  defp normalize_transaction_result(%{status: :succeeded} = envelope), do: {:ok, envelope}
  defp normalize_transaction_result(%{status: :replayed} = envelope), do: {:ok, envelope}

  defp normalize_transaction_result(%{status: :failed, error: error}), do: {:error, error}

  defp normalize_transaction_result(other),
    do: {:error, {:unexpected_actuation_result, other}}
end

defmodule Xaas.Actuation.Reactor do
  @moduledoc """
  Ash.Reactor implementing the transaction-coupled local consequential DO pipeline.

  External, non-rollbackable consequences use `Xaas.Actuation.prepare_external/4` and
  a domain-specific Reactor that persists its inert checkpoint before crossing DO.
  """

  use Reactor, extensions: [Ash.Reactor]

  input :resource
  input :action
  input :input
  input :subject_id
  input :actor
  input :tenant
  input :authorize?
  input :authority
  input :idempotency_key

  ash_step :admit do
    async? false
    argument :resource, input(:resource)
    argument :action, input(:action)
    argument :input, input(:input)
    argument :subject_id, input(:subject_id)
    argument :actor, input(:actor)
    argument :tenant, input(:tenant)
    argument :authorize?, input(:authorize?)
    argument :authority, input(:authority)
    argument :idempotency_key, input(:idempotency_key)
    run &Xaas.Actuation.Kernel.admit/2
  end

  ash_step :do do
    async? false
    argument :admission, result(:admit)
    argument :actor, input(:actor)
    argument :tenant, input(:tenant)
    argument :authorize?, input(:authorize?)
    run &Xaas.Actuation.Kernel.actuate/2
  end

  ash_step :receipt do
    async? false
    argument :admission, result(:admit)
    argument :execution, result(:do)
    run &Xaas.Actuation.Kernel.seal/2
  end

  return :receipt
end

defmodule Xaas.Actuation.Kernel do
  @moduledoc false

  require Ash.Query

  alias Xaas.Operations.{ActuationIntent, ActuationReceipt}
  alias Xaas.Semantics.Registry

  def admit(args, _context), do: do_admit(args, :transactional)
  def admit_external(args, _context), do: do_admit(args, :external)

  defp do_admit(args, mode) do
    with :ok <- admit_authority(args.authorize?, args.authority),
         {:ok, projection} <- Registry.admit(args.resource),
         projection_hash <- Registry.hash(projection),
         input_hash <-
           fingerprint({args.resource, args.action, args.subject_id, args.input, projection_hash}),
         {:ok, replay_or_new} <-
           find_or_create(args, projection, projection_hash, input_hash, mode) do
      {:ok, replay_or_new}
    end
  end

  def actuate(%{admission: %{replay?: true} = admission}, _context) do
    {:ok, {:replayed, admission.receipt.result}}
  end

  def actuate(%{
        admission: admission,
        actor: actor,
        tenant: tenant,
        authorize?: authorize?
      }, _context) do
    result =
      execute_action(
        admission.resource,
        admission.action,
        admission.subject_id,
        admission.raw_input,
        actor,
        tenant,
        authorize?,
        Xaas.Actuation.context(admission)
      )

    {:ok, result}
  rescue
    error -> {:ok, {:error, {:exception, error.__struct__, Exception.message(error)}}}
  catch
    kind, reason -> {:ok, {:error, {kind, reason}}}
  end

  def checkpoint_external(%{replay?: false} = admission, checkpoint) when is_map(checkpoint) do
    with {:ok, receipt} <- Ash.get(ActuationReceipt, admission.receipt.id, authorize?: false),
         {:ok, intent} <- Ash.get(ActuationIntent, admission.intent.id, authorize?: false),
         :ok <- verify_external_prepared(intent, receipt, admission),
         checkpoint_snapshot <- json_safe(checkpoint),
         checkpoint_hash <- fingerprint(checkpoint) do
      cond do
        receipt.result == %{} and is_nil(receipt.result_hash) ->
          with {:ok, receipt} <-
                 Ash.update(
                   receipt,
                   %{result: checkpoint_snapshot, result_hash: checkpoint_hash},
                   action: :checkpoint,
                   authorize?: false
                 ) do
            {:ok, %{admission | receipt: receipt, intent: intent, resumed?: false}}
          end

        receipt.result_hash == checkpoint_hash and receipt.result == checkpoint_snapshot ->
          {:ok, %{admission | receipt: receipt, intent: intent, resumed?: true}}

        true ->
          {:error, {:external_checkpoint_conflict, intent.idempotency_key}}
      end
    end
  end

  def seal(%{admission: %{replay?: true} = admission, execution: {:replayed, result}}, _context) do
    {:ok,
     %{
       status: :replayed,
       replay?: true,
       result: result,
       intent: admission.intent,
       receipt: admission.receipt
     }}
  end

  def seal(%{admission: admission, execution: {:ok, result}}, _context) do
    result_snapshot = json_safe(result)
    result_hash = fingerprint(result)
    completed_at = DateTime.utc_now()

    with {:ok, receipt} <-
           Ash.update(
             admission.receipt,
             %{
               status: :succeeded,
               result: result_snapshot,
               result_hash: result_hash,
               completed_at: completed_at
             },
             action: :seal,
             authorize?: false
           ),
         {:ok, intent} <-
           Ash.update(admission.intent, %{status: :succeeded},
             action: :transition,
             authorize?: false
           ) do
      {:ok,
       %{
         status: :succeeded,
         replay?: false,
         result: result,
         intent: intent,
         receipt: receipt
       }}
    end
  end

  def seal(%{admission: admission, execution: {:error, reason}}, _context) do
    completed_at = DateTime.utc_now()
    error = json_safe(reason)

    with {:ok, receipt} <-
           Ash.update(
             admission.receipt,
             %{status: :failed, error: error, completed_at: completed_at},
             action: :seal,
             authorize?: false
           ),
         {:ok, intent} <-
           Ash.update(admission.intent, %{status: :failed},
             action: :transition,
             authorize?: false
           ) do
      {:ok,
       %{
         status: :failed,
         replay?: false,
         error: reason,
         intent: intent,
         receipt: receipt
       }}
    end
  end

  defp verify_external_prepared(intent, receipt, admission) do
    cond do
      intent.status != :executing ->
        {:error, {:external_intent_not_executing, intent.status}}

      receipt.status != :prepared ->
        {:error, {:external_receipt_not_prepared, receipt.status}}

      to_string(receipt.intent_id) != to_string(intent.id) ->
        {:error, :external_receipt_intent_mismatch}

      intent.id != admission.intent.id or receipt.id != admission.receipt.id ->
        {:error, :external_admission_identity_mismatch}

      intent.ontology_projection_hash != admission.projection_hash or
          receipt.ontology_projection_hash != admission.projection_hash ->
        {:error, :external_projection_mismatch}

      intent.input_hash != receipt.input_hash ->
        {:error, :external_input_mismatch}

      true ->
        :ok
    end
  end

  defp admit_authority(false, authority) when is_map(authority) and map_size(authority) > 0,
    do: :ok

  defp admit_authority(false, _authority),
    do: {:error, :delegated_actuation_requires_authority_evidence}

  defp admit_authority(true, _authority), do: :ok

  defp find_or_create(args, projection, projection_hash, input_hash, mode) do
    case find_intent(args.idempotency_key) do
      {:ok, nil} -> create_admission(args, projection, projection_hash, input_hash)
      {:ok, intent} -> replay_or_refuse(intent, args, projection, projection_hash, input_hash, mode)
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_admission(args, projection, projection_hash, input_hash) do
    class_iri = projection.classes |> List.first() |> to_string()

    attrs = %{
      idempotency_key: args.idempotency_key,
      resource_module: inspect(args.resource),
      action: Atom.to_string(args.action),
      subject_id: stringify(args.subject_id),
      ontology_class_iri: class_iri,
      ontology_projection_hash: projection_hash,
      input_hash: input_hash,
      actor_ref: actor_ref(args.actor),
      tenant_ref: stringify(args.tenant),
      authority: json_safe(args.authority),
      input: json_safe(args.input),
      status: :admitted
    }

    with {:ok, intent} <- Ash.create(ActuationIntent, attrs, action: :admit, authorize?: false),
         replay_token <- fingerprint({args.idempotency_key, input_hash, 1}),
         {:ok, receipt} <-
           Ash.create(
             ActuationReceipt,
             %{
               intent_id: intent.id,
               attempt: 1,
               status: :prepared,
               resource_module: inspect(args.resource),
               action: Atom.to_string(args.action),
               subject_id: stringify(args.subject_id),
               ontology_class_iri: class_iri,
               ontology_projection_hash: projection_hash,
               input_hash: input_hash,
               replay_token: replay_token,
               started_at: DateTime.utc_now()
             },
             action: :prepare,
             authorize?: false
           ),
         {:ok, intent} <-
           Ash.update(intent, %{status: :executing}, action: :transition, authorize?: false) do
      {:ok,
       %{
         replay?: false,
         resumed?: false,
         resource: args.resource,
         action: args.action,
         subject_id: args.subject_id,
         raw_input: args.input,
         projection: projection,
         projection_hash: projection_hash,
         intent: intent,
         receipt: receipt
       }}
    end
  end

  defp replay_or_refuse(intent, args, projection, projection_hash, input_hash, mode) do
    cond do
      intent.resource_module != inspect(args.resource) or
          intent.action != Atom.to_string(args.action) or
          intent.subject_id != stringify(args.subject_id) or intent.input_hash != input_hash or
          intent.ontology_projection_hash != projection_hash ->
        {:error, {:idempotency_conflict, args.idempotency_key}}

      intent.status == :succeeded ->
        replay_succeeded(intent, args, projection_hash)

      mode == :external and intent.status == :executing ->
        resume_external(intent, args, projection, projection_hash)

      true ->
        {:error, {:idempotency_not_replayable, args.idempotency_key, intent.status}}
    end
  end

  defp replay_succeeded(intent, args, projection_hash) do
    with {:ok, receipt} <- find_succeeded_receipt(intent.id),
         %ActuationReceipt{} = receipt <- receipt do
      {:ok,
       %{
         replay?: true,
         resumed?: false,
         resource: args.resource,
         action: args.action,
         subject_id: args.subject_id,
         raw_input: args.input,
         projection_hash: projection_hash,
         intent: intent,
         receipt: receipt
       }}
    else
      nil -> {:error, {:receipt_missing_for_succeeded_intent, intent.id}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp resume_external(intent, args, projection, projection_hash) do
    with {:ok, receipt} <- find_prepared_receipt(intent.id),
         %ActuationReceipt{} = receipt <- receipt do
      {:ok,
       %{
         replay?: false,
         resumed?: true,
         resource: args.resource,
         action: args.action,
         subject_id: args.subject_id,
         raw_input: args.input,
         projection: projection,
         projection_hash: projection_hash,
         intent: intent,
         receipt: receipt
       }}
    else
      nil -> {:error, {:prepared_receipt_missing_for_external_intent, intent.id}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp find_intent(key) do
    query =
      ActuationIntent
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(idempotency_key == ^key)

    Ash.read_one(query, authorize?: false)
  end

  defp find_succeeded_receipt(intent_id) do
    query =
      ActuationReceipt
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(intent_id == ^intent_id and status == :succeeded)

    Ash.read_one(query, authorize?: false)
  end

  defp find_prepared_receipt(intent_id) do
    query =
      ActuationReceipt
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(intent_id == ^intent_id and status == :prepared)

    Ash.read_one(query, authorize?: false)
  end

  defp execute_action(resource, action, subject_id, input, actor, tenant, authorize?, context) do
    common = [action: action, authorize?: authorize?, actor: actor, tenant: tenant, context: context]

    case Ash.Resource.Info.action(resource, action) do
      %Ash.Resource.Actions.Create{} ->
        Ash.create(resource, input, common)

      %Ash.Resource.Actions.Update{} ->
        with {:ok, record} <- get_subject(resource, subject_id, actor, tenant, authorize?) do
          Ash.update(record, input, common)
        end

      %Ash.Resource.Actions.Destroy{} ->
        with {:ok, record} <- get_subject(resource, subject_id, actor, tenant, authorize?) do
          changeset =
            Ash.Changeset.for_destroy(record, action, input,
              actor: actor,
              tenant: tenant,
              context: context
            )

          Ash.destroy(changeset, authorize?: authorize?, actor: actor, tenant: tenant)
        end

      %Ash.Resource.Actions.Action{} ->
        action_input =
          Ash.ActionInput.for_action(resource, action, input,
            actor: actor,
            tenant: tenant,
            context: context
          )

        Ash.run_action(action_input, authorize?: authorize?, actor: actor, tenant: tenant)

      nil ->
        {:error, {:unknown_action, resource, action}}

      other ->
        {:error, {:unsupported_actuation_action, other.__struct__, action}}
    end
  end

  defp get_subject(_resource, nil, _actor, _tenant, _authorize?),
    do: {:error, :subject_id_required}

  defp get_subject(resource, subject_id, actor, tenant, authorize?) do
    Ash.get(resource, subject_id,
      actor: actor,
      tenant: tenant,
      authorize?: authorize?
    )
  end

  defp fingerprint(term) do
    term
    |> canonical_term()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical_term(%_{} = struct), do: struct |> Map.from_struct() |> canonical_term()

  defp canonical_term(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), canonical_term(value)} end)
    |> Enum.sort()
  end

  defp canonical_term(list) when is_list(list), do: Enum.map(list, &canonical_term/1)

  defp canonical_term(tuple) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> Enum.map(&canonical_term/1)

  defp canonical_term(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp canonical_term(other), do: other

  defp json_safe(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp json_safe(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)

  defp json_safe(%_{} = struct) do
    %{
      "type" => inspect(struct.__struct__),
      "id" => struct |> Map.get(:id) |> stringify(),
      "value" => inspect(struct)
    }
  end

  defp json_safe(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), json_safe(value)} end)
  end

  defp json_safe(list) when is_list(list), do: Enum.map(list, &json_safe/1)
  defp json_safe(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> Enum.map(&json_safe/1)
  defp json_safe(atom) when is_atom(atom), do: Atom.to_string(atom)

  defp json_safe(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: value

  defp json_safe(value), do: inspect(value)

  defp actor_ref(nil), do: nil
  defp actor_ref(%{id: id}), do: stringify(id)
  defp actor_ref(%{org_id: org_id}), do: "org:" <> stringify(org_id)
  defp actor_ref(actor), do: inspect(actor)

  defp stringify(nil), do: nil
  defp stringify(value) when is_binary(value), do: value
  defp stringify(value), do: to_string(value)
end
