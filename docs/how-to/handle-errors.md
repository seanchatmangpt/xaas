# How-to: handle dispatch errors (v26.9.15)

Every failure path returns a typed `ExNounVerbCli.Error.t()` inside
`{:error, error}` — the core never raises for expected failures, and the
JSON envelope **always** serializes, including on the error path
(guaranteed since v26.9.15; see
[why-json-by-default](../explanation/why-json-by-default.md)).

## Pattern-match on the code

```elixir
case ExNounVerbCli.Dispatcher.dispatch(MyCli.Registry, argv) do
  {:ok, value} -> value
  {:error, %ExNounVerbCli.Error{code: :unknown_verb} = e} -> ...
  {:error, %ExNounVerbCli.Error{code: :missing_required_option} = e} -> ...
  {:error, %ExNounVerbCli.Error{code: :invalid_option} = e} -> ...
  {:error, %ExNounVerbCli.Error{code: :handler_raised} = e} -> ...
end
```

The full table of codes, messages, and detail shapes:
[error-codes](../reference/error-codes.md).

## Invalid-option detail is JSON-shaped

Since v26.9.15, `:invalid_option`'s detail stores one `%{"flag"/"value"}`
map per rejected option — never raw `OptionParser` tuples:

```elixir
%{invalid: [%{"flag" => "--x-y", "value" => nil}]}
```

## Encode for output

```elixir
{:error, error} = ExNounVerbCli.Dispatcher.dispatch(MyCli.Registry, ["math", "add"])
json = ExNounVerbCli.JsonOutput.encode_string(ExNounVerbCli.JsonOutput.encode(:error, error))
# {"error":{"code":"missing_required_option","detail":{"missing":["y"]},"message":"..."},"status":"error"}
```

If your own code constructs an `Error` with non-encodable detail (tuples,
odd map keys), `JsonOutput.encode/2` defensively normalizes it (tuples →
lists, non-string/atom map keys → inspected strings) rather than crashing
the adapter.

## At the CLI boundary

The escript adapter prints the error envelope to stdout and exits 1; a
chained group that fails marks the whole run's exit status `:error` while
still emitting each group's envelope in the result array.
