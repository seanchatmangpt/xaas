# How-to: Run purchase-policy assessment through the pinned GraphLaw WASM seam

Verified 2026-10-08 against the working tree at `819c116f` (post-d5dd780a).
Every claim is grounded in the cited file and line range on this tree.

## The assess path at a glance

`Xaas.Bridges.Graphlaw.assess/2` (`lib/xaas/bridges/graphlaw.ex:84-158`):

1. Renders the purchase claim into N-Triples facts (`purchase_facts/2`,
   `lib/xaas/bridges/graphlaw.ex:44-61`) and SHACL shapes
   (`purchase_shapes/1`, `lib/xaas/bridges/graphlaw.ex:64-74`), gated by the
   JSON-depth gate (`lib/xaas/bridges/graphlaw.ex:87-99`) and the engine
   byte-limit gates (`gate_engine_limits/3`,
   `lib/xaas/bridges/graphlaw.ex:214-231`: abi `max_request_bytes` 16 MiB,
   n3 `n3_max_term_bytes` 64 KiB, `n3_max_total_bytes` 256 MiB — all through
   `Xaas.Graphlaw.LimitGate.enforce/2`).
2. With no explicit `:server` opt (the product path), the rendered request
   `%{"op" => "law", "data" => ..., "steps" => ...}` goes through `wasm_law/3`
   (`lib/xaas/bridges/graphlaw.ex:175-196`) to
   **`Xaas.Semantics.GraphlawPool.invoke/2`**. An explicit `:server` opt
   dispatches through the legacy dep host/pool layer (`AshGraphLaw.law/3`,
   `lib/xaas/bridges/graphlaw.ex:117-122`) — the legacy contract, not the
   product path. If the pinned transport returns a typed
   `Xaas.Actuation.Refusal`, the bridge falls back to the legacy dispatch so
   behavior only upgrades (`lib/xaas/bridges/graphlaw.ex:127-137,169-196`).
3. The pool boots ONE pinned instance lazily on the first call and holds it
   for the process lifetime (`lib/xaas/semantics/graphlaw_pool.ex:14-33`).
4. The pool delegates to **`Xaas.Semantics.GraphlawWasm`**
   (`lib/xaas/semantics/graphlaw_wasm.ex`, 569 lines), the wasmex host
   transport for the graphlaw kernel.

## GraphlawWasm: admission, FFI, watchdog, refusals

### Admission (`start/2`, `lib/xaas/semantics/graphlaw_wasm.ex:127-138`)

Fail-closed, in order:

1. Read the artifact bytes (`:file_unreadable` on failure,
   `graphlaw_wasm.ex:251-260`).
2. SHA-256 digest-pin verification (`verify_digest/2`,
   `graphlaw_wasm.ex:150-173`).
3. Compile on a REAL WASI store (`Wasmex.Store.new_wasi/1`,
   `graphlaw_wasm.ex:265-274`). Zero-value WASI stubs are retired: they trap
   on real `op:"law"`/`op:"shacl"` workloads (W640 differential court,
   finding (c); module doc `graphlaw_wasm.ex:111-117`).
4. WASI import-surface judge against the hard allowlist `@wasi_allowlist`
   (`graphlaw_wasm.ex:64-77`; judge at `judge_imports/2`,
   `graphlaw_wasm.ex:183-206`): every import must be
   `wasi_snapshot_preview1` and on the list with an exact signature match;
   anything else refuses `:import_surface_mismatch`.
5. Required exports judge (`judge_exports/2`, `graphlaw_wasm.ex:324-345`):
   `memory`, `gl_alloc`, `gl_free`, `gl_call`; anything missing refuses
   `:missing_export`.

### Digest pin

The digest is host-authoritative lower-hex SHA-256 over the artifact bytes
(`digest/1`, `graphlaw_wasm.ex:141-144`). Pin sources in precedence order
(`pin_for/1`, `graphlaw_wasm.ex:276-284`): the `:expected_sha256` opt, then
Application env `:xaas, :graphlaw_wasm_sha256`, then the pin file
`priv/graphlaw.wasm.sha256` (also read at compile time,
`graphlaw_wasm.ex:79-88`). No pin source refuses `:digest_unpinned`
(`graphlaw_wasm.ex:168-173`). The current pin:

```text
fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38  priv/graphlaw.wasm
```

The seam court (`test/xaas/semantics/graphlaw_wasm_seam_test.exs`) pins this in
test: digest == pin file == bytes on disk (test at
`graphlaw_wasm_seam_test.exs:28-37`), plus the two-leg discriminator — with the
pool poisoned via the Application-env pin, assess names the legacy dep engine
digest `7bb2a7e5...`; with the pool healthy, the envelope names `fc23a292...`
(moduledoc `graphlaw_wasm_seam_test.exs:3-13`).

### Guest ABI (packed u64)

Guest exports `gl_alloc(len) -> ptr`, `gl_free(ptr, len)`, and
`gl_call(in_ptr, in_len) -> packed u64`, plus the exported linear `memory`
(module doc, `graphlaw_wasm.ex:16-22`). `invoke/3`
(`graphlaw_wasm.ex:216-234`) encodes the request as UTF-8 JSON, `gl_alloc`s the
input buffer, writes the bytes into linear memory, calls `gl_call`, and unpacks
the result as `(out_ptr <<< 32) | out_len` (`invoke_packed/6`,
`graphlaw_wasm.ex:488-517`). `gl_call` consumes the input buffer, so the host
never `gl_free`s it after a completed call (`graphlaw_wasm.ex:223-225`).

### Input-buffer ownership (leak-window fix)

`with_input_buffer/3` / `with_buffer/3` (`graphlaw_wasm.ex:244-247,443-468`)
guarantee the input buffer is deallocated on every non-consumed exit path —
pre-call failure, raise, or host-side exit — while a guest-consumed buffer is
never double-freed. The raise/exit cleanup is exception-safe and re-raises /
re-exits with the original payload so the outer `guard/1` still classifies
exits as `:call_timeout`/`:call_trapped` unchanged
(`graphlaw_wasm.ex:431-442`). The seam court drives the raise and exit paths
with real collaborators, no mocks
(`test/xaas/semantics/graphlaw_wasm_seam_test.exs`, raise leg at lines 39-56).

### Watchdog and typed refusals

Timeouts are layered:

| Layer | Default | Where |
|---|---|---|
| Transport watchdog default | 15 ms | `@call_timeout_ms 15`, `graphlaw_wasm.ex:57-58`, applied via `timeout/1` (`:363`) in `invoke_packed/6` (`:491`) |
| Bridge ceiling passed as opt | 5 000 ms | `@wasm_timeout_ms`, `graphlaw.ex:24-26`, applied `:177` |
| Pool GenServer call timeout | opts timeout + 5 000 ms | `graphlaw_pool.ex:139-142` |
| Pool default opts timeout | 5 000 ms | `@default_timeout_ms`, `graphlaw_pool.ex:41` |

Every rejected operation returns
`{:error, %Xaas.Actuation.Refusal{}}` with a `:code` from the closed set in the
module doc (`graphlaw_wasm.ex:37-46`): `:digest_unpinned`, `:digest_mismatch`,
`:invalid_wasm`, `:import_surface_mismatch`, `:missing_export`,
`:file_unreadable`, `:invalid_encoding`, `:resource_limit`, `:abi_failure`,
`:call_trapped`, `:call_timeout`, `:invalid_json`, `:malformed_response`.

Request/response byte limits: `@max_request_bytes` / `@max_response_bytes` are
1 MiB each at the transport (`graphlaw_wasm.ex:59-60`, enforced at
`:366-374` and `:531-534`).

Sticky-failure semantics live at the pool: a failed lazy boot stays sticky
(returned on every call) until `GraphlawPool.reset/0`
(`graphlaw_pool.ex:20-23,160-161,135`); after a trap, timeout, or ABI failure
the pool recycles the instance instead of reusing it
(`graphlaw_pool.ex:107-112`).

## GraphlawPool: lazy-boot contract, serializing pool-of-one

`lib/xaas/semantics/graphlaw_pool.ex` (180 lines):

- **Lazy boot**: the pool is NOT in the application supervision tree; the
  first `invoke/2` pays the compile cost (`graphlaw_pool.ex:29-33,101-121,158-173`).
- **Pool-of-one**: `gl_alloc`/`gl_call`/`gl_free` transactions run inside the
  GenServer, one at a time — one core of throughput, exact-artifact identity
  (`graphlaw_pool.ex:24-27`).
- **Recycle-on-poison**: trap/timeout/ABI-failure outcomes drop the instance
  so the next call re-boots (`graphlaw_pool.ex:107-112`).
- **`info/0`** returns the digest + path the instance was booted from
  (`graphlaw_pool.ex:66-77,124-132`) — what the bridge uses to stamp
  `engine_sha256` into the verdict envelope (`graphlaw.ex:160-167,246-262`).
- **`reset/0`** drops a sticky start error (`graphlaw_pool.ex:79-89,135`).

## Operational notes

- Verify the seam with the narrow falsifier:
  `mix test test/xaas/semantics/graphlaw_wasm_seam_test.exs` (8 courts).
- The legacy `:server` opt remains a supported contract for dead-server courts
  (`:host_not_started` passthrough, `graphlaw.ex:115-122`); do not add new
  product callers through it.

## See Also

- `lib/xaas/semantics/graphlaw_wasm.ex`, `lib/xaas/semantics/graphlaw_pool.ex`,
  `lib/xaas/bridges/graphlaw.ex`
- `test/xaas/semantics/graphlaw_wasm_seam_test.exs`
- `docs/claude/diataxis/reference/actuation-and-semantics.md`
