# v26.10.7 Fleet Closure Receipt — DRAFT-pending-final-runs

Status: **DRAFT-pending-final-runs** (v2, second pass by lane W650c; delta
receipt `plans/w650c-closure-v2.md`). Every claim cites its lane receipt under
`docs/sjira/v26.10.7/plans/` (or the v26.10.6 corpus where the witness landed
there). DRAFT flags mark items pending a final run, commit, or receipt. This
file itself is unwritten-final: no commit per lane contract.

Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD `56325fa5`
(v26.10.7 version-bump seal, `w617-version-bump.md`), tagged `v26.10.7`
remote object `ccad2a59` (W649, `plans/w649-fleet-tag6.md`).

## 1. Statutory census (eu_ai_act gate): 1352 passed / 0 failed / 1 excluded

Witnessed repeatedly across the campaign; gate command
`mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap`
vs the w981x/w982w settled floor (≥1352/0):

| witness | subject | receipt |
|---|---|---|
| cf228da6 (lane W633 window) | `cf228da6632829...` | attribution gap closed: no 1352 line exists at cf228da6 itself; closure now rests on the HEAD witness below, not on this row (W650b) |
| **HEAD confirming witness (W650b, 2026-10-07)** | `56325fa5` (v26.10.7 seal HEAD) | `plans/w650b-open-items.md` — 1352 passed / 0 failed / 1 excluded, exit 0, fresh lane root `_build-laneW650b` (full from-scratch compile). First run at same subject: 1351/1352 + 1 flake (`counterfactual_test.exs:597` port crash under 32-way async; file passes 26/26 in isolation and full census passes clean on rerun — flake classified, not a regression). Supersedes the never-landed W984dj draft basis |
| mid-GraphQL-removal tree | 5f7f70d9, 182 dirty files | `~/xaas/docs/sjira/v26.10.6/plans/w984ax-euaia-rewitness.md` — ALIVE-PASS, 1352/0/1, exit 0 |
| post-removal re-witness | 5f7f70d9 (fresh build root, from-scratch compile) | `~/xaas/docs/sjira/v26.10.6/plans/w984am-census-rewitness.md` — 1352/0/1, "PASS (1352 = floor exactly)" |

**CLOSED (W650b, 2026-10-07)**: W984dj's receipt (`plans/w984dj-census-verify.md`)
never landed — confirmed absent at W650b re-read — so W650b executed the
confirming census itself at HEAD `56325fa5` (fresh lane root
`_build-laneW650b`, from-scratch compile): **1352 passed / 0 failed /
1 excluded, exit 0**, receipt `plans/w650b-open-items.md`. This closes the
W633 attribution gap by replacement, not attribution: closure rests on a
witnessed run at the exact seal HEAD, superseding the W984dj draft basis.
One flake disclosed: first run at the same subject was 1351/1352
(`counterfactual_test.exs:597` port crash under 32-way async); the file
passes 26/26 in isolation and the full census passes clean on rerun —
classified as environment flake, not a regression. Census standing: **ALIVE
at HEAD** (final, DRAFT flag cleared).

## 2. OS-18 kill proof — actuation identity tautology eliminated

- Residual tautology in `checkpoint_external/2` found and eliminated:
  `verify_external_prepared/3` now field-by-field compares the
  admission-carried context against BOTH the intent row and the
  ActuationReceipt row; divergence → typed
  `REFUSED_ACTUATION_IDENTITY_MISMATCH` — receipt
  `plans/w601-actuation-tautology.md`.
- Witness: negative-refusal court deepened 7→10 legs, dual mutation kills
  (forged-foreign-pair + honest-resume), witnessed ×2 — `w601` + commit
  receipt `plans/w601b-tautology-commit.md`: commit `579454be`
  (exactly 3 paths; `mix test test/xaas/actuation_refusal_negative_test.exs`
  = 10 passed; `actuation_test.exs` = 5 passed; fresh-root compile exit 0).
- Standing: ALIVE (commit-level, `579454be`, not pushed at receipt time).

## 3. Canonical anti-vacuity refusal ledger — 77 entries

- Census: 84 raw → **77 canonical entries** (76 `REFUSED_*` +
  1 `BLOCKED_CASTLE_TRANSPORT`), JCS (RFC 8785) canonical, sorted by atom —
  `plans/w616-refusal-ledger.md`.
- Court: emit-leg + digest replay **MATCH** at content digest
  sha256 `203fee7cd4ec9d7c68d4621469cac248c774a8c102ce6a1cc169f3132bea8f59`,
  fake-variant mutation refused — `w616`.
- Committed: `plans/w616b-ledger-commit.md` — commit `d95defa2`
  (2 lib paths); artifact + w616 receipt landed via W629 corpus commit
  `6222135e`, byte-identity verified (`6d1e4b89fa90c748...34ea7`).
- Standing: ALIVE (emit is itself the anti-vacuity proof: 77/77
  court_cited).

## 4. Playwright surface — 371/371 + live-instance 6/6

- ash_surface re-verify at `b70da9e1c`: zero graphql/fixture-pack residue in
  `lib/`; suite 371/371, 0 skipped, real headless Chromium —
  `plans/w611-ashsurface-reverify.md`.
- vs live `~/xaas` dev instance (booted PORT 4033, private DB
  `xaas_dev_w633`): hermetic 371/371 **plus** the live-instance court
  `e2e/ash-surface-client.spec.cjs` **6/6 passed (55.2s)** —
  `plans/w633-playwright-live.md`.
- Standing: ALIVE on both surfaces; zero failures to classify.

## 5. graphlaw WASM artifact + Wasmex host

- Phase 1 (W637, ~/graphlaw): FFI merge NO-OP (already present,
  signature-exact); `[profile.wasm]` merged; WASI-pure artifact
  `priv/graphlaw.wasm` 6,657,549 bytes, digest
  `b7664a5ed21c254da1ba1a2cf497e6de23406ce935a8c6ce8a9ea8cc7ae43121` —
  `plans/w637-graphlaw-wasm-build.md`.
- Committed + pushed: commit `1869a16` on `graphlaw-registry-limits`
  (`origin` ff `0bb0df2..1869a16`); binary local-only by repo convention,
  digest sidecar `priv/graphlaw.wasm.sha256` committed —
  `plans/w637b-graphlaw-commit.md`.
- Phase 2 host (W638, `plans/w638-wasmex-host.md`): `lib/xaas/semantics/graphlaw_wasm.ex`
  + 8-leg court + wasmex 0.15.1 (already locked) — landed-uncommitted;
  court verdicts witnessed in receipt; **DRAFT(W638-commit-pending) —
  CLEARED (W984ge, 2026-10-07)**: host code committed in `2f2748b3`
  (W650g).
- **DRAFT(W640-differential-pending) — CLEARED (W984ge, 2026-10-07)**:
  differential court receipt landed (`plans/w640-differential-shacl.md`,
  ALIVE 5/5 ×2 fresh roots) and the court artifact is committed
  (`a5f81439`, W650g2). See `_GRAPHLAW_WASM_UNIFICATION_RECEIPT.md`.

## 6. Fleet tags — 8/8 tagged per W648 audit

- W635 (`plans/w635-fleet-tag.md`) minted 1/8 (ash_pplan `862f0c0`) and
  honestly BLOCKED the rest on uncommitted version bumps.
- W636b (`plans/w636b-gymact-tag.md`): gymact `__version__` drift fixed
  forward, commit `8472ffd2`, tag `62835e7c`.
- W649 (`plans/w649-fleet-tag6.md`): tagged + pushed + ls-remote-peel-verified
  6 more: xaas `56325fa5` (tag `ccad2a59`), ash_a2a `e0fb769e`, ggen
  `905d8af33`, ggen_igniter `c3cd5d2`, wasm4pm `986e5daa1`, ash_graphlaw
  `3ecae0e`. All 6 fast-forward-only, peels exact.
- Total 8/8 per W648's audit table (`plans/w648-version-audit.md`).
- **v2 fresh re-verification (W650c, 2026-10-07)**: `git tag -l v26.10.7` in
  `/Users/sac/xaas` (local tag present, peels `56325fa5`) plus `git ls-remote
  origin refs/tags/v26.10.7 refs/tags/v26.10.7^{}` in all 8 repos — 8/8
  remote tags present, every peel exact:

  | repo | tag object (remote) | peels to |
  |---|---|---|
  | xaas | ccad2a59 | 56325fa5 |
  | ash_a2a | 16bd31e2 | e0fb769e |
  | ggen | 2b753d37 | 905d8af33 |
  | ggen_igniter | 5cd97b63 | c3cd5d2 |
  | wasm4pm | 90e90b1f | 986e5daa1 |
  | ash_graphlaw | b8f65a49 | 3ecae0e |
  | ash_pplan | 37a736f6 | 862f0c0 |
  | gymact | 62835e7c | 8472ffd2 |

  No drift vs W649/W635/W636b receipts.
- **a2a post-tag doc fix (W628b, `plans/w628b-a2a-docfix.md`)**: commit
  `13dd1a57` on `feat/tck-vuln-hardening` (fast-forward push,
  e0fb769e..13dd1a57) syncs `docs/reference/a2a-spec-version-mapping.md`
  Version line v26.10.5 → v26.10.7; the two formerly-failing coherence tests
  (`SupplyChain.ReleasePathTest` + `A2ATransport.SpecMappingDocTest`) green,
  3 passed. Tag `v26.10.7` remains at `e0fb769e` — the fix rides
  post-release on the branch per the coordinator note; tag not re-pointed.
  W628's third deterministic failure (arch-verifier 300s timeout) remains
  pre-existing, untouched.
- BLOCKED noted: **ash_surface** and **ggen-marketplace** — version bumps
  uncommitted (W618-era), `BLOCKED(version-commit-pending)` per W648 item 2
  and W635 table.
- **Tag-truth verdict (W650k4, recording W650k3,
  `plans/w650k3-tag-verdict.md`, 2026-10-07)**: standing of the tag
  surface is **PARTIAL_ALIVE — truthful with disclosures, no re-point
  required**:
  1. 8/8 tags peel to ancestors of their repo's local HEAD (W650k3 §3
     table) — tag ancestry truthful.
  2. xaas: the audited tree ≠ tagged subject. Local HEAD `1b14ec1e` is
     **42 commits ahead** of the tag peel `56325fa5`, including the
     audit remediation `428ae270` (plus `5997a4a9` graphlaw courts,
     `bae6bdc1`, `ea886c6a`). Audit-green is at HEAD, not at tag; the
     seal claim must read "tagged at `56325fa5`; audit-green at HEAD
     (42 ahead, remediation rides the branch)". W628b convention
     applies; re-pointing the pushed tag is NOT required.
  3. **New transport finding**: `56325fa5` is NOT reachable from
     `origin/main` (`5fc56da2`, behind the tag). The seal is
     **branch-local** to `feat/playwright-surface` until the
     coordinator merges to main (open item 11).
  4. Post-tag sibling drift: ash_pplan `847f487b` (W650j
     version-companion fix — arguably release content; v26.10.8 vs
     W628b is an operator call, open item 12); ash_a2a `13dd1a57`
     docs-only (W628b, already recorded above).

## 7. Shared DB migrated to head

`plans/w641-dev-migrate.md`: W984s three-step handoff executed against
shared `xaas_dev` — quiescence verified (0 oban running; no writes since
2026-10-01), verbatim reparent/delete pre-pass (1157 reparented, 109
doomed epochs deleted, dup groups 90→0, w984o counts reconciled), then
`MIX_ENV=dev mix ecto.migrate` ran all 9 pending migrations through
`20261007250000`; rerun "Migrations already up" (both repos).
Standing: ALIVE. Known residual (typed, pre-existing): the migration-ordering
defect (`20261007120000` sequenced after the index migration that fails on
the duplicate rows) documented in `w633` §1 — BLOCKED(db) on a from-duplicate
replay, not fixed by W633/W641.

## 8. Honest open-items register

| # | item | state | receipt |
|---|---|---|---|
| 1 | W984dj census re-witness | **CLOSED (W650b)** — W984dj receipt permanently absent; confirming census executed at HEAD `56325fa5` instead: 1352/0/1, exit 0 | `plans/w650b-open-items.md` |
| 1b | W650b closure-table incorporation | **LANDED** — `plans/w650b-open-items.md` written; this table updated in place (W650b) | `plans/w650b-open-items.md` |
| 2 | W638 Wasmex host commit | **CLOSED (W984ge, 2026-10-07)** — host committed: `lib/xaas/semantics/graphlaw_wasm.ex` landed in commit `2f2748b3` (W650g integration, W638/W644), on `feat/playwright-surface`; clean vs HEAD (`git diff --stat HEAD --` empty) | `plans/w638-wasmex-host.md`, commit `2f2748b3` |
| 3 | W640 differential court | **CLOSED (W984ge, 2026-10-07)** — receipt landed: `plans/w640-differential-shacl.md` (ALIVE, 5/5 ×2 fresh roots, host/guest agree, C0 typed-refused); court artifact `test/xaas/semantics/w640_differential_shacl_test.exs` committed in `a5f81439` (W650g2 restage) | `plans/w640-differential-shacl.md`, commit `a5f81439` |
| 4 | ash_surface version-commit lane + tag | BLOCKED(version-commit-pending) | `w648-version-audit.md` row 22, `w635` |
| 5 | ggen-marketplace version-commit lane + tag | BLOCKED(version-commit-pending) | `w648` row 7, `w635` |
| 6 | ash_surface `priv/ash_surface/` projection byte-staleness vs fresh regen (content drift decomposed, not regenerated) | OPEN | `~/xaas/docs/sjira/v26.10.6/plans/w984n-ashsurface-regen-check.md` |
| 7 | ash_graphlaw ggen re-render follow-up | OPEN | `plans/w641c-graphlaw-adoption.md` (residual integration design + pack .rq for byte-identical contract) |
| 8 | affidavit pack migration | BLOCKED(pack-contract-divergence), tree restored byte-identical to `1056fc69` | `plans/w641a-affidavit-migration.md` |
| 9 | ferroplan pack migration | BLOCKED(pack-capability-missing) — new pack ships no `queries/`, registry projection absent; falsifier + unblock condition written | `plans/w641b-ferroplan-migration.md` |
| 10 | xaas_dev migration-ordering defect (dedup after index-create) | OPEN (typed, pre-existing) | `w633` §1, `w641` |
| 11 | xaas seal commit `56325fa5` not reachable from `origin/main` — seal is branch-local until coordinator merges `feat/playwright-surface` → main | OPEN (BLOCKED-class, coordinator) — **re-verified 2026-10-07 (W984ge)**: `git merge-base --is-ancestor 56325fa5 origin/main` fails; still NOT reachable | `plans/w650k3-tag-verdict.md` (W650k4) |
| 12 | ash_pplan post-tag `847f487b` (W650j version-companion fix) is arguably release content — cut v26.10.8 or accept per W628b | OPEN (operator decision) — **re-verified 2026-10-07 (W984ge)**: `~/ash_pplan` HEAD still `847f487`, `v26.10.7-2-g847f487` (2 commits ahead of tag); untouched | `plans/w650k3-tag-verdict.md`, `plans/w650j-pplan-pins.md` |
| 13 | idempotency-deepening 3F (`run_idempotency_deepening_test.exs`) | **CLOSED (W650h23, 2026-10-07)** — real cause: unscoped global reads vs committed foreign rows in shared `xaas_test` (READ COMMITTED leak); scope fix, zero lib/ changes; repair + commit receipts landed | `~/xaas/docs/sjira/v26.10.6/plans/w650h23-repair.md`, `plans/w650h23-commit.md` (commit `8a5f7ea7`) |
| 14 | W984ee court file (`test/xaas/compat/otp29_map_update_court_test.exs`) loss → W984fo restoration | **CLOSED (W984gr, 2026-10-07)** — court file and receipt both landed by W984gi in commit `e49d7033` (landing batch #5): `git log --all` shows `e49d7033` touching both the file and `plans/w984fo-restoration.md`; both tracked clean at HEAD (`git ls-files` confirms). Court re-run green at HEAD: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984gr mix test test/xaas/compat/otp29_map_update_court_test.exs` → **7 passed, exit 0**. Receipt: `docs/sjira/v26.10.6/plans/w984gr-item14.md` | commit `e49d7033` (W984gi); court run 2026-10-07; `plans/w984fo-restoration.md`, `plans/w984gr-item14.md` |

## Standing summary

> **Addendum — Updated 2026-10-07 (lane W984ge)**: open-items register
> truthed against disk/git. Items 2 (W638 host commit `2f2748b3`) and 3
> (W640 differential receipt + committed artifact `a5f81439`) are CLOSED;
> the two register rows added since v2 (13: idempotency 3F closed by
> W650h23; 14: W984ee court file still untracked, W984fo receipt still
> absent) recorded. Items 11 and 12 re-verified still true/open. No DRAFT
> flag was cleared without its precondition being met on disk.

- Census gate: **ALIVE at HEAD `56325fa5`** (W650b confirming witness,
  1352/0/1, exit 0 — item 1 closed; W984dj superseded). Remaining DRAFT
  blockers after W984gr closure of item 14 (W984gi commit `e49d7033`,
  court 7/0 exit 0): **exactly two** — coordinator merge (item 11: seal
  `56325fa5` still not reachable from `origin/main`) and operator
  ash_pplan call (item 12: `~/ash_pplan` at `847f487`, post-tag).
- OS-18: ALIVE (`579454be`). Refusal ledger: ALIVE (`d95defa2`,
  digest `203fee7c…`). Playwright: ALIVE (371/371 + 6/6). WASM artifact:
  ALIVE (`1869a16`, digest `b7664a5e…`); Wasmex host committed
  `2f2748b3` (W650g); differential court ALIVE
  (`plans/w640-differential-shacl.md`, artifact committed `a5f81439`,
  W650g2). Fleet tags:
  **PARTIAL_ALIVE per W650k3/W650k4** — 8/8
  ancestry-truthful and re-verified fresh at v2 (W650c ls-remote table
  above; 2 repos BLOCKED noted), with disclosures: xaas audit-green at
  HEAD not tag (42 ahead), seal branch-local until main merge (item 11),
  ash_pplan post-tag operator item (item 12). a2a doc fix: ALIVE
  (`13dd1a57`, tag rides at `e0fb769e`, W628b). Shared DB: ALIVE at head.
- Seal verdict: **DRAFT — items 1, 1b, 2, 3, 13, and 14 closed (W650b, W984ge,
  W650h23, W984gr); not final until coordinator/operator items 11 and 12
  resolve and this receipt is re-read against them.**
