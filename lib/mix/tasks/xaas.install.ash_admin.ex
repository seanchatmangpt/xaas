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
    `Ash.Domain`/`AshAdmin.Domain`), same idempotent `Igniter.Code.Pattern.move_to/2` check before
    inserting the starter DSL block.

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
          |> add_starter_admin_block(target_module)
      end
    end

    # Idempotent: uses Igniter.Code.Pattern.move_to/2 (ExAST) to search the module body for an
    # existing `admin do ... end` block first, so re-running against an already-patched domain
    # does not insert a second, duplicate block -- same pattern as ash_r2rml.install.ex's
    # add_starter_dsl_block/2.
    defp add_starter_admin_block(igniter, target_module) do
      Igniter.Project.Module.find_and_update_module!(igniter, target_module, fn zipper ->
        if match?({:ok, _}, Igniter.Code.Pattern.move_to(zipper, "admin do ... end")) do
          {:ok, zipper}
        else
          case Igniter.Code.Module.move_to_use(zipper, Ash.Domain) do
            {:ok, use_zipper} ->
              {:ok,
               Igniter.Code.Common.add_code(
                 use_zipper,
                 """
                 admin do
                   show? true
                 end
                 """,
                 placement: :after
               )}

            :error ->
              {:ok, zipper}
          end
        end
      end)
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
