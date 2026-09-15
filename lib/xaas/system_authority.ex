defmodule Xaas.SystemAuthority do
  @moduledoc """
  The real internal-system actor for XAAS-2601 (docs/jira/v26.9.15).

  Replaces the action-wide `bypass ... authorize_if(always())` carve-outs
  this repo's ERRC refactor introduced for internal-only mutations: those
  bypasses made "internal-only" an architectural comment, not an
  authorization fact -- ANY caller reaching the action through the normal
  Ash authorization path satisfied them, which is broader than the
  localized `authorize?: false` calls they replaced.

  This struct IS the system authority object: a real actor value that
  `Xaas.Checks.SystemActor` (an `Ash.Policy.SimpleCheck`) evaluates. An
  ordinary user/principal actor is simply not one of these, so the same
  policies that admit the Ultracode Reactor pipeline, the AshOban cron
  entry points, and the webhook dispatch path now REFUSE every other
  actor -- the review's exact falsifier.

  `service` records which internal service invoked the action (e.g.
  `:ultracode_reactor`, `:webhook_dispatcher`, `:oban_scheduler`) for
  audit/evidence; policies may narrow admission to specific services via
  `authorize_if({Xaas.Checks.SystemActor, service: :some_service})`, or
  admit any genuine system actor with
  `authorize_if({Xaas.Checks.SystemActor, []})`.
  """

  @enforce_keys [:service]
  defstruct [:service]

  @type t :: %__MODULE__{service: atom()}

  @doc """
  Builds the system authority actor for an internal `service`. Binary
  service names are atomized (they are always this repo's own compile-time
  vocabulary, never caller input).
  """
  @spec new(atom() | String.t()) :: t()
  def new(service) when is_atom(service), do: %__MODULE__{service: service}

  def new(service) when is_binary(service), do: %__MODULE__{service: String.to_atom(service)}

  @doc """
  True only for a real `Xaas.SystemAuthority` struct -- the single
  predicate every internal-mutation policy keys on. Fail-closed for every
  other term (nil actor, user maps, fabricated org actors, ...).
  """
  @spec system?(term()) :: boolean()
  def system?(%__MODULE__{}), do: true
  def system?(_other), do: false
end
