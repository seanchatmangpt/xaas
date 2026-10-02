defmodule Xaas.Bridges.PPlan do
  @moduledoc """
  P-PLAN bridge: the agentic-payment spine driven through ash_pplan.

  The manufactured plan at this pin is `https://w3id.org/ash-pplan#SubscriptionRenewal`
  (`AuthorizePayment` → `RenewSubscription`) — the payment spine the plan catalog
  actually projects from ontology (there is no other plan at this pin; naming it
  otherwise would be fabrication).

  `run_purchase/2` executes the compiled Reactor with `run_id` = the exact
  subject URN. When the purchase exceeds the delegated limit and no human
  release is present, the renewal step halts the Reactor and the run is parked
  as a versioned, content-addressed `AshPPlan.Continuation` (the
  `await_human_release` park). `release_purchase/2` signals the release and
  resumes the parked continuation through Reactor.

  This bridge observes Reactor outcomes; it holds no execution authority beyond
  what the caller already carries (envelopes carry `authority_ceiling: :none`).
  """

  alias AshPPlan.Continuation.ETFCodec

  @plan_iri "https://w3id.org/ash-pplan#SubscriptionRenewal"
  @authorize_step "https://w3id.org/ash-pplan#AuthorizePayment"
  @renew_step "https://w3id.org/ash-pplan#RenewSubscription"

  @doc "The plan IRI of the manufactured payment spine."
  def plan_iri, do: @plan_iri

  @doc """
  Returns the manufactured P-PLAN purchase model from the ash_pplan plan catalog.
  """
  @spec purchase_model() :: {:ok, map()} | {:refused, %{code: :unknown_plan}}
  def purchase_model do
    case AshPPlan.plan(@plan_iri) do
      nil -> {:refused, %{code: :unknown_plan}}
      plan -> {:ok, plan}
    end
  end

  @doc """
  Runs the agentic-payment spine for `claim`.

  `opts`:

    * `:subject` — run identity override (default `Xaas.Bridges.subject/0`);
      the falsifier round-trips the subject byte-for-byte through the run.
    * `:human_release` — pre-supplied release signal; when present and the
      authorization requires one, the run completes without parking.

  Returns `{:ok, envelope}` (state `:completed` or `:awaiting_human_release`)
  or `{:refused, reason}`.
  """
  @spec run_purchase(map(), keyword()) :: {:ok, map()} | {:refused, map()}
  def run_purchase(claim, opts \\ []) when is_map(claim) and is_list(opts) do
    subject = Keyword.get(opts, :subject) || Xaas.Bridges.subject()
    input = %{"claim" => claim}

    context =
      case Keyword.fetch(opts, :human_release) do
        {:ok, release} -> %{human_release: release}
        :error -> %{}
      end

    case AshPPlan.execute(@plan_iri, handlers(), input, context, run_id: subject) do
      {{:ok, value}, receipt} ->
        {:ok, completed_envelope(subject, value, receipt)}

      {{:ok, value, _reactor}, receipt} ->
        {:ok, completed_envelope(subject, value, receipt)}

      {{:halted, reactor}, receipt} ->
        park(subject, reactor, receipt)

      {{:error, reason}, receipt} ->
        envelope = Xaas.Bridges.envelope(subject, "p-plan purchase run", :failed)

        {:refused,
         envelope
         |> Map.put(:code, :step_failed)
         |> Map.put(:reason, inspect(reason))
         |> Map.put(:receipt_ref, receipt.outcome_digest)}

      {:error, %AshPPlan.Compiler.Error{reason: reason} = error} ->
        envelope = Xaas.Bridges.envelope(subject, "p-plan purchase run", :refused)
        {:refused, Map.merge(envelope, %{code: reason, details: Map.from_struct(error)})}
    end
  end

  @doc """
  Signals human release and resumes a parked continuation through Reactor.

  The resumed run keeps the original `run_id` (the exact subject) and the
  original Reactor inputs; the release signal travels as `:human_release`
  context, which the renewal step requires before completing.
  """
  @spec release_purchase(AshPPlan.Continuation.t(), keyword()) :: {:ok, map()} | {:refused, map()}
  def release_purchase(%AshPPlan.Continuation{} = continuation, opts \\ []) do
    subject = continuation.run_id
    release = Keyword.get(opts, :release, "operator-release")

    case AshPPlan.resume_continuation(continuation, ETFCodec, %{human_release: release}) do
      {:ok, value} ->
        {:ok,
         %{
           Xaas.Bridges.envelope(subject, "p-plan purchase run", :completed, "PARTIAL_ALIVE")
           | evidence_ref: "ash_pplan.continuation:" <> continuation.id,
             provenance: %{resumed_from_continuation: continuation.id, value: inspect(value)}
         }}

      {:halted, _reactor} ->
        envelope = Xaas.Bridges.envelope(subject, "p-plan purchase run", :awaiting_human_release)
        {:refused, Map.put(envelope, :code, :release_not_accepted)}

      {:error, reason} ->
        envelope = Xaas.Bridges.envelope(subject, "p-plan purchase run", :failed)
        {:refused, Map.merge(envelope, %{code: resume_refusal_code(reason), reason: inspect(reason)})}
    end
  end

  defp handlers do
    %{
      @authorize_step => Xaas.Bridges.PPlan.Steps.AuthorizePayment,
      @renew_step => Xaas.Bridges.PPlan.Steps.RenewSubscription
    }
  end

  defp park(subject, reactor, receipt) do
    case AshPPlan.capture_continuation(@plan_iri, subject, reactor) do
      {:ok, continuation} ->
        envelope =
          Xaas.Bridges.envelope(subject, "p-plan purchase run", :awaiting_human_release, "PARTIAL_ALIVE")

        {:ok,
         %{
           envelope
           | evidence_ref: "ash_pplan.continuation:" <> continuation.id,
             receipt_ref: receipt.outcome_digest,
             provenance: %{
               plan_iri: @plan_iri,
               run_id: subject,
               reactor_state: :halted,
               continuation_schema: continuation.schema_version,
               continuation: continuation
             }
         }}

      {:error, reason} ->
        envelope = Xaas.Bridges.envelope(subject, "p-plan purchase run", :failed)

        {:refused,
         Map.merge(envelope, %{code: capture_refusal_code(reason), reason: inspect(reason)})}
    end
  end

  defp completed_envelope(subject, value, receipt) do
    envelope =
      Xaas.Bridges.envelope(subject, "p-plan purchase run", :completed, "PARTIAL_ALIVE")

    %{
      envelope
      | evidence_ref: "ash_pplan.execution_receipt:" <> receipt.outcome_digest,
        receipt_ref: receipt.outcome_digest,
        provenance: %{
          plan_iri: receipt.plan_iri,
          run_id: receipt.run_id,
          status: receipt.status,
          value: inspect(value)
        }
    }
  end

  defp resume_refusal_code(%{reason: reason}) when is_atom(reason), do: reason
  defp resume_refusal_code(_other), do: :resume_failed

  defp capture_refusal_code(%{reason: reason}) when is_atom(reason), do: reason
  defp capture_refusal_code(_other), do: :continuation_capture_failed

  defmodule Steps.AuthorizePayment do
    @moduledoc """
    `AuthorizePayment` step: observes the claim's amount against the delegated
    limit. Pure — it touches no resource and grants no authority; it only
    computes the authorization observation the renewal step consumes.
    """
    use Reactor.Step

    @impl true
    def run(arguments, _context, _options) do
      claim = arguments[:input]["claim"] || %{}
      amount = Xaas.Bridges.PPlan.number(claim["amount"])
      limit = Xaas.Bridges.PPlan.number(claim["limit"])

      cond do
        is_nil(amount) or is_nil(limit) ->
          {:error, :invalid_claim}

        amount > limit ->
          {:ok, %{status: :over_limit, requires_human_release: true, amount: amount, limit: limit}}

        true ->
          {:ok, %{status: :authorized, requires_human_release: false, amount: amount, limit: limit}}
      end
    end
  end

  defmodule Steps.RenewSubscription do
    @moduledoc """
    `RenewSubscription` step: the human-release gate. Over-limit purchases halt
    here (`{:halt, :await_human_release}`) and park the Reactor until a release
    signal arrives in context; with a release present the renewal completes.
    """
    use Reactor.Step

    @impl true
    def run(arguments, context, _options) do
      authorization = arguments[:predecessor_0] || %{}

      if authorization[:requires_human_release] and is_nil(context[:human_release]) do
        {:halt, {:await_human_release, authorization}}
      else
        {:ok, %{renewed: true, authorization: authorization, released_by: context[:human_release]}}
      end
    end
  end

  @doc false
  def number(value) when is_integer(value), do: value
  def number(value) when is_float(value), do: value

  def number(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  def number(_other), do: nil
end
