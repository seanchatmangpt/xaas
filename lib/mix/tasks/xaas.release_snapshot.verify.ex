defmodule Mix.Tasks.Xaas.ReleaseSnapshot.Verify do
  @moduledoc """
  Verify a frozen XaaS release snapshot JSON artifact.

      mix xaas.release_snapshot.verify path/to/release-snapshot.json

  Exit success proves only deterministic structural/replay admission of the
  artifact. It does not deploy or grant authority.
  """
  use Mix.Task

  @shortdoc "Verify one frozen release snapshot artifact"

  alias Xaas.Deployment.ReleaseSnapshot
  alias Xaas.Deployment.ReleaseSnapshot.Codec

  @impl Mix.Task
  def run([path]) do
    with {:ok, body} <- File.read(path),
         {:ok, snapshot} <- Codec.decode(body),
         :ok <- ReleaseSnapshot.verify(snapshot) do
      Mix.shell().info(
        Jason.encode!(%{
          schema: "xaas.release-snapshot-verdict/v1",
          standing: "ALIVE",
          authority: "none",
          closure_digest: snapshot.closure_digest,
          snapshot_digest: snapshot.snapshot_digest,
          member_count: map_size(snapshot.members)
        })
      )
    else
      {:error, reason} ->
        Mix.raise("REFUSED:RELEASE_SNAPSHOT:" <> inspect(reason))
    end
  end

  def run(_args) do
    Mix.raise("usage: mix xaas.release_snapshot.verify <snapshot.json>")
  end
end
