defmodule Xaas.Ultracode.ConvergenceReceipt do
  @moduledoc """
  The FAILED_CONVERGENCE receipt (loops-of-loops spec L4, Epistemic Horizon
  K_max): what a loop that CANNOT converge leaves behind when it stops.

  Until this module, horizon exhaustion was silent: the crown's `execute/6`
  ran out of `:max_attempts` and returned `{:blocked, %{"status" => "blocked",
  "history" => ...}}` -- no receipt, no witness, no andon trip; the fleet's
  only real budget (the ash_a2a `Replan.AttemptBudget`, `:replan_exhausted`
  after `max_attempts: 3`) refused as an untyped refusal; the pplan
  `PolicySupervisor` had an epoch field but no horizon at all. An epistemic
  horizon is now a typed, digested, standing-carrying fact.

  ## The receipt

  `mint/1` builds the receipt-shaped map:

      %{
        "receipt_class" => "FAILED_CONVERGENCE",
        "identity"      => identity,
        "k_max"         => k_max,
        "attempts"      => [attempt summaries...],
        "horizon_witness" => sha256 hex over the canonical JSON of `attempts`,
        "standing"      => "BLOCKED:epistemic_horizon_exceeded"
      }

  plus an optional `"source"` marker (`"source"` key, present only when the
  ctx names one) recording which loop minted it:
  `"semantic_crown"`, `"semantic_drive"`, `"ash_pplan_horizon"` or
  `"replan_attempt_budget"`.

  ## Standing rides the EXISTING R standing enum

  `@standing` is the literal string `"BLOCKED:epistemic_horizon_exceeded"`.
  This is deliberately NOT a new standing value: the fleet R schema
  (`~/.claude/dfcm/receipt.schema.json`) declares the standing pattern
  `^(UNKNOWN|PARTIAL_ALIVE|ALIVE|BLOCKED(:.+)?|BUILD_BROKEN|UNSUPPORTED(\(.+\))?|REFUSED\(.+\))$`,
  and `BLOCKED:epistemic_horizon_exceeded` matches its existing
  `BLOCKED(:.+)` alternative exactly -- the colon alternative means
  "BLOCKED" optionally followed by ":" + reason (the spec's own
  `BLOCKED(:reason)` pseudo-syntax, spelled the way the schema actually
  admits: `RProjection` renders BLOCKED standings as
  `"BLOCKED:subject_unreachable"`, the drive as `"BLOCKED:not_on_frontier"`).
  No enum extension, no validator change. In the R projection's term shape
  this is the BLOCKED family (`mu_on_O`: the court cannot witness
  convergence past the horizon); a downstream R projection renders it
  `{"value" => "BLOCKED:epistemic_horizon_exceeded", "broken_term" =>
  "mu_on_O"}`. The validator is the gate: the test suite runs the real
  fleet schema pattern over it -- a literal parenthesised spelling
  (`"BLOCKED(:epistemic_horizon_exceeded)"`) does NOT match the pattern
  (the `(` precedes the `:`) and is refused.

  ## The two mapped budgets

  Two upstream exhaustion shapes map onto this receipt; both are documented
  so the horizon law stays one law:

    * **ash_pplan horizon** -- `AshPPlan.FOND.PolicySupervisor.observe/3`
      returns `{:error, {:horizon_exceeded, k, witness}}` when the epoch
      counter exhausts the struct's `:horizon` (K_max, default 9). The
      failure is data, never a crash; `mint/1` accepts it under
      `:pplan_failure` and names the source `ash_pplan_horizon`.
    * **ash_a2a Replan AttemptBudget** -- the fleet's only real budget
      today. `AshA2A.Replan.AttemptBudget.consume/1` returns
      `{:error, AshA2A.Replan.Refusal.new(:replan_exhausted)}` after
      `max_attempts` (3 in the drive's plan-next path); the drive's
      plan-next journal records it as `REFUSED(plan_next_loop_failed)`.
      The mapping is fixed here: **Replan `:replan_exhausted` maps to
      FAILED_CONVERGENCE** -- the attempt budget IS an epistemic horizon;
      `mint/1` accepts `:replan_exhausted` under `:pplan_failure` and
      names the source `replan_attempt_budget`.

  Nothing here actuates. The receipt is data; writing it is the caller's
  act (the drive's artifact channel, `convergence-failed.json`; the
  crown's `{:blocked, receipt}` return).
  """

  @standing "BLOCKED:epistemic_horizon_exceeded"
  @receipt_class "FAILED_CONVERGENCE"
  @schema "xaas/ultracode-convergence-receipt/v1"

  @typedoc "The minted receipt (JSON-able; the attempt summaries are JSON-able)."
  @type t :: %{
          required(String.t()) => String.t() | pos_integer() | [map()] | [String.t()]
        }

  @doc "The standing of every horizon exhaustion: `BLOCKED:epistemic_horizon_exceeded`."
  @spec standing() :: String.t()
  def standing, do: @standing

  @doc "The receipt class marker (`FAILED_CONVERGENCE`)."
  @spec receipt_class() :: String.t()
  def receipt_class, do: @receipt_class

  @doc "The receipt schema marker (`xaas/ultracode-convergence-receipt/v1`)."
  @spec schema() :: String.t()
  def schema, do: @schema

  @doc """
  Mints the receipt. `ctx` keys:

    * `:identity` (required, binary) -- the work order / loop identity;
    * `:k_max` (required, positive integer) -- the exhausted horizon;
    * `:attempts` (required list) -- the attempt summaries (one per non-advancing
      cycle / failed attempt; carried verbatim into the receipt);
    * `:pplan_failure` (optional) -- `{:horizon_exceeded, k, witness}` (the
      pplan PolicySupervisor shape) or `:replan_exhausted` (the ash_a2a
      AttemptBudget shape); when present the source marker is derived and the
      upstream `witness`/`k` ride the receipt's `"source"` object;
    * `:source` (optional binary) -- explicit source marker, overriding the
      `:pplan_failure` derivation.

  The `horizon_witness` is the lowercase-hex sha256 over the canonical JSON
  of the attempt summaries (sorted keys, compact separators, UTF-8
  unescaped) -- the no-drift fingerprint of the exhausted horizon. The same
  canonicalization as `Xaas.Sa2a.Route.digest/1` (Python's
  `json.dumps(..., sort_keys=True, separators=(",", ":"))`).
  """
  @spec mint(map()) :: t()
  def mint(ctx) when is_map(ctx) do
    identity = Map.fetch!(ctx, :identity)
    k_max = Map.fetch!(ctx, :k_max)
    attempts = Map.fetch!(ctx, :attempts)

    receipt =
      %{
        "receipt_class" => @receipt_class,
        "identity" => identity,
        "k_max" => k_max,
        "attempts" => attempts,
        "horizon_witness" => witness(attempts),
        "standing" => @standing
      }

    Map.merge(receipt, source(ctx))
  end

  @doc """
  True iff `receipt` carries the convergence-failure class and standing and
  its witness recomputes over its own attempts -- the receipt's self-check
  (the no-overclaiming law applied to the receipt itself: a witness that
  does not recompute proves nothing).
  """
  @spec valid?(term()) :: boolean()
  def valid?(%{"receipt_class" => @receipt_class, "standing" => @standing} = receipt) do
    is_integer(receipt["k_max"]) and receipt["k_max"] > 0 and is_list(receipt["attempts"]) and
      receipt["horizon_witness"] == witness(receipt["attempts"])
  end

  def valid?(_other), do: false

  @doc """
  The OCEL `ConvergenceFailed` event for the receipt, as a
  `Xaas.Ultracode.SemanticDrive.Ocel` event map (type, time, attributes,
  relationships). The class is declared in `Ocel.extension_classes/0`, so a
  court-form log that includes it validates. Relationships: the work order
  (`workorder:<identity>`).
  """
  @spec ocel_event(t()) :: %{
          type: String.t(),
          time: DateTime.t(),
          attributes: map(),
          relationships: [{String.t(), String.t()}]
        }
  def ocel_event(%{"receipt_class" => @receipt_class} = receipt) do
    %{
      type: "ConvergenceFailed",
      time: DateTime.utc_now(),
      attributes: Map.take(receipt, ~w(k_max horizon_witness standing)),
      relationships: [{"workorder:" <> receipt["identity"], "work-order"}]
    }
  end

  # -- helpers -----------------------------------------------------------------

  # The source marker: an explicit `:source` wins; otherwise the
  # `:pplan_failure` shape derives it ({:horizon_exceeded, _, _} ->
  # "ash_pplan_horizon"; :replan_exhausted -> "replan_attempt_budget").
  # Absent both, the key is not present at all.
  defp source(%{source: source}) when is_binary(source),
    do: %{"source" => source}

  defp source(%{pplan_failure: {:horizon_exceeded, k, witness}})
       when is_integer(k) and is_binary(witness) do
    %{"source" => %{"kind" => "ash_pplan_horizon", "k" => k, "witness" => witness}}
  end

  defp source(%{pplan_failure: :replan_exhausted}),
    do: %{"source" => %{"kind" => "replan_attempt_budget", "reason" => "replan_exhausted"}}

  defp source(_ctx), do: %{}

  # sha256 hex over the canonical JSON of the attempt summaries.
  defp witness(attempts), do: attempts |> canonical() |> Jason.encode!() |> hash()

  defp canonical(list) when is_list(list), do: Enum.map(list, &canonical/1)

  defp canonical(%{} = map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), canonical(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Jason.OrderedObject.new()
  end

  defp canonical(value), do: value

  defp hash(bytes), do: "sha256:" <> (:crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower))
end
