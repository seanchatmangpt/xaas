defmodule Mix.Tasks.Xaas.Ultracode.Stop do
  @shortdoc "Stops (abandons) a running ultracode wave campaign"

  @moduledoc """
  The operator cut for an ultracode wave campaign: transitions the campaign
  row `:running -> :abandoned` through the real `:transition_state` action
  (an admitted edge of `RunTransitionAllowed`). See
  `Xaas.Ultracode.Campaign.stop/1`.

      mix xaas.ultracode.stop
      mix xaas.ultracode.stop --run <campaign-run-id>

  With no `--run`, targets the most recent `:running` campaign. An
  in-flight wave finishes first (waves are serial and synchronous); the
  start loop observes the abandonment at its next poll and exits without
  launching further waves. To cut immediately mid-wave, also
  SIGINT/SIGTERM the `mix xaas.ultracode.start` process -- already-claimed
  worker leases simply expire and are reaped by the fabric.
  """

  use Mix.Task

  alias Xaas.Ultracode.Campaign

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} = OptionParser.parse(args, strict: [run: :string])
    Mix.Task.run("app.start")

    case Campaign.stop(opts[:run]) do
      {:ok, campaign} ->
        Mix.shell().info(
          "campaign #{campaign.id} -> :abandoned (#{campaign.cycle} wave(s) discharged)"
        )

      {:error, reason} ->
        Mix.raise("campaign stop failed: #{inspect(reason)}")
    end
  end
end
