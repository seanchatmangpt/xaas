# ExNounVerbCli v26.9.16 — PRD / ARD

**Repository:** `seanchatmangpt/ex_noun_verb_cli`
**Ecosystem role:** dispatch contract for pack-rendered CLIs
**Depends on:** nothing at runtime (`:jason` only); `:igniter` optional (dev/test)
**Release:** v26.9.16 (CalVer)
**Working-backwards source:** `press-release-v26.9.16.md`, `vision-2030.md`
**Standing conferred:** `UNKNOWN`.

## Product requirement

v26.9.16 SHALL complete the discovery leg of the dispatch contract:
every question a human or an agent asks of a CLI — what commands exist,
how do I type them, how do I get help — SHALL be answered by projection
from the one registry manifest, never by hand-maintained parallel
surfaces. Composition SHALL reach token level: a chained group's
envelope value SHALL be spliceable inside a larger argument token,
matching the Rust upstream preprocessor's semantics.

## Required capabilities

1. **F1 — `--help` (human projection).** The escript adapter SHALL
   answer a leading `--help` with a plain-text usage view derived from
   `Introspect.manifest/1` (per-noun command table: verb, doc, options
   with types, required markers, positional names), exit `0`. `--help
   <noun>` SHALL filter to one noun. No hand-authored help strings
   SHALL exist anywhere in the library.
2. **F2 — `--completions <shell>` (shell projection).** The adapter
   SHALL emit a sourceable completion script for `bash`, `zsh`, and
   `fish`, generated from the manifest (nouns as subcommands, verbs per
   noun, option flags per verb). An unknown or unsupported shell
   (including upstream's `powershell`/`elvish`) SHALL return the typed
   error envelope (`:invalid_option`, naming the unsupported shell),
   exit `1` — never a crash. Completion scripts SHALL contain every
   noun and verb string and use shell-appropriate line endings (`\n`;
   the port keeps upstream's `line_ending` policy table observable).
3. **F3 — inline `@{N.path}` embedding.** `Chaining` SHALL resolve
   `@{N.path}` references occurring anywhere inside a token
   (`"run-@{0.result}-final"` → `"run-5-final"`), not only as whole
   tokens. Substitution SHALL be repeated for every reference in the
   token, left to right; unmatched brace-like text SHALL pass through
   byte-for-byte; out-of-range/missing paths SHALL substitute `""`
   (whole-token behavior unchanged).
4. **F4 — contract invariants (carried).** The envelope SHALL remain
   always-serializable; no-new-dependencies SHALL hold (F1–F3 add zero
   deps); `mix compile --warnings-as-errors` and the full suite SHALL
   be green on the newest toolchain.

## Architecture requirements

```text
registry (data)
   -> Introspect.manifest/1          (the one source of truth)
        -> --introspect              (machine projection, v26.9.15)
        -> --help                    (human projection, F1)
        -> --completions <shell>     (shell projection, F2)
chained envelopes
   -> Chaining.resolve_references/2  (whole-token, v26.9.15)
   -> inline embedding               (sub-token splice, F3)
```

Projections SHALL NOT parse or restate schema knowledge independently:
`--help` and `--completions` consume `manifest/1`'s output. The
`ExNounVerbCli.Shell` policy table (name, command-substitution support,
line ending, supported?) SHALL be a port-shaped echo of upstream
`clap_noun_verb::shell::ShellType`, with unimplemented shells marked
unsupported rather than approximated.

## Acceptance for v26.9.16

- `--help` and `--help <noun>` render every verb/doc/option for the
  real fixture registry, exit 0 — asserted against manifest content, not
  golden prose.
- `--completions bash|zsh|fish` scripts contain every noun and verb;
  `--completions powershell` (and unknowns) return the typed error
  envelope with exit 1.
- `calc add --x 2 --y 3 ++ calc multiply --x '@{0.result}' --y 5`
  still yields `[5, 25]`; `--name run-@{0.result}-x` splices `5`
  mid-token; `--name @{9.nope}` resolves the reference to `""` inside
  the surrounding text.
- Full Chicago-style suite green (no mocks: real registry, real
  `Escript.run/2`, real generated scripts); suite count grows by ≥ 12.
- Docs: new how-to for completions; chain-commands updated for inline
  embedding; module map + README matrix updated; CHANGELOG entry;
  press release claims all satisfied.

## Falsifiers

The release is falsified if: help text exists that the manifest does not
imply; a completion script contains a command string absent from the
registry; inline substitution drops or reorders surrounding bytes; any
new runtime dependency appears; any acceptance case crashes instead of
enveloping; or the press release's customer story cannot be replayed
verbatim by the test suite.

## Ecosystem contract

`ex_noun_verb_cli` holds the dispatch contract. Packs render registries.
`GraphProvider` implementers stand behind capability claims. Nothing in
this release actuates anything: projections describe, dispatch computes,
the envelope answers.
