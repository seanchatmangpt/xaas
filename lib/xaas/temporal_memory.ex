defmodule Xaas.TemporalMemory do
  @moduledoc """
  Ash domain for bitemporal process memory
  (`docs/jira/v26.9.11/temporal-process-memory.md`).

  Scope implemented in this slice: the bitemporal event model
  (`Xaas.TemporalMemory.Observation`), retroactive-observation-safe
  admission (`:observe`), non-destructive correction/supersession
  (`:supersede`), a temporal query API that keeps valid-time and
  observation-time independent (`Xaas.TemporalMemory.Query.as_of/2`), and
  a deterministic temporal replay verifier
  (`Xaas.TemporalMemory.Replay.verify/2`) that checks the ticket's stated
  invariant `Replay(d_t, O_<=t) = d_t`.

  Explicitly UNSUPPORTED in this slice (see `Xaas.TemporalMemory.Replay`
  and `Xaas.TemporalMemory.Query` moduledocs for the typed refusal and
  reasoning): concurrent/conflicting correction resolution beyond a single
  linear supersession chain, and a native Postgres range-type (`tstzrange`)
  storage representation -- this slice uses two plain
  `utc_datetime_usec` columns (`valid_from`/`valid_to`) instead, which is a
  real but simplified interval representation, not a fabricated one.
  """

  use Ash.Domain,
    otp_app: :xaas

  resources do
    resource(Xaas.TemporalMemory.Observation)
  end
end
