defmodule Xaas.Marketplace.Changes.ApplyProviderStatusChange do
  @moduledoc """
  Maker-checker bridge from an approved status-change request into the canonical
  Reactor actuation path.

  The approval action remains an Ash transaction hook, but it no longer mutates
  `Provider` directly. Instead it manufactures delegated authority evidence and
  invokes `Xaas.Actuation.run/4`. That call admits the provider's public-ontology
  projection, prepares durable intent/receipt rows, runs the consequential Ash
  action through Ash.Reactor, and seals the receipt before the transaction can
  commit.
  """

  use Ash.Resource.Change

  alias Xaas.Marketplace.Provider

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      case Xaas.Actuation.run(
             Provider,
             :actuate_status,
             %{status: record.requested_status},
             subject_id: record.provider_id,
             idempotency_key: idempotency_key(record),
             authorize?: false,
             authority: authority(record)
           ) do
        {:ok, _receipt_envelope} -> {:ok, record}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  @doc """
  The delegated authority evidence this bridge records for an approved
  `record` (`ActuationIntent.authority`). Public so a court that re-verifies a
  maker-checker approval (`Xaas.Pack`) derives the identical map from the
  persisted record instead of trusting a caller-supplied copy.
  """
  @spec authority(struct()) :: map()
  def authority(record) do
    %{
      kind: "maker_checker_approval",
      approval_resource: inspect(record.__struct__),
      approval_id: to_string(record.id),
      approved_by: stringify(record.approved_by),
      org_id: stringify(record.org_id),
      requested_status: to_string(record.requested_status)
    }
  end

  @doc "The one idempotency key of an approval's consequence: one approval, at most one DO."
  @spec idempotency_key(struct()) :: String.t()
  def idempotency_key(record), do: "approval-provider-status-change:#{record.id}"

  defp stringify(nil), do: nil
  defp stringify(value) when is_binary(value), do: value
  defp stringify(value), do: to_string(value)
end
