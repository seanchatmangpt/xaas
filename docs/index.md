# ExNounVerbCli documentation — v26.9.16

`ex_noun_verb_cli` is a generator-first, dispatch-agnostic noun-verb CLI
core for Elixir. This is the documentation index for release
**v26.9.16** — the current release (v26.9.15, earlier the same day, was the first published release).

These docs follow the [Diataxis](https://diataxis.fr) structure, the same
documentation convention the `ggen-marketplace` ecosystem uses:

| Quadrant | Question it answers | Where |
|---|---|---|
| Tutorial | Learning — get a working CLI in ten minutes | [docs/tutorials/first-cli.md](tutorials/first-cli.md) |
| How-to guides | A specific goal, starting from a working setup | [docs/how-to/](how-to/) |
| Reference | Authoritative description of the machinery | [docs/reference/](reference/) |
| Explanation | Why it is designed the way it is | [docs/explanation/](explanation/) |

## Where to start

- New to the library: [the tutorial](tutorials/first-cli.md) builds a real
  noun-verb CLI (`greet hello --name World`) end to end.
- Adding commands: [add-a-verb](how-to/add-a-verb.md).
- Wiring into a mix project: [use-with-igniter](how-to/use-with-igniter.md).
- Every failure shape the core can return: [error-codes](reference/error-codes.md).
- Letting an LLM agent discover and drive your CLI: [introspect-for-agents](how-to/introspect-for-agents.md).
- Shell completions and human help, generated from the same manifest: [completions-and-help](how-to/completions-and-help.md).

## Also in this repo

- [README.md](../README.md) — quick start and the implemented-vs-deferred
  feature matrix.
- [CHANGELOG.md](../CHANGELOG.md) — release history (v26.9.15 is the first
  published release; the v26.9.11 entry records the unpublished scaffold).
- [Design spec](superpowers/specs/2026-09-11-ex-noun-verb-cli-design.md) —
  the original design charter, with its v26.9.15 release amendment.
