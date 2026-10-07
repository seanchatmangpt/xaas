defmodule Xaas.Bridges.Ex4Pm do
  @moduledoc """
  ex4pm bridge: conformance of the agentic-payment OCEL event log.

  The bridge ingests the purchase OCEL log (the subject URN is the purchase
  object's own id), discovers a POWL model from the clean log with the inductive
  miner, and conforms the log against that model. Every call goes through
  `apply/3` (the repo's fabric-adapter convention for the prod-git-pinned
  sibling) and returns ex4pm's own outcomes: a receipted `Ex4pm.Run` on
  success, or the sibling's typed `Ex4pm.Refusal` passed through.

  A mutated log (an event the discovered model never saw) flips the conformance
  verdict — the falsifier that proves the engine, not the bridge, decides.
  """

  @object_type "Purchase"

  @doc "The event-log object type the bridge projects for the purchase subject."
  def object_type, do: @object_type

  @doc """
  The clean purchase OCEL log: submit → human_release → settle on the exact
  subject object.
  """
  @spec purchase_log(String.t()) :: map()
  def purchase_log(subject \\ Xaas.Bridges.subject()) do
    %{
      "objects" => %{
        subject => %{"type" => @object_type}
      },
      "events" => %{
        "e1" => %{
          "activity" => "submit",
          "timestamp" => "2026-10-01T09:00:00Z",
          "objects" => [subject]
        },
        "e2" => %{
          "activity" => "human_release",
          "timestamp" => "2026-10-01T09:05:00Z",
          "objects" => [subject]
        },
        "e3" => %{
          "activity" => "settle",
          "timestamp" => "2026-10-01T09:10:00Z",
          "objects" => [subject]
        }
      }
    }
  end

  @doc """
  Discovers a POWL model from an OCEL log with the inductive miner.

  Exposed so a caller can conform a mutated log against the model discovered
  from the clean log — the mutation falsifier needs exactly that.
  """
  @spec discover_model(map(), keyword()) :: {:ok, term()} | {:refused, map()}
  def discover_model(raw, opts \\ []) when is_map(raw) and is_list(opts) do
    subject = Keyword.get(opts, :subject) || Xaas.Bridges.subject()
    object_type = Keyword.get(opts, :object_type, @object_type)

    with {:ok, log} <- apply(Ex4pm, :ingest, [raw]),
         {:ok, discovery} <- apply(Ex4pm, :discover, [log, [object_type: object_type]]) do
      {:ok, discovery.value}
    else
      {:error, %Ex4pm.Refusal{code: code} = refusal} ->
        envelope = Xaas.Bridges.envelope(subject, "ex4pm model discovery", :refused)

        {:refused,
         envelope
         |> Map.put(:code, code)
         |> Map.put(:message, refusal.message)}

      {:error, other} ->
        envelope = Xaas.Bridges.envelope(subject, "ex4pm model discovery", :failed)
        {:refused, Map.merge(envelope, %{code: :sibling_error, reason: inspect(other)})}
    end
  end

  @doc """
  Conforms the purchase OCEL log against a model discovered from itself.

  `opts`:

    * `:model` — conform against this pre-discovered model instead of one
      discovered from the same log;
    * `:object_type` — event-log object type (default `"Purchase"`).

  Returns `{:ok, envelope}` with the engine's real fitness and receipt hash, or
  `{:refused, reason}` passing the sibling's typed refusal through (malformed
  OCEL never becomes green).
  """
  @spec conform_purchase(map(), keyword()) :: {:ok, map()} | {:refused, map()}
  def conform_purchase(raw, opts \\ []) when is_map(raw) and is_list(opts) do
    subject = Keyword.get(opts, :subject) || Xaas.Bridges.subject()
    object_type = Keyword.get(opts, :object_type, @object_type)
    base = Xaas.Bridges.envelope(subject, "ex4pm purchase conformance", :conformed)

    with {:ok, base} <- ensure_store(base),
         {:ok, model} <- model_for(raw, opts),
         {:ok, run} <- apply(Ex4pm, :conform, [raw, model, [object_type: object_type]]) do
      {:ok,
       base
       |> Map.put(:receipt_ref, "ex4pm.receipt:" <> run.receipt.hash)
       |> Map.put(:evidence_ref, "ex4pm.subject_hash:" <> run.subject_hash)
       |> Map.put(:provenance, %{
         sibling_standing: run.standing,
         subject_hash: run.subject_hash,
         engine: run.engine_result.engine,
         algorithm: run.engine_result.algorithm,
         value: run.value
       })}
    else
      {:error, %Ex4pm.Refusal{code: code} = refusal} ->
        envelope = Xaas.Bridges.envelope(subject, "ex4pm purchase conformance", :refused)

        {:refused,
         envelope
         |> Map.put(:code, code)
         |> Map.put(:message, refusal.message)
         |> Map.put(:sibling_subject, sibling_subject(refusal))}

      {:error, other} ->
        envelope = Xaas.Bridges.envelope(subject, "ex4pm purchase conformance", :failed)
        {:refused, Map.merge(envelope, %{code: :sibling_error, reason: inspect(other)})}

      {:refused, _} = refused ->
        refused
    end
  end

  defp model_for(raw, opts) do
    case Keyword.fetch(opts, :model) do
      {:ok, model} -> {:ok, model}
      :error -> discover_model(raw, opts)
    end
  end

  # ex4pm's receipt ledger is a process-local ETS store supervised by the :ex4pm
  # application; when the host app booted without it, conform would crash. Start
  # it on demand — this is infrastructure for evidence, not a mock.
  defp ensure_store(envelope) do
    if Process.whereis(Ex4pm.Evidence.Store) do
      {:ok, envelope}
    else
      case Ex4pm.Evidence.Store.start_link() do
        {:ok, _pid} ->
          {:ok, envelope}

        {:error, {:already_started, _pid}} ->
          {:ok, envelope}

        {:error, reason} ->
          {:refused, Map.merge(envelope, %{code: :evidence_store_down, reason: inspect(reason)})}
      end
    end
  end

  defp sibling_subject(%Ex4pm.Refusal{subject: nil}), do: nil
  defp sibling_subject(%Ex4pm.Refusal{subject: subject}), do: inspect(subject)
end
