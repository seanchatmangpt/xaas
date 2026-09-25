# How-to: add a verb (v26.9.15)

You have a working registry (see [the tutorial](../tutorials/first-cli.md))
and want to add, change, or alias a command.

## Add a noun/verb pair

Append one entry to the `verbs:` list of your
`use ExNounVerbCli.Registry.Generated` module:

```elixir
[noun: "profile", verb: "echo", module: MyCli.Profile, function: :echo,
 info: %{schema: [profile_id: :string], required: [:profile_id]},
 doc: "Echoes --profile-id."]
```

The `info` map understands four keys (all optional):

| Key | Meaning |
|---|---|
| `:schema` | `OptionParser`-style switches, e.g. `[x: :integer, name: :string]` |
| `:required` | schema keys that must be present |
| `:positional` | names of expected positional arguments (values are passed to the handler in order) |
| `:aliases` | extra `OptionParser` aliases for short flags |

## Handler argument order

The dispatcher calls `module.function(positional_values ++ required_values)`.
Positional values come first (in `:positional` order), then required option
values (in `:required` declaration order).

## kebab-case is canonical; snake_case is accepted

Mirroring the upstream Rust `clap-noun-verb` convention, long flags are
canonical in kebab-case and the snake_case spelling works as an alias —
including `--flag=value` form (all three verified in v26.9.15):

```elixir
Dispatcher.dispatch(MyCli.Registry, ["profile", "echo", "--profile-id", "acme"])
{:ok, "acme"}
Dispatcher.dispatch(MyCli.Registry, ["profile", "echo", "--profile_id", "acme"])
{:ok, "acme"}
Dispatcher.dispatch(MyCli.Registry, ["profile", "echo", "--profile_id=acme"])
{:ok, "acme"}
```

## Verify it

The cheapest full-fidelity check is the dispatcher plus the JSON layer:

```elixir
{:ok, value} = ExNounVerbCli.Dispatcher.dispatch(MyCli.Registry, ["profile", "echo", "--profile-id", "acme"])
"{\"result\":\"acme\",\"status\":\"ok\"}" = ExNounVerbCli.JsonOutput.encode_string(ExNounVerbCli.JsonOutput.encode(:ok, value))
```

A schema violation never raises — it returns the typed error envelope
(see [error-codes](../reference/error-codes.md)).
