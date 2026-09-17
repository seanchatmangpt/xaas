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
      There are no ZCode/Claude-Code-style PreToolUse/PostToolUse/Stop hooks
      in this plugin — admission and observation are explicit MCP tool calls
      the worker makes itself, not automatic host-level interception. A
      transport failure on any of those calls must be treated by the worker
      as a denial (see the doctrine below), never as an implicit allow.
    * `scripts/xaas-lease.mjs` persists the current claim_next result to a
      local state file keyed by cwd, so the worker can recover its lease
      token across tool calls within the same worktree.
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
      token_user_config_key: String.downcase(token_env),
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
    Rendered #{length(files)} to #{output}.

    Qualification steps (morning test):
      1. Register/update the marketplace pointing at generated/ (directory source),
         then install and configure the MCP token as a persistent plugin option:
           zcode plugins install xaas-fabric@<marketplace> --scope user --yes
           zcode plugins configure xaas-fabric@<marketplace> \\
             --options-file (with "#{String.downcase(token_env)}": <internal api token>)
      2. The worker process still reads #{token_env} from its own session
         environment for scripts/xaas-lease.mjs: export #{token_env}=<internal
         api token> before launching zcode.
      3. In a leased worktree, run /xaas and confirm the full MCP loop through
         the XaaS log stream: claim_next -> explicit admit_tool calls ->
         record_provider_event -> close_candidate/refuse. There is no
         PreToolUse/Stop hook in this plugin; every admission/observation step
         is a tool call the worker makes on purpose, not an automatic gate.
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
