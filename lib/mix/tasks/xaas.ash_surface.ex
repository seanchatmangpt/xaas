defmodule Mix.Tasks.Xaas.AshSurface do
  @shortdoc "Run the ash_surface generation pipeline over the Xaas Ash resources"

  @moduledoc """
  Full real pipeline, no mocks:

    Ash.Info.Manifest.generate(otp_app: :xaas)
      -> AshSurface.from_manifest/2   (custom.ash_surface profile + verified contract + digest)
      -> AshSurface.Compiler.compile/2 (IR sections per action)
      -> projectors (JS .mjs client, LiveView structure map, ARIA)
      -> artifacts written under priv/ash_surface/

  Usage:

      mix xaas.ash_surface
      mix xaas.ash_surface --resource Xaas.Marketplace.Pack

  `--resource` filters the manifest entrypoints to a single resource before the
  surface contract is minted.

  ## Exit codes

    * 0 — artifacts generated and digest verified;
    * 1 — any pipeline stage refused (typed error printed, nothing written).

  """

  use Mix.Task

  alias Ash.Info.Manifest

  @requirements ["app.start"]

  @out_dir "priv/ash_surface"
  @js_prefix "xaas_ash_surface_client"

  @impl Mix.Task
  def run(args) do
    {opts, _argv} =
      OptionParser.parse!(args, strict: [resource: :string])

    with {:ok, manifest} <- generate_manifest(opts),
         {:ok, surface} <- AshSurface.from_manifest(manifest, profile: profile()),
         :ok <- AshSurface.verify_surface_digest(surface),
         {:ok, irs} <- AshSurface.Compiler.compile(surface.manifest),
         {:ok, _artifacts, js_meta} <-
           AshSurface.Projectors.JS.project_ir(
             irs,
             [prefix: @js_prefix, target_dir: @out_dir] ++ js_projector_opts(manifest, opts)
           ),
         {:ok, live_view, _} <- AshSurface.Projectors.LiveView.project_ir(irs, []),
         {:ok, aria, _} <- AshSurface.Projectors.ARIA.project_ir(irs) do
      File.mkdir_p!(@out_dir)

      write("surface_contract.json", Jason.encode!(surface.contract))
      write("live_view.json", Jason.encode!(live_view))
      write("aria.json", Jason.encode!(aria))

      {:ok, runtime} = AshSurface.runtime_source()
      File.write!(Path.join(@out_dir, "ash_surface_runtime.mjs"), runtime)

      Mix.shell().info("""
      ash_surface generation complete
        entrypoints:     #{length(surface.action_ids)}
        surface digest:  #{surface.digest}
        js artifact:     #{Path.join(@out_dir, "#{@js_prefix}.mjs")} (#{js_meta.action_count} actions, #{js_meta.namespace_count} namespaces)
        live view:       #{Path.join(@out_dir, "live_view.json")}
        aria:            #{Path.join(@out_dir, "aria.json")}
        contract:        #{Path.join(@out_dir, "surface_contract.json")}
        runtime:         #{Path.join(@out_dir, "ash_surface_runtime.mjs")}
      """)

      :ok
    else
      {:error, reason} ->
        Mix.shell().error("xaas.ash_surface refused: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  # Full-app runs prefix every namespace with "Xaas" so short names that
  # collide with JS built-ins ("Object") refuse no more, and derive explicit
  # bindings for resources whose short names collide with each other (e.g.
  # Xaas.Conference.Event vs Xaas.Ocel.Event, or the governance "Version"
  # resources) from the full module path — drift-free, no literal list.
  # Pack-scoped runs stay unprefixed to keep committed Pack artifacts stable.
  defp js_projector_opts(manifest, opts) do
    case Keyword.fetch(opts, :resource) do
      :error ->
        [namespace_prefix: "Xaas", namespace_names: namespace_names(manifest)]

      {:ok, _} ->
        []
    end
  end

  # For every resource whose short name is shared by 2+ manifest resources,
  # bind it to "Xaas" <> full module path sans "Elixir.Xaas." with dots
  # removed (e.g. "Xaas.Conference.Event" -> "XaasConferenceEvent").
  defp namespace_names(manifest) do
    fulls =
      manifest.entrypoints
      |> Enum.map(& &1.resource)
      |> Enum.uniq()

    counts = Enum.frequencies_by(fulls, &short_name/1)

    for full <- fulls,
        Map.get(counts, short_name(full), 0) > 1,
        into: %{} do
      {full |> to_string() |> String.replace_prefix("Elixir.", ""),
       "Xaas" <> sanitize_module(full)}
    end
  end

  defp short_name(mod) when is_atom(mod),
    do: mod |> to_string() |> String.split(".") |> List.last()

  defp sanitize_module(mod) when is_atom(mod) do
    mod
    |> to_string()
    |> String.replace_prefix("Elixir.Xaas.", "")
    |> String.replace(".", "")
  end

  defp generate_manifest(opts) do
    with {:ok, manifest} <- Manifest.generate(otp_app: :xaas) do
      case Keyword.fetch(opts, :resource) do
        :error ->
          {:ok, manifest}

        {:ok, resource} ->
          module = Module.concat([resource])

          entrypoints =
            Enum.filter(manifest.entrypoints, &(&1.resource == module))

          case entrypoints do
            [] -> {:error, {:no_entrypoints_for_resource, resource}}
            _ -> {:ok, %{manifest | entrypoints: entrypoints}}
          end
      end
    end
  end

  # custom.ash_surface profile: projection metadata only, keyed by action id.
  # Kept minimal and deterministic; per-action entries are additive.
  defp profile do
    %{
      "tier" => "xaas",
      "generator" => "mix xaas.ash_surface",
      "actions" => %{}
    }
  end

  defp write(name, content) do
    path = Path.join(@out_dir, name)
    File.write!(path, content)
    Mix.shell().info("wrote #{path}")
  end
end
