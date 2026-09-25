# Reference: the verb arg schema (v26.9.15)

Each registry entry binds a `noun`/`verb` pair to `module`/`function`
plus an `info` map whose shape deliberately mirrors
`Igniter.Mix.Task.Info` (plain data — the core never references the real
Igniter struct):

```elixir
[
  noun: "math",
  verb: "add",
  module: MyCli.Math,
  function: :add,
  info: %{
    schema: [x: :integer, y: :integer],
    required: [:x, :y],
    positional: [],
    aliases: []
  },
  doc: "Adds --x and --y."
]
```

## `info` keys (all optional, v26.9.15)

| Key | Type | Meaning |
|---|---|---|
| `:schema` | keyword of `OptionParser` switch types (`:integer`, `:string`, `:boolean`, …) | strict switches accepted by this verb |
| `:required` | list of schema keys | keys that must be present before the handler runs |
| `:positional` | list of names | expected positional arguments, consumed in order after noun/verb |
| `:aliases` | `OptionParser` aliases | extra short-flag aliases |

## Parsing behavior

- Parsing is `OptionParser.parse/2` with `strict: schema, aliases: aliases`.
- Long flags are canonical in **kebab-case**; a snake_case spelling
  (`--profile_id`) is normalized to `--profile-id` before parsing, and
  `--flag=value` form works for both spellings.
- Unrecognized flags and failed type casts never raise — they produce the
  `:invalid_option` envelope (see [error-codes](error-codes.md)).

## Handler invocation order

`module.function(positional_values ++ required_values)` — positional
values first (in `:positional` order), then required option values (in
`:required` declaration order). Optional flags are not passed; handlers
that need them should read `Application` config or wrap a richer struct
behind the verb.

## Where registries come from

`use ExNounVerbCli.Registry.Generated, verbs: [...]` compiles the list
into an explicit, zero-reflection registry (v1-primary).
`ExNounVerbCli.Registry.Reflection` provides an opt-in BEAM-reflection
fallback. See [why-generated-registry](../explanation/why-generated-registry.md).
