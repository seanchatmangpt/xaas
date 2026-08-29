defmodule Xaas.Marketplace.Validations.ProviderStatusTransition do
  @moduledoc """
  Enforces `Xaas.Marketplace.Provider`'s real, declared `AshStateMachine` transition
  graph against `:actuate_status`'s freely-accepted `:status` attribute.

  `AshStateMachine` ships a `transition_state/1` built-in change, but it takes a
  compile-time-fixed target state -- it cannot validate an arbitrary runtime value
  the way `:actuate_status` accepts one (`accept [:status]`, gated by
  `Xaas.Actuation.Validations.ReactorContext` for authority, not structural validity).
  This validation closes that gap: it reads the real transition graph declared in
  `Xaas.Marketplace.Provider`'s `state_machine do transitions do ... end end` block via
  `AshStateMachine.Info.state_machine_transitions/2` (the same introspection
  `AshStateMachine`'s own built-in change uses internally) and refuses any status
  change the declared graph doesn't admit, rather than duplicating the graph by hand.
  """

  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    current = changeset.data.status

    case Ash.Changeset.fetch_change(changeset, :status) do
      :error ->
        :ok

      {:ok, ^current} ->
        :ok

      {:ok, target} ->
        transitions =
          AshStateMachine.Info.state_machine_transitions(changeset.resource, changeset.action.name)

        if Enum.any?(transitions, &transition_allows?(&1, current, target)) do
          :ok
        else
          {:error,
           message:
             "invalid provider status transition #{inspect(current)} -> #{inspect(target)}: not declared in the state_machine transition graph"}
        end
    end
  end

  defp transition_allows?(%{from: from, to: to}, current, target) do
    matches?(from, current) and matches?(to, target)
  end

  defp matches?(:*, _value), do: true
  defp matches?(values, value) when is_list(values), do: value in values
  defp matches?(value, value), do: true
  defp matches?(_, _), do: false
end
