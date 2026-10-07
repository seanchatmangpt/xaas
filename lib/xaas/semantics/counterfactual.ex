defmodule Xaas.Semantics.Counterfactual do
  @moduledoc """
  Deterministic counterfactual evaluation over recorded admission decisions
  (EU AI Act Art. 86 / dissertation Theorem 7.1).

  Theorem 7.1: `P(Y_{X<-x'} = y' | X, Y) ∈ {0,1}` — because the admission
  pipeline is deterministic and the recorded decision record carries the full
  ordered per-check verdicts (the structural recourse variables `U`, recovered
  from the receipt), the counterfactual `Y_{X<-x'}` is computed exactly by
  re-running the same pipeline on the substituted input `x'`. The outcome is
  0 or 1, never a distribution.

  A decision record is a map:

      %{
        input: input,
        admitted?: boolean(),
        refusal: atom() | nil,
        checks: [%{name: atom() | binary(), verdict: :pass | :fail, refusal: atom() | nil}]
      }

  `checks` on the record is the ordered per-check verdict log (the recovered
  `U`). The `checks` argument to `evaluate/3` is the *check-list* — an ordered
  list of admission checks, each either:

    * a 1-arity fun `(input -> :ok | {:refused, reason_atom})`, or
    * a `{name, fun}` tuple with the same fun contract.

  Check order is the causal order; the decision comes from the FIRST refusal
  in order (the same check-list shape the admission surface uses), and every
  check verdict is still recorded so the full counterfactual `U` is witnessed.
  """

  @typedoc "A single ordered per-check verdict from a recorded decision."
  @type recorded_check :: %{
          required(:name) => atom() | binary(),
          required(:verdict) => :pass | :fail,
          optional(:refusal) => atom() | nil
        }

  @typedoc "Recorded admission decision (the receipt body)."
  @type decision_record :: %{
          required(:input) => term(),
          required(:admitted?) => boolean(),
          required(:refusal) => atom() | nil,
          required(:checks) => [recorded_check()]
        }

  @typedoc "An admission check: `{name, fun}` or bare 1-arity fun."
  @type check ::
          {atom() | binary(), (term() -> :ok | {:refused, atom()})}
          | (term() -> :ok | {:refused, atom()})

  @typedoc "Counterfactual result."
  @type result :: %{
          required(:outcome) => :admitted | {:refused, atom()},
          required(:changed?) => boolean(),
          required(:explanation) => String.t(),
          required(:checks) => [recorded_check()]
        }

  @doc """
  Re-run the deterministic admission pipeline on the counterfactual input
  `x_prime` using `checks`, and diff the outcome against the recorded
  decision.

  Returns `{:ok, result}`:

    * `:outcome` — the counterfactual decision on `x'`: `:admitted` or
      `{:refused, reason}` (Theorem 7.1: exactly one, probability 1).
    * `:changed?` — whether the counterfactual outcome differs from the
      recorded one.
    * `:explanation` — deterministic binary naming the exact check (or checks)
      whose verdict flipped: the causal delta.
    * `:checks` — the full counterfactual per-check verdict log.

  Returns `{:error, {:record_outcome_mismatch, detail}}` if replaying the
  *recorded* input under `checks` does not reproduce the recorded decision —
  the receipt is then not a faithful witness of this check-list, and no
  counterfactual claim is admitted (typed refusal, no silent counterfactual).
  """
  @spec evaluate(decision_record(), term(), [check()]) ::
          {:ok, result()} | {:error, {:record_outcome_mismatch, term()}}
  def evaluate(
        %{input: input, admitted?: recorded_admitted?, refusal: recorded_refusal, checks: recorded_checks} = _record,
        x_prime,
        checks
      )
      when is_boolean(recorded_admitted?) and is_list(checks) and is_list(recorded_checks) do
    with :ok <- verify_recorded_outcome(input, recorded_admitted?, recorded_refusal, checks) do
      cf = run_pipeline(x_prime, checks)
      recorded_outcome = recorded_outcome(recorded_admitted?, recorded_refusal)
      {changed?, flipped} = diff(recorded_outcome, cf, recorded_checks)

      {:ok,
       %{
         outcome: cf.outcome,
         changed?: changed?,
         explanation: explanation(recorded_outcome, cf, flipped),
         checks: cf.checks
       }}
    end
  end

  @doc "Run the admission pipeline on `input` (no recorded decision needed)."
  @spec run(term(), [check()]) :: %{outcome: :admitted | {:refused, atom()}, checks: [recorded_check()]}
  def run(input, checks) when is_list(checks) do
    cf = run_pipeline(input, checks)
    %{outcome: cf.outcome, checks: cf.checks}
  end

  ## Internals

  defp verify_recorded_outcome(input, recorded_admitted?, recorded_refusal, checks) do
    replay = run_pipeline(input, checks)

    if replay_outcome_matches?(replay.outcome, recorded_admitted?, recorded_refusal) do
      :ok
    else
      {:error,
       {:record_outcome_mismatch,
        {:expected, {recorded_admitted?, recorded_refusal}, :got, replay.outcome}}}
    end
  end

  defp replay_outcome_matches?(:admitted, true, nil), do: true
  defp replay_outcome_matches?({:refused, reason}, false, reason), do: true
  defp replay_outcome_matches?(_, _, _), do: false

  # Runs every check in order (full per-check verdict log = the recovered U),
  # with the decision taken from the FIRST refusal in check order — the same
  # outcome a short-circuiting pipeline produces, but with downstream verdicts
  # still witnessed. Deterministic: same input + same check-list => same
  # outcome and same per-check log.
  defp run_pipeline(input, checks) do
    check_log = Enum.map(checks, fn check ->
      {name, fun} = normalize_check(check)

      case apply_check(fun, input) do
        :ok -> %{name: name, verdict: :pass, refusal: nil}
        {:refused, reason} -> %{name: name, verdict: :fail, refusal: reason}
      end
    end)

    outcome =
      case Enum.find(check_log, &(&1.verdict == :fail)) do
        nil -> :admitted
        %{refusal: reason} -> {:refused, reason}
      end

    %{outcome: outcome, checks: check_log}
  end

  defp apply_check(fun, input) do
    case fun.(input) do
      :ok -> :ok
      {:refused, reason} -> {:refused, reason}
    end
  end

  defp normalize_check({name, fun}) when (is_atom(name) or is_binary(name)) and is_function(fun, 1),
    do: {normalize_name(name), fun}

  defp normalize_check(fun) when is_function(fun, 1),
    do: {normalize_name(Function.info(fun, :name)), fun}

  defp normalize_name(name) when is_atom(name), do: name
  defp normalize_name(name) when is_binary(name), do: String.to_atom(name)

  # Causal delta: every recorded check whose verdict differs from the
  # counterfactual check with the same name, in recorded order.
  defp diff(recorded_outcome, cf, recorded_checks) do
    changed? = recorded_outcome != cf.outcome
    flipped = flipped_checks(recorded_checks, cf.checks)
    {changed?, flipped}
  end

  defp recorded_outcome(true, nil), do: :admitted
  defp recorded_outcome(false, reason) when not is_nil(reason), do: {:refused, reason}
  # malformed records replay-verify first, so this branch is unreachable
  defp recorded_outcome(_, _), do: :unknown

  defp flipped_checks(recorded_checks, cf_checks) do
    cf_by_name = Map.new(cf_checks, fn c -> {c.name, c} end)

    Enum.filter(recorded_checks, fn rc ->
      case Map.fetch(cf_by_name, rc.name) do
        {:ok, cf_check} -> rc.verdict != cf_check.verdict
        :error -> false
      end
    end)
  end

  defp explanation(recorded_outcome, cf, flipped) do
    case {flipped, cf.outcome == recorded_outcome} do
      {[], true} ->
        "No check verdicts changed; the counterfactual input yields the same decision " <>
          "(#{format_outcome(cf.outcome)}), so the recorded outcome is not caused by any single check flip."

      {[], false} ->
        "The outcome changed without any named check verdict flipping (outcome-level divergence)."

      {flipped, _same?} ->
        "Counterfactual outcome is #{format_outcome(cf.outcome)}; caused by check " <>
          format_flips(flipped) <> " flipping verdict."
    end
  end

  defp format_flips([only]), do: "`#{only.name}`"

  defp format_flips(flipped) do
    names = Enum.map_join(flipped, ", ", fn f -> "`#{f.name}`" end)
    "#{names} (multi-check flip)"
  end

  defp format_outcome(:admitted), do: "admitted"
  defp format_outcome({:refused, reason}), do: "refused (#{reason})"
end
