defmodule Xaas.Ultracode.Validations.AliveRequiresCourt do
  @moduledoc """
  The receipt-vocabulary law, enforced at the ONE action every standing
  receipt enters through (`Xaas.Ultracode.Receipt.:seal`): `outcome: :alive`
  is manufactured ONLY by a qualifying terminal court, never asserted.

  A qualifying terminal court is, in the sealed evidence:

    * `head_verified == true` -- git confirmed the worker's `final_head`
      against the real worktree (`Lease.close/4`'s head check), and
    * `fabric_verifier.status == "pass"` -- the FABRIC ran the Run's
      registered verifier suite against that exact head and it passed
      (`Xaas.Ultracode.Verifier`).

  Anything else claiming `:alive` is standing-vocabulary pollution and is
  REFUSED here with the typed reason below -- a tick/liveness record has
  no court, so the tick path (`Xaas.Ultracode.EpochReactor`) seals its
  lifecycle turns as `:heartbeat` (a typed non-standing class: consumers
  -- campaign standings, OCEL egress, run validation -- never count it as
  standing), and a lease close without a passing court downgrades to
  `:partial_alive` before it ever reaches this validation.

  This is the fail-closed backstop: the honest producers already compute
  the honest outcome themselves (`Lease.close/4`,
  `EpochReactor`), so this validation only ever fires when a FUTURE code
  path tries to manufacture `:alive` out of thin air.
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :outcome) do
      :alive ->
        evidence = Ash.Changeset.get_attribute(changeset, :evidence) || %{}

        if qualifying_court?(evidence) do
          :ok
        else
          {:error,
           field: :outcome,
           message:
             "REFUSED_ALIVE_WITHOUT_COURT: outcome :alive is manufactured only by a " <>
               "qualifying terminal court (evidence head_verified == true AND " <>
               "fabric_verifier.status == \"pass\"); a tick/liveness record seals " <>
               ":heartbeat and an unverified close downgrades to :partial_alive"}
        end

      _non_alive ->
        :ok
    end
  end

  defp qualifying_court?(evidence) when is_map(evidence) do
    evidence["head_verified"] == true and is_map(evidence["fabric_verifier"]) and
      evidence["fabric_verifier"]["status"] == "pass"
  end

  defp qualifying_court?(_not_a_map), do: false
end
