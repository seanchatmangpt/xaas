# Reference: module map (v26.9.16)

The complete public surface of `ex_noun_verb_cli` v26.9.15.

## Core dispatch

| Module | Role |
|---|---|
| `ExNounVerbCli.Verb` | the verb entry struct (noun/verb/module/function/info/doc) |
| `ExNounVerbCli.Registry` | registry behaviour (`verbs/0`, `fetch/2`) |
| `ExNounVerbCli.Registry.Generated` | `use`-based explicit registry — v1-primary, zero reflection |
| `ExNounVerbCli.Registry.Reflection` | opt-in BEAM-reflection registry fallback |
| `ExNounVerbCli.Dispatcher` | pure, adapter-agnostic `dispatch(registry, argv)` |
| `ExNounVerbCli.Chaining` | argv preprocessing: `++` group split, `@-` / `@-::path` stdin extraction, `@{N.path}` cross-group reference resolution (`resolve_references/2`, v26.9.15) |
| `ExNounVerbCli.Introspect` | machine-readable registry manifest for agents (`manifest/2`, `--introspect`, v26.9.15) |
| `ExNounVerbCli.JsonOutput` | the always-serializable JSON envelope (`encode/2`, `encode_string/1`) |
| `ExNounVerbCli.Error` | typed error struct (`code`/`message`/`detail`) |

## Adapters

| Module | Role |
|---|---|
| `ExNounVerbCli.Escript` | single-binary CLI: prints the envelope, exits 0/1; meta-flags `--introspect` / `--help` / `--completions`; reads `config :ex_noun_verb_cli, :registry` (and optional `:completion_command`) |
| `Mix.Tasks.ExNounVerbCli` | `Igniter.Mix.Task` adapter; **defined only when `:igniter` is loadable** (optional-dep contract, v26.9.15) — folds the envelope into the composed `Igniter.t()` via `add_notice/2` and strips Igniter's own global flags from dispatch |

## Capability / graph layer (decoupled)

| Module | Role |
|---|---|
| `ExNounVerbCli.GraphProvider` | behaviour a consumer implements to back capability standing with a real RDF graph |
| `ExNounVerbCli.Capability` | `CapabilityPackage` / `ProofSurface` shapes, `refresh_standing` derivation, `Package.with_dependency/2` + `validate/1` |
| `ExNounVerbCli.CapabilityRegistry` | port of the Rust `CapabilityRegistry`: dependency-closure container with `dependency_order/1` topological sort (cycle + missing-dependency detection), duplicate-id refusal |

The graph layer deliberately has **no** oxigraph/`ggen_igniter`
dependency — see
[why-decoupled-graph](../explanation/why-decoupled-graph.md).

## Examples

`examples/calc/` — the toy calc CLI mirroring clap-noun-verb's README
quickstart; compiled into this repo's own escript proof-of-concept. The
generated-consumer counterpart (greet + math, produced by
ggen-marketplace's `ex-noun-verb-cli-pack`) lives in that pack's
`examples/greet-cli/`.
