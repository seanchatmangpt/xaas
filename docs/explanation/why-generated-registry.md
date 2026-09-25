# Explanation: why the registry is generated data (v26.9.15)

The upstream Rust framework, `clap-noun-verb`, registers verbs at compile
time with `#[verb]` macros expanding to `#[linkme::distributed_slice]` —
zero runtime work, but at the cost of a proc-macro + linkme toolchain
that every consumer crate must adopt directly.

`ex_noun_verb_cli` makes the opposite trade: **registration is plain
data**, compiled once by `use ExNounVerbCli.Registry.Generated, verbs: [...]`
into an explicit lookup module. Why:

- **Generator-first.** This library exists to be *written by* tools —
  ggen-marketplace's `ex-noun-verb-cli-pack` renders a registry module
  from a Turtle ontology instance (`examples/greet-cli` in that pack is
  exactly this). A data-shaped registry is trivially templatable; a macro
  ecosystem is not.
- **No linkme/proc-macro machinery.** Consumers keep a vanilla Mix
  project — the port's charter is explicitly "the ergonomics without the
  machinery".
- **Inspectable.** The full verb table is readable in one module and in
  one `info` shape (mirroring `Igniter.Mix.Task.Info`), which is what
  makes adapters (escript, Igniter task) thin: they only resolve a
  registry from config and hand argv to `Dispatcher.dispatch/2`.

`ExNounVerbCli.Registry.Reflection` still exists as an opt-in fallback
that discovers handlers via BEAM reflection at runtime — useful for
prototyping — but the v1-primary path is the generated explicit registry,
and all shipped examples and pack templates use it.

The same philosophy explains why dispatch is pure and adapter-agnostic:
the core never prints, exits, or reads config; adapters own the boundary
concerns (output format, exit codes, composition into Igniter).
