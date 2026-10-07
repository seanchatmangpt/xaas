defmodule Xaas.Platform.Validations.RouteProjectsBackupsRetainUntilPassed do
  @moduledoc """
  Real business rule for `Xaas.Platform.RouteProjectsBackups`'s
  `:purge_expired` destroy action (lane W970b, closing the W770
  "no transition path / no retention sweep" OPEN row): a backup row may be
  pruned only once its own `retain_until` timestamp has actually passed.

  Before this action existed the resource had no write path past
  `:create` at all -- a `:pending` backup could never be transitioned or
  pruned through the Ash surface (W770's typed gap, pinned by
  `Xaas.Platform.PlatformRouteDeepeningTest` (4b)).

  W981d (strict-sweep Exclusion 2 removal): the validation now also
  implements `atomic/3`, so `:purge_expired` can run as a single set-based
  bulk destroy (no per-row operator read). The atomic expression
  re-derives the same rule server-side in SQL: refuse when `retain_until`
  is absent (fail closed) or still in the future (`retain_until > now()`).
  """
  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidAttribute

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def atomic(_changeset, _opts, _context) do
    {:atomic, [:retain_until],
     expr(is_nil(retain_until) or retain_until > now()),
     expr(
       error(^InvalidAttribute, %{
         field: :retain_until,
         value: ^atomic_ref(:retain_until),
         message: "retain_until must have passed before purging (fail closed when absent)"
       })
     )}
  end

  @impl true
  def validate(changeset, _opts, _context) do
    retain_until =
      case Ash.Changeset.get_attribute(changeset, :retain_until) do
        nil -> changeset.data && Map.get(changeset.data, :retain_until)
        v -> v
      end

    now = DateTime.truncate(DateTime.utc_now(), :second)

    case retain_until do
      nil ->
        # fail closed: no retention deadline means never auto-prunable
        {:error,
         field: :retain_until,
         message: "has no retention deadline; refusing to prune (fail closed)"}

      %DateTime{} = retain_until ->
        if DateTime.compare(retain_until, now) == :gt do
          {:error,
           field: :retain_until,
           message:
             "is still within its retention window (retain_until #{DateTime.to_iso8601(retain_until)}); " <>
               "purging before expiry is refused"}
        else
          :ok
        end

      _ ->
        {:error,
         field: :retain_until,
         message: "could not be interpreted as a retention deadline; refusing (fail closed)"}
    end
  end
end
