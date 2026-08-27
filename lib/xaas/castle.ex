defmodule Xaas.Castle do
  @moduledoc """
  Receipt-bound XaaS -> CASTLE PaaS bridge.

  XaaS remains the outer platform/governance plane, but CASTLE provider DO is an
  external consequence and therefore does **not** run inside the XaaS Postgres
  transaction. The lawful path is:

      XaaS ontology admission
        -> durable outer intent + prepared receipt
        -> CASTLE inert construct manufacture
        -> durable outer construct checkpoint
        -> CASTLE BRCE PREPARE -> provider DO -> BRCE OUTCOME -> durable evidence
        -> XaaS outer receipt seal
        -> deterministic replay/recovery

  If the process dies after CASTLE DO and before the XaaS seal, the outer prepared
  receipt and construct checkpoint survive. A retry resumes the same admission and
  asks CASTLE to verify the deterministic evidence directory before considering a
  second DO. Verified evidence is recovery proof; an unverified file is not.
  """

  alias Xaas.Operations.RouteCastleRun

  @spec run(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run(intent, opts) when is_map(intent) and is_list(opts) do
    with {:ok, request} <- request(intent, opts),
         {:ok, prepared} <-
           Xaas.Actuation.prepare_external(
             RouteCastleRun,
             :execute,
             %{intent: intent},
             subject_id: request.subject,
             idempotency_key: request.idempotency_key,
             actor: request.actor,
             tenant: request.tenant,
             authorize?: false,
             authority: request.authority
           ) do
      case prepared do
        %{status: :replayed} = replay ->
          {:ok, Map.drop(replay, [:admission])}

        %{status: :prepared, admission: admission} ->
          run_external_reactor(admission, intent, request)
      end
    end
  end

  @spec contract_identity() :: map()
  def contract_identity, do: Xaas.Castle.Contract.identity()

  defp run_external_reactor(admission, intent, request) do
    inputs = %{
      admission: admission,
      intent: intent,
      actor: request.actor,
      tenant: request.tenant,
      kernel: Application.get_env(:kanban, :castle_kernel_module, Xaas.Castle.Kernel.CLI),
      now_epoch_ms: System.system_time(:millisecond)
    }

    case Reactor.run(Xaas.Castle.Reactor, inputs, %{}, async?: false) do
      {:ok, envelope} -> {:ok, envelope}
      {:ok, envelope, _reactor} -> {:ok, envelope}
      {:error, reason} -> {:error, reason}
      {:halted, reactor} -> {:error, {:castle_reactor_halted, reactor.state}}
      other -> {:error, {:unexpected_castle_reactor_result, other}}
    end
  end

  defp request(intent, opts) do
    idempotency_key = Keyword.get(opts, :idempotency_key)
    authority = Keyword.get(opts, :authority)
    subject = field(intent, :subject)

    cond do
      not (is_binary(idempotency_key) and idempotency_key != "") ->
        {:error, :idempotency_key_required}

      not (is_map(authority) and map_size(authority) > 0) ->
        {:error, :castle_authority_evidence_required}

      not (is_binary(subject) and subject != "") ->
        {:error, :castle_subject_required}

      true ->
        {:ok,
         %{
           idempotency_key: idempotency_key,
           authority: authority,
           subject: subject,
           actor: Keyword.get(opts, :actor),
           tenant: Keyword.get(opts, :tenant)
         }}
    end
  end

  defp field(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
end

defmodule Xaas.Castle.Contract do
  @moduledoc false

  @castle_paas_source_sha "a71801dcc0c0783eb8a4544cbee8b40bb0b30296"
  @castle_paas_pack_sha "238b408c5cf74e8334046165ac87102026bd8c1e"
  @ash_r2rml_sha "067954ad406fd637fd47646bdb10c4580809c79d"
  @protocol "CASTLE_PAAS_XAAS_BRIDGE_V1"

  @spec identity() :: map()
  def identity do
    %{
      protocol: @protocol,
      castle_paas_source_sha: @castle_paas_source_sha,
      castle_paas_pack_sha: @castle_paas_pack_sha,
      ash_r2rml_sha: @ash_r2rml_sha,
      xaas_actuation:
        "ontology->durable-admission/prepared-receipt->construct-checkpoint->external-reactor->sealed-receipt->replay",
      castle_actuation:
        "construct->admission->brce-prepare->do->brce-outcome->content-addressed-evidence->verify/recover"
    }
  end
end

defmodule Xaas.Castle.Kernel do
  @moduledoc "Narrow CASTLE consequence-kernel boundary."

  @type result :: {:ok, map()} | {:error, term()}

  @callback release_info() :: result()
  @callback manufacture(map(), map()) :: result()
  @callback execute(map(), map(), map(), integer()) :: result()
end

defmodule Xaas.Castle.Reactor do
  @moduledoc """
  External-consequence Reactor for the XaaS -> CASTLE bridge.

  The construct is inert. The outer checkpoint is committed before the private Ash
  action is invoked. That private action is the sole step allowed to cross CASTLE DO,
  and it independently reloads/validates the outer admission and checkpoint.
  """

  use Reactor

  input :admission
  input :intent
  input :actor
  input :tenant
  input :kernel
  input :now_epoch_ms

  step :witness do
    async? false
    argument :admission, input(:admission)
    argument :intent, input(:intent)
    argument :now_epoch_ms, input(:now_epoch_ms)

    run fn args, _context ->
      Xaas.Castle.Admission.witness(args.admission, args.intent, args.now_epoch_ms)
    end
  end

  step :manufacture_construct do
    async? false
    argument :kernel, input(:kernel)
    argument :intent, input(:intent)
    argument :witness, result(:witness)

    run fn args, _context -> args.kernel.manufacture(args.intent, args.witness) end
  end

  step :checkpoint_outer_receipt do
    async? false
    argument :admission, input(:admission)
    argument :construct, result(:manufacture_construct)

    run fn args, _context ->
      Xaas.Actuation.checkpoint_external(args.admission, %{
        "castle_construct" => args.construct
      })
    end
  end

  step :execute_private_action do
    async? false
    argument :admission, result(:checkpoint_outer_receipt)
    argument :intent, input(:intent)
    argument :actor, input(:actor)
    argument :tenant, input(:tenant)

    run fn args, _context ->
      action_input =
        Ash.ActionInput.for_action(
          Xaas.Operations.RouteCastleRun,
          :execute,
          %{intent: args.intent},
          actor: args.actor,
          tenant: args.tenant,
          context: Xaas.Actuation.context(args.admission)
        )

      # Preserve the action result as data so the seal step runs for both success
      # and typed failure. `authorize?: false` is not authority: the action reloads
      # the persisted outer receipt and refuses absent/mismatched context.
      {:ok,
       Ash.run_action(action_input,
         authorize?: false,
         actor: args.actor,
         tenant: args.tenant
       )}
    end
  end

  step :seal_outer_receipt do
    async? false
    argument :admission, result(:checkpoint_outer_receipt)
    argument :execution, result(:execute_private_action)

    run fn args, _context ->
      Xaas.Actuation.seal_external(args.admission, args.execution)
    end
  end

  return :seal_outer_receipt
end

defmodule Xaas.Castle.Admission do
  @moduledoc false

  alias Xaas.Operations.{ActuationIntent, ActuationReceipt, RouteCastleRun}

  @spec witness(map() | Ash.ActionInput.t(), map(), integer()) :: {:ok, map()} | {:error, term()}
  def witness(%Ash.ActionInput{} = action_input, intent, now_epoch_ms)
      when is_map(intent) and is_integer(now_epoch_ms) do
    with {:ok, context} <- reactor_context(action_input) do
      witness_from_context(context, intent, now_epoch_ms)
    end
  end

  def witness(%{intent: outer_intent, receipt: outer_receipt, projection_hash: projection_hash}, intent, now_epoch_ms)
      when is_map(intent) and is_integer(now_epoch_ms) do
    context = %{
      intent_id: to_string(outer_intent.id),
      receipt_id: to_string(outer_receipt.id),
      projection_hash: projection_hash,
      idempotency_key: outer_intent.idempotency_key
    }

    witness_from_context(context, intent, now_epoch_ms)
  end

  def witness(_, _, _), do: {:error, :REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED}

  @spec checkpoint(Ash.ActionInput.t(), map()) :: {:ok, map()} | {:error, term()}
  def checkpoint(%Ash.ActionInput{} = action_input, witness) when is_map(witness) do
    with {:ok, context} <- reactor_context(action_input),
         true <- witness["xaas_receipt_id"] == context.receipt_id,
         {:ok, receipt} <- Ash.get(ActuationReceipt, context.receipt_id, authorize?: false),
         :ok <- verify_checkpoint_receipt(receipt, context),
         %{"castle_construct" => checkpoint} when is_map(checkpoint) <- receipt.result,
         :ok <- verify_checkpoint(checkpoint, witness) do
      {:ok, checkpoint}
    else
      false -> {:error, :REFUSED_XAAS_CHECKPOINT_WITNESS_MISMATCH}
      {:error, _} = error -> error
      _ -> {:error, :REFUSED_XAAS_CASTLE_CHECKPOINT_REQUIRED}
    end
  end

  def checkpoint(_, _), do: {:error, :REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED}

  defp witness_from_context(context, intent, now_epoch_ms) do
    with {:ok, outer_intent} <- Ash.get(ActuationIntent, context.intent_id, authorize?: false),
         {:ok, outer_receipt} <- Ash.get(ActuationReceipt, context.receipt_id, authorize?: false),
         :ok <- verify_outer_intent(outer_intent, context, intent),
         :ok <- verify_outer_receipt(outer_receipt, outer_intent, context),
         {:ok, subject} <- required_string(intent, :subject),
         {:ok, authority} <- required_string(intent, :authority),
         {:ok, envelope} <- required_map(intent, :envelope),
         expires when is_integer(expires) and expires >= now_epoch_ms <-
           field(envelope, :expires_at_epoch_ms) do
      contract = Xaas.Castle.Contract.identity()

      policy_digest =
        digest(%{
          outer_authority: outer_intent.authority,
          resource_module: outer_intent.resource_module,
          action: outer_intent.action,
          ontology_projection_hash: outer_intent.ontology_projection_hash,
          contract: contract
        })

      evidence_digest = outer_receipt.replay_token

      witness_payload = %{
        protocol: contract.protocol,
        subject: subject,
        authority: authority,
        xaas_intent_id: to_string(outer_intent.id),
        xaas_receipt_id: to_string(outer_receipt.id),
        xaas_input_hash: outer_intent.input_hash,
        xaas_projection_hash: outer_intent.ontology_projection_hash,
        xaas_replay_token: outer_receipt.replay_token,
        policy_digest: policy_digest,
        evidence_digest: evidence_digest,
        expires_at_epoch_ms: expires
      }

      {:ok,
       witness_payload
       |> Map.put(:witness_digest, digest(witness_payload))
       |> Map.put(:admitted, true)
       |> Map.put(:standing, "ALIVE")
       |> stringify()}
    else
      expires when is_integer(expires) -> {:error, :REFUSED_XAAS_ADMISSION_EXPIRED}
      {:error, _} = error -> error
      _ -> {:error, :REFUSED_XAAS_ADMISSION_MISMATCH}
    end
  end

  defp reactor_context(%Ash.ActionInput{context: context}) when is_map(context) do
    case Map.get(context, :xaas_actuation) do
      %{
        intent_id: intent_id,
        receipt_id: receipt_id,
        ontology_projection_hash: projection_hash,
        idempotency_key: idempotency_key
      }
      when is_binary(intent_id) and is_binary(receipt_id) and is_binary(projection_hash) and
             is_binary(idempotency_key) ->
        {:ok,
         %{
           intent_id: intent_id,
           receipt_id: receipt_id,
           projection_hash: projection_hash,
           idempotency_key: idempotency_key
         }}

      _ ->
        {:error, :REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED}
    end
  end

  defp verify_outer_intent(outer, context, runtime_intent) do
    subject = field(runtime_intent, :subject)

    cond do
      outer.status != :executing ->
        {:error, :REFUSED_XAAS_INTENT_NOT_EXECUTING}

      outer.resource_module != inspect(RouteCastleRun) ->
        {:error, :REFUSED_XAAS_RESOURCE_MISMATCH}

      outer.action != "execute" ->
        {:error, :REFUSED_XAAS_ACTION_MISMATCH}

      outer.subject_id != subject ->
        {:error, :REFUSED_XAAS_SUBJECT_MISMATCH}

      outer.ontology_projection_hash != context.projection_hash ->
        {:error, :REFUSED_XAAS_PROJECTION_MISMATCH}

      outer.ontology_projection_hash != RouteCastleRun.ontology_projection_hash() ->
        {:error, :REFUSED_XAAS_PROJECTION_DRIFT}

      outer.idempotency_key != context.idempotency_key ->
        {:error, :REFUSED_XAAS_IDEMPOTENCY_MISMATCH}

      true ->
        :ok
    end
  end

  defp verify_outer_receipt(receipt, outer_intent, context) do
    cond do
      to_string(receipt.intent_id) != to_string(outer_intent.id) ->
        {:error, :REFUSED_XAAS_RECEIPT_INTENT_MISMATCH}

      receipt.status != :prepared ->
        {:error, :REFUSED_XAAS_RECEIPT_NOT_PREPARED}

      receipt.resource_module != inspect(RouteCastleRun) or receipt.action != "execute" ->
        {:error, :REFUSED_XAAS_RECEIPT_ACTION_MISMATCH}

      receipt.ontology_projection_hash != context.projection_hash ->
        {:error, :REFUSED_XAAS_RECEIPT_PROJECTION_MISMATCH}

      receipt.input_hash != outer_intent.input_hash ->
        {:error, :REFUSED_XAAS_RECEIPT_INPUT_MISMATCH}

      not digest?(receipt.replay_token) ->
        {:error, :REFUSED_XAAS_RECEIPT_REPLAY_TOKEN}

      true ->
        :ok
    end
  end

  defp verify_checkpoint_receipt(receipt, context) do
    cond do
      receipt.status != :prepared ->
        {:error, :REFUSED_XAAS_RECEIPT_NOT_PREPARED}

      receipt.ontology_projection_hash != context.projection_hash ->
        {:error, :REFUSED_XAAS_RECEIPT_PROJECTION_MISMATCH}

      not (is_binary(receipt.result_hash) and digest?(receipt.result_hash)) ->
        {:error, :REFUSED_XAAS_CHECKPOINT_HASH_REQUIRED}

      true ->
        :ok
    end
  end

  defp verify_checkpoint(checkpoint, witness) do
    contract = Xaas.Castle.Contract.identity()

    cond do
      checkpoint["protocol"] != contract.protocol ->
        {:error, :REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH}

      checkpoint["castle_paas_source_sha"] != contract.castle_paas_source_sha ->
        {:error, :REFUSED_CASTLE_CHECKPOINT_SOURCE_MISMATCH}

      checkpoint["witness_digest"] != witness["witness_digest"] ->
        {:error, :REFUSED_CASTLE_CHECKPOINT_WITNESS_MISMATCH}

      not Enum.all?(
            [
              checkpoint["construct_digest"],
              checkpoint["construct_receipt_digest"],
              checkpoint["process_digest"],
              checkpoint["replay_identity_digest"],
              checkpoint["kernel_binary_sha256"],
              checkpoint["signing_key_sha256"],
              checkpoint["adapter_profile_digest"]
            ],
            &digest?/1
          ) ->
        {:error, :REFUSED_CASTLE_CHECKPOINT_DIGEST}

      not (is_binary(checkpoint["evidence_dir"]) and Path.type(checkpoint["evidence_dir"]) == :absolute) ->
        {:error, :REFUSED_CASTLE_CHECKPOINT_EVIDENCE_PATH}

      true ->
        :ok
    end
  end

  defp digest(term) do
    term
    |> canonical_term()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp digest?(value) when is_binary(value),
    do: byte_size(value) == 64 and String.match?(value, ~r/\A[0-9a-fA-F]{64}\z/)

  defp digest?(_), do: false

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

  defp required_string(map, key) do
    value = field(map, key)
    if is_binary(value) and value != "", do: {:ok, value}, else: {:error, {:REFUSED_REQUIRED_FIELD, key}}
  end

  defp required_map(map, key) do
    value = field(map, key)
    if is_map(value), do: {:ok, value}, else: {:error, {:REFUSED_REQUIRED_FIELD, key}}
  end

  defp field(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))

  defp stringify(value) when is_map(value),
    do: Map.new(value, fn {key, item} -> {to_string(key), stringify(item)} end)

  defp stringify(value) when is_list(value), do: Enum.map(value, &stringify/1)
  defp stringify(value), do: value
end

defmodule Xaas.Castle.Actions.Execute do
  @moduledoc false

  @spec run(Ash.ActionInput.t(), map()) :: {:ok, map()} | {:error, term()}
  def run(%Ash.ActionInput{} = input, _context) do
    intent = Map.get(input.arguments, :intent)
    now_epoch_ms = System.system_time(:millisecond)

    with {:ok, witness} <- Xaas.Castle.Admission.witness(input, intent, now_epoch_ms),
         {:ok, checkpoint} <- Xaas.Castle.Admission.checkpoint(input, witness),
         kernel <- Application.get_env(:kanban, :castle_kernel_module, Xaas.Castle.Kernel.CLI),
         {:ok, result} <- kernel.execute(intent, witness, checkpoint, now_epoch_ms) do
      {:ok,
       Map.merge(result, %{
         "xaas_outer_admission" => %{
           "witness_digest" => witness["witness_digest"],
           "policy_digest" => witness["policy_digest"],
           "evidence_digest" => witness["evidence_digest"],
           "xaas_intent_id" => witness["xaas_intent_id"],
           "xaas_receipt_id" => witness["xaas_receipt_id"]
         },
         "contract" => Xaas.Castle.Contract.identity() |> stringify()
       })}
    end
  end

  defp stringify(value) when is_map(value),
    do: Map.new(value, fn {key, item} -> {to_string(key), stringify(item)} end)

  defp stringify(value) when is_list(value), do: Enum.map(value, &stringify/1)
  defp stringify(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify(value), do: value
end

defmodule Xaas.Castle.Kernel.CLI do
  @moduledoc """
  Exact-binary CASTLE bridge used by the XaaS external-consequence Reactor.

  Required environment:

    * `CASTLE_BIN` - exact CASTLE binary path
    * `CASTLE_BIN_SHA256` - expected exact binary SHA-256
    * `CASTLE_SIGNING_KEY_PATH` - server-side receipt signing seed
    * `CASTLE_KEY_ID` - receipt key identifier
    * `CASTLE_EVIDENCE_ROOT` - absolute durable filesystem root mounted for CASTLE evidence

  Adapter profiles are server-owned `config :kanban, :castle_adapter_profiles, ...`.
  Caller/model input cannot provide provider programs, command maps, or signing material.
  """

  @behaviour Xaas.Castle.Kernel

  @impl true
  def release_info do
    with {:ok, runtime} <- runtime(),
         {:ok, result} <- run(runtime.bin, ["release", "info", "--format", "json"]),
         :ok <- require_castle_identity(result) do
      {:ok, Map.put(result, "binary_sha256", runtime.bin_sha256)}
    end
  end

  @impl true
  def manufacture(intent, witness) when is_map(intent) and is_map(witness) do
    with :ok <- reject_ambient_command_policy(intent),
         {:ok, runtime} <- runtime(),
         {:ok, request, profile_digest} <- build_request(runtime, intent, witness),
         {:ok, construct} <- invoke_construct(runtime, request),
         :ok <- require_construct(construct) do
      contract = Xaas.Castle.Contract.identity()

      {:ok,
       %{
         "protocol" => Atom.to_string(contract.protocol),
         "castle_paas_source_sha" => contract.castle_paas_source_sha,
         "witness_digest" => witness["witness_digest"],
         "construct_digest" => construct["construct_digest"],
         "construct_receipt_digest" => construct["construct_receipt_digest"],
         "process_digest" => construct["process_digest"],
         "replay_identity_digest" => construct["replay_identity_digest"],
         "kernel_binary_sha256" => runtime.bin_sha256,
         "signing_key_sha256" => runtime.signing_key_sha256,
         "adapter_profile_digest" => profile_digest,
         "evidence_dir" => request["evidence_dir"]
       }}
    end
  end

  def manufacture(_, _), do: {:error, :REFUSED_INVALID_CASTLE_CONSTRUCT_INTENT}

  @impl true
  def execute(intent, witness, checkpoint, now_epoch_ms)
      when is_map(intent) and is_map(witness) and is_map(checkpoint) and is_integer(now_epoch_ms) do
    with :ok <- reject_ambient_command_policy(intent),
         {:ok, runtime} <- runtime(),
         {:ok, request, profile_digest} <- build_request(runtime, intent, witness),
         :ok <- verify_runtime_checkpoint(runtime, checkpoint, witness, request, profile_digest) do
      case recover_existing_evidence(runtime, request, checkpoint) do
        {:ok, recovered} when is_map(recovered) ->
          {:ok, recovered}

        {:ok, nil} ->
          execute_or_recover(runtime, request, checkpoint, now_epoch_ms)

        {:error, _} = error ->
          error
      end
    end
  end

  def execute(_, _, _, _), do: {:error, :REFUSED_INVALID_CASTLE_EXECUTION_INTENT}

  defp execute_or_recover(runtime, request, checkpoint, now_epoch_ms) do
    case invoke_do(runtime, request, checkpoint["construct_digest"], now_epoch_ms) do
      {:ok, executed} ->
        with :ok <- require_receipted_do(executed) do
          {:ok, do_result(runtime, checkpoint, executed, false)}
        end

      {:error, reason} ->
        case recover_existing_evidence(runtime, request, checkpoint) do
          {:ok, recovered} when is_map(recovered) -> {:ok, recovered}
          {:ok, nil} -> {:error, reason}
          {:error, recovery_reason} -> {:error, {:castle_do_and_recovery_failed, reason, recovery_reason}}
        end
    end
  end

  defp recover_existing_evidence(runtime, request, checkpoint) do
    evidence_dir = request["evidence_dir"]

    case File.ls(evidence_dir) do
      {:error, :enoent} ->
        {:ok, nil}

      {:error, reason} ->
        {:error, {:BLOCKED_CASTLE_EVIDENCE_LIST, reason}}

      {:ok, names} ->
        json_files = names |> Enum.filter(&String.ends_with?(&1, ".json")) |> Enum.sort()
        verify_evidence_set(runtime, request, checkpoint, json_files)
    end
  end

  defp verify_evidence_set(_runtime, _request, _checkpoint, []), do: {:ok, nil}

  defp verify_evidence_set(runtime, request, checkpoint, names) do
    Enum.reduce_while(names, {:ok, []}, fn name, {:ok, matches} ->
      path = Path.join(request["evidence_dir"], name)

      case verify_evidence(runtime, path) do
        {:ok, verification} ->
          record = verification["record"] || %{}

          if record["construct_digest"] == checkpoint["construct_digest"] and
               record["subject"] == request["subject"] and record["cell_id"] == request["cell_id"] do
            {:cont, {:ok, [verification | matches]}}
          else
            {:halt, {:error, :REFUSED_UNEXPECTED_CASTLE_EVIDENCE_RECORD}}
          end

        {:error, reason} ->
          {:halt, {:error, {:REFUSED_UNVERIFIED_CASTLE_EVIDENCE, reason}}}
      end
    end)
    |> case do
      {:ok, [verification]} -> {:ok, recovered_result(runtime, checkpoint, verification)}
      {:ok, []} -> {:ok, nil}
      {:ok, _many} -> {:error, :REFUSED_AMBIGUOUS_CASTLE_EVIDENCE}
      {:error, _} = error -> error
    end
  end

  defp verify_evidence(runtime, path) do
    run(runtime.bin, [
      "evidence",
      "verify",
      "--evidence-path",
      path,
      "--format",
      "json"
    ])
  end

  defp recovered_result(runtime, checkpoint, verification) do
    record = verification["record"]

    %{
      "standing" => "ALIVE",
      "kernel_binary_sha256" => runtime.bin_sha256,
      "construct_digest" => checkpoint["construct_digest"],
      "construct_receipt_digest" => checkpoint["construct_receipt_digest"],
      "process_digest" => checkpoint["process_digest"],
      "replay_identity_digest" => checkpoint["replay_identity_digest"],
      "ocel_receipt_digest" => record["ocel_receipt_digest"],
      "event_count" => record["event_count"],
      "brce_prepare_receipt_digests" => record["brce_prepare_receipt_digests"],
      "brce_outcome_receipt_digests" => record["brce_outcome_receipt_digests"],
      "evidence_commit" => %{
        "standing" => verification["standing"],
        "record_identity" => verification["record_identity"],
        "path" => verification["path"],
        "reason" => "ALIVE:RECOVERED_FROM_VERIFIED_DURABLE_EVIDENCE"
      },
      "recovered_from_evidence" => true
    }
  end

  defp do_result(runtime, checkpoint, executed, recovered?) do
    %{
      "standing" => "ALIVE",
      "kernel_binary_sha256" => runtime.bin_sha256,
      "construct_digest" => checkpoint["construct_digest"],
      "construct_receipt_digest" => checkpoint["construct_receipt_digest"],
      "process_digest" => checkpoint["process_digest"],
      "replay_identity_digest" => checkpoint["replay_identity_digest"],
      "ocel_receipt_digest" => executed["ocel_receipt_digest"],
      "event_count" => executed["event_count"],
      "brce_prepare_receipt_digests" => executed["brce_prepare_receipt_digests"],
      "brce_outcome_receipt_digests" => executed["brce_outcome_receipt_digests"],
      "evidence_commit" => executed["evidence_commit"],
      "recovered_from_evidence" => recovered?
    }
  end

  defp invoke_construct(runtime, request) do
    with_request(request, fn request_path ->
      run(runtime.bin, [
        "construct",
        "manufacture",
        "--request-path",
        request_path,
        "--signing-key-path",
        runtime.signing_key_path,
        "--key-id",
        runtime.key_id,
        "--format",
        "json"
      ])
    end)
  end

  defp invoke_do(runtime, request, construct_digest, now_epoch_ms) do
    with_request(request, fn request_path ->
      run(runtime.bin, [
        "do",
        "execute",
        "--request-path",
        request_path,
        "--signing-key-path",
        runtime.signing_key_path,
        "--key-id",
        runtime.key_id,
        "--expected-construct-digest",
        construct_digest,
        "--now-epoch-ms",
        Integer.to_string(now_epoch_ms),
        "--format",
        "json"
      ])
    end)
  end

  defp build_request(runtime, intent, witness) do
    profile_id = field(intent, :adapter_profile_id)
    profiles = Application.get_env(:kanban, :castle_adapter_profiles, %{})
    profile = if is_nil(profile_id), do: nil, else: Map.get(profiles, profile_id) || Map.get(profiles, to_string(profile_id))

    with profile when is_map(profile) <- profile,
         {:ok, subject} <- required_string(intent, :subject),
         {:ok, authority} <- required_string(intent, :authority),
         {:ok, process} <- required_map(intent, :process),
         {:ok, envelope} <- required_map(intent, :envelope),
         ^subject <- field(envelope, :system_id),
         ^subject <- witness["subject"],
         ^authority <- witness["authority"],
         :ok <- digest(witness["witness_digest"]),
         adapter_policy when is_map(adapter_policy) <- Map.get(profile, :adapter_policy),
         allowed_authorities when is_list(allowed_authorities) <- Map.get(profile, :allowed_authorities),
         true <- authority in allowed_authorities do
      profile_digest = fingerprint(%{adapter_policy: adapter_policy, allowed_authorities: allowed_authorities})
      evidence_dir = Path.join(runtime.evidence_root, witness["witness_digest"])

      {:ok,
       %{
         "cell_id" => "cell:xaas:#{witness["xaas_receipt_id"]}",
         "evidence_dir" => evidence_dir,
         "subject" => subject,
         "authority" => authority,
         "o_star" => witness,
         "config_graph" =>
           stringify(field(intent, :config_graph) || %{"zeroUnreceiptedActuation" => true}),
         "ontology" => stringify(field(intent, :ontology) || %{"version" => "26.8.18"}),
         "process" => stringify(process),
         "envelope" => stringify(envelope),
         "allowed_authorities" => allowed_authorities,
         "adapter_policy" => stringify(adapter_policy)
       }, profile_digest}
    else
      nil -> {:error, :REFUSED_UNKNOWN_CASTLE_ADAPTER_PROFILE}
      false -> {:error, :REFUSED_CASTLE_AUTHORITY_NOT_ALLOWED}
      {:error, _} = error -> error
      _ -> {:error, :REFUSED_INVALID_CASTLE_ADAPTER_PROFILE}
    end
  end

  defp runtime do
    with bin when is_binary(bin) and bin != "" <- System.get_env("CASTLE_BIN"),
         expected when is_binary(expected) and byte_size(expected) == 64 <- System.get_env("CASTLE_BIN_SHA256"),
         signing_key_path when is_binary(signing_key_path) and signing_key_path != "" <- System.get_env("CASTLE_SIGNING_KEY_PATH"),
         key_id when is_binary(key_id) and key_id != "" <- System.get_env("CASTLE_KEY_ID"),
         evidence_root when is_binary(evidence_root) and evidence_root != "" <- System.get_env("CASTLE_EVIDENCE_ROOT"),
         true <- Path.type(evidence_root) == :absolute,
         {:ok, bytes} <- File.read(bin),
         actual <- Base.encode16(:crypto.hash(:sha256, bytes), case: :lower),
         true <- actual == String.downcase(expected),
         {:ok, key_bytes} <- File.read(signing_key_path),
         true <- File.regular?(signing_key_path),
         signing_key_sha256 <- Base.encode16(:crypto.hash(:sha256, key_bytes), case: :lower) do
      {:ok,
       %{
         bin: bin,
         bin_sha256: actual,
         signing_key_path: signing_key_path,
         signing_key_sha256: signing_key_sha256,
         key_id: key_id,
         evidence_root: Path.expand(evidence_root)
       }}
    else
      nil -> {:error, :BLOCKED_CASTLE_RUNTIME_CONFIGURATION}
      false -> {:error, :REFUSED_CASTLE_RUNTIME_IDENTITY}
      {:error, reason} -> {:error, {:BLOCKED_CASTLE_RUNTIME_FILE, reason}}
      _ -> {:error, :REFUSED_CASTLE_RUNTIME_CONFIGURATION}
    end
  end

  defp verify_runtime_checkpoint(runtime, checkpoint, witness, request, profile_digest) do
    contract = Xaas.Castle.Contract.identity()

    cond do
      checkpoint["protocol"] != Atom.to_string(contract.protocol) ->
        {:error, :REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH}

      checkpoint["castle_paas_source_sha"] != contract.castle_paas_source_sha ->
        {:error, :REFUSED_CASTLE_CHECKPOINT_SOURCE_MISMATCH}

      checkpoint["witness_digest"] != witness["witness_digest"] ->
        {:error, :REFUSED_CASTLE_CHECKPOINT_WITNESS_MISMATCH}

      checkpoint["kernel_binary_sha256"] != runtime.bin_sha256 ->
        {:error, :REFUSED_CASTLE_KERNEL_DRIFT}

      checkpoint["signing_key_sha256"] != runtime.signing_key_sha256 ->
        {:error, :REFUSED_CASTLE_SIGNING_IDENTITY_DRIFT}

      checkpoint["adapter_profile_digest"] != profile_digest ->
        {:error, :REFUSED_CASTLE_ADAPTER_PROFILE_DRIFT}

      checkpoint["evidence_dir"] != request["evidence_dir"] ->
        {:error, :REFUSED_CASTLE_EVIDENCE_ROOT_DRIFT}

      digest(checkpoint["construct_digest"]) != :ok ->
        {:error, :REFUSED_CASTLE_CONSTRUCT_DIGEST}

      true ->
        :ok
    end
  end

  defp require_construct(%{
         "standing" => "ALIVE",
         "construct_digest" => construct_digest,
         "construct_receipt_digest" => receipt_digest,
         "process_digest" => process_digest,
         "replay_identity_digest" => replay_digest
       }) do
    with :ok <- digest(construct_digest),
         :ok <- digest(receipt_digest),
         :ok <- digest(process_digest),
         :ok <- digest(replay_digest) do
      :ok
    end
  end

  defp require_construct(_), do: {:error, :REFUSED_CASTLE_CONSTRUCT_NOT_ALIVE}

  defp with_request(request, fun) when is_function(fun, 1) do
    path =
      Path.join(
        System.tmp_dir!(),
        "xaas-castle-request-#{System.unique_integer([:positive, :monotonic])}.json"
      )

    with {:ok, encoded} <- Jason.encode(request),
         :ok <- File.write(path, encoded, [:exclusive]) do
      try do
        fun.(path)
      after
        _ = File.rm(path)
      end
    end
  end

  defp run(bin, args) do
    try do
      case System.cmd(bin, args, stderr_to_stdout: true) do
        {output, 0} ->
          case Jason.decode(output) do
            {:ok, value} when is_map(value) -> {:ok, value}
            _ -> {:error, {:REFUSED_NON_JSON_CASTLE_RESPONSE, output}}
          end

        {output, status} ->
          {:error, {:REFUSED_CASTLE_EXIT, status, output}}
      end
    rescue
      error -> {:error, {:BLOCKED_CASTLE_TRANSPORT, Exception.message(error)}}
    end
  end

  defp require_castle_identity(%{"name" => "CASTLE", "release" => release})
       when is_binary(release),
       do: :ok

  defp require_castle_identity(_), do: {:error, :REFUSED_WRONG_CASTLE_IDENTITY}

  defp require_receipted_do(%{
         "standing" => "ALIVE",
         "brce_prepare_receipt_digests" => prepare,
         "brce_outcome_receipt_digests" => outcome,
         "evidence_commit" => %{"standing" => "ALIVE"}
       })
       when is_list(prepare) and is_list(outcome) and prepare != [] and outcome != [] do
    if Enum.all?(prepare ++ outcome, &(digest(&1) == :ok)) do
      :ok
    else
      {:error, :REFUSED_INVALID_CASTLE_RECEIPT_DIGEST}
    end
  end

  defp require_receipted_do(_), do: {:error, :REFUSED_UNRECEIPTED_CASTLE_DO}

  defp reject_ambient_command_policy(value) when is_map(value) do
    if Enum.any?(value, fn {key, item} ->
         to_string(key) in ["adapter_policy", "commands", "program", "signing_key_path", "evidence_dir"] or
           reject_ambient_command_policy(item) != :ok
       end) do
      {:error, :REFUSED_AMBIENT_CASTLE_COMMAND_POLICY}
    else
      :ok
    end
  end

  defp reject_ambient_command_policy(value) when is_list(value) do
    if Enum.all?(value, &(reject_ambient_command_policy(&1) == :ok)),
      do: :ok,
      else: {:error, :REFUSED_AMBIENT_CASTLE_COMMAND_POLICY}
  end

  defp reject_ambient_command_policy(_), do: :ok

  defp digest(value) when is_binary(value) and byte_size(value) == 64 do
    if String.match?(value, ~r/\A[0-9a-fA-F]{64}\z/),
      do: :ok,
      else: {:error, :REFUSED_INVALID_CASTLE_DIGEST}
  end

  defp digest(_), do: {:error, :REFUSED_INVALID_CASTLE_DIGEST}

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

  defp required_string(map, key) do
    value = field(map, key)
    if is_binary(value) and value != "", do: {:ok, value}, else: {:error, {:REFUSED_REQUIRED_FIELD, key}}
  end

  defp required_map(map, key) do
    value = field(map, key)
    if is_map(value), do: {:ok, value}, else: {:error, {:REFUSED_REQUIRED_FIELD, key}}
  end

  defp field(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))

  defp stringify(value) when is_map(value),
    do: Map.new(value, fn {key, item} -> {to_string(key), stringify(item)} end)

  defp stringify(value) when is_list(value), do: Enum.map(value, &stringify/1)
  defp stringify(value), do: value
end
