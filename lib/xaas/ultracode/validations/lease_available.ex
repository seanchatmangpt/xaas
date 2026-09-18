defmodule Xaas.Ultracode.Validations.LeaseAvailable do
  @moduledoc """
  Real `Ash.Resource.Validation` guarding `Epoch.:lease`: refuses (typed
  error, not a silent no-op) unless the Epoch is `:running` and holds no
  live lease (`lease_token` nil, or `lease_expires_at` already past).

  An expired lease does NOT block a fresh `:lease` -- expiry releases the
  epoch for the next claimer; only a LIVE lease fences. Race safety between
  two simultaneous claimers is not this validation's job -- it is a
  pre-flight check; the binding race is closed by
  `Xaas.Ultracode.Lease.claim_next/1`'s filtered bulk update.
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    state = Ash.Changeset.get_data(changeset, :state)
    token = Ash.Changeset.get_data(changeset, :lease_token)
    expires_at = Ash.Changeset.get_data(changeset, :lease_expires_at)

    cond do
      state != :running ->
        {:error, field: :state, message: "lease requires a running epoch"}

      token && live?(expires_at) ->
        {:error, field: :lease_token, message: "epoch already holds a live lease"}

      true ->
        :ok
    end
  end

  defp live?(nil), do: false
  defp live?(expires_at), do: DateTime.compare(expires_at, DateTime.utc_now()) == :gt
end
