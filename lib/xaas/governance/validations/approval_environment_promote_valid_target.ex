defmodule Xaas.Governance.Validations.ApprovalEnvironmentPromoteValidTarget do
  @moduledoc """
  Real single-stage-forward-only rule, ported verbatim from
  platform-console's `validatePromotion`/`nextEnvironment`
  (`app/lib/environments.ts`): the only valid `to_environment` from a given
  `from_environment` is the exact next stage (dev -> staging -> prod).
  Skipping a stage (dev -> prod), reversing, promoting from the terminal
  `prod` stage, or a no-op (from == to) is rejected.
  """
  use Ash.Resource.Validation

  @next_environment %{dev: :staging, staging: :prod}

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    from = Ash.Changeset.get_attribute(changeset, :from_environment)
    to = Ash.Changeset.get_attribute(changeset, :to_environment)

    case Map.fetch(@next_environment, from) do
      :error ->
        {:error,
         field: :from_environment,
         message: "'#{from}' is already the terminal environment -- there is nothing to promote it to"}

      {:ok, expected} when to == expected ->
        :ok

      {:ok, expected} ->
        {:error,
         field: :to_environment,
         message: "invalid promotion from '#{from}' to '#{to}' -- the only valid target is '#{expected}'"}
    end
  end
end
