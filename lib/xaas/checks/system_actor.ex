defmodule Xaas.Checks.SystemActor do
  @moduledoc """
  Fail-closed `Ash.Policy.SimpleCheck` for internal-system authority.

  When a policy supplies `service: ...`, that service is required directly.
  When the policy uses the repository's generic `{Xaas.Checks.SystemActor, []}`
  form, this check derives the required service from the exact resource/action
  subject. Unknown subjects have no ambient authority and are refused.

  This turns `Xaas.SystemAuthority.service` from audit metadata into a
  load-bearing capability boundary without duplicating the matrix across every
  resource policy.
  """

  use Ash.Policy.SimpleCheck

  @action_services %{
    {Xaas.Ultracode.Run, :tick} => :oban_scheduler,
    {Xaas.Ultracode.Run, :advance_cycle} => :ultracode_reactor,
    {Xaas.Ultracode.Run, :transition_state} => :ultracode_reactor,
    {Xaas.Ultracode.Epoch, :create} => :ultracode_reactor,
    {Xaas.Ultracode.Epoch, :start} => :ultracode_reactor,
    {Xaas.Ultracode.Epoch, :complete} => :ultracode_reactor,
    {Xaas.Ultracode.Epoch, :mark_missed} => :ultracode_reactor,
    {Xaas.Ultracode.Epoch, :mark_failed} => :ultracode_reactor,
    {Xaas.Ultracode.Receipt, :seal} => :ultracode_reactor,
    {Xaas.Platform.WebhookDelivery, :retry_failed_deliveries} => :oban_scheduler,
    {Xaas.Platform.WebhookDelivery, :deliver} => :webhook_dispatcher,
    {Xaas.Library.HoldRequest, :expire_stale} => :oban_scheduler,
    {Xaas.Library.HoldRequest, :expire} => :oban_scheduler
  }

  @impl true
  def describe(opts) do
    case opts[:service] do
      nil -> "actor carries the service capability required by the exact protected action"
      service -> "actor is a Xaas.SystemAuthority for service #{inspect(service)}"
    end
  end

  @impl true
  def match?(actor, %{subject: subject}, opts) do
    with true <- Xaas.SystemAuthority.system?(actor),
         {:ok, required_service} <- required_service(subject, opts) do
      actor.service == required_service
    else
      _ -> false
    end
  end

  def match?(_actor, _context, _opts), do: false

  defp required_service(_subject, opts) do
    case Keyword.fetch(opts, :service) do
      {:ok, service} when service in Xaas.SystemAuthority.services() -> {:ok, service}
      {:ok, _unknown} -> :error
      :error -> :derive_from_subject
    end
  end

  defp required_service(subject, opts) when opts == [] do
    subject
    |> subject_key()
    |> then(&Map.fetch(@action_services, &1))
  end

  defp required_service(subject, opts) do
    case Keyword.fetch(opts, :service) do
      {:ok, service} when service in Xaas.SystemAuthority.services() -> {:ok, service}
      {:ok, _unknown} -> :error
      :error -> subject |> subject_key() |> then(&Map.fetch(@action_services, &1))
    end
  end

  defp subject_key(%Ash.Changeset{resource: resource, action: %{name: action}}),
    do: {resource, action}

  defp subject_key(%Ash.ActionInput{resource: resource, action: %{name: action}}),
    do: {resource, action}

  defp subject_key(%Ash.Query{resource: resource, action: %{name: action}}),
    do: {resource, action}

  defp subject_key(_subject), do: nil
end
