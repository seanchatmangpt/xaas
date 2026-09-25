# How-to: chain commands and read stdin (v26.9.16)

`ExNounVerbCli.Chaining` preprocesses argv before dispatch: it splits
chained invocations and resolves stdin-extraction tokens. The escript
adapter runs it for you; call `Chaining.expand/1` directly for other
adapters.

## Chain with `++`

Separate noun/verb groups with the literal token `++`; each group runs in
sequence, the JSON result is an array, and the overall exit status is
`:error` if any group errored (verified against v26.9.15):

```console
$ ./my_cli math add --x 2 --y 3 ++ math multiply --x 4 --y 5
[{"result":5,"status":"ok"},{"result":20,"status":"ok"}]
```

## Read stdin with `@-`

A bare `@-` token is replaced with the entire contents of stdin, read
once, **verbatim** — this matches the upstream Rust preprocessor, which
does not trim. If the raw bytes (including a trailing newline) don't
satisfy the option's type, you get a typed invalid-option envelope, not a
crash:

```console
$ echo 7 | ./my_cli math add --x @- --y 3
{"error":{"code":"invalid_option","detail":{"invalid":[{"flag":"--x","value":"7\n"}]},"message":"unrecognized option(s): [{\"--x\", \"7\\n\"}]"},"status":"error"}
```

Strip the newline yourself when the target type is strict:

```console
$ printf 7 | ./my_cli math add --x @- --y 3
{"result":10,"status":"ok"}
```

## Dig into JSON stdin with `@-::path`

`@-::a.b.c` reads stdin once, decodes it as JSON, digs the dot-separated
path out, and stringifies the result (numbers/booleans become strings;
missing keys resolve to `""`):

```console
$ echo '{"a":{"b":{"c":42}}}' | ./my_cli profile echo --profile-id @-::a.b.c
{"result":"42","status":"ok"}
```

## Known limitations (real, documented)

- Stdin is a single stream: only the **first** stdin-reading token in an
  `expand/1` call receives the contents; later ones resolve to `""`.
- `@{N.path}` (referencing a *prior chained group's* envelope) IS
  resolved — but between groups, by the adapter, not by `expand/1`
  (which runs before anything has dispatched). `@{0.result}` threads the
  first group's result into the second group's options;
  `@{0.error.code}` reaches into a failed group's error envelope; a bad
  path or out-of-range index resolves to `""` and surfaces as the next
  group's own error envelope. Quote the token in shells so brace
  expansion stays literal:

```console
$ ./my_cli math add --x 2 --y 3 ++ math multiply --x '@{0.result}' --y 5
[{"result":5,"status":"ok"},{"result":20,"status":"ok"}]
```
