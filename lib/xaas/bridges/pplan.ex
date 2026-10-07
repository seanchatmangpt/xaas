defmodule Xaas.Bridges.PPlan do
  @moduledoc """
  P-PLAN bridge: the agentic-payment spine driven through ash_pplan.

  The manufactured plan at this pin is `https://w3id.org/ash-pplan#SubscriptionRenewal`
  (`AuthorizePayment` → `RenewSubscription`) — the payment spine the plan catalog
  projects from ontology. The execution surface at pin 5f10c97 is the durable
  engine (`AshPPlan.Reactor.Durable.Engine`) behind `AshPPlan.A2A.Facade`
  (`capture_continuation/3` and `resume_continuation/3` were removed at this
  pin); the park is a real durable run parked on a signal waiter.

  `run_purchase/2` starts (or adopts) a durable run keyed by `run_id` = the
  exact subject URN. When the purchase exceeds the delegated limit and no human
  release is present, the renewal step parks the run (`:waiting` on the
  `human_release` signal waiter — the `await_human_release` park) and
  `release_purchase/2` delivers the release as a consume-once signal through
  the facade and resumes the run.

  This bridge observes Reactor outcomes; it holds no execution authority beyond
  what the caller already carries (envelopes carry `authority_ceiling: :none`).

  Store wiring: the durable store is read from
  `Application.get_env(:xaas, :pplan_durable_store)` — the pid/registered name
  of an `AshPPlan.Reactor.Durable.Store.Ets` process. The application tree
  starts it as `Xaas.Bridges.PPlan.Store`; tests start their own and set the
  env (see `Xaas.Chicago.Bridges.PPlanTest`).
  """

  @plan_iri "https://w3id.org/ash-pplan#SubscriptionRenewal"
  @model_name "XaasPurchaseSpine"

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
  Runs the agentic-payment spine for `claim` as a durable run.

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
    store = store!()
    store_mod = store_module()

    context =
      case Keyword.fetch(opts, :human_release) do
        {:ok, release} -> %{human_release: release}
        :error -> %{}
      end

    facade_opts = [
      store_module: store_mod,
      inputs: %{"claim" => claim},
      context: context,
      plan_iri: @plan_iri
    ]

    case AshPPlan.A2A.Facade.start_or_adopt(
           store,
           subject,
           purchase_model_struct(),
           bindings(),
           facade_opts
         ) do
      {:ok, :completed, result} ->
        {:ok, completed_envelope(subject, result, store, store_mod)}

      {:ok, :input_required, _waiters} ->
        {:ok, parked_envelope(subject, store, store_mod)}

      {:ok, :failed, reason} ->
        {:refused,
         Map.merge(failed_envelope(subject), %{code: :step_failed, reason: inspect(reason)})}

      {:ok, state, detail} ->
        # :working / :claim_held (another attempt holds the claim) — typed, not guessed.
        {:refused,
         Map.merge(failed_envelope(subject), %{
           code: :run_not_settled,
           reason: "durable run state #{inspect(state)}: #{inspect(detail)}"
         })}

      {:error, reason} ->
        {:refused,
         Map.merge(failed_envelope(subject), %{code: :run_refused, reason: inspect(reason)})}
    end
  end

  @doc """
  Signals human release and resumes a parked durable run.

  The run keeps its original id (the exact subject) and its recorded
  checkpoints; the release signal travels as a consume-once signal on the
  parked `human_release` waiter, which the renewal step consumes before
  completing.
  """
  @spec release_purchase(AshPPlan.Reactor.Durable.Record.t(), keyword()) ::
          {:ok, map()} | {:refused, map()}
  def release_purchase(%AshPPlan.Reactor.Durable.Record{} = record, opts \\ []) do
    subject = record.id
    release = Keyword.get(opts, :release, "operator-release")
    store = store!()
    store_mod = store_module()

    case AshPPlan.A2A.Facade.resume(store, subject, release, store_module: store_mod) do
      {:ok, :completed, result} ->
        envelope =
          Xaas.Bridges.envelope(subject, "p-plan purchase run", :completed, "PARTIAL_ALIVE")

        {:ok,
         %{
           envelope
           | evidence_ref: "ash_pplan.durable_run:" <> record.id,
             receipt_ref: "ash_pplan.durable_run:" <> record.id,
             provenance: %{
               resumed_from_continuation: record.id,
               value: inspect(result)
             }
         }}

      {:ok, :input_required, _waiters} ->
        envelope =
          Xaas.Bridges.envelope(subject, "p-plan purchase run", :awaiting_human_release)

        {:refused, Map.put(envelope, :code, :release_not_accepted)}

      {:ok, state, detail} when state in [:working, :failed, :canceled, :submitted] ->
        envelope = Xaas.Bridges.envelope(subject, "p-plan purchase run", :failed)

        {:refused,
         Map.merge(envelope, %{code: resume_refusal_code(state, detail), reason: inspect(detail)})}

      {:error, :no_such_run} ->
        envelope = Xaas.Bridges.envelope(subject, "p-plan purchase run", :failed)
        {:refused, Map.merge(envelope, %{code: :no_such_run, reason: "no parked durable run"})}

      {:error, reason} ->
        envelope = Xaas.Bridges.envelope(subject, "p-plan purchase run", :failed)
        {:refused, Map.merge(envelope, %{code: :resume_failed, reason: inspect(reason)})}
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

  # -- durable run construction -------------------------------------------------

  defp purchase_model_struct do
    {:ok, model} =
      AshPPlan.Workflow.Model.new(
        name: @model_name,
        goal: @model_name,
        tasks: [
          [id: :authorize, capability: "Process.Authorize", depends_on: []],
          [id: :renew, capability: "Process.Renew", depends_on: [:authorize]]
        ]
      )

    model
  end

  defp bindings do
    Map.new(
      [
        {:authorize, "Process.Authorize"},
        {:renew, "Process.Renew"}
      ],
      fn {task, cap} ->
        {task,
         %AshPPlan.Realization{
           capability: cap,
           provider: :xaas_pplan,
           binding: %{adapter: :xaas_pplan, op: AshPPlan.Realization.op_for(cap)},
           options: []
         }}
      end
    )
  end

  defp store! do
    Application.get_env(:xaas, :pplan_durable_store) ||
      raise """
      no durable P-PLAN store configured. Set Application env
      `:xaas -> :pplan_durable_store` to the pid/name of a running
      #{inspect(AshPPlan.Reactor.Durable.Store.Ets)} process (the application
      tree starts one as #{inspect(Xaas.Bridges.PPlan.Store)}).
      """
  end

  defp store_module, do: AshPPlan.Reactor.Durable.Store.Ets

  # -- envelopes ----------------------------------------------------------------

  defp completed_envelope(subject, value, store, store_mod) do
    envelope =
      Xaas.Bridges.envelope(subject, "p-plan purchase run", :completed, "PARTIAL_ALIVE")

    record = fetch_record!(store, subject, store_mod)

    %{
      envelope
      | evidence_ref: "ash_pplan.durable_run:" <> record.id,
        receipt_ref: "ash_pplan.durable_run:" <> record.id,
        provenance: %{
          plan_iri: @plan_iri,
          run_id: record.id,
          status: record.status,
          value: inspect(value)
        }
    }
  end

  defp parked_envelope(subject, store, store_mod) do
    envelope =
      Xaas.Bridges.envelope(
        subject,
        "p-plan purchase run",
        :awaiting_human_release,
        "PARTIAL_ALIVE"
      )

    record = fetch_record!(store, subject, store_mod)

    %{
      envelope
      | evidence_ref: "ash_pplan.durable_run:" <> record.id,
        receipt_ref: "ash_pplan.durable_run:" <> record.id,
        provenance: %{
          plan_iri: @plan_iri,
          run_id: subject,
          reactor_state: :halted,
          continuation_schema: record.version,
          continuation: record
        }
    }
  end

  defp failed_envelope(subject),
    do: Xaas.Bridges.envelope(subject, "p-plan purchase run", :failed)

  defp fetch_record!(store, id, store_mod) do
    {:ok, record} = AshPPlan.A2A.Facade.fetch(store, id, store_module: store_mod)
    record
  end

  defp resume_refusal_code(:failed, _detail), do: :resume_failed
  defp resume_refusal_code(:working, _detail), do: :run_busy
  defp resume_refusal_code(:canceled, _detail), do: :run_canceled
  defp resume_refusal_code(_state, _detail), do: :resume_failed

  # -- the durable adapter ------------------------------------------------------

  defmodule DurableAdapter do
    @moduledoc """
    The xaas realization adapter for the payment spine: binds the two plan
    steps to real step modules for the durable engine. Registered under
    `config :ash_pplan, :extra_adapters` as `:xaas_pplan`. Grants no authority.
    """

    @behaviour AshPPlan.Reactor.Adapter

    alias AshPPlan.Reactor.Durable.Steps

    @impl true
    def id, do: :xaas_pplan

    @impl true
    def available?, do: true

    @impl true
    def ops, do: [:process_authorize, :process_renew]

    @impl true
    def step(op, _options) do
      table = %{
        process_authorize: {Xaas.Bridges.PPlan.Steps.AuthorizePayment, []},
        process_renew: {Xaas.Bridges.PPlan.Steps.RenewSubscription, []}
      }

      case Map.fetch(table, op) do
        {:ok, step} -> {:ok, step}
        :error -> {:error, {:unsupported_op, op}}
      end
    end
  end

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
          {:ok,
           %{status: :over_limit, requires_human_release: true, amount: amount, limit: limit}}

        true ->
          {:ok,
           %{status: :authorized, requires_human_release: false, amount: amount, limit: limit}}
      end
    end
  end

  defmodule Steps.RenewSubscription do
    @moduledoc """
    `RenewSubscription` step: the human-release gate. Over-limit purchases halt
    here — parking a durable `human_release` signal waiter (`{:halt,
    :await_human_release}`) so the run parks as `:waiting` (facade
    `:input_required`) — until a release signal arrives; with a release
    present (context `:human_release` or a delivered signal payload) the
    renewal completes.
    """
    use Reactor.Step

    @release_signal "human_release"

    @impl true
    def run(arguments, context, _options) do
      authorization = arguments[:predecessor_0] || %{}
      durable = context[:durable]
      release = context[:human_release] || (durable && take_release(durable))

      cond do
        release != nil ->
          {:ok, %{renewed: true, authorization: authorization, released_by: release}}

        not release_required?(authorization) ->
          {:ok, %{renewed: true, authorization: authorization, released_by: nil}}

        true ->
          park_and_halt(durable, authorization)
      end
    end

    # Consume-once take of the parked release signal, mirroring
    # `AshPPlan.Reactor.Durable.Steps.Await`'s take/park/take ordering.
    defp take_release(%{store: store, store_module: mod, run_id: run_id}) do
      case mod.pending_signal(store, run_id, @release_signal) do
        nil ->
          nil

        signal ->
          case mod.consume_signal(store, signal.id, AshPPlan.Reactor.Durable.Clock.now()) do
            {:ok, taken} ->
              :ok = mod.release(store, run_id, @release_signal)
              taken.payload

            :taken ->
              take_release(%{store: store, store_module: mod, run_id: run_id})
          end
      end
    end

    defp take_release(nil), do: nil

    defp park_and_halt(%{store: store, store_module: mod, run_id: run_id}, authorization) do
      {:ok, _waiter} = mod.park(store, run_id, @release_signal, :signal, nil, [])

      # re-check closes the delivery race, exactly like Steps.Await
      case take_release(%{store: store, store_module: mod, run_id: run_id}) do
        nil -> {:halt, {:await_human_release, authorization}}
        payload -> {:ok, %{renewed: true, authorization: authorization, released_by: payload}}
      end
    end

    defp release_required?(%{requires_human_release: true}), do: true
    defp release_required?(_), do: false
  end
end
