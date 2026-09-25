# PRESS RELEASE — working backwards for `ex_noun_verb_cli` v26.9.16

*Amazon Working Backwards: written before implementation, as if shipped.
Dateline: the v26.9.16 release day. If the release cannot honestly claim
this, the release is not done.*

**Chatman Ecosystem ships ex_noun_verb_cli v26.9.16: every noun-verb CLI
is now self-documenting, self-completing, and composable at the token
level**

SEAN CHATMAN'S ELIXIR TOOLCHAIN — Today `ex_noun_verb_cli` v26.9.16
shipped, closing the last discovery gap between noun-verb CLIs and the
agents and humans who drive them. Any CLI built on the library — which
is any registry rendered by a ggen-marketplace pack — now answers three
questions about itself, from one source of truth, with zero hand-written
documentation:

- **"What can you do?"** — `--introspect` (shipped v26.9.15) returns the
  full machine-readable manifest; **new in v26.9.16**, `--help` renders
  the same manifest as a human-readable command table, and
  `--completions bash|zsh|fish` emits a ready-to-source completion
  script generated entirely from the registry.
- **"What happened?"** — the always-serializable JSON envelope
  (v26.9.15) answers on every path, success or failure.
- **"Can you use that answer?"** — v26.9.15 threaded whole tokens
  between chained commands (`@{0.result}`); **new in v26.9.16**,
  references compose *inside* tokens: `--tag run-@{0.result}-final`
  splices a prior group's result into a larger argument, matching the
  Rust upstream's preprocessor semantics.

The customer story is an agent with one shell. It introspects the CLI,
plans a chain of calls, threads outputs into inputs mid-token, parses
every result as JSON, and gets tab-completion for free when a human
takes over. No prose docs were read in the making of this loop.

"Why this matters," said the repository's design charter, "is that CLIs
are the last universal API. An agent that can drive one noun-verb CLI
can drive every projection of it — a pack-rendered CLI today, something
else tomorrow — because the manifest, the envelope, and the chaining
tokens are the contract, not the binary."

Every claim above is falsified by the test suite if untrue: `--help` and
`--completions` are projections of the same manifest the introspection
tests assert; inline embedding is proven against real chained dispatch;
an unknown shell returns a typed error envelope, not a crash.

**Availability**: [hex.pm/packages/ex_noun_verb_cli](https://hex.pm/packages/ex_noun_verb_cli)
under MIT. CalVer `26.9.16`.

*Working-backwards note (kept in the release): the press release was
written first; the v26.9.16 ARD/PRD and Vision 2030 documents under
`docs/working-backwards/` are its requirements contract, and the
implementation is their consequence.*
