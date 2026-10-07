# W616 Receipt — Canonical Anti-Vacuity Refusal Ledger (v26.10.7 WP-6)

- **Subject**: `/Users/sac/xaas` @ branch `feat/playwright-surface` (working tree, uncommitted — lane contract: no commit)
- **Standing**: PARTIAL_ALIVE — emit + digest replay + fake-variant mutation court witnessed ×2 fresh roots; artifact not committed
- **Mode**: CONSTRUCT (lane W616, v26.10.7 campaign)

## Landed

1. `lib/xaas/operations/refusal_ledger_export.ex` — `Xaas.Operations.RefualLedgerExport`
   (sic: `Xaas.Operations.RefusalLedgerExport`), thin-shell design over real repo
   reads (Chicago: real files, real parse, no mocks).
2. `lib/mix/tasks/xaas.export_refusal_ledger.ex` — `mix xaas.export_refusal_ledger [--court]`.
3. `docs/cro/artifacts/refusal-ledger-v26.10.7.jcs.json` — the emitted ledger artifact
   (JCS canonical, RFC 8785 via `Xaas.Semantics.Jcs`, w603 idiom reused — `Xaas.Operations.AuthorityLedgerExport`
   read as the canonicalization exemplar, not duplicated).
4. This receipt.

## Vocabulary census (grounded this session, read from source)

| source | grounded at | atoms contributed |
|---|---|---|
| v26.10.6 refusal ledger | `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json` (71 variants; projected by `Xaas.Semantics.AiroRiskMapping` W984bj/ce) | 71 |
| eyerun EU-gate codes | `/Users/sac/wasm4pm/crates/eu_gate/src/lib.rs` `RefusalCode::as_str` (lines 39–43, per W613 receipt read) | 5 |
| typed-gap register | `lib/xaas/semantics/authority_channel.ex` `@type transmit_result` (:72/:73) | 2 |
| `Xaas.Semantics.Vkg` | `vkg.ex:56`, `vkg/witness.ex:152`, `vkg/replay.ex:95`, `vkg/query.ex:151`, `vkg/workspace.ex:158`, + `REFUSED_VKG_MANIFEST` (ash_r2rml manifest.ex:49 surfaced at `vkg.ex:53`) | 6 |

Raw census 84; merged by atom across sources → **77 canonical entries**
(76 `REFUSED_*` + 1 `BLOCKED_CASTLE_TRANSPORT`), sorted by atom, JCS-encoded.

Per-entry shape: `{atom, sources, minters, pinning_court, mutation_kill{killed, receipt}}`.

## Court (witnessed, ×2 fresh roots)

`mix xaas.export_refusal_ledger --court` (fresh `MIX_BUILD_ROOT=_build-laneW616`,
PATH asdf shims, MIX_ENV=test), artifact deleted between runs:

- **Leg 1 (full-vocabulary emit succeeds)**: `emitted: .../refusal-ledger-v26.10.7.jcs.json` — the emit
  itself is the anti-vacuity proof: all 77 entries cite pinning courts that exist on disk
  (77/77 court_cited in the artifact counts block).
- **Leg 2 (digest replay)**: sha256 `203fee7cd4ec9d7c68d4621469cac248c774a8c102ce6a1cc169f3132bea8f59`,
  re-read from disk and recomputed — MATCH, and run 2 == run 1 (deterministic, byte-identical).
- **Leg 3 (mutation leg — anti-vacuity non-vacuity)**: injected fake variant
  `REFUSED_FAKE_W616_NO_COURT` citing `test/xaas/w616_does_not_exist_test.exs` → typed
  refusal `{:error, {:unpinned_variant, %{atom: ..., reason: :court_missing, ...}}}`; emit
  fails closed, nothing written. **The court is not vacuous.**

## Counts (re-read from the emitted artifact this session)

```
counts: {"court_cited": 77, "declared": 77, "mutation_kill_verified": 7,
         "refused_atoms": 76}, hash_algorithm: sha256, entries sorted: true
```

- Per-entry citation coverage: **77/77**.
- Net-new atoms beyond the v26.10.6 ledger: `REFUSED_ENUM_VIOLATION`,
  `REFUSED_RANGE_VIOLATION`, `REFUSED_FORBIDDEN_FIELD` (eyerun, W613),
  `REFUSED_UNKNOWN_CHANNEL`, `REFUSED_NO_INCIDENT_EVIDENCE` (typed-gap register),
  `REFUSED_VKG_MANIFEST` (Vkg/r2rml). `REFUSED_INFRASTRUCTURE_FAULT`,
  `REFUSED_REQUIRED_FIELD_MISSING`, `REFUSED_VKG_EMPTY_CATALOG/QUERY/REPLAY/WITNESS/WORKSPACE`,
  `REFUSED_EUAIA_MANIPULATIVE` merged (already ledger-covered) — sources unioned per entry.
- Mutation-kill receipts: 7 entries carry `mutation_kill.killed=true` with receipt citation
  (the w705 kill set: ARITHMETIC_OVERFLOW, EUAIA_MANIPULATIVE, MALFORMED_MARGIN_INPUT,
  NON_UNIQUE_SEMANTIC_IDENTITY, REQUIRED_FIELD, XAAS_IDEMPOTENCY_MISMATCH,
  XAAS_PROJECTION_MISMATCH) — citations inherited from the source ledger's `note` fields.

## Falsifiers that fired and were repaired in-session

- `repo_root` resolved one level short (`Path.expand("../..", __DIR__)` from
  `lib/xaas/operations/`) → first real emit refused on an entry whose court exists
  (`BLOCKED_CASTLE_TRANSPORT`); fail-closed gate fired correctly on a parser bug, not on
  a real vacuity. Fixed to `../../..`, emit then still refused on
  `REFUSED_LIFECYCLE_EVIDENCE`'s annotated citation form
  `"test/eu_ai_act/title_iii_test.exs (deepen_kind :vuln_lifecycle)"`;
  `court_file/1` now strips ` (annotation)` and `:LINE` suffixes. All 71 source fixtures
  verified present on disk (python audit, 0 missing).
- v26.10.6 ledger has no per-variant `note` field on non-killed entries; `kill_receipt/1`
  falls back to the w320 audit citation for killed entries lacking a note.

## Disclosures

- **BLAKE3**: not in `mix.lock` (real grep this session — no `blake3` entry). Digest is
  SHA-256, disclosed in the module doc, the artifact (`"hash_algorithm": "sha256"`), and here.
- **w603 reuse**: canonicalization idiom (JCS facade `Xaas.Semantics.Jcs`, sorted entries,
  no wall-clock, typed fail-closed errors) reused from `Xaas.Operations.AuthorityLedgerExport`;
  no logic duplicated.
- **Vkg line cites**: `vkg/workspace.ex:158` verified by grep; `vkg/query.ex:151`,
  `witness.ex:152`, `replay.ex:95` verified by grep. `REFUSED_VKG_EMPTY_CATALOG` is
  structurally unreachable per the pinning court (`vkg_refusal_negative_test.exs:94`)
  — carried into the ledger as-is (the ledger records the citation, not a reachability claim).
- **Not committed** (lane contract). No dev compile; MIX_ENV=test lane build root only.
- Pre-existing unrelated warnings in the compile output (`ash_affidavit`, `approval_causal_anatomy`,
  `xaas.airo.compile_shacl`) are not session-introduced.

## Exclusions / next hops

- Coordinator: integrate artifact + module + task; the ledger regeneration is now a single
  command (`mix xaas.export_refusal_ledger --court`) for future refreshes.
- Per-variant kill receipts for the 7 killed entries cite the w705 notes verbatim; a future
  wave could split these into per-variant receipt paths.
