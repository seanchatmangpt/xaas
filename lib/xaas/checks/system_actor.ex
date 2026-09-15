defmodule Xaas.Checks.SystemActor do
  @moduledoc """
  Real `Ash.Policy.SimpleCheck` backing XAAS-2601 (docs/jira/v26.9.15):
  admits only a genuine `Xaas.SystemAuthority` actor -- the real
  system/internal authority object -- optionally narrowed to one `service`
  via `authorize_if({Xaas.Checks.SystemActor, service: :ultracode_reactor})`.

  This is the predicate that replaces the action-wide
  `bypass action(...) do authorize_if(always()) end` shape on every
  internal-only mutation (Ultracode Run/Epoch/Receipt, WebhookDelivery's
  `:deliver`/`:retry_failed_deliveries`, HoldRequest's `:expire_stale`):
  an ordinary non-system actor that reaches one of those actions through
  the normal authorization path now fails this check and falls to the
  resource's deny floor, exactly the review's falsifier. Not a mock or
  interaction double -- a real `Ash.Policy.Check` implementation of
  `match?/3` against the real actor value, same shape as
  `Xaas.Platform.Checks.ActorOrgMatches` and its sibling per-domain
  checks.
  """

  use Ash.Policy.SimpleCheck

  @impl true
  def describe(opts) do
    case opts[:service] do
      nil -> "actor is a genuine Xaas.SystemAuthority (any internal service)"
      service -> "actor is a Xaas.SystemAuthority for service #{inspect(service)}"
    end
  end

  @impl true
  def match?(actor, _context, opts) do
    Xaas.SystemAuthority.system?(actor) and service_admitted?(actor.service, opts[:service])
  end

  defp service_admitted?(_actual, nil), do: true
  defp service_admitted?(actual, required) when is_atom(actual), do: actual == required
  defp service_admitted?(_actual, _required), do: false
end
