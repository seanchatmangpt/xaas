if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Xaas.Install.AshAdmin do
    use Igniter.Mix.Task

    @shortdoc "Adds AshAdmin.Domain + admin do show? true end to an Ash.Domain module"
    @moduledoc """
    Automated Igniter installer task closing the exact gap
    `docs/claude/diataxis/how-to/fix-ash-admin-and-use-ggen-for-codegen.md` documents: every one
    of this repo's 6 domains needed `AshAdmin.Domain` added to `extensions:` *and* a real
    `admin do show? true end` block by hand -- `AshAdmin.Domain.show?/1` defaults to `false`, and
    adding just the extension without the block leaves the domain invisible to `/admin`, which
    previously masked a real upstream `ash_admin` bug (`KeyError: key :action_type not found` in
    `page_live.ex`'s `assign_action/3` fallback branch, only reachable when zero domains pass
    `show?: true`).

    Modeled directly on `~/ash_r2rml`'s `ash_r2rml.install.ex` installer: same
    `Spark.Igniter.add_extension/6` call shape (swapping `Ash.Resource`/`AshR2RML.Resource` for
    `Ash.Domain`/`AshAdmin.Domain`). The `admin do show? true end` block itself is set via
    `Spark.Igniter.set_option/5` -- a real, structured DSL-section-option setter Spark itself
    provides (`Spark.Igniter.set_option(igniter, module, [:admin, :show?], true)` creates the
    `admin do ... end` section if absent and sets `show?` inside it, both idempotently) -- rather
    than templating the block as raw source text via `Igniter.Code.Common.add_code/3`. An
    adversarial review flagged the raw-text approach as fragile against formatting/indentation
    drift that the zipper-based DSL setter is specifically built to avoid.

    ## Usage

        mix xaas.install.ash_admin --target MyApp.SomeDomain
    """

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :xaas,
        example: "mix xaas.install.ash_admin --target Xaas.SomeDomain",
        positional: [],
        schema: [target: :string],
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      case igniter.args.options[:target] do
        nil ->
          Igniter.add_notice(igniter, """
          xaas.install.ash_admin requires --target.

          Add `AshAdmin.Domain` to your Ash.Domain modules and a real `admin do show? true end`
          block, or re-run with `--target MyApp.SomeDomain` to patch a specific module
          automatically:

              use Ash.Domain,
                otp_app: :kanban,
                extensions: [AshAdmin.Domain]

              admin do
                show? true
              end
          """)

        target ->
          target_module = Igniter.Project.Module.parse(target)

          igniter
          |> Spark.Igniter.add_extension(target_module, Ash.Domain, :extensions, AshAdmin.Domain)
          |> Spark.Igniter.set_option(target_module, [:admin, :show?], true)
      end
    end
  end
else
  defmodule Mix.Tasks.Xaas.Install.AshAdmin do
    use Mix.Task

    @shortdoc "Adds AshAdmin.Domain to a domain (manual instructions -- Igniter unavailable)"

    @impl Mix.Task
    def run(_args) do
      Mix.shell().info("""
      xaas.install.ash_admin manual installation steps:

      1. Add `AshAdmin.Domain` to your Ash.Domain module's `extensions:`.
      2. Add a real `admin do show? true end` block to that module.
      3. Confirm the domain is registered in `config :kanban, ash_domains: [...]`.
      """)
    end
  end
end
