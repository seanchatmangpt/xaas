# ExNounVerbCli

A generator-first, dispatch-agnostic noun-verb CLI core for Elixir. Ports the
useful parts of the Rust [`clap-noun-verb`](https://github.com/seanchatmangpt/clap-noun-verb)
framework's ergonomics — compile-time-registered noun/verb dispatch, a
declarative arg schema, JSON-by-default output, command chaining/stdin
extraction — without the `linkme`/proc-macro machinery: registration is a
generated explicit registry module by default (a real BEAM reflection-based
fallback exists too, see the matrix below).

Full design charter:
[`docs/superpowers/specs/2026-09-11-ex-noun-verb-cli-design.md`](docs/superpowers/specs/2026-09-11-ex-noun-verb-cli-design.md).

## Installation

```elixir
def deps do
  [
    {:ex_noun_verb_cli, "~> 26.9"}
  ]
end
```

## Quick Start

The toy `calc` CLI under `examples/calc/` proves the core end-to-end,
mirroring clap-noun-verb's own README quickstart (`calc add`/`calc
multiply`). A verb is a `noun`/`verb` pair bound to a `module`/`function`
plus an `Igniter.Mix.Task.Info`-shaped arg schema:

```elixir
defmodule ExNounVerbCli.Examples.Calc.Registry do
  use ExNounVerbCli.Registry.Generated,
    verbs: [
      [
        noun: "calc",
        verb: "add",
        module: ExNounVerbCli.Examples.Calc,
        function: :add,
        info: %{schema: [x: :integer, y: :integer], required: [:x, :y]},
        doc: "Adds --x and --y."
      ],
      [
        noun: "calc",
        verb: "multiply",
        module: ExNounVerbCli.Examples.Calc,
        function: :multiply,
        info: %{schema: [x: :integer, y: :integer], required: [:x, :y]},
        doc: "Multiplies --x and --y."
      ]
    ]
end
```

Dispatching runs the pipeline directly, in-process, with no adapter needed —
this is exactly what `ExNounVerbCli.Escript.run/2` does under the hood:

```elixir
iex> ExNounVerbCli.Dispatcher.dispatch(
...>   ExNounVerbCli.Examples.Calc.Registry,
...>   ["calc", "add", "--x", "2", "--y", "3"]
...> )
{:ok, 5}

iex> ExNounVerbCli.JsonOutput.encode_string(
...>   ExNounVerbCli.JsonOutput.encode(:ok, 5)
...> )
"{\"status\":\"ok\",\"result\":5}"
```

### As a single-binary escript

```elixir
# config/config.exs (or wherever the escript reads config from)
config :ex_noun_verb_cli, registry: ExNounVerbCli.Examples.Calc.Registry
```

```
$ mix escript.build
$ ./ex_noun_verb_cli calc add --x 2 --y 3
{"status":"ok","result":5}
$ echo $?
0
```

### Command chaining

Multiple noun/verb groups separated by `++` run in sequence; the JSON result
is an array, and the overall exit status is `:error` if any group errored:

```
$ ./ex_noun_verb_cli calc add --x 2 --y 3 ++ calc multiply --x 4 --y 5
[{"status":"ok","result":5},{"status":"ok","result":20}]
```

### As an `Igniter.Mix.Task`

Requires `:igniter` as a dependency of the consuming application (the
adapter module is compiled only when Igniter is present):

```elixir
{:igniter, "~> 0.5"}
```

```
$ mix ex_noun_verb_cli calc add --x 2 --y 3
```

folds the same dispatch result into the `Igniter.t()` being built, since an
Igniter task composes rather than prints-and-exits — see
`lib/mix/tasks/ex_noun_verb_cli.ex`.

## Feature matrix

What's implemented in this v1 proof-of-concept vs. deferred per the design
spec's [Section 6 non-goals](docs/superpowers/specs/2026-09-11-ex-noun-verb-cli-design.md#6-non-goals-for-v1):

| Capability | Status |
|---|---|
| Noun/verb dispatch (`Dispatcher.dispatch/2`) | Implemented |
| Declarative arg schema (`Igniter.Mix.Task.Info`-shaped) | Implemented |
| JSON-by-default output (`JsonOutput`) | Implemented |
| Command chaining (`++`) | Implemented |
| Cross-group value threading (`@{N.path}` into a prior group's envelope) | Implemented, v26.9.15 |
| `--introspect` LLM self-description (machine-readable verb manifest) | Implemented, v26.9.15 |
| Stdin/file extraction (`@-` / `@-::json.path`) | Implemented |
| Generated explicit registry (`Registry.Generated`) | Implemented, v1-primary |
| Reflection-based registry (`Registry.Reflection`) | Implemented, v2 opt-in convenience |
| Escript adapter | Implemented |
| `Igniter.Mix.Task` adapter | Implemented |
| Capability standing / RDF graph ops (`Capability`, `GraphProvider` behaviour) | Implemented (decoupled — no oxigraph/`ggen_igniter` dependency in this library; a consumer supplies the `GraphProvider` implementation) |
| Toy `calc` example CLI (`examples/calc/`) | Implemented |
| Real `ggen-marketplace` consumer (`marketplace_cli.catalog`/`validate`) | Implemented consumer-side — ggen-marketplace's `packages/marketplace-cli` (Milestone 2) |
| Dynamic shell completions (`--completions bash\|zsh\|fish`) | Implemented, v26.9.16 |
| Human help (`--help [<noun>]`) as a manifest projection | Implemented, v26.9.16 |
| Inline `@{N.path}` splicing inside larger tokens | Implemented, v26.9.16 |
| Full `clap-noun-verb` parity (semantic composition, economic simulation, quantum-ready crypto-agility, etc.) | Out of scope for this port's charter |
| Real Hex.pm publish | v26.9.15 — first release published to Hex.pm (`mix hex.publish --dry-run` verified) |

## Testing

Chicago-style throughout: real collaborators (a genuine, simple `Registry`
fixture — not a mock; a real in-memory `GraphProvider` fixture; a real
`System.cmd` subprocess for the escript adapter; `Igniter.Test` for the
Igniter adapter), state-based assertions. No `Mox`/`Mimic`/`:meck`/`Patch`
anywhere in this repo.

```
mix test
```

## Documentation

Diataxis doc set for **v26.9.16** (the same documentation convention the
ggen-marketplace ecosystem uses):

- Tutorial: [your first noun-verb CLI](docs/tutorials/first-cli.md)
- How-to: [add a verb](docs/how-to/add-a-verb.md) ·
  [chain commands / stdin](docs/how-to/chain-commands.md) ·
  [run as an Igniter task](docs/how-to/use-with-igniter.md) ·
  [handle errors](docs/how-to/handle-errors.md) ·
  [introspect for agents](docs/how-to/introspect-for-agents.md) ·
  [shell completions & help](docs/how-to/completions-and-help.md)
- Reference: [error codes](docs/reference/error-codes.md) ·
  [arg schema](docs/reference/arg-schema.md) ·
  [JSON envelope](docs/reference/envelope-format.md) ·
  [module map](docs/reference/modules.md)
- Explanation: [why a generated registry](docs/explanation/why-generated-registry.md) ·
  [why a decoupled graph layer](docs/explanation/why-decoupled-graph.md) ·
  [why JSON by default](docs/explanation/why-json-by-default.md)

Also: [CHANGELOG.md](CHANGELOG.md), the
[design spec](docs/superpowers/specs/2026-09-11-ex-noun-verb-cli-design.md)
(with its v26.9.15 release amendment), and the full API on
[HexDocs](https://ex-noun-verb-cli.hexdocs.pm).
