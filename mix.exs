# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---

defmodule Kanban.MixProject do
  use Mix.Project

  @version File.read!("VERSION") |> String.trim()

  def project do
    [
      app: :kanban,
      version: @version,
      elixir: "~> 1.20",
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

  def application do
    [
      mod: {Kanban.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # v26.8.21 keeps one Ash-native dependency graph. The exact resolved
  # versions remain receipt-bearing in mix.lock; constraints below describe
  # the supported compatibility envelope rather than duplicating lock state.
  defp deps do
    [
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      {:opentelemetry_ash, "~> 0.1"},
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
      {:ash_admin, "~> 1.3"},
      {:ash_graphql, "~> 1.0"},
      {:open_api_spex, "~> 3.0"},
      {:ash_json_api, "~> 1.0"},
      {:ash_typescript, "~> 0.17"},
      {:ash_authentication_phoenix, "~> 2.17"},
      {:bcrypt_elixir, "~> 3.0"},
      {:ash_authentication, "~> 4.0"},
      {:picosat_elixir, "~> 0.2"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:sourceror, "~> 1.8", only: [:dev, :test]},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.0", only: :dev},
      {:dns_cluster, "~> 0.1.3"},
      {:ecto_sql, "~> 3.6"},
      {:esbuild, "~> 0.5", runtime: Mix.env() == :dev},
      {:finch, "~> 0.13"},
      {:floki, ">= 0.30.0", only: :test},
      {:stream_data, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:heroicons, "~> 0.5"},
      {:jason, "~> 1.2"},
      {:phoenix, "~> 1.7.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_dashboard, "~> 0.9.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:postgrex, ">= 0.0.0"},
      {:swoosh, "~> 1.3"},
      {:tailwind, "~> 0.1.8", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:prom_ex, "~> 1.9.0"},
      {:ex_aws, "~> 2.1"},
      {:sweet_xml, "~> 0.6"},
      {:req, "~> 0.5.7"},
      {:stripity_stripe, "~> 2.17"}
    ]
  end

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
