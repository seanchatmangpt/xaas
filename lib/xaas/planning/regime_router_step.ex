defmodule Xaas.Planning.RegimeRouterStep do
  @moduledoc """
  Wires `Xaas.Planning.RegimeRouter.dispatch/2` into the existing Reactor
  boundary this repo uses for admitted control-plane work
  (`docs/jira/v26.9.11/planning-regime-router.md` -- "wired into the
  existing Ash/Reactor boundary").

  Expects `arguments` with `:features` (a
  `Xaas.Planning.ProblemFeatures.t()`, or a map/keyword the router will
  admit via `Xaas.Planning.ProblemFeatures.new/1`) and `:problem` (the raw
  term handed to whichever adapter, if any, is dispatched to).

  This step performs no planning itself and never falls back to a default
  planner: an unsupported formalism surfaces as a real `{:error, ...}` step
  result (which a Reactor caller can choose to halt on or handle), not a
  silently-succeeded no-op.
  """

  use Reactor.Step

  alias Xaas.Planning.{ProblemFeatures, RegimeRouter}

  @impl true
  def run(%{features: %ProblemFeatures{} = features, problem: problem}, _context, _options) do
    RegimeRouter.dispatch(features, problem)
  end

  def run(%{features: features, problem: problem}, context, options) do
    case ProblemFeatures.new(features) do
      {:ok, admitted} -> run(%{features: admitted, problem: problem}, context, options)
      {:error, _reason} = error -> error
    end
  end
end
