# W767 — Xaas.Bridges.Registry deepening court — receipt

**Lane**: W767, xaas v26.10.6 campaign. Canonical checkout `/Users/sac/xaas`,
branch `feat/playwright-surface`, HEAD `a0723bf6`.
**Files written**: `test/xaas/bridges/registry_deepening_test.exs` (new) + this receipt. No lib changes.
**Standing**: PARTIAL_ALIVE — registry surface verified by observed execution; 14/14 real ExUnit run.

## Subject

`Xaas.Bridges.Registry` — the composition-root bridge registry (Chicago-layer
bridge capability: real bridges + truthful absences). Static compile-time
literal entries; 0-arity projection surface (`all/0`, `ids/0`, `absences/0`).
Doctrine-central (connector object ≠ mounted tree); previously undocketed as
its own court — W716 covered the ferroplan engine, not the registry.

## Backlog phrasing vs. live registry (typed divergence)

The backlog described "ferroplan/gymact/ash_a2a rows with state :bridge and
standing UNKNOWN". The live registry has **no gymact or ash_a2a rows**. Real
contents (pinned by court (a)):

- 5 bridge rows: `pplan, graphlaw, ex4pm, sa2a, ferroplan` — state `:bridge`, standing `"UNKNOWN"`, capability `{:bridge, Module}`
- 5 typed absences: `beam4pm, graphlaw_rust, affidavit_cli, ash_r2rml, wasm4pm` — state `:unsupported`, standing `"UNSUPPORTED"`, capability `{:unsupported, reason}`

The code is the live ontology; this court pins the real row set, and the
divergence is recorded here rather than silently matching the backlog prose.

## Real commands and output tails

Toolchain: asdf shims per repo `.tool-versions` (elixir 1.20.4-otp-29),
`MIX_ENV=test MIX_BUILD_ROOT=_build-laneW767`.

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW767 \
  mix test test/xaas/bridges/registry_deepening_test.exs
Running ExUnit with seed: 843068, max_cases: 32
Finished in 0.1 seconds (0.00s async, 0.1s sync)
Result: 14 passed
```

Earlier seeded run: `seed: 997377` → `13/14 passed, Failed: 1` — the single
failure was a real court catch: the "no non-projection exports" assertion did
not exempt the implicit `__info__/1` export; fixed by excluding
`__info__/1`/`module_info` (implicit compiler exports, not registry surface).
Fix-forward, rerun green.

## Court coverage (a–e)

- **(a) Exact row set**: id set is exactly `pplan, graphlaw, ex4pm, sa2a,
  ferroplan` + `beam4pm, graphlaw_rust, affidavit_cli, ash_r2rml, wasm4pm`
  (10 rows); bridge/absence partition exact; `absences/0` keys match absence
  rows; each `{:bridge, module}` is `Code.ensure_loaded?/1`-verified; each
  `{:unsupported, reason}` byte-matches `absences()[id]`.
- **(b) Vocabulary validity**: bridges are `:bridge`/`"UNKNOWN"`, absences
  `:unsupported`/`"UNSUPPORTED"`; standing vocabulary limited to the rendered
  R2/R8 strings; every row carries the exact Chicago subject
  (`urn:chicago:agentic-payment:purchase-001`), `authority_ceiling: :none`,
  `evidence_ref: nil`, `receipt_ref: nil`, `provenance: %{}` — no synthesized
  evidence.
- **(c) Unknown-kind registration**: typed structural gap — the registry has
  NO mutation API. Export surface is exactly the 0-arity projections; asserted
  no export name starts with register/put/add/update/upsert, and
  `register/2`, `register/3`, `absences/1` are not exported. Registering an
  unknown bridge kind is structurally impossible (compile-time literal);
  falsifier would be a mutating export appearing.
- **(d) Standing-never-silent-upgrade**: structural, not runtime — no registry
  function has arity > 0 (excluding implicit `__info__/1`/`module_info`), so
  no path accepts a receipt/standing argument; repeated evaluation
  (4×) returns identical standing with `receipt_ref`/`evidence_ref` still nil.
  Standing can only change by recompiling the literal entries — an admitted
  code transition, never a runtime silent upgrade. This IS the R8 property,
  structurally guaranteed. No gap remains here.
- **(e) Determinism**: `all/0` is a pure projection — two calls equal after
  id-sort; each row's envelope fields equal a fresh
  `Xaas.Bridges.envelope/4` with the row's own values; id list stable across
  interleaved `absences/0` calls.

## Verification ladder

Narrow (single test file, real compiled registry, real module exports, no
mocks, no stubs).Chicago-style: assertions on real state (`Registry.all/0`
output, `module_info(:exports)`), zero interaction assertions.

## Transport failures / incidents (honest disclosure)

1. First run hit the 420s foreground timeout — cold lane build root; moved to
   background, completed successfully (13/14).
2. Mid-session, `mix.exs` developed an unresolved stash-pop conflict (`UU`,
   `<<<<<<< Updated upstream` at line 254) from another concurrent session —
   not this lane's file, not touched by this lane; blocked the second mix run.
   Attempted a direct-ExUnit bypass (compiled-beam `-pa` run), which
   collected 0 tests (manual `ExUnit.run/0` after `Code.require_file/1` does
   not pick up sync suites the way mix test's at_exit hook does — bypass
   abandoned as UNSUPPORTED(runtime-bypass), no receipt-grade output). The
   conflict was resolved by the other session; rerun via mix went green.
3. First version of this receipt file was written garbled during drafting;
   overwritten clean in place. Content of record is this version.

## Standing vocabulary

- Registry surface courts (a)–(e): **PARTIAL_ALIVE** (observed execution, 14/14).
- gymact/ash_a2a bridge rows: **UNSUPPORTED(absent-from-registry)** — not
  registry rows at this HEAD; if a future wave adds them, court (a) will
  fail by design and force the receipt to be updated.
- Standing upgrade path: none at runtime (structural, per (d)).

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW767 \
  mix test test/xaas/bridges/registry_deepening_test.exs
# expect: Result: 14 passed
```

Lane build root `_build-laneW767` is deleted at integration per fanout law.
