# How-to: run as an `Igniter.Mix.Task` (v26.9.15)

You want `mix my_task <noun> <verb> [opts]` inside an Igniter pipeline
instead of a standalone binary.

## 1. The consuming app must depend on `:igniter`

The adapter (`Mix.Tasks.ExNounVerbCli`) `use`s `Igniter.Mix.Task` at
compile time. `ex_noun_verb_cli` declares `:igniter` as an
`optional: true` dependency, and since v26.9.15 the adapter module is
only defined when Igniter is actually loadable — so apps that never
depend on `:igniter` still compile the package cleanly. Apps that DO want
this adapter must declare the dependency themselves:

```elixir
# consuming app's mix.exs
defp deps do
  [
    {:ex_noun_verb_cli, "~> 26.9"},
    {:igniter, "~> 0.5"}
  ]
end
```

## 2. Point config at your registry

```elixir
config :ex_noun_verb_cli, registry: MyCli.Registry
```

## 3. Invoke or compose

```console
$ mix ex_noun_verb_cli math add --x 2 --y 3
```

The task composes rather than prints-and-exits: the JSON envelope is
folded into the `Igniter.t()` being built via `Igniter.add_notice/2`, so
it shows up alongside any other notices a composed pipeline accumulates.

From code, compose it like any Igniter task:

```elixir
igniter
|> Igniter.compose_task(Mix.Tasks.ExNounVerbCli, ["math", "add", "--x", "2", "--y", "3"])
```

## Igniter's own global flags are stripped for you

Igniter's standing flags (`--dry-run`, `--yes`, `--yes-to-deps`, …) never
leak into your verb's schema as unrecognized options — the adapter rejects
them from the dispatch argv using real `OptionParser` semantics against
`Igniter.Mix.Task.Info.global_options/0` (value-taking globals like
`--only` lose their value too). `--help` still delegates to `mix help`.

Verified in v26.9.15 against Igniter 0.8.4 under
`mix compile --warnings-as-errors` and the full task test suite, and
against a no-igniter consumer (the pack's `examples/greet-cli`) via a
real `elixirc` compile guard in this package's test suite.
