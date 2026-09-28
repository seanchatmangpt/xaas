defmodule Xaas.AshTypescriptManifest do
  @moduledoc """
  The AshTypescript manifest module mandated by ash_typescript 0.18
  (`AshTypescript.manifest_module/0` refuses to run without it). This is the
  version-drift fix for the previously-working 0.17 `output_file` config
  shape; without it `mix ash.codegen` crashes in the ash_typescript leg
  before the ash_postgres leg writes snapshots/migrations.
  """

  use AshTypescript.Manifest, otp_app: :xaas
end
