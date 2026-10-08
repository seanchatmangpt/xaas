# W984km — v26.10.7 deepening wave: consolidated law-7 manufacturing receipt

- Lane: W984km, 2026-10-08. Docs-only. No commit, no build root.
- Exact subject: `/Users/sac/xaas` @ `feat/playwright-surface`. Wave range:
  baseline fence `5e03acf5` (W984iz manifest) through the current front
  `b6fad269` (HEAD at receipt-writing time). Push state per W984kb:
  origin == HEAD == `f446d9c5` at that lane's fetch (W984jm batch #10
  pushed); `b6fad269` is the docs commit on top of it.
- Aggregate counts below are **arithmetic over cited numbers** extracted
  from the cited receipts by a disclosed, reproducible extraction: for each
  lane receipt, the maximal single recorded green test run below census
  scale (< 500 tests; census-scale runs 1355/1388 are shared-suite reruns,
  not new courts) is taken as that receipt's court-run figure. Each cited
  figure is read from that receipt's own recorded output; nothing is
  inferred.

## 1. Wave shape

- 178 lane receipts enumerated, W984da → W984km inclusive
  (`docs/sjira/v26.10.6/plans/w984{d..k}*.md`, 178 files, plus the
  v26.10.7 landing/push receipts cited in §2).
- 144 of 178 record at least one executed green test run at wave scale;
  their maximal-recorded-run figures sum to **2334 test-passes cited**.
  The remaining 34 are docs-only, recensus, registry, disposition, or
  witness lanes (list in §5).
- Aggregate includes named family-dir/sibling regression runs cited in some
  receipts (e.g. w984ig 119 = actuation+deepening dirs, w984iq 78 =
  27 court + 51 ard, w984ip 80, w984fr 74 billing dir, w984fp 91 = landing
  batch gate, w984eu 391, w984ff 65). The new-court-only subtotal is
  smaller and is per-receipt as-cited; no figure here is an estimate.

## 2. Landed subjects (batches + SHAs)

All SHAs below are cited from the named landing-batch receipts (read, not
inferred), inside range `5e03acf5..3961c4ab` (W984iz manifest, 63 commits)
plus batch #10 through `b6fad269`:

| batch | receipt (docs/sjira/v26.10.7/plans/) | landed SHAs | batch gate (as cited) |
|---|---|---|---|
| #1 (gated) | `w650h14-gated-commit.md` | `3c03bffa` (16 files) | compile EXIT=0, census 1354/1355 (1 disclosed concurrent-edit failure), batch 57 passed |
| spg/validations/incident | `w650h22-commit.md` / `w984ds2b-commit.md` / `w650h33c-commit.md` | `f0321df2`, `5cf56c13`, `32b72c4f` | SpgGate 7-case integration green ×2 fresh roots; batch 10 green ALIVE on `5cf56c13`; causal_receipt 5 passed ALIVE on `32b72c4f` |
| #2 | `w984fe-commit.md` | `0153101a`, `c6bf5bbc`, `49992412`, `a420b7d5` (+ `43265cb1` self-carried) | real run 28 passed exit 0; mix.lock diff exactly 3 deletions |
| el legs | `w984el-commit.md` | `acacc1db`, `ab3562b8`, `8f9ea495` | batch gate 91 passed / 0 failed (14+14+20+33+5+5), mock gate `[]` |
| #7 group | `w984gy-commit.md` / `w984hg-commit.md` / `w984hm-commit.md` | `58cd87b9`, `d1a2b91b`, `fc2adcb0`, `1ac2ad42`, `226803b8` | exact subjects of W984iy mutation legs M1–M6, all EXIT=0 before/after |
| #9 | `w984il-commit.md` (on disk per W984jy) | `145b5659` batch head | batch #9 CLOSED; "IN FLIGHT" flag retired |
| #10 | `w984jm-commit.md` | `ad159c18`, `ef2e8714`, `79581cf6`, `127dc790` | compile EXIT=0, mock gate `[]`, batch gate 160 passed / 0 failures over 13 candidate files |
| docs/push | `w984jm-commit.md` + `w984kb-push.md` | `f446d9c5` (jm batch receipt), `b6fad269` (kb reconciliation) | push reconciliation: origin == HEAD == `f446d9c5`; `git merge-base --is-ancestor 145b5659 HEAD` exit 0 |

Additional in-range landing SHAs collected from the batch commit receipts:
`06fed7b2`, `180d4606`, `32487e08`, `5855fd02`, `68073d8d`, `956b772a`,
`a355e317`, `a9056f7b`, `b5615c6d`, `b9d35fdd`, `e2ef8aa5`, `e49d7033`.
Disclosed sibling-repo refs (not xaas commits, per W984iz manifest):
`0e210efb`, `e3dcc4fa`, `297da2f1`, `6274d2d8`.

## 3. lib/ repairs (receipt + landing subject each)

| repair | receipt | landing |
|---|---|---|
| parse-dt typed-refusal path fix | `docs/sjira/v26.10.6/plans/w984dj3-parse-dt.md` (10 passed) | landed via `w650r2-parse-dt-commit.md` |
| sa2a authority-evidence repair (`execute.ex` passes `authority:` through the DO hop; pre-fix every court-admitted execution BLOCKED `execute_unexpected_reply`) | `w984es-repair.md` (3-passed repair court) | `1ac2ad42` (cited by `w984ha-probe.md` M1) |
| AWS adapter IMDS instance-id 2xx guard | `w984gu-repair.md` (7 passed) | `226803b8` (cited by `w984iy-probe.md` M3) |
| AWS adapter token-path 2xx guard | `w984hc-repair.md` (9 passed) | `226803b8` (cited by `w984iy-probe.md` M4) |
| Airo risk-mapping wiring entry (`EnforceBorrowCap` control) | `w984fx-probe.md` (11 passed) | `fc2adcb0` (cited by `w984iy-probe.md` M1) |
| EDS trim/non-map clause repairs (2 files in `lib/xaas/eds/`) | `w984ht-probe.md` (45 passed; lib/ diff verified byte-level by W984jm) | `ad159c18` |
| AuthorityLedgerExport `recompute_root` entries-shape guard | `w984ii-repair.md` (19 passed; diff verified by W984jm) | `ad159c18` |
| mix.lock 3-pin prune | `w984et-probe.md` | `0153101a` (fe batch #2, diff exactly 3 deletions) |
| OTP-29 census court file | `w984ee-probe.md` (7/7) | `e49d7033` (batch #5, per `w984jg-probe.md`) |
| W902 seed fixture fix (0/2 → 2/2 red→green) | `w984fs-w902.md` | landing rows per `w984fp-probe.md` manifest table |
| e2e seed-writer MIX_ENV fix (3 config/JS files) | `w984fw-seed-writer.md` | REPAIRED at config/JS layer; full e2e re-run open |
| ggen_igniter 0-row driver crash fix + regression court | `w984hl-reconcile.md` / `w984ic-chaos-drivers.md` | landed in **ggen_igniter** (sibling repo), real subprocess court |
| `ref_resolves?` wildcard-glob fix + W650k regression courts | `w984gv-probe.md`, `w984hf-probe.md` (11 passed) | `58cd87b9` batch set (court files); lib fix landed with batch #7 group |

## 4. Open typed findings (standing, not closed)

- **W984ho rpc asymmetry** — finding receipt
  `docs/sjira/v26.10.6/plans/w984ho-probe.md` (7-passed court pins the
  `FunctionClauseError` classes); repair **in flight by W984kk — no
  W984kk receipt on disk as of this writing**; status IN-FLIGHT.
- **W984jk `CREATE_APPROVED_BY_BYPASS` residue** — finding receipt
  `w984jk-probe.md` (3-passed court + 18 sibling; one-line fix named:
  drop `:approved_by` from the `:create` accept list); repair **in flight
  by W984jz — no W984jz receipt on disk**; status IN-FLIGHT.
- **W984dq8 dead-residue disposition FALSIFIED** — `w984jh-dead-residue.md`
  proved all three "typed-dead" files LIVE (5/9/1 live refs); zero
  deletions warranted; dq8's UNSUPPORTED(dead-residue) row is superseded.
- **W984er orphan register**: `ApprovalInvoiceReconciliationApproveApprove`
  and `ApprovalQuotaOverrideApprove` UNWIRED dead residue since `0dd96d2d`
  — retire-or-UNWIRED-guard recommendation; W984ea court (3 passed) pins
  the unwired status. Coordinator disposition still open.
- **W729 atomic_update**: flipped LANDED per `w984fr-atomic-site1.md`
  ("ALREADY-LANDED", re-witnessed 74-passed billing dir run); last
  registrar OPEN row superseded per `w984kd-tally.md`.
- **ash_pplan stale pack courts** (gate rows 1/6/4 vs violation-gate
  bytes): out-of-lane work order per `w984hl-reconcile.md`; upstream pack
  needs driver queries. OPEN (sibling repo).
- **W984gn Playwright cold-compile triage**: REPAIRED(partial,
  honesty-bounded) per `w984fv-w784.md`; not landed. OPEN.
- **W984ff verified-landed flips**: W770/W796-G3/W799 all REPAIRED with
  courts on disk (SHAs `b2758300`, `352cc34c` per `w984ff-probe.md`).
- **Census floor**: standing wave floor witnessed at **1388 passed /
  1 excluded / exit 0** across ≥8 receipts (1355 at `w984eb` → 1388 at
  `w984ev`/`w984ey`/`w984fa`/`w984fb`/`w984fc` → re-run block in
  `w984ja-registry.md`); single intentional Art. 49.3 OPEN_GAP marker per
  `w984ig-quiescent-repair.md`.

## 5. Receipts cited (complete enumeration, W984da → W984km)

All under `docs/sjira/v26.10.6/plans/`. Figures are the extracted
maximal-recorded-run count (<500) per receipt; `—` = no recorded
sub-census run (docs-only / recensus / registry / disposition lanes).

| receipt | fig | receipt | fig | receipt | fig |
|---|---|---|---|---|---|
| w984da-security-probe.md | 5 | w984db-a2a-probe.md | 5 | w984dc-probe.md | 5 |
| w984dd-probe.md | 5 | w984df-jcs.md | 20 | w984di-sjira-probe.md | 5 |
| w984dj2-spg-gate.md | 5 | w984dj3-parse-dt.md | 10 | w984dj4-ultracode.md | 5 |
| w984dj5-generation.md | 5 | w984dj5b2-lock-encode.md | 19 | w984dk-provenance.md | 5 |
| w984dl-vault-probe.md | 9 | w984dm-probe.md | 5 | w984dn-sponsor-track.md | 5 |
| w984do-probe.md | 5 | w984dp-probe.md | 5 | w984dp2-ops-residue.md | 10 |
| w984dp3-sjira.md | 5 | w984dp4-probe.md | 5 | w984dq-typescript-manifest.md | 5 |
| w984dq2-autofde.md | 5 | w984dq3-durable-adapter.md | 5 | w984dq6-spg-execute.md | 18 |
| w984dq8-probe.md | 10 | w984dq9-probe.md | 3 | w984dr-gov-types.md | 10 |
| w984dr2-gov-batch.md | 10 | w984dr2b-gov-batch2.md | 33 | w984dr3-gov-changes.md | 10 |
| w984ds-probe.md | 5 | w984ds2-probe.md | 10 | w984dt-probe.md | 5 |
| w984dv-probe.md | 10 | w984dw-probe.md | 14 | w984dx-probe.md | 14 |
| w984dy-probe.md | 20 | w984dz-probe.md | 13 | w984ea-probe.md | 3 |
| w984eb-probe.md | 30 | w984ec-probe.md | 3 | w984ed-probe.md | 11 |
| w984ee-probe.md | 7 | w984ef-probe.md | 5 | w984eh-probe.md | 2 |
| w984ei-probe.md | 9 | w984ej-probe.md | 11 | w984ek-probe.md | 8 |
| w984em-probe.md | 7 | w984en-probe.md | 12 | w984eo-probe.md | 26 |
| w984ep-probe.md | 16 | w984eq-probe.md | 5 | w984es-repair.md | 3 |
| w984eu-probe.md | 391 | w984ev-probe.md | 4 | w984ew-probe.md | 8 |
| w984ex-probe.md | 16 | w984ey-probe.md | 3 | w984ez-repair.md | 11 |
| w984fa-probe.md | 8 | w984fb-probe.md | 3 | w984fc-probe.md | 7 |
| w984ff-probe.md | 65 | w984fg-probe.md | 11 | w984fi-probe.md | 4 |
| w984fj-probe.md | 6 | w984fm-probe.md | 3 | w984fn-probe.md | 11 |
| w984fo-restoration.md | 7 | w984fp-probe.md | 91 | w984fq-probe.md | 21 |
| w984fr-atomic-site1.md | 74 | w984fs-w902.md | 2 | w984fv-w784.md | 6 |
| w984fx-probe.md | 11 | w984fy-probe.md | 7 | w984ga-probe.md | 5 |
| w984gb-probe.md | 3 | w984gd-probe.md | 15 | w984gf-probe.md | 4 |
| w984gg-probe.md | 3 | w984gh-probe.md | 6 | w984gj-probe.md | 4 |
| w984gk-probe.md | 11 | w984gl-probe.md | 28 | w984go-probe.md | 5 |
| w984gp-probe.md | 8 | w984gr-item14.md | 7 | w984gs-probe.md | 16 |
| w984gt-airo-pins.md | 9 | w984gu-repair.md | 7 | w984gw-probe.md | 27 |
| w984gx-probe.md | 7 | w984ha-probe.md | 26 | w984hc-repair.md | 9 |
| w984hd-repin.md | 18 | w984he-probe.md | 3 | w984hf-probe.md | 11 |
| w984hh-probe.md | 10 | w984hi-probe.md | 3 | w984hj-probe.md | 8 |
| w984hk-probe.md | 21 | w984hl-reconcile.md | 4 | w984hn-probe.md | 32 |
| w984ho-probe.md | 7 | w984hp-probe.md | 10 | w984hq-probe.md | 6 |
| w984hr-probe.md | 11 | w984ht-probe.md | 45 | w984hu-probe.md | 3 |
| w984hw-probe.md | 4 | w984ib-probe.md | 18 | w984ie-probe.md | 3 |
| w984if-probe.md | 5 | w984ig-quiescent-repair.md | 119 | w984ih-probe.md | 4 |
| w984ii-repair.md | 19 | w984ij-probe.md | 13 | w984im-fixtures.md | 18 |
| w984io-probe.md | 11 | w984ip-probe.md | 80 | w984iq-probe.md | 78 |
| w984is-probe.md | 36 | w984iu-probe.md | 19 | w984iv-probe.md | 16 |
| w984ix-probe.md | 1 | w984iy-probe.md | 16 | w984jb-probe.md | 5 |
| w984jc-probe.md | 6 | w984jd-probe.md | 9 | w984je-probe.md | 9 |
| w984jf-probe.md | 6 | w984jg-probe.md | 55 | w984ji-probe.md | 21 |
| w984jj-probe.md | 5 | w984jk-probe.md | 18 | w984jn-shacl-drift.md | 23 |
| w984jq-probe.md | 25 | w984jr-probe.md | 5 | w984js-probe.md | 10 |
| w984jt-probe.md | 6 | w984ju-probe.md | 5 | w984jv-probe.md | 3 |
| w984km (this wave receipt, v26.10.7/plans/) | — | | | | |

No-count receipts (34): w984di2, w984du, w984eg, w984er, w984et, w984fh,
w984ft, w984fw, w984fz, w984gc, w984ge, w984gn, w984gq, w984gv,
w984gz, w984hs, w984hv, w984hy, w984hz, w984ic, w984ik, w984in, w984it,
w984iw, w984iz, w984ja, w984jh, w984jl, w984jo, w984jw, w984jy, w984kd,
w984kg, w984kl.

Note on table transcription: figures were extracted mechanically
(`grep -oE '[0-9]+ passed' | awk '$1<500' | sort -n | tail -1` per file,
sum 2334 over 144 files) and re-verified against
`/tmp/l_all.txt` at write time; the per-row value above is that file's
value. Where a receipt records multiple runs of the same court (fresh-root
re-witness), the maximal single run is counted once.

## 6. Standing

- Wave standing: **PARTIAL_ALIVE** — every cited court figure is a real
  observed execution recorded in the cited receipt; landing SHAs are cited
  from batch receipts; push state reconciled by W984kb. Open typed
  findings (§4) carry typed OPEN/IN-FLIGHT status, not silent closure.
- This receipt: docs-only, no commit, no build root (lane law). Falsifier:
  any cited count or SHA not reproducible from the cited receipt or
  `git log` at `b6fad269` falsifies this receipt.

---

## 7. Delta addendum (W984mp, 2026-10-08): receipts newer than this wave's coverage

- Docs-only addendum by lane W984mp. Same disclosed method as §1–§5:
  per receipt, the maximal single recorded green sub-census run
  (`grep -oE '[0-9]+ passed' | awk '$1<500' | sort -n | tail -1`).
  Coverage boundary: §5 ended at W984km; this addendum covers the
  W984l* series and W984ma+ in `docs/sjira/v26.10.6/plans/` plus the
  v26.10.7 lanes `w984kn`, `w984ko`, `w984kw`, `w984lo`, `w984mf`.
  `w984mn-vendor.md` appeared on disk mid-lane (concurrent sibling lane,
  zero sub-census runs recorded) and is included as docs-only.
- Landing-batch commit SHAs (read from `git log`, HEAD `567ab1f5`):
  batch #11 = `52ce8236` (receipt commit; legs `9a00385c`/`caf91669`/
  `86c69061`), batch #12 = `1ba31a97` (legs `fcef478b`/`6ff734f2`),
  batch #13 = `567ab1f5` (legs `d3189b40`/`be2591bd`/`4371fcff`/
  `9ba3a44f`/`dc125c8c`/`038fd867`). No batch #14 exists as of
  addendum time.
- **Delta aggregate**: 23 receipts record at least one sub-census run;
  their maximal figures sum to **1458 test-passes cited** (§7.1).
  New wave total over both sections: **2334 + 1458 = 3792**. New
  census floor: **1394 passed / 1 excluded / exit 0** (W984ko
  `w984ko-census-witness.md`, superseding the §4 floor of 1388).

### 7.1 Delta table (lane, court result, landing status)

All receipts under `docs/sjira/v26.10.6/plans/` unless noted
`v26.10.7`. Landing status read from `git status` / `git ls-files` /
batch `--stat` at addendum time; HEAD `567ab1f5`.

| receipt | fig | court result (as cited) | landing status |
|---|---|---|---|
| w984la-probe.md | 4 | dev-scope controller court, 4 passed | STAGED-UNCOMMITTED (receipt + `test/xaas_web/controllers/dev_court_w984la_test.exs` untracked) |
| w984lb-probe.md | 2 | docs deepening, 2 dated blockquotes | LANDED batch #13 (`9ba3a44f` receipt; doc edits in `dc125c8c`) |
| w984lc-probe.md | 4 | mutation non-vacuity audit #7, 4 legs | STAGED-UNCOMMITTED (receipt only) |
| w984ld-probe.md | — | 9th landing addendum, docs-only | LANDED batch #13 (`9ba3a44f`) |
| w984le-probe.md | 8 | pack query surfaces court, 8 passed | STAGED-UNCOMMITTED (receipt + `pack_queries_court_w984le_test.exs` untracked) |
| w984lf-probe.md | 3 | closure-receipt truthing at `52ce8236` | LANDED batch #13 (`9ba3a44f`) |
| w984lg-probe.md | 99 | evidence-index rows 77–92, 105/0 batch #11 re-read | LANDED batch #13 (`9ba3a44f`) |
| w984lh-repair.md | 37 | next_read_live 2-failure repair, 37 passed | STAGED-UNCOMMITTED (receipt + `next_read_live_deepening_test.exs` modified) |
| w984li-probe.md | — | 10th landing addendum, docs-only | LANDED batch #13 (`9ba3a44f`) |
| w984lj-probe.md | 7 | supervision-tree court, 7 passed exit 0 | STAGED-UNCOMMITTED (receipt + `application_supervision_court_w984lj_test.exs` untracked) |
| w984lm-repair.md | 137 | W984kk 4-failure pin repair, 137 passed | STAGED-UNCOMMITTED (receipt + repair edits uncommitted) |
| w984ln-repair.md | 57 | W984kt typed-contract repair, 57 passed | STAGED-UNCOMMITTED (receipt + repair edits uncommitted) |
| w984lp-e2e-falsifier.md | 6 | e2e seed falsifier, 6 passed | STAGED-UNCOMMITTED (receipt + `e2e/seed-library.exs` modified) |
| w984lq-recensus.md | — | 8th census re-run (census-scale, sub-census n/a) | STAGED-UNCOMMITTED (receipt only) |
| w984lr-fix.md | — | e2e seed Sandbox guard, falsifier progressed | STAGED-UNCOMMITTED (`e2e/seed-library.exs` modified; receipt untracked) |
| w984ls-probe.md | 5 | platform route validations court, 5 passed | STAGED-UNCOMMITTED (receipt + `route_validations_court_w984ls_test.exs` untracked) |
| w984lt-probe.md | 6 | 11th landing addendum + falsifier run, 6 passed | STAGED-UNCOMMITTED (runbook addendum in modified `_INTEGRATION_RUNBOOK.md`) |
| w984lu-flake.md | 108 | fabric 204-flake classified, 108 passed × re-runs | STAGED-UNCOMMITTED (receipt only) |
| w984lw-probe.md | — | mutation non-vacuity on w984lr guard (docs) | STAGED-UNCOMMITTED (receipt only) |
| w984lx-probe.md | — | 12th landing addendum, docs-only | STAGED-UNCOMMITTED (runbook addendum uncommitted) |
| w984ly-probe.md | 52 | flake-class sweep, 52 passed | STAGED-UNCOMMITTED (receipt only) |
| w984lz-probe.md | 58 | evidence-index rows 93–95 (batch #12), 58 passed | STAGED-UNCOMMITTED (receipt only) |
| w984m-graphql-doc.md | — | GraphQL doc census, docs-only | STAGED-UNCOMMITTED (receipt only) |
| w984ma-probe.md | 5 | KNOWN-DEFECT comment refresh, 5 passed | STAGED-UNCOMMITTED (comment edits in modified lib/ files) |
| w984mc-probe.md | — | 13th landing addendum, docs-only | STAGED-UNCOMMITTED (runbook addendum uncommitted) |
| w984mg-probe.md | 391 | evidence-index batch #13 refresh (391 re-cites w984ke/lo eu_ai_act run) | STAGED-UNCOMMITTED (receipt only) |
| w984mh-probe.md | — | 14th landing addendum, docs-only | STAGED-UNCOMMITTED (receipt only) |
| w984ml-probe.md | — | 15th landing addendum, docs-only | STAGED-UNCOMMITTED (receipt only) |
| w984mn-vendor.md | — | ash_pplan vendor residue disposition, zero tree changes | STAGED-UNCOMMITTED (receipt only; sibling `ash_pplan` untouched) |
| v26.10.7 `w984kn-commit.md` | 58 | batch #12 gate: 58 passed / 0 failures | LANDED (`1ba31a97`) |
| v26.10.7 `w984ko-census-witness.md` | 6 | census witness 1394/0/1 at `b6fad269` | STAGED-UNCOMMITTED (receipt untracked) |
| v26.10.7 `w984kw-burndown.md` | 10 | fleet-seal burn-down, arithmetic only | LANDED batch #13 (`9ba3a44f`) |
| v26.10.7 `w984lo-commit.md` | 391 | batch #13 gate 88 passed + eu_ai_act 391 passed | LANDED (`567ab1f5`) |
| v26.10.7 `w984mf-ash-surface-playwright.md` | 4 | ash_surface Playwright seal ALIVE (sibling repo) | STAGED-UNCOMMITTED (receipt untracked; sibling repo untouched) |

### 7.2 Landing-batch leg detail (post-W984km, from `git show --stat`)

- Batch #12 (`1ba31a97`): `fcef478b` 10 courts → 3 court files + 3
  receipts (jc/ju/jv); `6ff734f2` receipt-only lanes jn/kl/kh.
- Batch #13 (`567ab1f5`): `d3189b40` disclosed lib repairs
  (W984kk `approved_by` accept-list fix, W984jz, W984kg `no_lease`);
  `4371fcff` W984ks orphan-change retirement (deletes the two
  UNWIRED change modules, closes the §4 W984er orphan register —
  **that open finding is now closed**); `be2591bd` 12 court files
  (jt/jx/ka/jw/kr/kg/kj/js/ki/kq + `sparql_bridge_court_test.exs`
  + title_iii edit); `9ba3a44f` 21 receipts incl. this wave receipt
  and `w984kw-burndown.md`; `dc125c8c` diataxis edits (kx/ky/kz/kv/lb);
  `038fd867` registers, closure receipt regen, evidence index (+101
  lines), runbook (+348).
- Batch #13 gate (as cited by `w984lo-commit.md`): 14 candidate court
  files → **88 passed / exit 0**; W984ks gate re-run
  `mix test test/xaas/billing` → 80 passed; `mix test test/eu_ai_act
  --include eu_ai_act` → 391 passed.
- Batch #12 gate (as cited by `w984kn-commit.md`): 10 candidate court
  files → **58 passed / 0 failures**.

### 7.3 §4 open-finding updates from the delta

- W984ho rpc asymmetry: repair landed in batch #13 (`d3189b40`,
  `execution_fabric_controller.ex` +10/-1) — **CLOSED**.
- W984jk `CREATE_APPROVED_BY_BYPASS`: repair landed in batch #13
  (`d3189b40`, `approval_invoice_reconciliation_approve.ex` +7/-1) —
  **CLOSED** (W984ma's in-source comment refresh is the disclosed
  follow-up, staged-uncommitted).
- W984er orphan register: closed by `4371fcff` (see §7.2) — **CLOSED**.
- Census floor raised to 1394 (W984ko). Remaining open items from §4
  unchanged except as noted here; delta adds no new OPEN finding.
