defmodule Xaas.TemporalMemory.Replay do
  @moduledoc """
  Temporal replay verifier (ticket scope item 9) checking the ticket's
  stated key invariant:

      Replay(d_t, O_<=t) = d_t

  Concretely: reconstructing "what was known, as of observation-time
  `t_o`, to be valid at valid-time `t_v`" via
  `Xaas.TemporalMemory.Query.as_of/2` must be a deterministic function of
  the observation set knowable by `t_o` -- re-running it against the same
  bound must always reproduce the same `receipt_hash`, and must never pick
  up an observation recorded after `t_o` (a retroactive-observation leak).

  ## UNSUPPORTED

  This verifies the *reconstruction* invariant against the persisted
  `Observation` log -- it does not verify replay of an arbitrary upstream
  "decision" `d_t` (this ticket does not define what a decision record
  looks like outside this bitemporal event model; that is a distinct,
  not-yet-specified concern). `verify/2`'s `d_t` is the reconstructed
  observation itself, which is the only concrete `d_t` this slice has
  real, admitted data to replay.
  """

  alias Xaas.TemporalMemory.Query

  @doc """
  Recomputes `Query.as_of/2` for the given `params` twice and checks:

  1. Determinism -- both recomputations agree (same `receipt_hash`, or
     both `nil`).
  2. No retroactive leak -- if a result is found, its `observed_at` never
     exceeds the requested observation-time bound.

  Returns `{:ok, receipt}` where `receipt` carries the reconstructed
  observation (or `nil`) and the bounds it was verified against, or
  `{:error, reason}` naming exactly which invariant broke.
  """
  @spec verify(map(), keyword()) ::
          {:ok,
           %{
             observation: Xaas.TemporalMemory.Observation.t() | nil,
             valid_time: DateTime.t(),
             observation_time: DateTime.t()
           }}
          | {:error, :nondeterministic_replay | :retroactive_observation_leak | term()}
  def verify(%{subject_type: _, subject_id: _} = params, opts \\ []) do
    t_v = Map.get(params, :valid_time, DateTime.utc_now())
    t_o = Map.get(params, :observation_time, DateTime.utc_now())
    bound_params = Map.merge(params, %{valid_time: t_v, observation_time: t_o})

    with {:ok, first} <- Query.as_of(bound_params, opts),
         {:ok, second} <- Query.as_of(bound_params, opts) do
      cond do
        receipt_hash(first) != receipt_hash(second) ->
          {:error, :nondeterministic_replay}

        leaks_future_observation?(first, t_o) ->
          {:error, :retroactive_observation_leak}

        true ->
          {:ok, %{observation: first, valid_time: t_v, observation_time: t_o}}
      end
    end
  end

  @doc """
  Compares a freshly-recomputed reconstruction's `receipt_hash` against a
  previously recorded `expected_hash` (e.g. one captured on a past
  decision record). `true` means replay reproduced the exact same
  bitemporal fact; `false` means it did not -- either the fact truly
  differs, or the earlier capture was wrong, but either way this is a real
  hash comparison, not a heuristic.
  """
  @spec replay_matches?(map(), String.t() | nil, keyword()) :: boolean()
  def replay_matches?(params, expected_hash, opts \\ []) do
    case Query.as_of(params, opts) do
      {:ok, observation} -> receipt_hash(observation) == expected_hash
      {:error, _} -> false
    end
  end

  defp receipt_hash(nil), do: nil
  defp receipt_hash(%{receipt_hash: hash}), do: hash

  defp leaks_future_observation?(nil, _t_o), do: false

  defp leaks_future_observation?(%{observed_at: observed_at}, t_o) do
    DateTime.compare(observed_at, t_o) == :gt
  end
end
