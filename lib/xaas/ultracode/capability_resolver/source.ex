defmodule Xaas.Ultracode.CapabilityResolver.Source do
  @moduledoc """
  The source behaviour of the Ultracode capability-resolution court: one
  enumeration of the capabilities a capability FLEET already holds.

  A source is a witness, not a planner: it answers "what capabilities do
  you hold?" for one sensed item, and the court
  (`Xaas.Ultracode.CapabilityResolver`) alone decides reuse/compose/
  extend/generate/frontier. NO LLM anywhere on this edge -- both sides of
  the behaviour are mechanical, so the court is an admission function
  whose verdicts replay byte-identically from the same inputs.

  ## Result contract

      @callback candidates(item, ctx) ::
                {:ok, [capability]} | {:error, term} | {:skipped, term}

    * `{:ok, capabilities}` -- the source ANSWERED; the capability list may
      be empty. An `:ok` with zero capabilities is evidence (the fleet
      holds nothing here) and is exactly what a `:frontier` verdict is
      built from.
    * `{:error, reason}` -- the source TRIED and failed (transport error,
      unparseable answer, admission refusal). The court fail-closes: any
      error anywhere forces `:unresolved`, never a frontier verdict on a
      closure the court could not fully see.
    * `{:skipped, reason}` -- the source is NOT CONFIGURED / not enabled
      (e.g. the SA2A fleet endpoint unset). Under the default full-closure
      mode this too forces `:unresolved`; an operator may turn
      full-closure off (`ctx[:capability_full_closure] == false`) to let
      the remaining `:ok` sources drive a verdict, at their own risk.

  ## Capability shape (admitted by `admit_candidates/2`)

  A capability is a plain map with at least:

    * `capability_id` -- a binary matching the canonical `sj:capabilityId`
      pattern, byte-identical to `SemanticWork.capability_id_pattern/0`
      (e.g. `"recipe:mix-format"`);
    * `satisfies` -- a non-empty list of requirement-id binaries the
      capability satisfies.

  The court re-admits every returned candidate through
  `admit_candidates/2` regardless of what the source claims: one invalid
  candidate fails the WHOLE source call (`{:error, {:invalid_candidate,
  _}}`) -- a malformed witness must never silently vanish, because the
  vanished candidate might have been the satisfier.
  """

  @type capability :: %{
          required(:capability_id) => String.t(),
          required(:satisfies) => [String.t()],
          optional(atom()) => term()
        }

  @type item :: map()

  @type result :: {:ok, [capability()]} | {:error, term()} | {:skipped, term()}

  @callback candidates(item(), ctx :: map() | keyword()) :: result()
end
