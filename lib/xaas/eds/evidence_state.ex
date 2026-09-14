defmodule Xaas.Eds.EvidenceState do
  @moduledoc """
  The Executable Design Science (EDS) evidence-state model.

  Implements the paper's evidence-state set (`docs/research/executable-design-science.md`,
  Section 7) and its central non-collapse invariant:

      implemented != executed != observed != verified != reproduced

  ## What this module is

  A pure, deterministic classifier: given which evidence artifacts an
  `Xaas.Eds.ExecutableResearchClaim` (ECR) actually holds, `classify/1`
  computes the claim's current evidence state -- honestly, without ever
  promoting a state the evidence does not support. It never guesses a
  stronger state than the evidence held.

  States are **not** a single linear ladder. `FALSIFIED` and `BLOCKED` can
  occur regardless of how much prior evidence exists; a claim can be
  `EXECUTABLE` while remaining scientifically `UNSUPPORTED`.

  ## UNSUPPORTED (real, disclosed gap)

  This module classifies evidence a caller already asserts exists (a
  falsifier ran and produced a verdict, a validator ran and produced a
  verdict, a reproduction attempt happened). It does not itself execute
  code, run validators, or perform reproduction -- those are owned by
  whatever subsystem produces the `Xaas.Eds.ExecutableResearchClaim`'s
  evidence fields. This is the honest boundary: a classifier over asserted
  evidence, not a scientific truth oracle.
  """

  @type t ::
          :proposed
          | :implemented
          | :executable
          | :observed
          | :verified
          | :reproducible
          | :reproduced
          | :falsified
          | :blocked
          | :unsupported
          | :unknown

  @states [
    :proposed,
    :implemented,
    :executable,
    :observed,
    :verified,
    :reproducible,
    :reproduced,
    :falsified,
    :blocked,
    :unsupported,
    :unknown
  ]

  @doc "The full enumerated evidence-state set from the paper (Section 7)."
  @spec states() :: [t()]
  def states, do: @states

  @doc """
  Classify the evidence state of a claim's evidence bundle.

  `evidence` is a plain map describing what has actually been asserted to
  exist for this claim -- not what is hoped to exist. Recognized keys
  (all optional; absence means "not yet asserted"):

    * `:artifact_exists` (boolean) -- source/artifact exists (P1)
    * `:blocked?` (boolean) -- a hard blocker was hit (dependency, env, etc.)
    * `:blocked_reason` (string, required when `blocked?: true`)
    * `:executed?` (boolean) -- the artifact was actually run (P3)
    * `:execution_identity` (map) -- exact subject/environment identity
    * `:observed_output` (any) -- raw output actually captured (P4)
    * `:falsifier_result` (`:survived` | `:falsified` | nil) -- outcome of
      running the claim's own falsifier against observed output
    * `:verified?` (boolean) -- a verification procedure ran and bound
      observed output to the claim's proposition (P5)
    * `:reproduction_attempted?` (boolean)
    * `:reproduction_independent?` (boolean) -- reproduction by a party
      other than the original executor (P6)
    * `:reproduction_result` (`:matched` | `:diverged` | nil)

  Returns the single best-supported state. Never returns a state stronger
  than the weakest link in the evidence chain actually asserted.
  """
  @spec classify(map()) :: t()
  def classify(evidence) when is_map(evidence) do
    cond do
      Map.get(evidence, :blocked?) == true and blocked_reason_present?(evidence) ->
        :blocked

      Map.get(evidence, :falsifier_result) == :falsified ->
        :falsified

      not Map.get(evidence, :artifact_exists, false) ->
        :proposed

      not Map.get(evidence, :executed?, false) ->
        :implemented

      not observed?(evidence) ->
        :executable

      not Map.get(evidence, :verified?, false) ->
        :observed

      Map.get(evidence, :reproduction_independent?) == true and
          Map.get(evidence, :reproduction_result) == :matched ->
        :reproduced

      Map.get(evidence, :reproduction_attempted?) == true and
          Map.get(evidence, :reproduction_result) == :matched ->
        # Reproduced, but not by an independent party -- the paper's
        # threats-to-validity section (Section 20) explicitly refuses to
        # collapse this into REPRODUCED.
        :reproducible

      true ->
        :verified
    end
  end

  defp observed?(evidence) do
    Map.has_key?(evidence, :observed_output) and Map.get(evidence, :observed_output) != nil
  end

  defp blocked_reason_present?(evidence) do
    case Map.get(evidence, :blocked_reason) do
      reason when is_binary(reason) and byte_size(reason) > 0 -> true
      _ -> false
    end
  end

  @doc """
  Assert the paper's non-collapse invariant between two named states for a
  single claim's evidence: state `a` must not be reported to hold when the
  weaker prerequisite state `b` does not.

  Returns `:ok` or `{:error, reason}` -- never raises, never silently
  passes on evidence that does not support the assertion.
  """
  @spec assert_non_collapse(map(), t(), t()) :: :ok | {:error, String.t()}
  def assert_non_collapse(evidence, stronger, weaker)
      when stronger in @states and weaker in @states do
    rank = Enum.with_index(precedence_order())

    with {_, stronger_rank} <- Enum.find(rank, fn {s, _} -> s == stronger end),
         {_, weaker_rank} <- Enum.find(rank, fn {s, _} -> s == weaker end) do
      actual = classify(evidence)
      actual_rank = actual |> then(&Enum.find(rank, fn {s, _} -> s == &1 end)) |> elem(1)

      cond do
        weaker_rank > stronger_rank ->
          {:error,
           "#{inspect(weaker)} is not weaker than #{inspect(stronger)} in the precedence order"}

        actual_rank < stronger_rank ->
          {:error,
           "claim evidence only supports #{inspect(actual)}, which is weaker than the asserted #{inspect(stronger)}"}

        true ->
          :ok
      end
    end
  end

  # Linear precedence used only for non-collapse assertions between
  # comparable states on the main implemented->reproduced spine.
  # FALSIFIED/BLOCKED/UNSUPPORTED/UNKNOWN are deliberately excluded --
  # they are not comparable points on this spine (Section 7).
  defp precedence_order,
    do: [:proposed, :implemented, :executable, :observed, :verified, :reproducible, :reproduced]
end
