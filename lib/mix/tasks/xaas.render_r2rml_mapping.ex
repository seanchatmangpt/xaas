defmodule Mix.Tasks.Xaas.RenderR2rmlMapping do
  @shortdoc "Renders the real ash_r2rml R2RML mapping for every Xaas.Resource to priv/ontop/"
  @moduledoc """
  Runs `Xaas.Semantics.OntopMapping.write!/0`: builds the real `AshR2RML.Mapping.Bundle`
  from every admitted `Xaas.Resource`'s `Xaas.Semantics.Registry.r2rml_mapping/1` and
  renders it via the published `AshR2RML.R2RML.render/1` to
  `priv/ontop/xaas-mapping.generated.ttl`.

  This is a generated artifact -- never hand-edit it. The Ontop container's real,
  currently-served mapping (`priv/ontop/xaas-mapping.ttl`) is not overwritten by this
  task; cutover to the generated file is a separate, deliberate step gated by
  `test/xaas/semantics/ontop_mapping_test.exs`.

  Usage:

      mix xaas.render_r2rml_mapping

  Fails closed (non-zero exit) if any resource cannot be mapped.
  """
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case Xaas.Semantics.OntopMapping.write!() do
      {:ok, path, :unchanged} ->
        Mix.shell().info("R2RML mapping at #{path} already byte-identical (no write)")

      {:ok, path, outcome} ->
        Mix.shell().info("Wrote real R2RML mapping to #{path} (#{outcome})")

      {:error, {:unmapped_resources, failures}} ->
        Mix.shell().error("Refused to write an incomplete R2RML mapping. Unmapped resources:")

        Enum.each(failures, fn {resource, reason} ->
          Mix.shell().error("  #{inspect(resource)}: #{inspect(reason)}")
        end)

        Mix.raise("mix xaas.render_r2rml_mapping failed: #{length(failures)} resource(s) unmapped")

      {:error, reason} ->
        Mix.raise("mix xaas.render_r2rml_mapping failed: #{inspect(reason)}")
    end
  end
end
