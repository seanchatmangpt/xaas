# Reference: error codes (v26.9.15)

`ExNounVerbCli.Error.t()` carries `code` (atom), `message` (string), and
`detail` (map, defaults to `%{}`). Four codes exist in v26.9.15 — this is
the complete set, verified against `lib/ex_noun_verb_cli/dispatcher.ex`:

| Code | Raised when | `detail` shape |
|---|---|---|
| `:unknown_verb` | no verb registered for the noun/verb pair | `%{noun: noun, verb: verb}` |
| `:missing_required_option` | a key in `info.required` was absent | `%{missing: [atom, ...]}` |
| `:invalid_option` | an option token not in `info.schema`, or a value failing its type cast | `%{invalid: [%{"flag" => String.t(), "value" => term}, ...]}` |
| `:handler_raised` | the handler function raised | `%{exception: "MyApp.MyError"}` (the inspected exception module) |

## `:invalid_option` in depth

`detail.invalid` holds one `%{"flag" => ..., "value" => ...}` map per
rejected token. Two sub-cases surface in practice:

- Unknown flag — the flag never matched the schema; `value` is `null` and
  any following bare token stays positional:
  `%{"flag" => "--x-y", "value" => nil}`.
- Failed type cast — the flag matched but its value failed the switch's
  type (e.g. `--x` declared `:integer` receiving raw stdin bytes
  `"7\n"`): `%{"flag" => "--x", "value" => "7\n"}`.

Since v26.9.15 this detail is stored JSON-encodable at construction time
(previously raw `OptionParser` `{flag, value}` tuples flowed into the
envelope and crashed `Jason.encode!/1` on the error path).

## Envelope rendering

```json
{"error": {"code": "invalid_option",
           "message": "unrecognized option(s): [{\"--x-y\", nil}]",
           "detail": {"invalid": [{"flag": "--x-y", "value": null}]}},
 "status": "error"}
```

See also: [handle-errors](../how-to/handle-errors.md),
[envelope-format](envelope-format.md).
