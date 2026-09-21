defmodule Xaas.TemporalMemory.Query do
  @moduledoc """
  Temporal query API over `Xaas.TemporalMemory.Observation` (ticket scope
  items 4, 5, 8): historical state reconstruction and historical
  observation projection, with valid-time (`t_v`) and observation-time
  (`t_o`) kept as independent bound parameters rather than conflated into
  one axis.

  `as_of/2` answers exactly the two questions the ticket's falsifier for
  the query API names as needing to be independently answerable:

  - "what was true at `t_v`" -- the `valid_from <= t_v` /
    `valid_to is nil or valid_to > t_v` filter.
  - "what did we know at `t_o`" -- the `observed_at <= t_o` filter.

  Passing both bounds answers "what did we know, as of `t_o`, about what
  was true at `t_v`" -- the compound bitemporal query, and the one
  `Xaas.TemporalMemory.Replay` verifies against the ticket's stated
  invariant.

  ## UNSUPPORTED

  This module resolves "latest known state per subject as of `t_o`" by
  picking the single row with the greatest `observed_at` among rows that
  satisfy both bounds (see `latest_per_subject/1`). That is correct for a
  single, linear supersession chain per subject (one active correction
  lineage at a time), which is the only case `Observation`'s `:supersede`
  action can produce. Resolving *concurrent, conflicting* corrections to
  the same subject (two independent supersession branches reconciled by
  some merge policy) is out of scope for this slice -- there is no honest
  way to invent a conflict-resolution policy the ticket does not specify,
  so this is left as an explicit gap rather than a fabricated tie-break
  rule.
  """

  require Ash.Query

  alias Xaas.TemporalMemory.Observation

  @doc """
  Reconstructs the observation(s) known, as of observation-time `t_o`
  (default: now), to describe `subject_type`/`subject_id` as valid at
  valid-time `t_v` (default: now).

  Returns `{:ok, observation | nil}` -- `nil` means no observation both
  covers `t_v` and was knowable by `t_o` (an honest "unknown", not an
  error).
  """
  @spec as_of(map(), keyword()) :: {:ok, Observation.t() | nil} | {:error, term()}
  def as_of(%{subject_type: subject_type, subject_id: subject_id} = params, opts \\ []) do
    t_v = Map.get(params, :valid_time, DateTime.utc_now())
    t_o = Map.get(params, :observation_time, DateTime.utc_now())
    authorize? = Keyword.get(opts, :authorize?, false)

    with {:ok, rows} <-
           Observation
           |> Ash.Query.filter(subject_type == ^subject_type and subject_id == ^subject_id)
           |> Ash.Query.filter(observed_at <= ^t_o)
           |> Ash.Query.filter(valid_from <= ^t_v)
           |> Ash.Query.filter(is_nil(valid_to) or valid_to > ^t_v)
           |> Ash.read(authorize?: authorize?) do
      {:ok, latest_per_subject(rows)}
    end
  end

  @doc "Raising counterpart of `as_of/2`."
  @spec as_of!(map(), keyword()) :: Observation.t() | nil
  def as_of!(params, opts \\ []) do
    case as_of(params, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "Xaas.TemporalMemory.Query.as_of failed: #{inspect(reason)}"
    end
  end

  @doc """
  All observations ever recorded (any observation-time) whose valid-time
  interval covers `t_v` -- i.e. the full historical/corrected lineage for a
  subject at that valid time, newest observation first. Used by
  `Xaas.TemporalMemory.Replay` to show what changed between successive
  corrections.
  """
  @spec lineage_at(map(), keyword()) :: {:ok, [Observation.t()]} | {:error, term()}
  def lineage_at(%{subject_type: subject_type, subject_id: subject_id} = params, opts \\ []) do
    t_v = Map.get(params, :valid_time, DateTime.utc_now())
    authorize? = Keyword.get(opts, :authorize?, false)

    Observation
    |> Ash.Query.filter(subject_type == ^subject_type and subject_id == ^subject_id)
    |> Ash.Query.filter(valid_from <= ^t_v)
    |> Ash.Query.filter(is_nil(valid_to) or valid_to > ^t_v)
    |> Ash.Query.sort(observed_at: :desc)
    |> Ash.read(authorize?: authorize?)
  end

  defp latest_per_subject([]), do: nil

  defp latest_per_subject(rows) do
    Enum.max_by(rows, & &1.observed_at, DateTime)
  end
end
