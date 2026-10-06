defmodule Xaas.AshTypescriptManifest do
  @moduledoc """
  The AshTypescript manifest module mandated by ash_typescript 0.18
  (`AshTypescript.manifest_module/0` refuses to run without it). This is the
  version-drift fix for the previously-working 0.17 `output_file` config
  shape; without it `mix ash.codegen` crashes in the ash_typescript leg
  before the ash_postgres leg writes snapshots/migrations.

  ## Fresh-build-root domain resolution (EA45)

  `AshTypescript.Manifest` injects `Domain.module_info(:md5)` compile-time
  dependency calls for every entry in `config :xaas, :ash_domains` and
  evaluates them via `Code.eval_quoted` while this module's body expands.
  On a fresh build root those domain beams do not exist yet, so the eval
  raises `UndefinedFunctionError` and `mix compile` dies. To stay robust we
  resolve each configured domain with `Code.ensure_compiled/1` before the
  manifest DSL expands: present domains are kept (their injected md5 calls
  are byte-identical to the unfiltered path), missing domains are excluded
  from the manifest with a compile warning instead of crashing the build.
  A skipped domain is self-healing: the source file is re-touched so the
  next `mix compile` re-expands this manifest once the domain beam exists.
  """

  @manifest_env_key :ash_domains
  @manifest_otp_app :xaas

  @original_ash_domains Application.get_env(@manifest_otp_app, @manifest_env_key, [])

  {resolved_ash_domains, skipped_ash_domains} =
    Enum.reduce(@original_ash_domains, {[], []}, fn
      domain, {resolved, skipped} ->
        case Code.ensure_compiled(domain) do
          {:module, _} ->
            {[domain | resolved], skipped}

          {:error, _reason} ->
            IO.warn("""
            Xaas.AshTypescriptManifest: domain #{inspect(domain)} is listed in \
            config :xaas, :ash_domains but is not compiled yet; excluding it from \
            the ash_typescript manifest for this build. It will be picked up on \
            the next `mix compile` once its beam exists.\
            """)

            {resolved, [domain | skipped]}
        end
    end)

  resolved_ash_domains = Enum.reverse(resolved_ash_domains)
  skipped_ash_domains = Enum.reverse(skipped_ash_domains)

  # Scope the filtered domain list so the manifest DSL's compile-time domain
  # walk (and the injected md5 dependency calls) only sees loadable modules.
  # Restored in __after_compile__/2, which runs after the Spark DSL's
  # before_compile transformers have read the filtered list.
  Application.put_env(@manifest_otp_app, @manifest_env_key, resolved_ash_domains)

  use AshTypescript.Manifest, otp_app: :xaas

  if skipped_ash_domains != [] do
    # Self-heal: the fresh build excludes missing domains to survive; touching
    # this source makes the next `mix compile` re-expand the manifest now that
    # the skipped domains' beams were produced by that same build.
    File.touch(__ENV__.file)
  end

  @doc false
  def __after_compile__(_env, _bytecode) do
    Application.put_env(
      @manifest_otp_app,
      @manifest_env_key,
      @original_ash_domains
    )
  end
end
