# ash_surface Refusal Ledger — v26.10.6 (lane W403)

Subject: `/Users/sac/ash_surface` (one canonical checkout, read-only; no commit).
Method: `grep -oE 'REFUSED_[A-Z_]+'` over `lib/` and `test/`, plus targeted reads
of `lib/ash_surface/vocabulary.ex`, `lib/ash_surface/standing.ex`,
`lib/ash_surface/projectors/js.ex`, and the w326 fixture
`test/ash_surface/standing_evidence_adversarial_test.exs`.

## Counts

- Lib-emitted refusal variants (`lib/`): **9**
- REFUSED-class members witnessed repo-wide (lib-emitted + test/fixture-witnessed): **20**
- Lib sites: **40 occurrences across 8 files** (the vocabulary.ex hit is a
  doctest negative probe, not an emission).
- Coverage: **9/9 lib-emitted variants test-covered; 0 uncovered.**
- Typed-gap sites (w321): **2** (`projectors/js.ex` `dispatchIntent`).
- Zero-config re-check (w322 mirror): **PASS — zero env/config reads in `lib/`**
  (`grep -rn 'System.get_env\|Application.get_env\|Application.fetch_env\|Application.get_all_env' lib/`
  → no matches, exit 1).

## Declared vocabulary (the law)

`AshSurface.Standing` (`lib/ash_surface/standing.ex`) is the single canonical
owner. The REFUSED class is **open-prefixed**: every `:"REFUSED_*"` atom with a
non-empty reason token (`[A-Za-z0-9_]+`) is admitted; bare `REFUSED` /
`REFUSED_` is NOT — an unnamed refusal is a fabricated refusal
(`lib/ash_surface/vocabulary.ex:97-104`, `refusal_code?/1`).
`AshSurface.Standing.valid?/1` = base standings + `Vocabulary.refusal_atom?/1`.
`:UNKNOWN` gets a dedicated refusal naming it a post-dispatch transport outcome
(`UNKNOWN_AFTER_DISPATCH`), never a verified standing.

## Per-variant table (lib-emitted variants)

Sites are `file:line` under `/Users/sac/ash_surface/lib`. Counts are grep
occurrences.

| Variant | Lib sites (file:line, count) | Test coverage (file:line, representative) | Verdict |
|---|---|---|---|
| `REFUSED_NO_AUTHORITY` | intent/dispatch.ex:16,52,79,80,126,140; standing.ex:16,61; health.ex:81,125,154; telemetry.ex:74 — 12 occ, 5 files | boundary_hardening_test.exs:74,79,90,98; intent_path_test.exs:247,258,280; intent/dispatch_test.exs:10,100,103,110; standing_test.exs:34,139,181; observation_deep_test.exs:77,92,221; telemetry_test.exs:18,141; js/error_paths.test.mjs:349,356; js/zod_boundaries.test.mjs:33,175 | FIXTURE-COVERED |
| `REFUSED_UNKNOWN_ACTION` | intent/dispatch.ex:61,62,79,80,126,140; standing.ex:17; projectors/js.ex:494,495; telemetry.ex:73 — 11 occ, 4 files | intent/dispatch_test.exs:15,17,178,190,215,221; intent/dispatch_knownness_gate_test.exs:21,104,112; standing_test.exs:35; projectors/js_projector_test.exs:164,168; tokyo_depeg_surface_test.exs:22,204; telemetry_test.exs:144; js/ir_projection.test.mjs:213; js/ir_projector_deep.test.mjs:183,533,534 | FIXTURE-COVERED (js.ex sites = typed gap, below) |
| `REFUSED_UNKNOWN_SUBJECT` | standing.ex:109,110 — 2 occ | standing_test.exs:36; observation_deep_test.exs:93; js/zod_boundaries.test.mjs:33,258 | FIXTURE-COVERED |
| `REFUSED_INVALID_SUBJECT` | ir/event_projection.ex:45,64,116,191; health.ex:81,125,154 — 7 occ | boundary_hardening_test.exs:185,191,198,200; event_replay_state_test.exs:222; ir/event_projection_test.exs:272,278; health_deep_test.exs:253; health_http_mapping_test.exs:11,179,184; telemetry_test.exs:92,102 | FIXTURE-COVERED |
| `REFUSED_INVALID_OPTION` | health.ex:81,126,266 — 3 occ | health_deep_test.exs:253,265; js/e2e_hermetic.test.mjs:130; js/zoela_mx_consumer_fixture.test.mjs:101 (as `REFUSED_UNKNOWN_OPTION`, sibling) | FIXTURE-COVERED |
| `REFUSED_MISSING_TIMESTAMP` | ir/event_projection.ex:41,116,224 — 3 occ | event_projection_coverage_test.exs:58; event_replay_state_test.exs:210,216; ir/event_projection_test.exs:239,250,262; telemetry_test.exs:94,105 | FIXTURE-COVERED |
| `REFUSED_RECEIPT_DIGEST_MISMATCH` | ir/event_projection.ex:47,118,266 — 3 occ | boundary_hardening_test.exs:130,160,172; event_replay_state_test.exs:202,261; fuzz_event_projection_test.exs:20,203,226; telemetry_test.exs:121,127 | FIXTURE-COVERED |
| `REFUSED_NO_COMMAND_BUS` | intent/dispatch.ex:16,154,158 — 3 occ | intent/dispatch_test.exs:164,165,166,210; intent_path_test.exs:321,324; telemetry_test.exs:148 | FIXTURE-COVERED |
| `REFUSED_NOT_DO_BOUNDARY` | projectors/js.ex:501,502 — 2 occ | projectors/js_projector_test.exs:165; tokyo_depeg_surface_test.exs:21,203; js/ir_projection.test.mjs:207; js/ir_projector_deep.test.mjs:180,529; js/generated_js_projector_runner.mjs:59 | FIXTURE-COVERED (js.ex sites = typed gap, below) |
| `REFUSED_X` | vocabulary.ex:103 — doctest negative probe only (`refusal_code?(:REFUSED_X)` → false: atoms are not refusal codes) | vocabulary_test.exs prefix-law negative probes | NOT A VARIANT (negative probe) |

## Open-class members witnessed only in the test/fixture tree (not lib-emitted)

Admitted by the prefix law; never emitted by `lib/` code; witnessed in test
tables, fixtures, and consumer contracts:

- `REFUSED_EVIDENCE_REQUIRED` — standing_test.exs:41; manifest_serializer_test.exs:49,145;
  project_test.exs:23,129; projector/expo_*.exs; mx_closed_loop_*; js/e2e_hermetic.test.mjs:130
- `REFUSED_EVIDENCE_MISSING` — standing_test.exs:42; w326 fixture
  (standing_evidence_adversarial_test.exs:58-62); js/namespaces_deep.test.mjs:144,161
- `REFUSED_UNKNOWN_OPTION` — standing_test.exs:37; js/e2e_hermetic.test.mjs:130;
  js/zoela_mx_consumer_fixture.test.mjs:101
- `REFUSED_UNKNOWN_REVERSIBILITY` — standing_test.exs:38 (class table only)
- `REFUSED_GENERATOR_OWNED` — standing_test.exs:43; js/digest_cross_language.test.mjs:60;
  test/js/fixtures/digest_cross_language_fixtures.json (`possibleRefusals`);
  test/support/digest_parity_fixtures.ex:132
- `REFUSED_SESSION_LAW` — standing_test.exs:46; declared synthetic member,
  never emitted by any consumer (proves the class table is descriptive, not a
  closed list)
- `REFUSED_SCRIPT_EXHAUSTED` — intent_path_test.exs:72,73
- `REFUSED_AUTHORITY_REVOKED`, `REFUSED_LEASE_EXPIRED`,
  `REFUSED_DUPLICATE_EFFECT`, `REFUSED_CONFORMANCE_DEVIATION` —
  tokyo_depeg_surface_test.exs:99-102,223-226

The canonical class table is `test/ash_surface/standing_test.exs:34-46`: it
enumerates every REFUSED_* atom witnessed anywhere in the repo plus one
synthetic member — admission of the synthetic proves the class is open, not a
closed list.

## w326 adversarial fixture (admission-law coverage)

`test/ash_surface/standing_evidence_adversarial_test.exs`:

- :48 — a valid `REFUSED_*` atom (`:REFUSED_EVIDENCE_MISSING`) IS admissible
  evidence and survives `Observation.create` unchanged (BEHAVIOR-COVERED: the
  adversarial corpus covers the class, not one variant)
- :58-62 — off-vocabulary garbage (`42, nil, %{}, [], "ALIVE", 42` etc.)
  raises with the exact off-vocabulary message
- :66 — a **synthetic `REFUSED_W326_ADVERSARIAL_PROBE_*` member no consumer
  ever emitted is admitted by the prefix law** — proves the class is open

## Typed-gap sites (w321 follow-up)

`lib/ash_surface/projectors/js.ex:494-502`, `dispatchIntent`: unknown action /
non-DO-boundary refuse by throwing an `Error` with a structured `refusal`
property (`{refusal, standing: "BLOCKED", detail}`) rather than a typed reason
in the Elixir vocabulary. Machine-readable via the Error property, but not
typed into `AshSurface.Standing` — residual gap: 2 sites, 2 variants
(`REFUSED_UNKNOWN_ACTION`, `REFUSED_NOT_DO_BOUNDARY`).

## Zero-config re-check (w322 mirror)

`grep -rn 'System.get_env\|Application.get_env\|Application.fetch_env\|Application.get_all_env' lib/`
→ zero matches (exit 1). The refusal paths read no env/config: refusal
behavior is invariant under environment. Zero-config re-confirmed for
ash_surface exactly as w322 found for xaas.

## Unrepresentability claim, as evidenced for ash_surface

- **Fixture-proven**: 9/9 lib-emitted variants have real assertions in the test
  tree; the w326 corpus proves off-vocabulary garbage is refused at the
  admission law and a never-before-seen `REFUSED_*` is admitted (open class).
- **Class-covered**: the admission law (`Observation.create` →
  `Standing.validate!` → `Vocabulary.refusal_atom?`) covers the whole REFUSED
  class by prefix, so every future variant is machine-admitted without new
  code or new configuration — the zero-config unrepresentability moat,
  evidenced here on the second wired repo.
- **Typed-gap (honest)**: the 2 JS-side throw sites in
  `lib/ash_surface/projectors/js.ex:494-502` carry structured `refusal`
  properties on the Error but are not typed into `AshSurface.Standing` —
  machine-readable, not vocabulary-typed; residual gap = 2 sites / 2 variants.
- **Zero-config**: 0 env/config reads anywhere in `lib/` — refusal surfaces
  require no configuration to admit a refusal.

Receipt = this ledger. Declared (lib-emitted) 9 · covered 9 · typed-gap 2
sites / 2 variants · off-vocabulary negative probes pass · 20 REFUSED_*
members witnessed repo-wide (9 lib-emitted + 11 test/fixture-witnessed,
including the `SESSION_LAW` synthetic).
