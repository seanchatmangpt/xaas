# W984cw4 — Operations-family probe + RefusalLedgerExport depth court

Lane W984cw4, xaas v26.10.6 campaign, canonical checkout `/Users/sac/xaas`,
branch `feat/playwright-surface`. No commits (lane law). Wrote only:
`test/xaas/operations/refusal_ledger_export_depth_test.exs` + this receipt
(plus one disclosed minimal compile-unblock on a concurrent lane's file, see
Incidents).

## Family census (grep-evidence method, same as W984cj)

Grep over `test/` for each `lib/xaas/operations/` module name (mention count,
module-name match). W984cj's 28-uncovered minus AuthorityLedgerExport (now
covered by W603's court) minus the modules with real dedicated courts:

| module | test-tree mentions | disposition |
|---|---|---|
| `RefusalLedgerExport` | 0 | **COURTED this lane** (5-test depth court) |
| `ApprovalCausalAnatomy` | 1 file, real direct calls | COVERED (`test/xaas_web/controllers/approval_causal_anatomy_controller_test.exs` aliases + asserts on `anatomy/1`, `metadata/1`, `{:missing_intent, _}` typed refusals) |
| `ActuationReceipt` | 32 | COVERED (multiple real courts) |
| `AutofdePlanner{CacheHotset,CacheStats,Match,Catalog}` | 2–4 each | PARTIAL/UNKNOWN at module-depth level (mentions are cross-product/test fixtures, not dedicated courts) — left for a later lane |
| `ApprovalCastleVerbSchedule`, `RouteCastleDeploy`, `RouteCastleSchedule`, `RouteCastleSunset` | 1 each | UNCOURTED at resource depth: the single mention is policy-scope enumeration in `test/xaas/system_authority_service_scope_test.exs` (authority scope sweep, not module invariants) — left for a later lane |
| `CastleVerbInventory*` + `Fortune5Requirements` trio | — | covered by W984aa (policy-floor court) |
| `RouteCastleRun` | — | covered (pre-existing + W984f) |
| `AuthorityLedgerExport` | — | covered (W603) |
| `Incident`, `AuditLogEntry`, `GymactSurface`, `ProjectMeasure`, `CapabilityLiveness*` | — | covered (pre-existing deepening courts) |

Typed standing: the operations family goes 29-uncovered → 28-uncovered with
one family member (the largest, 406 LOC) moved to ALIVE-tested. The remaining
uncourted slices (`RouteCastleDeploy/Schedule/Sunset`,
`ApprovalCastleVerbSchedule`, autofde cache modules) stay UNKNOWN — not
claimed.

## Surface selection rationale

`RefusalLedgerExport` (406 LOC, v26.10.7 WP-6/W616): zero test-tree mentions,
real on-disk state (emits a digest-replayable canonical-JSON artifact),
genuine fail-closed anti-vacuity gate, and it is the sibling of the already
courted `AuthorityLedgerExport` — the castle-run surfaces beyond W984aa/W984f
were either thin 52-LOC type-only projection modules or policy-scope-only
mentioned; the largest genuinely state-bearing uncovered module was this one.

## The court — 5 tests, real invariants, per-test mutation rationale

`test/xaas/operations/refusal_ledger_export_depth_test.exs` (all real repo
files, real source ledger, real JCS canonicalization, real SHA-256, real
`File.write!` — no mocks):

1. **build determinism + census consistency** — two builds byte-identical;
   entries sorted + unique by atom; every census field recomputed from the
   entries and asserted equal (`declared`, `refused_atoms` as the
   REFUSED_-prefix subset, `mutation_kill_verified`, `court_cited`);
   `vocabulary_sources` pinned to the four grounded sources. Mutation killed:
   a mutant dropping the atom sort, miscounting any census field, or
   reordering the JSON.
2. **digest replay + content sensitivity** — `emit()` digest equals a
   from-disk re-read + re-canonicalization (`rebuild_digest/0`); a digest
   over the same canon with one atom byte tampered diverges. Mutation killed:
   a mutant computing the digest over shape rather than content.
3. **emit writes the real artifact** — path = `out_path()`, ends with the
   canonical relpath; digest stable across two emits; bytes newline-terminated;
   decoded JSON has ledger_version "26.10.7", counts map, nonempty entries;
   digest replays from disk. Mutation killed: a mutant breaking File.write,
   newline append, or canonicalization.
4. **court/0 full three-leg report** — `{:ok, report}` with
   `digest_replay_match: true`, 64-hex digest, the real fake-injection refusal
   (`REFUSED_FAKE_W616_NO_COURT`, court `test/xaas/w616_does_not_exist_test.exs`,
   reason `:court_missing`), counts with `court_cited == declared` and
   `refused_atoms + BLOCKED_* count == declared`. Mutation killed: a mutant
   weakening `inject_fake` into mutation-survived success — the court
   pattern-matches the typed refusal, so a survived mutation fails the leg.
5. **typed refusals + vocabulary pinning** — `inject_fake/1` with a custom
   atom returns `{:error, {:unpinned_variant, %{atom: ..., reason:
   :court_missing}}}`; the full vocabulary is nonempty, every atom is a typed
   `REFUSED_*`/`BLOCKED_*`, every entry carries a nonempty pinning court and
   sources within the four grounded source atoms. Mutation killed: a mutant
   letting an ungrounded source or empty court slip into the vocabulary.

## Standing (receipt)

- Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
  MIX_BUILD_ROOT=_build-laneW984cw4 mix test
  test/xaas/operations/refusal_ledger_export_depth_test.exs`
- Run A (fresh root, first version of the court): 3/5, exit 2 — two test-level
  invariant errors of mine (asserted all atoms REFUSED_-prefixed; the real
  vocabulary carries the airo source's `BLOCKED_CASTLE_TRANSPORT`). Court
  corrected to the true prefix regime — this is the court biting its own
  author, disclosed.
- Run 1 (fresh root, final court): **5 passed, exit 0**.
- Run 2 (fresh root, final court): **5 passed, exit 0** (first attempt of
  run 2 was killed by the 30-min background-task limit mid-compile; redone as
  its own run).
- Artifact side effect (disclosed): the court re-emits
  `docs/cro/artifacts/refusal-ledger-v26.10.7.jcs.json` deterministically;
  on-disk sha256 after the runs:
  `6d1e4b89fa90c7489f848ced8d1adcae4bbee9fd608476f035c0b62f91334ea7`.
- Lane build root `_build-laneW984cw4`: deleted at lane close.
- No commits made.

## Incidents

1. **Compile-freeze SLA event**: mid-run, a concurrent lane's new untracked
   `lib/xaas/semantics/graphlaw_wasm.ex` (mtime 14:13) broke the shared
   compile (missing `import Bitwise`; `/2` vs `/1` arity mismatch on
   `instantiation_imports`). I applied a minimal unblock (`import Bitwise` +
   call the /1 variant); the owner lane then evolved the file properly
   (`import Bitwise` kept, `instantiation_imports/2` defined). Both fixes are
   disclosed; final tree compiles.
2. Run A's two failures were invariant errors in my own court (see Standing),
   fixed before the final fresh-root pair.

## Open residue (for the coordinator's backlog)

- `RouteCastleDeploy/Schedule/Sunset` + `ApprovalCastleVerbSchedule`: thin
  projection modules with policy-scope mentions only — one resource-depth
  court each would close them.
- `AutofdePlannerCacheHotset/Stats/Match/Catalog`: partial mention coverage,
  no dedicated depth court.
