# Explanation: why JSON-by-default output (v26.9.15)

Every adapter emits the same small JSON envelope —
`{"result": _, "status": "ok"}` or
`{"error": {code, message, detail}, "status": "error"}` — instead of
human-formatted text. Why this is the right default for this library:

- **Chaining needs machine-readable results.** The `++` operator exists
  so one command's output can sit next to another's in a single array a
  script can consume. Pretty text breaks that contract at the first
  multi-line result.
- **The envelope is the stable contract, not the rendering.** Codes stay
  atoms in Elixir and strings in JSON; tools (and LLM agents) can match
  on `status`/`error.code` without parsing prose.
- **Errors are data, not stack traces.** A dispatch failure is a typed
  `ExNounVerbCli.Error` with a machine-readable `detail` map; the
  alternative — raising or printing ad-hoc text — forces every consumer
  to re-parse.

## The invariant, and the bug that taught it

The envelope must serialize **always** — a CLI whose error path crashes
the process has no error path at all. v26.9.11's original code violated
this twice in the wild: raw `OptionParser` `{flag, value}` tuples flowed
into `error.detail`, and `Jason.encode!/1` crashed on them (first in the
Igniter adapter, then — found while validating v26.9.15 against the
clap-noun-verb quickstart — on the core escript path itself: an
unrecognized flag or an `@-` stdin value failing an `:integer` cast took
the whole binary down).

v26.9.15 closes the class, not just the instances: the construction site
stores encodable `%{"flag"/"value"}` maps, and `JsonOutput.encode/2`
defensively sanitizes any non-encodable detail (tuples → lists,
non-binary/atom map keys → inspected strings) so even a handler that
builds its own `Error` with exotic detail cannot crash the boundary.
Both layers carry regression tests, including a real no-network
`elixirc` compile guard for the optional-Igniter contract — the same
discipline, applied to "this boundary must never fail this way again".
