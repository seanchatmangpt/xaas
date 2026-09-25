# Tutorial: your first noun-verb CLI (v26.9.15)

This tutorial builds a real two-noun CLI (`greet` and `math`) with
`ex_noun_verb_cli` v26.9.15 — the same shape as the generated
`examples/greet-cli` in ggen-marketplace's `ex-noun-verb-cli-pack`, and
every command below was verified against the published release.

Time: about ten minutes.

## 1. Create the project and depend on the package

```elixir
# mix.exs
defp deps do
  [
    {:ex_noun_verb_cli, "~> 26.9"}
  ]
end
```

```console
$ mix deps.get
...
New:
  ex_noun_verb_cli 26.9.15
```

(If you plan to use the `Igniter.Mix.Task` adapter, also depend on
`:igniter` — see [use-with-igniter](../how-to/use-with-igniter.md). The
core and the escript adapter do not need it.)

## 2. Write verb handlers

A verb handler is a plain function. Keep it pure — the dispatcher passes
positional values first, then required option values, in declaration
order:

```elixir
# lib/my_cli/greet.ex
defmodule MyCli.Greet do
  def hello(name), do: "Hello, #{name}!"
  def shout(name), do: String.upcase("Hello, #{name}!")
end

# lib/my_cli/math.ex
defmodule MyCli.Math do
  def add(x, y), do: x + y
  def multiply(x, y), do: x * y
end
```

## 3. Register the verbs

The registry is data, not macros — one entry per noun/verb pair, each
shaped like `Igniter.Mix.Task.Info`:

```elixir
# lib/my_cli/registry.ex
defmodule MyCli.Registry do
  use ExNounVerbCli.Registry.Generated,
    verbs: [
      [noun: "greet", verb: "hello", module: MyCli.Greet, function: :hello,
       info: %{schema: [name: :string], required: [:name]},
       doc: "Prints a friendly greeting for --name."],
      [noun: "greet", verb: "shout", module: MyCli.Greet, function: :shout,
       info: %{schema: [name: :string], required: [:name]},
       doc: "Prints an uppercase greeting for --name."],
      [noun: "math", verb: "add", module: MyCli.Math, function: :add,
       info: %{schema: [x: :integer, y: :integer], required: [:x, :y]},
       doc: "Adds --x and --y."],
      [noun: "math", verb: "multiply", module: MyCli.Math, function: :multiply,
       info: %{schema: [x: :integer, y: :integer], required: [:x, :y]},
       doc: "Multiplies --x and --y."]
    ]
end
```

## 4. Dispatch in-process (no adapter needed)

```elixir
iex> ExNounVerbCli.Dispatcher.dispatch(MyCli.Registry, ["math", "add", "--x", "2", "--y", "3"])
{:ok, 5}
```

## 5. Ship it as a single-binary escript

```elixir
# config/config.exs
import Config
config :ex_noun_verb_cli, registry: MyCli.Registry
```

```elixir
# mix.exs
defp escript, do: [main_module: ExNounVerbCli.Escript, app: nil]
```

```console
$ mix escript.build
Generated escript my_cli with MIX_ENV=dev
$ ./my_cli greet hello --name World
{"result":"Hello, World!","status":"ok"}
$ ./my_cli math add --x 2 --y 3
{"result":5,"status":"ok"}
$ ./my_cli math multiply --x 4 --y 5
{"result":20,"status":"ok"}
```

Errors come back as the same JSON envelope with exit code 1:

```console
$ ./my_cli math add --x-y 2 --y 3
{"error":{"code":"invalid_option","detail":{"invalid":[{"flag":"--x-y","value":null}]},"message":"unrecognized option(s): [{\"--x-y\", nil}]"},"status":"error"}
$ echo $?
1
```

That's the whole loop. Where to go next:

- [Chain commands and read stdin](../how-to/chain-commands.md)
- [Every error shape and how to read it](../reference/error-codes.md)
- [Why the registry is generated data](../explanation/why-generated-registry.md)
