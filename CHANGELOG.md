# Changelog

## v26.9.16

The Working Backwards release: press release, Vision 2030, and ARD/PRD
were written first (`docs/working-backwards/`), and this release is
their consequence — the discovery leg of the dispatch contract completed.

- **`--help [<noun>]` — human help as a manifest projection.** New
  `ExNounVerbCli.Help.render/2` renders usage, the per-noun command
  table (verb, doc, options with types and required markers,
  positionals), and a chaining quick reference — every word implied by
  `Introspect.manifest/1`. No hand-authored help strings exist in the
  library (an ARD falsifier, tested).
- **`--completions <bash|zsh|fish>` — dynamic shell completions.** New
  `ExNounVerbCli.Completions.script/3` emits sourceable bash/zsh/fish
  scripts generated from the manifest (nouns as subcommands, verbs per
  noun, option flags per verb); `config :ex_noun_verb_cli,
  :completion_command` renames the completed command. New
  `ExNounVerbCli.Shell` ports upstream `clap_noun_verb::shell::ShellType`
  policies (supported shells, command substitution, line endings);
  unported/unknown shells return the typed `invalid_option` envelope —
  never a fake script or a crash. Previously deferred.
- **Inline `@{N.path}` splicing.** References now resolve inside larger
  tokens (`--tag run-@{0.result}-final` → `run-5-final`), byte-for-byte
  around the splice, matching the Rust upstream preprocessor's
  `replace_range` semantics; whole-token behavior unchanged.
- **Manifest flag names are now the canonical CLI spelling.** The
  introspection manifest reported schema keys in atom form
  (`profile_id`); it now reports the kebab-case long flag users type
  (`--profile-id`), with `required`/`positional`/`aliases` following the
  same spelling.
- 23 new Chicago-style tests (shell policy table, all three completion
  scripts incl. a no-invented-flags falsifier, help projection against
  both real registries, inline splicing, `--help`/`--completions`
  integration incl. typed refusals); suite now 110.

## v26.9.15

First release published to Hex.pm. `v26.9.11` was the scaffold-date version:
it passed `mix hex.build` but was never published (no Hex account was
configured at the time). This release carries all of `v26.9.11`'s content,
everything merged after it, and the AGI-80/20 pair. (26.9.15 was briefly
published without the AGI pair, reverted within the 24h window — which
removed the package entirely, it being the only release — and republished
with them; the package's only release is this one.)

- Igniter adapter (`Mix.Tasks.ExNounVerbCli`): Igniter's own global option
  flags (`--dry-run`, `--yes`, `--yes-to-deps`, …) no longer leak into verb
  dispatch as unrecognized-option tokens (which previously crashed JSON
  encoding with an unencodable tuple); the adapter's contract is verified
  against Igniter's own test suite.
- `:igniter` dependency is `optional: true` with no `only:` restriction, so
  the package compiles cleanly as a dependency in consumers that never
  depend on `:igniter`, while Igniter-adapter consumers get a real,
  resolvable dependency.
- The `Igniter.Mix.Task` adapter module is now defined only when Igniter
  is actually loadable (`Code.ensure_loaded?/1` guard). Before this, a
  consumer without `:igniter` (e.g. the pack's `examples/greet-cli`)
  failed to compile the package outright: `use Igniter.Mix.Task` is a
  compile-time macro, and `optional: true` only affects dependency
  resolution, not compilation. Regression-guarded by a real no-igniter
  `elixirc` compile in the test suite.
- `ExNounVerbCli.CapabilityRegistry`: real port of clap-noun-verb's
  `CapabilityRegistry` container — `dependency_order/1` topological sort
  with cycle and missing-dependency detection, duplicate-id refusal — plus
  `Package.with_dependency/2` and `Package.validate/1`.
- `ExNounVerbCli.Dispatcher`: snake_case flags (`--some_flag`) are accepted
  as aliases, normalized to the canonical kebab-case form (`--some-flag`).
- Error envelopes always serialize: the `:invalid_option` detail now stores
  an encodable `%{"flag"/"value"}` shape instead of raw `OptionParser`
  tuples, and `JsonOutput.encode/2` defensively sanitizes any
  non-encodable detail terms. Before this, an unrecognized flag (or a
  `@-` stdin value failing an `:integer` cast) crashed `Jason.encode!/1`
  inside the escript adapter instead of printing the failure envelope —
  the same crash class the Igniter adapter fix covered, on the core
  error path.
- **`--introspect` — machine-readable self-description (the AGI 80/20).**
  New `ExNounVerbCli.Introspect.manifest/2` renders the whole verb table
  as JSON-ready data (nouns index; per-verb doc, handler arity,
  schema/required/positional/aliases; the chaining-token reference), and
  the escript adapter answers a leading `--introspect` (optionally
  `--introspect <noun>`) with the manifest wrapped in the standard ok
  envelope. This is the agent-discovery loop: introspect → invoke →
  parse envelope → chain. Previously deferred.
- **`@{N.path}` — cross-group value threading (the other AGI 80/20
  half).** Chained groups can now consume an earlier group's envelope:
  `@{0.result}` threads a result into a later group's options,
  `@{0.error.code}` reaches into a failed group's error envelope. New
  `Chaining.resolve_references/2` runs between dispatches in the escript
  adapter (`expand/1` still owns stdin, which needs no dispatch
  results). Missing paths and out-of-range indexes resolve to `""` —
  the `@-::path` convention — so a bad reference surfaces as the next
  group's ordinary error envelope instead of crashing. Previously a
  documented TODO.
- 14 new Chicago-style tests (introspect manifest, reference resolution,
  real `Escript.run/2` threading incl. error-envelope reach-in), suite
  now 87; new how-to `docs/how-to/introspect-for-agents.md`; README
  matrix rows updated (`--introspect` and `@{N.path}` move from Deferred
  to Implemented; the marketplace-consumer row reflects the real
  `marketplace-cli`).

## v26.9.11

Initial proof-of-concept release. See `docs/superpowers/specs/2026-09-11-ex-noun-verb-cli-design.md`
for the full design charter.

- `ExNounVerbCli.Verb`, `ExNounVerbCli.Registry` (behaviour) + `Registry.Generated`
  (v1-primary) + `Registry.Reflection` (opt-in fallback).
- `ExNounVerbCli.Dispatcher` — pure, adapter-agnostic noun/verb dispatch against
  an `Igniter.Mix.Task.Info`-shaped arg schema.
- `ExNounVerbCli.JsonOutput`, `ExNounVerbCli.Error` — JSON-by-default result envelope.
- `ExNounVerbCli.Chaining` — `++`/`@{path}`/`@-`/`@-::json.path` argv preprocessing.
- `ExNounVerbCli.GraphProvider` (behaviour) + `ExNounVerbCli.Capability` — decoupled
  capability-standing/RDF layer, no oxigraph/ggen_igniter dependency in this library.
- Escript adapter (`ExNounVerbCli.Escript`) and `Igniter.Mix.Task` adapter.
- `examples/calc/` toy CLI proof of concept.
