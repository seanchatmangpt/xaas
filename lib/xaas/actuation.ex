defmodule Xaas.Actuation do
  @moduledoc """
  Exclusive control-plane API for consequential Ash actions.

  The path is: ontology projection -> admission -> intent -> prepared receipt ->
  Ash.Reactor DO -> sealed receipt -> deterministic replay. The whole sequence is
  wrapped in the participating Ash data-layer transaction and Reactor is forced
  synchronous, so a committed database mutation cannot outrun its receipt.
  """

  alias Xaas.Operations.{ActuationIntent, ActuationReceipt}

  @spec run(module(), atom(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run(resource, action, input, opts \\ [])
      when is_atom(resource) and is_atom(action) and is_map(input) do
    with idempotency_key when is_binary(idempotency_key) and idempotency_key != "" <-
           Keyword.get(opts, :idempotency_key) do
      inputs = %{
        resource: resource,
        action: action,
        input: input,
        subject_id: Keyword.get(opts, :subject_id),
        actor: Keyword.get(opts, :actor),
        tenant: Keyword.get(opts, :tenant),
        authorize?: Keyword.get(opts, :authorize?, true),
        authority: Keyword.get(opts, :authority, %{}),
        idempotency_key: idempotency_key
      }

      resources = [resource, ActuationIntent, ActuationReceipt]

      transaction_result =
        Ash.DataLayer.transaction(
          resources,
          fn -> run_reactor_or_rollback(resources, inputs) end,
          nil,
          %{
            type: :custom,
            metadata: %{
              operation: :xaas_reactor_actuation,
              resource: resource,
              action: action,
              idempotency_key: idempotency_key
            }
          }
        )

      normalize_transaction_result(transaction_result)
    else
      _ -> {:error, :idempotency_key_required}
    end
  end

  defp run_reactor_or_rollback(resources, inputs) do
    case Reactor.run(Xaas.Actuation.Reactor, inputs, %{}, async?: false) do
      {:ok, envelope} ->
        envelope

      {:ok, envelope, _completed_reactor} ->
        envelope

      {:error, reason} ->
        Ash.DataLayer.rollback(resources, unwrap_reactor_error(reason))

      {:halted, reactor} ->
        Ash.DataLayer.rollback(resources, {:reactor_halted, reactor.state})

      other ->
        Ash.DataLayer.rollback(resources, {:unexpected_reactor_result, other})
    end
  end

  # Reactor wraps a step's own `{:error, reason}` return in
  # `%Reactor.Error.Invalid{errors: [%Reactor.Error.Invalid.RunStepError{error: reason}]}`.
  # Surface the step's original domain error (e.g. `{:idempotency_conflict, key}`)
  # directly rather than doubly-wrapping it in an opaque `{:reactor_failed, _}`
  # tag callers cannot pattern-match on.
  defp unwrap_reactor_error(%Reactor.Error.Invalid{errors: [%{error: inner} | _]}), do: inner
  defp unwrap_reactor_error(reason), do: {:reactor_failed, reason}

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
  Ash.Reactor implementing the only admitted consequential DO pipeline.

  `ash_step` is used rather than a plain Reactor step so Ash notification and
  execution semantics remain inside the Ash ecosystem. Every step is synchronous
  because this Reactor is deliberately transaction-coupled to its caller.
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

  def admit(args, _context) do
    with :ok <- admit_authority(args.authorize?, args.authority),
         {:ok, projection} <- Registry.admit(args.resource),
         projection_hash <- Registry.hash(projection),
         input_hash <-
           fingerprint({args.resource, args.action, args.subject_id, args.input, projection_hash}),
         {:ok, replay_or_new} <-
           find_or_create(args, projection, projection_hash, input_hash) do
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
    context = %{
      xaas_actuation: %{
        intent_id: to_string(admission.intent.id),
        receipt_id: to_string(admission.receipt.id),
        ontology_projection_hash: admission.projection_hash,
        idempotency_key: admission.intent.idempotency_key
      }
    }

    result =
      execute_action(
        admission.resource,
        admission.action,
        admission.subject_id,
        admission.raw_input,
        actor,
        tenant,
        authorize?,
        context
      )

    {:ok, result}
  rescue
    error -> {:ok, {:error, {:exception, error.__struct__, Exception.message(error)}}}
  catch
    kind, reason -> {:ok, {:error, {kind, reason}}}
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

  defp admit_authority(false, authority) when is_map(authority) and map_size(authority) > 0,
    do: :ok

  defp admit_authority(false, _authority),
    do: {:error, :delegated_actuation_requires_authority_evidence}

  defp admit_authority(true, _authority), do: :ok

  defp find_or_create(args, projection, projection_hash, input_hash) do
    case find_intent(args.idempotency_key) do
      {:ok, nil} -> create_admission(args, projection, projection_hash, input_hash)
      {:ok, intent} -> replay_or_refuse(intent, args, projection_hash, input_hash)
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

  defp replay_or_refuse(intent, args, projection_hash, input_hash) do
    cond do
      intent.resource_module != inspect(args.resource) or
          intent.action != Atom.to_string(args.action) or
          intent.subject_id != stringify(args.subject_id) or intent.input_hash != input_hash or
          intent.ontology_projection_hash != projection_hash ->
        {:error, {:idempotency_conflict, args.idempotency_key}}

      intent.status == :succeeded ->
        with {:ok, receipt} <- find_succeeded_receipt(intent.id),
             %ActuationReceipt{} = receipt <- receipt do
          {:ok,
           %{
             replay?: true,
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

      true ->
        {:error, {:idempotency_not_replayable, args.idempotency_key, intent.status}}
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
