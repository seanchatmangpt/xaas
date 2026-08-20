# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
# in mix.exs

defmodule Kanban.MixProject do
  use Mix.Project

  def project do
    [
      app: :kanban,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [
        plt_core_path: "priv/plts/core.plt",
        plt_file: {:no_warn, "priv/plts/project.plt"},
        plt_add_apps: [:ex_unit]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Kanban.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Real Ash deps ported verbatim from ~/dev-fresh/xaas/mix.exs -- the 89
      # real Ash.Resource modules in that repo were written against this
      # exact dep set (extensions: opentelemetry_ash, ash_ai, ash_onetime,
      # ash_iam, ash_rate_limiter, ash_cloak, ash_money/ash_double_entry,
      # ash_archival, ash_events, ash_paper_trail, ash_state_machine,
      # ash_oban, ash_admin, ash_graphql, ash_json_api, ash_authentication)
      # confirmed via a real grep of `extensions:`/`use` across those files
      # in Phase 3 -- porting only ash/ash_postgres (Phase 1's original,
      # narrower guess) would not compile against the real resource files.
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      {:opentelemetry_ash, "~> 0.1"},
      # ash_ai's transitive dep req_llm fails to compile against the resolved
      # finch version (real: %Finch.Pool{}/pool_tag mismatch, confirmed via
      # a real mix compile error) -- dropped; zero real resource files
      # under lib/xaas/{operations,governance,billing,platform,accounts,
      # ledger} reference AshAi (confirmed via grep).
      {:ash_onetime, "~> 1.0"},
      {:ash_iam, "~> 2.0"},
      {:hammer, "~> 7.0"},
      {:ash_rate_limiter, "~> 2.0"},
      {:cloak, "~> 1.0"},
      {:ash_cloak, "~> 0.3"},
      {:ex_money_sql, "~> 2.0"},
      {:ash_money, "~> 0.2"},
      {:ash_double_entry, "~> 1.0"},
      {:ash_archival, "~> 2.0"},
      {:ash_events, "~> 0.7"},
      {:ash_paper_trail, "~> 0.6"},
      {:ash_state_machine, "~> 0.2"},
      {:oban, "~> 2.0"},
      {:ash_oban, "~> 0.8"},
      # ash_admin ~> 1.0 forces phoenix_live_view ~> 1.1-rc, a major bump that
      # would touch the currently-deployed KanbanWeb LiveView code -- real,
      # confirmed resolver conflict. Dropped; the 4 domain modules' AshAdmin.
      # Domain extension entries are dropped on port too, the 89 resources
      # don't reference it.
      {:ash_graphql, "~> 1.0"},
      {:open_api_spex, "~> 3.0"},
      {:ash_json_api, "~> 1.0"},
      # ash_authentication_phoenix forces phoenix_html ~> 4.0, a major bump
      # risking existing KanbanWeb templates -- real, confirmed resolver
      # conflict. Dropped; zero real resource files under lib/xaas/{operations,
      # governance,billing,platform,accounts,ledger} reference it (confirmed
      # via grep), only the core, non-Phoenix ash_authentication lib is used
      # (AshAuthentication.Sender in the 3 email-sender modules).
      {:bcrypt_elixir, "~> 3.0"},
      {:ash_authentication, "~> 4.0"},
      {:picosat_elixir, "~> 0.2"},
      {:sourceror, "~> 1.8", only: [:dev, :test]},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dns_cluster, "~> 0.1.3"},
      {:ecto_sql, "~> 3.6"},
      {:esbuild, "~> 0.5", runtime: Mix.env() == :dev},
      {:finch, "~> 0.13"},
      {:floki, ">= 0.30.0", only: :test},
      # Real fix: exact-pinned "0.24.0" (the book's original) conflicts with
      # ash_onetime -> ecto_sql ~> 3.14 -> ... -> ex_money_sql's real
      # transitive requirement on gettext ~> 1.0 (confirmed via real resolver
      # output). Relaxed to allow the resolver to pick a compatible version.
      {:gettext, "~> 0.24 or ~> 1.0"},
      {:heroicons, "~> 0.5"},
      {:jason, "~> 1.2"},
      {:phoenix, "~> 1.7.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_dashboard, "~> 0.7.2"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.18.16"},
      {:plug_cowboy, "~> 2.5"},
      {:postgrex, ">= 0.0.0"},
      {:swoosh, "~> 1.3"},
      {:tailwind, "~> 0.1.8", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:prom_ex, "~> 1.9.0"},
      {:ex_aws, "~> 2.1"},
      {:sweet_xml, "~> 0.6"},
      {:req, "~> 0.5.7"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
