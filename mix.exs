defmodule ExNounVerbCli.MixProject do
  use Mix.Project

  @version "26.9.16"
  @source_url "https://github.com/seanchatmangpt/ex_noun_verb_cli"

  def project do
    [
      app: :ex_noun_verb_cli,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      package: package(),
      description: description(),
      escript: escript(),
      docs: [
        main: "readme",
        extras:
          ["README.md", "CHANGELOG.md", "docs/index.md"] ++
            Path.wildcard("docs/tutorials/*.md") ++
            Path.wildcard("docs/how-to/*.md") ++
            Path.wildcard("docs/reference/*.md") ++
            Path.wildcard("docs/explanation/*.md"),
        source_url: @source_url
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # `examples/calc` is included in every env's compile path (not just
  # :test) because it backs a real `mix escript.build` proof-of-concept --
  # the toy `calc` registry/handlers must be part of the compiled escript
  # binary, not just available under `MIX_ENV=test`.
  defp elixirc_paths(:test), do: ["lib", "examples/calc", "test/support"]
  defp elixirc_paths(_), do: ["lib", "examples/calc"]

  defp escript do
    [main_module: ExNounVerbCli.Escript, app: nil]
  end

  defp description do
    "A generator-first, dispatch-agnostic noun-verb CLI core for Elixir: " <>
      "declarative arg schema, JSON-by-default output, command chaining, " <>
      "and a decoupled capability-standing/RDF-graph layer. Ports " <>
      "clap-noun-verb's ergonomics without the linkme/proc-macro machinery."
  end

  defp package do
    [
      licenses: ["MIT"],
      description: description(),
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md .formatter.exs)
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      # `optional: true`, NOT `only: [:dev, :test]`: `lib/mix/tasks/
      # ex_noun_verb_cli.ex` (`Mix.Tasks.ExNounVerbCli`) `use`s
      # `Igniter.Mix.Task` at compile time and is part of this app's
      # unconditional `elixirc_paths` (not test-only), i.e. real production
      # code, not test tooling -- the comment this replaced mischaracterized
      # it. Marking it `only: [:dev, :test]` here is exactly the failure
      # class ggen_igniter's own mix.exs already documents for its own
      # `:igniter`/`:tesla`/`:gno` deps: a dependency's own `only:`
      # restriction is dropped entirely for ANY consuming application
      # regardless of that consumer's own Mix.env, so a fresh external
      # `{:ex_noun_verb_cli, path: ...}` consumer fails
      # `mix compile --warnings-as-errors` with "module Igniter.Mix.Task is
      # not loaded and could not be found" at this file's `use
      # Igniter.Mix.Task` line -- confirmed via a real minimal path-dependency
      # repro (ggen-marketplace's noun-verb-cli-pack consumer,
      # 2026-09-11) even after manually pre-building igniter's entire
      # dependency chain first. `optional: true` alone is the correct fix
      # (mirrors ggen_igniter's own `:tesla`/`:gno` handling): Hex/Mix still
      # resolves and compiles `:igniter` for *this* project's own dev/test,
      # while a consuming app that never uses the Igniter adapter and never
      # depends on `:igniter` itself still compiles clean -- but only because
      # `lib/mix/tasks/ex_noun_verb_cli.ex` defines the adapter module behind
      # `if Code.ensure_loaded?(Igniter.Mix.Task)` (the compile-time `use`
      # cannot fire without Igniter on the load path; `optional: true` alone
      # does NOT achieve this -- an igniter-less consumer's `mix compile`
      # really failed on that file before the guard, see
      # test/mix/tasks/ex_noun_verb_cli_igniter_optional_test.exs), while a
      # consumer that DOES want the Igniter adapter (as ggen-marketplace's
      # real `noun-verb-cli-pack` milestone does) gets a real, compilable
      # dependency instead of an unconditionally-broken one.
      {:igniter, "~> 0.5", optional: true},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
