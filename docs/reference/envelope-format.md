# Reference: the JSON envelope (v26.9.15)

`ExNounVerbCli.JsonOutput` wraps every dispatch result in one stable,
always-serializable envelope. JSON is the default output mode for all
adapters.

## Shapes

Success:

```json
{"result": <term>, "status": "ok"}
```

Error:

```json
{"error": {"code": <atom-as-string>,
           "message": <string>,
           "detail": <map>},
 "status": "error"}
```

Chained runs return an **array** of per-group envelopes, one entry per
`++`-separated group, in invocation order.

## API

```elixir
JsonOutput.encode(:ok, value)        # -> Jason-encodable map
JsonOutput.encode(:error, %Error{})  # -> Jason-encodable map
JsonOutput.encode_string(term)       # -> Jason.encode!(term)
```

## The serializability invariant (v26.9.15)

The envelope ALWAYS serializes — including on the error path. Two layers
guarantee it:

1. The `:invalid_option` construction site stores
   `%{"flag"/"value"}` maps instead of raw `OptionParser` tuples.
2. `encode(:error, ...)` runs `detail` through a defensive `sanitize/1`:
   tuples become lists, nested lists/maps recurse, and map keys that are
   neither binaries nor atoms are replaced with their `inspect/1` form.
   Any other term passes through unchanged.

Before v26.9.15, an unrecognized flag or a failed type cast crashed
`Jason.encode!/1` inside the escript adapter
(`protocol Jason.Encoder not implemented for Tuple`) instead of printing
the failure envelope. That crash class is now regression-guarded in the
test suite at both the construction site and the encoder.

## Exit codes (escript adapter)

| Envelope | Exit status |
|---|---|
| single group, `ok` | 0 |
| single group, `error` | 1 |
| chained run, any group errored | 1 |
