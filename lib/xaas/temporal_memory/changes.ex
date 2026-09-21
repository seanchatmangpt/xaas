defmodule Xaas.TemporalMemory.Changes do
  @moduledoc """
  Ash changes shared by `Xaas.TemporalMemory.Observation`'s `:observe` and
  `:supersede` actions.
  """

  defmodule ComputeReceiptHash do
    @moduledoc """
    Deterministically hashes the canonical bitemporal fields of an
    observation before it is persisted (ticket scope item 10, temporal
    receipt hashing).

    Runs `before_action` (after `observed_at` has been set by
    `set_attribute/2` earlier in the same action's change pipeline) so the
    hash covers the real, final value of every temporal axis: `subject_type`,
    `subject_id`, `fact`, `valid_from`, `valid_to`, `observed_at`, and
    `supersedes_id`. Any later mutation of any one of those fields would
    produce a different hash, which is exactly the detectability the
    ticket's falsifier for receipt hashing requires.
    """

    use Ash.Resource.Change

    @impl Ash.Resource.Change
    def change(changeset, _opts, _context) do
      Ash.Changeset.before_action(changeset, fn changeset ->
        hash = compute(changeset)
        Ash.Changeset.force_change_attribute(changeset, :receipt_hash, hash)
      end)
    end

    defp compute(changeset) do
      canonical = %{
        subject_type: Ash.Changeset.get_attribute(changeset, :subject_type),
        subject_id: Ash.Changeset.get_attribute(changeset, :subject_id),
        fact: Ash.Changeset.get_attribute(changeset, :fact) || %{},
        valid_from: to_iso(Ash.Changeset.get_attribute(changeset, :valid_from)),
        valid_to: to_iso(Ash.Changeset.get_attribute(changeset, :valid_to)),
        observed_at: to_iso(Ash.Changeset.get_attribute(changeset, :observed_at)),
        supersedes_id: Ash.Changeset.get_attribute(changeset, :supersedes_id)
      }

      canonical
      |> canonical_json()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)
    end

    defp to_iso(nil), do: nil
    defp to_iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

    # Deterministic, key-sorted encoding so two logically-identical canonical
    # maps always hash to the same digest regardless of map key iteration
    # order (Elixir maps do not guarantee key order across a JSON encode).
    defp canonical_json(map) when is_map(map) do
      map
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Enum.map(fn {k, v} -> [to_string(k), ?=, canonical_value(v)] end)
      |> Enum.intersperse(?&)
      |> IO.iodata_to_binary()
    end

    defp canonical_value(v) when is_map(v), do: canonical_json(v)
    defp canonical_value(v) when is_list(v), do: Enum.map_join(v, ",", &canonical_value/1)
    defp canonical_value(nil), do: "nil"
    defp canonical_value(v), do: to_string(v)
  end

  defmodule MarkPriorSuperseded do
    @moduledoc """
    After a `:supersede` create succeeds, points the prior observation's
    `superseded_by_id` at the new row -- the audit-trail side of
    correction/supersession semantics (ticket scope item 7). This never
    touches the prior row's `fact`/`valid_from`/`valid_to`/`observed_at`, so
    reconstructing "what was believed before the correction"
    (`Xaas.TemporalMemory.Query.as_of/2` bounded before the new row's
    `observed_at`) still returns the original, untouched fact.
    """

    use Ash.Resource.Change

    @impl Ash.Resource.Change
    def change(changeset, _opts, _context) do
      Ash.Changeset.after_action(changeset, fn _changeset, result ->
        case result.supersedes_id do
          nil ->
            {:ok, result}

          prior_id ->
            case Ash.get(Xaas.TemporalMemory.Observation, prior_id, authorize?: false) do
              {:ok, prior} ->
                prior
                |> Ash.Changeset.for_update(:mark_superseded_by, %{superseded_by_id: result.id})
                |> Ash.update!(authorize?: false)

                {:ok, result}

              {:error, _} ->
                # The referenced prior observation doesn't exist. The new
                # observation itself is still a valid, honest record -- we
                # do not fail the whole supersede for a dangling audit
                # pointer, we just cannot mark the (nonexistent) prior.
                {:ok, result}
            end
        end
      end)
    end
  end
end
