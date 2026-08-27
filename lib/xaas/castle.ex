defmodule Xaas.Castle do
  @moduledoc """
  Receipt-bound XaaS -> CASTLE PaaS bridge.

  XaaS remains the outer platform transaction: public-ontology admission, durable
  idempotent intent, and prepared receipt are manufactured first by `Xaas.Actuation`.
  `Xaas.Operations.RouteCastleRun.:execute` then verifies those exact persisted
  objects and manufactures an O* witness for the CASTLE `construct -> do` protocol.

  The bridge never accepts provider programs, argv, signing keys, or adapter policy
  from a caller. Provider command policy is selected only from server configuration.
  """

  alias Xaas.Operations.RouteCastleRun

  @spec run(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run(intent, opts) when is_map(intent) and is_list(opts) do
    with idempotency_key when is_binary(idempotency_key) and idempotency_key != "" <-
           Keyword.get(opts, :idempotency_key),
         authority when is_map(authority) and map_size(authority) > 0 <-
           Keyword.get(opts, :authority),
         subject when is_binary(subject) and subject != "" <- field(intent, :subject) do
      Xaas.Actuation.run(
        RouteCastleRun,
        :execute,
        %{intent: intent},
        subject_id: subject,
        idempotency_key: idempotency_key,
        actor: Keyword.get(opts, :actor),
        tenant: Keyword.get(opts, :tenant),
        authorize?: false,
        authority: authority
      )
    else
      nil -> {:error, :idempotency_key_required}
      "" -> {:error, :idempotency_key_required}
      _ -> {:error, :castle_authority_evidence_required}
    end
  end

  @spec contract_identity() :: map()
  def contract_identity, do: Xaas.Castle.Contract.identity()

  defp field(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
end

defmodule Xaas.Castle.Contract do
  @moduledoc false

  @castle_paas_source_sha "13fe9728251e4a309eeb9e48315dc8d693d3da3b"
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
      xaas_actuation: "ontology->admission->intent/prepared-receipt->reactor->sealed-receipt->replay",
      castle_actuation: "construct->admission->brce-prepare->do->brce-outcome->evidence"
    }
  end
end

defmodule Xaas.Castle.Kernel do
  @moduledoc "Narrow CASTLE consequence-kernel boundary."

  @type result :: {:ok, map()} | {:error, term()}

  @callback release_info() :: result()
  @callback execute(map(), map(), integer()) :: result()
end

defmodule Xaas.Castle.Admission do
  @moduledoc false

  require Ash.Query

  alias Xaas.Operations.{ActuationIntent, ActuationReceipt, RouteCastleRun}

  @spec witness(Ash.ActionInput.t(), map(), integer()) :: {:ok, map()} | {:error, term()}
  def witness(%Ash.ActionInput{} = action_input, intent, now_epoch_ms)
      when is_map(intent) and is_integer(now_epoch_ms) do
    with {:ok, context} <- reactor_context(action_input),
         {:ok, outer_intent} <- Ash.get(ActuationIntent, context.intent_id, authorize?: false),
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

  def witness(_, _, _), do: {:error, :REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED}

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
         kernel <- Application.get_env(:kanban, :castle_kernel_module, Xaas.Castle.Kernel.CLI),
         {:ok, result} <- kernel.execute(intent, witness, now_epoch_ms) do
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
  Exact-binary CASTLE bridge used by the XaaS actuation Reactor.

  Required environment:

    * `CASTLE_BIN`
    * `CASTLE_BIN_SHA256`
    * `CASTLE_SIGNING_KEY_PATH`
    * `CASTLE_KEY_ID`

  Adapter profiles are server-owned `config :kanban, :castle_adapter_profiles, ...`.
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
  def execute(intent, witness, now_epoch_ms)
      when is_map(intent) and is_map(witness) and is_integer(now_epoch_ms) do
    with :ok <- reject_ambient_command_policy(intent),
         {:ok, runtime} <- runtime(),
         {:ok, request} <- build_request(intent, witness),
         {:ok, construct} <- invoke_construct(runtime, request),
         {:ok, executed} <- invoke_do(runtime, request, construct["construct_digest"], now_epoch_ms),
         :ok <- require_receipted_do(executed) do
      {:ok,
       %{
         "standing" => "ALIVE",
         "kernel_binary_sha256" => runtime.bin_sha256,
         "construct_digest" => construct["construct_digest"],
         "construct_receipt_digest" => construct["construct_receipt_digest"],
         "process_digest" => construct["process_digest"],
         "replay_identity_digest" => construct["replay_identity_digest"],
         "ocel_receipt_digest" => executed["ocel_receipt_digest"],
         "event_count" => executed["event_count"],
         "brce_prepare_receipt_digests" => executed["brce_prepare_receipt_digests"],
         "brce_outcome_receipt_digests" => executed["brce_outcome_receipt_digests"],
         "evidence_commit" => executed["evidence_commit"]
       }}
    end
  end

  def execute(_, _, _), do: {:error, :REFUSED_INVALID_CASTLE_EXECUTION_INTENT}

  defp invoke_construct(runtime, request) do
    with_request(request, fn request_path ->
      with {:ok, summary} <-
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
             ]),
           "ALIVE" <- summary["standing"],
           :ok <- digest(summary["construct_digest"]),
           :ok <- digest(summary["construct_receipt_digest"]) do
        {:ok, summary}
      else
        {:error, _} = error -> error
        _ -> {:error, :REFUSED_CASTLE_CONSTRUCT_NOT_ALIVE}
      end
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

  defp build_request(intent, witness) do
    profile_id = field(intent, :adapter_profile_id)
    profiles = Application.get_env(:kanban, :castle_adapter_profiles, %{})
    profile = Map.get(profiles, profile_id) || Map.get(profiles, to_string(profile_id))

    with profile when is_map(profile) <- profile,
         {:ok, subject} <- required_string(intent, :subject),
         {:ok, authority} <- required_string(intent, :authority),
         {:ok, process} <- required_map(intent, :process),
         {:ok, envelope} <- required_map(intent, :envelope),
         ^subject <- field(envelope, :system_id),
         ^subject <- witness["subject"],
         ^authority <- witness["authority"],
         adapter_policy when is_map(adapter_policy) <- Map.get(profile, :adapter_policy),
         allowed_authorities when is_list(allowed_authorities) <-
           Map.get(profile, :allowed_authorities),
         true <- authority in allowed_authorities do
      evidence_dir =
        Path.join(
          System.tmp_dir!(),
          "xaas-castle-evidence-#{System.unique_integer([:positive, :monotonic])}"
        )

      {:ok,
       %{
         "cell_id" => field(intent, :cell_id) || "cell:xaas-castle",
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
       }}
    else
      nil -> {:error, :REFUSED_UNKNOWN_CASTLE_ADAPTER_PROFILE}
      false -> {:error, :REFUSED_CASTLE_AUTHORITY_NOT_ALLOWED}
      {:error, _} = error -> error
      _ -> {:error, :REFUSED_INVALID_CASTLE_ADAPTER_PROFILE}
    end
  end

  defp runtime do
    with bin when is_binary(bin) and bin != "" <- System.get_env("CASTLE_BIN"),
         expected when is_binary(expected) and byte_size(expected) == 64 <-
           System.get_env("CASTLE_BIN_SHA256"),
         signing_key_path when is_binary(signing_key_path) and signing_key_path != "" <-
           System.get_env("CASTLE_SIGNING_KEY_PATH"),
         key_id when is_binary(key_id) and key_id != "" <- System.get_env("CASTLE_KEY_ID"),
         {:ok, bytes} <- File.read(bin),
         actual <- Base.encode16(:crypto.hash(:sha256, bytes), case: :lower),
         true <- actual == String.downcase(expected),
         true <- File.regular?(signing_key_path) do
      {:ok,
       %{
         bin: bin,
         bin_sha256: actual,
         signing_key_path: signing_key_path,
         key_id: key_id
       }}
    else
      nil -> {:error, :BLOCKED_CASTLE_RUNTIME_CONFIGURATION}
      false -> {:error, :REFUSED_CASTLE_RUNTIME_IDENTITY}
      {:error, reason} -> {:error, {:BLOCKED_CASTLE_BINARY, reason}}
      _ -> {:error, :REFUSED_CASTLE_RUNTIME_CONFIGURATION}
    end
  end

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
         to_string(key) in ["adapter_policy", "commands", "program", "signing_key_path"] or
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
