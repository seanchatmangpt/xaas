defmodule Xaas.Ultracode.RecoveryPolicy do
  @moduledoc """
  The WaveLoop recovery policy as a FOND (fully observable nondeterministic)
  policy, admitted by `ash_pplan` — not a nest of `if`s.

  One tick is one nondeterministic action: from `:ready` the loop
  `:dispatch`es and the environment answers with any tick outcome
  (completed, requeued, refused, provider open, ...). The policy maps every
  observed outcome to exactly one follow-up action:

    * `:chain`      — enqueue the next tick now (work-conserving)
    * `:await_cron` — let the next scheduled tick retry (fair retry)
    * `:backoff`    — the provider breaker is open; wait for half-open
    * `:dispatch`   — the tick itself (from `:ready`)

  `:complete` is the only goal. Every recovery edge returns to `:ready`, so
  the policy is strong-cyclic: under the fairness assumption every reachable
  state keeps a path to `:complete`.

  **Admission is at compile time.** `@admission` runs
  `AshPPlan.FOND.validate_policy/4` (mode `:strong_cyclic`) and
  `AshPPlan.FOND.Synthesis.synthesize/3` over the declared domain; a law edit
  that leaves any reachable outcome without a policy decision, names an
  action the domain does not admit, or makes `:complete` unreachable fails
  the build. The same domain, policy and digest are exposed at runtime
  (`receipt/0`) so tick telemetry can bind each decision to the exact
  admitted policy.

  Authority: selecting the next tick is SELECT over admitted structure.
  The policy carries no actuation authority; dispatch still flows through
  `Xaas.Ultracode.Dispatch` and the lease kernel.
  """

  alias AshPPlan.FOND
  alias AshPPlan.FOND.Synthesis
  alias Xaas.Sa2a.WaveOutcome

  @retry_outcomes [
    :requeued,
    :dispatch_refused,
    :construction_refused,
    :busy,
    :waiting_deps,
    :blocked,
    :refused,
    :error,
    :stale_reap_failed
  ]

  @tick_outcomes [:worker_completed, :provider_open, :complete | @retry_outcomes]

  @transitions Map.merge(
                 %{
                   ready: %{dispatch: @tick_outcomes},
                   worker_completed: %{chain: [:ready], await_cron: [:ready]},
                   provider_open: %{backoff: [:ready], await_cron: [:ready]},
                   complete: %{}
                 },
                 Map.new(@retry_outcomes, &{&1, %{await_cron: [:ready], chain: [:ready]}})
               )

  @policy Map.merge(
            %{ready: :dispatch, worker_completed: :chain, provider_open: :backoff},
            Map.new(@retry_outcomes, &{&1, :await_cron})
          )

  @admission (fn ->
                {:ok, domain} = FOND.new(@transitions, [:complete])

                case FOND.validate_policy(domain, @policy, :ready, :strong_cyclic) do
                  {:ok, report} ->
                    {:ok, _synthesized} = Synthesis.synthesize(domain, :ready, :strong_cyclic)
                    report

                  {:error, refusal} ->
                    raise CompileError,
                      description:
                        "RecoveryPolicy is not strong-cyclic admissible: " <> inspect(refusal)
                end
              end).()

  @digest :crypto.hash(:sha256, :erlang.term_to_binary({@transitions, @policy}, [:deterministic]))
          |> Base.encode16(case: :lower)

  @type action :: :dispatch | :chain | :await_cron | :backoff | :halt
  @type state :: atom()

  @doc "The admitted FOND domain."
  @spec domain() :: FOND.t()
  def domain do
    {:ok, domain} = FOND.new(@transitions, [:complete])
    domain
  end

  @doc "The declared (admitted) policy map."
  @spec policy() :: %{optional(state()) => action()}
  def policy, do: @policy

  @doc "Tick outcomes the domain models."
  @spec tick_outcomes() :: [state()]
  def tick_outcomes, do: @tick_outcomes

  @doc """
  The compile-time admission receipt: policy digest, mode, and the
  ash_pplan validation report (reachable policy states).
  """
  @spec receipt() :: map()
  def receipt do
    %{
      schema: "xaas.ultracode.recovery-policy/1",
      policy_digest: "sha256:" <> @digest,
      mode: :strong_cyclic,
      initial: :ready,
      goals: [:complete],
      admitted_by: "AshPPlan.FOND.validate_policy/4 + FOND.Synthesis.synthesize/3",
      validation: @admission
    }
  end

  @doc """
  Maps an observed tick outcome (and whether the provider is overloaded /
  its breaker open) to the FOND state the policy is evaluated on.

  Overload dominates a completion: a completed worker observed while the
  provider is open is `:provider_open` (never chain into an open breaker).
  An outcome the domain does not model is `:error` — the fail-safe retry
  class — so an unknown outcome can never chain.
  """
  @spec observe(atom(), boolean()) :: state()
  def observe(:complete, _overloaded?), do: :complete
  def observe(_outcome, true), do: :provider_open
  def observe(outcome, false) when outcome in @tick_outcomes, do: outcome
  def observe(outcome, false) do
    case WaveOutcome.consequence(outcome) do
      :executed -> if(outcome == :worker_completed, do: :worker_completed, else: :error)
      :refused -> if(outcome in @retry_outcomes, do: outcome, else: :refused)
      :failed -> if(outcome in @retry_outcomes, do: outcome, else: :error)
      :unknown_outcome -> :error
    end
  end

  @doc """
  The admitted next action for an observed tick outcome. `:complete`
  yields `:halt` (the goal has no actions).
  """
  @spec decide(atom(), boolean()) :: action()
  def decide(outcome, overloaded?) do
    case observe(outcome, overloaded?) do
      :complete -> :halt
      state -> Map.fetch!(@policy, state)
    end
  end
end
