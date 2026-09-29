defmodule Xaas.Sa2a.WaveOutcome do
  @moduledoc """
  XaaS adapter from WaveLoop/runtime vocabulary into the SA2A consequence
  vocabulary. SA2A owns terminal/recoverable consequence semantics; XaaS
  retains scheduling policy such as chain/await/backoff.
  """

  @success [:worker_completed, :complete, :completed, :success, :alive, :partial_alive, :reconciled, :compensated]
  @refused [:blocked, :refused]
  @failed [
    :failed,
    :timeout,
    :rate_limited,
    :dispatch_refused,
    :construction_refused,
    :requeued,
    :error,
    :stale_reap_failed,
    :worker_exit,
    :reclaim_failed
  ]
  @known Enum.uniq(@success ++ @refused ++ @failed ++ [:busy, :waiting_deps, :handed_off, :unknown_outcome])
  @strings Map.new(@known, &{Atom.to_string(&1), &1})

  def parse(outcome) when is_atom(outcome), do: if(outcome in @known, do: outcome, else: :unknown_outcome)
  def parse(outcome) when is_binary(outcome), do: Map.get(@strings, outcome, :unknown_outcome)
  def parse(_), do: :unknown_outcome

  def consequence(outcome) do
    case parse(outcome) do
      value when value in @success -> :executed
      value when value in @refused -> :refused
      value when value in @failed -> :failed
      _ -> :unknown_outcome
    end
  end

  def settlement(outcome) do
    case consequence(outcome) do
      :executed -> :complete
      :refused -> :block
      consequence when consequence in [:failed, :unknown_outcome] -> :requeue
    end
  end

  def recovery(outcome), do: AshA2A.Replan.RecoveryPolicy.next(consequence(outcome))

  def chainable?(outcome, overloaded?) do
    not overloaded? and parse(outcome) == :worker_completed and consequence(outcome) == :executed
  end
end
