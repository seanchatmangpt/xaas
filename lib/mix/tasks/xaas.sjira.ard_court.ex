defmodule Mix.Tasks.Xaas.Sjira.ArdCourt do
  @shortdoc "Machine acceptance court for a Semantic Jira ARD (exit 0 = ACCEPTED)"

  @moduledoc """
  Judges an ARD file against the artifacts its machine manifest names.

      mix xaas.sjira.ard_court docs/sjira/v26.9.21/ash-atlassian-ard.md \\
        --receipt docs/sjira/v26.9.21/receipts/SJ-007-ard-court.json

  Exit codes: `0` ACCEPTED, `1` REFUSED (a check failed), `2` the court could not run.
  The checks and their semantics are documented on `Xaas.Sjira.ArdCourt`.

  Filesystem-only by law: it loads config (`loadconfig`) but never starts the application
  (no Repo, no Oban). It needs `:rdf`, `:rdf_xml`, `:toml` and `:jason` on the code path, which
  the project already compiles.
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    # Config WITHOUT app.start: the court reads files and parses RDF/TOML; it boots no Repo.
    Mix.Task.run("loadconfig")

    case Xaas.Sjira.ArdCourt.cli(args) do
      0 -> :ok
      code -> exit({:shutdown, code})
    end
  end
end
