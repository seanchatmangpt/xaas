# How-to: let an agent discover and drive your CLI (v26.9.15)

You want an LLM agent (or a completion generator, or a harness) to use
your noun-verb CLI without reading prose docs. Since v26.9.15 the escript
adapter answers `--introspect` with a machine-readable manifest of the
entire verb table.

## Ask for the manifest

```console
$ ./my_cli --introspect
{"result":{"chaining":{...},"nouns":{...},"registry":"MyCli.Registry","schema":"https://ggen.dev/ex-noun-verb-cli/introspect/v1","verbs":[...]},"status":"ok"}
```

Filter to one noun:

```console
$ ./my_cli --introspect greet
```

## What the manifest gives you

- `nouns` — noun → verb names, sorted.
- `verbs` — one record per verb: `noun`, `verb`, `doc`, `handler`
  (`Module.function/arity`, where arity = positionals + required
  options), `schema` (option name → type), `required`, `positional`,
  `aliases`.
- `chaining` — the composition tokens the adapter understands (`++`,
  `@-`, `@-::path`, `@{N.path}`), so an agent can chain calls without
  consulting separate documentation.

Everything is JSON-ready by construction (string keys, atom types
stringified) and arrives inside the standard
`{"result": ..., "status": "ok"}` envelope.

## The agent loop this enables

1. `cli --introspect` — discover verbs and their schemas.
2. `cli <noun> <verb> --flag value` — invoke; parse the JSON envelope.
3. Chain with value threading — a later group can consume an earlier
   group's envelope via `@{N.path}`:

```console
$ ./my_cli math add --x 2 --y 3 ++ math multiply --x '@{0.result}' --y 5
[{"result":5,"status":"ok"},{"result":25,"status":"ok"}]
```

`@{0.error.code}` reaches into a failed group's error envelope; a bad
reference resolves to `""` and surfaces as the next group's ordinary
error envelope rather than crashing the run. In shells, quote the token
so the brace expansion stays literal.

`ExNounVerbCli.Introspect.manifest/2` exposes the same data for
in-process use (registry module, optional noun filter).
