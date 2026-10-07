# W641c — graphlaw adoption of rust-wasi-wasmex-pack — BLOCKED(integration-design-needed)

Standing: **BLOCKED(integration-design-needed)** — no graphlaw commit, no push, verified binary untouched.

Subject: ~/graphlaw @ graphlaw-registry-limits, HEAD `1869a16`
("build(wasm): W637b [profile.wasm] merge + artifact digest sidecar"). Tree clean
except pre-existing untracked `priv/graphlaw.wasm` (binary is untracked; the
digest sidecar `priv/graphlaw.wasm.sha256` is tracked).

## Grounding (read, not inferred)

1. `~/graphlaw/ggen.toml` exists with `[[generation.rules]]` for the
   chicago-graphlaw-court-pack only (tests/chicago_fibo.rs,
   tests/chicago_cross_authority.rs). **No `[[packs]]` entries.**
2. In-tree `wasm/src/lib.rs` (93 lines) wires gl_alloc/gl_call/gl_free directly to
   `graphlaw::abi::{call, missing_buffer_response, limit_response}` with limits
   `MAX_REQUEST_BYTES=16MiB` / `MAX_OUTSTANDING_ALLOC_BYTES=256MiB` sourced from
   `graphlaw::abi` (src/abi.rs:48,59 — the native-tested single source of truth).
3. Pack template `templates/guest/ffi.rs.tmpl` conflicts with the in-line
   implementation on four load-bearing points:

   | # | Template | In-tree verified module |
   |---|---|---|
   | 1 | Defines `MAX_REQUEST_BYTES`/`MAX_OUTSTANDING_BYTES` as **local consts** | limits live in `graphlaw::abi`, exercised natively by the whole suite |
   | 2 | Calls `crate::handle_request(&request)` | wasm crate calls `graphlaw::abi::call` directly; no `handle_request` hook exists in the crate |
   | 3 | Calls `crate::missing_buffer_response()` / `crate::limit_response(...)` as crate-local | those fns live in `graphlaw::abi`, not the wasm crate |
   | 4 | `call_buf` substitutes `b"{}"` when the response is empty | verified module returns the real (never-empty) response unmodified |

   Additional structural gap: the pack ships **no SPARQL query file** (no `.rq`
   anywhere under the pack), so a `ggen.toml` `[[generation.rules]]` entry for
   ffi.rs is not expressible without authoring a query — i.e. inventing pack
   content, which is outside this lane's authority.

4. Digest: `priv/graphlaw.wasm.sha256` (tracked, committed by W637b @ 1869a16)
   pins `b7664a5e…2131`. The on-disk binary matches today
   (`shasum -a 256 priv/graphlaw.wasm` → `b7664a5e…2131`). Any lib.rs
   restructuring (mod/include! of a generated ffi.rs) forces a wasm rebuild;
   binary bytes would change (different module structure/symbol layout) →
   digest sidecar breaks → per lane instructions that is STOP, not a silent
   sidecar update.

## Verdict

Template output would CONFLICT with the existing in-line implementation
(4 concrete conflicts above), and the only migration path forces an artifact
digest change that the W637b sidecar pins. Per the adoption prompt's explicit
instruction, this lane STOPs here and writes this typed BLOCKED receipt.
The verified binary (b7664a5e) is untouched; ~/graphlaw has **zero new
commits** from this lane; nothing pushed.

## What integration design must decide (for the next order)

- Where limits live: template consts vs `graphlaw::abi` re-export injected via
  ggen variables (pack ontology has `rww:maxRequestBytes`/`rww:maxOutstandingBytes`
  properties — a query + variable injection is the lawful shape).
- A `handle_request`/`missing_buffer_response`/`limit_response` shim contract for
  the guest crate (template's crate-local hooks vs `graphlaw::abi` delegation).
- Whether empty-response→`b"{}"` substitution is accepted behavior (it differs
  from the verified module).
- A pack `.rq` query must exist before any `[[generation.rules]]` entry.
- Digest rotation receipt: any accepted design changes b7664a5e and must mint a
  new receipt + sidecar update, disclosed, not silent.

## Commands / exits (real output)

- `git -C ~/graphlaw status -sb` → clean on graphlaw-registry-limits (untracked priv/graphlaw.wasm)
- `shasum -a 256 priv/graphlaw.wasm` → `b7664a5e2131…43121` — matches sidecar; unchanged
- `ggen --version` → 26.9.28 available
- No sync run, no cargo build/test: the design conflict + digest pin make them
  moot for this lane; running them would not change the BLOCKED verdict.

## Receipt fields

- identity: lane W641c, ~/graphlaw @ 1869a16, branch graphlaw-registry-limits
- authority: operator adoption prompt (lane W641c), delegated commit authority
  (unexercised — nothing to commit)
- consequence: zero bytes changed in ~/graphlaw; receipt file only in ~/xaas
- replay: re-read the four template-vs-lib.rs rows above against
  `wasm/src/lib.rs` and `templates/guest/ffi.rs.tmpl` at any SHA
- standing: BLOCKED(integration-design-needed); falsifier = an accepted
  integration design + a pack .rq query that lands a byte-identical-contract
  generated ffi.rs and a disclosed digest-rotation receipt
