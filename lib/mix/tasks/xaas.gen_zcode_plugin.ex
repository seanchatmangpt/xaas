defmodule Mix.Tasks.Xaas.GenZcodePlugin do
  @shortdoc "Renders the ZCode provider plugin from XaaS execution-fabric templates"

  @moduledoc """
  Renders the XaaS execution-fabric ZCode plugin projection.

  The plugin is a generated artifact, never a hand-maintained subsystem: this
  task is its only manufacturer. Every file under the output directory is a
  projection of `priv/templates/zcode_plugin/` plus the rendered binds
  (endpoint URL, token env var name, plugin name/version).

  The rendered plugin speaks to the XaaS lease kernel over the internal-token
  gated HTTP surface:

    * `.mcp.json` registers the `xaas-execution` MCP server (claim_next,
      heartbeat, admit_tool, record_provider_event, close_candidate, refuse).
    * `hooks/hooks.json` + `hooks/*.mjs` implement the provider lifecycle:
      PreToolUse is the admission court (transport failure denies, never
      allows), PostToolUse/Failure record observations, Stop attempts
      head-verified closure.
    * `commands/xaas.md` + `skills/xaas-worker/SKILL.md` +
      `agents/xaas-worker.md` give the provider agent its worker contract.

  ## Examples

      mix xaas.gen_zcode_plugin \\
        --endpoint http://localhost:4000 \\
        --output generated/xaas-zcode-plugin

  ## Options

    * `--endpoint` - (required) base URL of the XaaS web endpoint.
    * `--token-env` - env var holding the internal API bearer token
      (default `XAAS_INTERNAL_TOKEN`). The token itself never enters the
      rendered tree or version control.
    * `--output` - output directory (default `generated/xaas-zcode-plugin`).
  """

  use Mix.Task

  @template_dir "priv/templates/zcode_plugin"

  @impl Mix.Task
  def run(args) do
    {opts, _positional, _invalid} =
      OptionParser.parse(args, strict: [endpoint: :string, token_env: :string, output: :string])

    endpoint = Keyword.get(opts, :endpoint)
    token_env = Keyword.get(opts, :token_env, "XAAS_INTERNAL_TOKEN")
    output = Keyword.get(opts, :output, "generated/xaas-zcode-plugin")

    unless endpoint do
      Mix.raise("--endpoint is required (e.g. --endpoint http://localhost:4000)")
    end

    assigns = %{
      endpoint: String.trim_trailing(endpoint, "/"),
      token_env: token_env,
      plugin_name: "xaas-fabric",
      version: String.trim(File.read!("VERSION"))
    }

    files = template_files()

    Enum.each(files, fn relative ->
      source = Path.join(@template_dir, relative)
      target = Path.join(output, String.replace_suffix(relative, ".eex", ""))

      File.mkdir_p(Path.dirname(target))

      binding = [assigns: assigns]

      rendered = EEx.eval_file(source, binding)

      File.write!(target, rendered)
      Mix.shell().info("  rendered #{target}")
    end)

    Mix.shell().info("""
    Rendered #{length(files)} files to #{output}.

    Qualification steps (morning test):
      1. export #{token_env}=<internal api token>
      2. Point ZCode at the plugin (marketplace.json with a local/plugin path,
         or the app's plugin installer against this directory).
      3. In a leased worktree, run /xaas and confirm claim -> PreToolUse
         admission -> Stop closure through the XaaS log stream.
    """)
  end

  defp template_files do
    @template_dir
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.reject(&File.dir?/1)
    |> Enum.map(fn path -> path |> String.replace_prefix(@template_dir <> "/", "") end)
  end
end
