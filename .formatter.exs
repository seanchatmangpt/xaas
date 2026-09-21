# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
[
  import_deps: [:ash_onetime, :ecto, :ecto_sql, :phoenix],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs:
    Enum.flat_map(
      ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"],
      &Path.wildcard/1
    ) --
      # lib/xaas/generated/ is a projection rendered by the ggen-marketplace pack renderer
      # ("GENERATED ... Do not hand-edit"). Formatting it in place would break byte-identity
      # with the generator's output, so the next regeneration would re-introduce the
      # --check-formatted failure. The formatting fix belongs in the pack template, not here.
      Path.wildcard("lib/xaas/generated/**/*.{ex,exs}")
]
