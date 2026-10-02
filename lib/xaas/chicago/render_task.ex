defmodule Mix.Tasks.Xaas.Chicago.Render do
  @moduledoc """
  Render the Chicago projections into `priv/chicago/` (resolution R4).

  Shells to the owning pack render (`ggen sync` over
  `../ggen-marketplace/packs/chicago-xaas-surface-pack`), renders TWICE and
  copies the four artifacts (`chicago.{machine,verification,executive,replay}.json`)
  into `priv/chicago/` ONLY when the two renders are byte-identical (R5
  byte-identity court, consumer side). Prints the sha256 of every copied
  artifact and re-validates them through `Xaas.Chicago` before declaring ok.

  Exits nonzero with a typed message when the renderer is absent, the render
  fails, the double render is not byte-stable, or the copied projection fails
  consumer validation.

      mix xaas.chicago.render        # aliased as `mix chicago.render` (R7)
  """

  use Mix.Task

  alias Xaas.Chicago
  alias Xaas.Chicago.Subject

  @shortdoc "Render Chicago projections into priv/chicago (double-render gated)"

  @artifacts ~w(chicago.machine.json chicago.verification.json chicago.executive.json chicago.replay.json)
  @pack_relative "../ggen-marketplace/packs/chicago-xaas-surface-pack"

  @impl Mix.Task
  def run(_args) do
    case render() do
      {:ok, rendered} ->
        Enum.each(rendered, fn {name, digest} ->
          Mix.shell().info("#{name} sha256=#{digest}")
        end)

        Mix.shell().info("subject=#{Subject.literal()} copied=#{length(rendered)}")

      {:refused, {reason, details}} ->
        Mix.raise("REFUSED_CHICAGO_RENDER #{inspect(reason)} #{inspect(details)}")
    end
  end

  @doc """
  The render pipeline, injectable for tests.

  * `pack_dir` — the marketplace pack directory (must contain `ggen.yaml`)
  * `:render_fn` — `fn pack_dir, out_dir -> :ok | {:error, binary}` running the
    real renderer into `out_dir` (default: `ggen sync` + copy from pack
    `generated/`)
  * `:dest_dir` — target directory (default `priv/chicago`)

  Returns `{:ok, [{filename, sha256}]}` or `{:refused, {atom, details}}`.
  """
  @spec render(Path.t() | nil, keyword) ::
          {:ok, [{String.t(), String.t()}]} | {:refused, {atom, term}}
  def render(pack_dir \\ default_pack_dir(), opts \\ []) do
    render_fn = Keyword.get(opts, :render_fn, &default_render_fn/2)
    dest_dir = Keyword.get(opts, :dest_dir, default_dest_dir())
    injected = Keyword.has_key?(opts, :render_fn)

    with :ok <- renderer_present?(pack_dir, injected),
         {:ok, first} <- render_once(render_fn, pack_dir),
         result <- render_twice_stable(render_fn, pack_dir, first) do
      case result do
        {:ok, stable_dir} ->
          copy_and_validate(stable_dir, dest_dir)

        {:refused, _} = refusal ->
          cleanup(first)
          refusal
      end
    end
  end

  @doc "Default marketplace pack directory relative to the current project."
  @spec default_pack_dir :: String.t()
  def default_pack_dir, do: Path.expand(@pack_relative, File.cwd!())

  defp default_dest_dir, do: Path.expand("priv/chicago", File.cwd!())

  defp renderer_present?(pack_dir, injected) do
    cond do
      not File.dir?(pack_dir) ->
        {:refused, {:chicago_renderer_absent, pack_dir}}

      not File.exists?(Path.join(pack_dir, "ggen.toml")) ->
        {:refused, {:chicago_renderer_absent, {:no_manifest, pack_dir}}}

      not injected and System.find_executable("ggen") == nil ->
        {:refused, {:chicago_renderer_absent, :ggen_not_on_path}}

      true ->
        :ok
    end
  end

  defp render_once(render_fn, pack_dir) do
    out_dir =
      Path.join(System.tmp_dir!(), "chicago-render-#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(out_dir)

    case render_fn.(pack_dir, out_dir) do
      :ok ->
        with :ok <- artifacts_present?(out_dir) do
          {:ok, out_dir}
        end

      {:error, reason} ->
        cleanup(out_dir)
        {:refused, {:chicago_render_failed, reason}}
    end
  end

  defp artifacts_present?(out_dir) do
    missing = Enum.filter(@artifacts, fn name -> not File.exists?(Path.join(out_dir, name)) end)

    if missing == [] do
      :ok
    else
      {:refused, {:chicago_render_failed, {:missing_artifacts, missing}}}
    end
  end

  defp render_twice_stable(render_fn, pack_dir, first) do
    case render_once(render_fn, pack_dir) do
      {:ok, second} ->
        differing =
          Enum.filter(@artifacts, fn name ->
            File.read!(Path.join(first, name)) != File.read!(Path.join(second, name))
          end)

        cleanup(second)

        if differing == [] do
          {:ok, first}
        else
          {:refused, {:chicago_render_unstable, differing}}
        end

      {:refused, _} = refusal ->
        refusal
    end
  end

  defp copy_and_validate(out_dir, dest_dir) do
    File.mkdir_p!(dest_dir)

    copied =
      Enum.map(@artifacts, fn name ->
        source = Path.join(out_dir, name)
        target = Path.join(dest_dir, name)
        File.copy!(source, target)
        {name, digest_of(source)}
      end)

    cleanup(out_dir)

    # invalidate any stale memoized projections for the live paths
    Chicago.reload()

    case Xaas.Chicago.Projection.load(:machine, Path.join(dest_dir, "chicago.machine.json")) do
      {:ok, _machine} ->
        {:ok, copied}

      {:refused, {:chicago_projection_invalid, {path, reason}}} ->
        {:refused, {:chicago_render_invalid_projection, {path, reason}}}

      {:refused, other} ->
        {:refused, {:chicago_render_invalid_projection, other}}
    end
  end

  defp cleanup(dir), do: File.rm_rf(dir)

  defp digest_of(path), do: :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)

  # Default renderer: ggen sync over the pack manifest, then lift the pack's
  # generated chicago.*.json (R1: pack self-test renders to generated/) into
  # the given out_dir. ggen reads ggen.toml from its cwd (no manifest arg);
  # the existence check above guards the pack manifest.
  defp default_render_fn(pack_dir, out_dir) do
    case System.cmd("ggen", ["sync", "run"], cd: pack_dir, stderr_to_stdout: true) do
      {_output, 0} ->
        generated = Path.join(pack_dir, "generated")

        Enum.reduce_while(@artifacts, :ok, fn name, :ok ->
          source = Path.join(generated, name)

          if File.exists?(source) do
            File.copy!(source, Path.join(out_dir, name))
            {:cont, :ok}
          else
            {:halt, {:error, {:missing_artifacts, name}}}
          end
        end)

      {output, code} ->
        {:error, {:ggen_exit, code, output}}
    end
  end
end
