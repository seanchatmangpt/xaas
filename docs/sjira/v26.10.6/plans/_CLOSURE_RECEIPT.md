# v26.10.6 Final Substantial Receipt — Skeleton

Integration lane W243 (skeleton); updated by integration lane W306,
2026-10-06; W352 flip pass 2026-10-06 — PENDING markers flipped to CLOSED
only where the closing
receipt file now exists on disk under `docs/sjira/v26.10.6/plans/`
(coordinator commit / P2-2 / r8 legs remain PENDING; final-PW CLOSED via
w317). Original
skeleton rule stands: every field is populated ONLY with what is already
receipt-cited on disk under `docs/sjira/v26.10.6/plans/`
(`_FRONTIER.md`, `_WIRING_MATRIX.md`, `_INDEX.md`, `_CLOSURE_PLAN.md` §5 DoD
status / DoD run-sheet). Anything not yet witnessed carries an explicit
`PENDING: <lane>` marker — the coordinator finalizes post-wave. No standing
below is asserted beyond what a receipt on disk shows.

> **W352 flip pass (2026-10-06)** — executed `w330-receipt-flip-plan.md`
> plus fresher evidence. FLIPPED: all 5 `PENDING: final Playwright lane`
> occurrences → CLOSED on `w317-pw-final-tokened.md` (96/0/2, 98/98
> --list, exact subject `d1db2b03`), each with the w344 health residual
> note appended. ANNOTATED (still PENDING): `W185` ×2 (standalone receipt
> in flight (W318); capstone evidence w236 on disk (w263b/w312 are
> coordinator-backfill lane tags with no standalone receipt files — their
> verdicts are recorded in w176 appendices and _CLOSURE_PLAN §2.1) —
> `w185-refusal-batch6-receipt.md` test -f MISSING at W352 check time);
> `P2-2` ×2 (advisory draft landed: `.github/workflows/closure-gates.yml`
> (w327, YAML-valid, continue-on-error); blocking promotion = operator
> transition); ash_surface fleet falsifiers (`w348` receipt test -f
> MISSING at W352 check time). UNCHANGED PENDING: W20 (still interim),
> coordinator commit legs, PR/replay-identity legs, coordinator CI lane,
> r8 falsifier (no w325 receipt on disk).

Repo: `/Users/sac/xaas`. Receipt dir: `docs/sjira/v26.10.6/plans/`
(119 receipt files per `_INDEX.md`, W184b).

---

## Exact subject

- **Integration base**: `feat/playwright-surface` @ `d1db2b03` (xaas) — per
  `_FRONTIER.md`, `_WIRING_MATRIX.md`, `_CLOSURE_PLAN.md`.
- **Repo pins (live-verified per `_WIRING_MATRIX.md`, W164)**:
  - ash_a2a — git pin `86214551de93fc8ab395f5ed0b84d32922a5d99b`
    (`mix.lock:7`; mount `/a2a/v1` → `AshA2A.Protocol.Plug`,
    `router.ex:196-216`, forward at `:211`)
  - ash_pplan — git ref `5f10c9798b78…` (`mix.exs:252-254`, `mix.lock:26`)
  - ash_surface — path dep `../ash_surface` (`mix.exs:115`); alias
    `ash_surface` (`mix.exs:268-272`); `@version "26.10.6"` on its tree
    (W19, disk-verified per `_CLOSURE_PLAN.md` §1 row 26)
  - ash_graphlaw / ash_affidavit — path deps with override
    (`mix.exs:114/116`)
  - ggen_igniter — hex `~> 26.10.1` (`mix.exs:226`), lock sha256
    `4a7fe00e…` (`mix.lock:88`)
  - ggen — repo ALIVE @ `000bffb8f` (`r1-ggen.md`, `w81`); consumer pin
    `ggen.toml:16-20` → marketplace pack `xaas_castle_bridge` @
    `518572b6b531…`
  - ggen-marketplace — selection authority `marketplace.active.toml`
    (front_door=ggen-platform-pack); v26.10.5 FINAL base `3ddbfeb7` (`r2`)
  - ferroplan — wasm artifact digest `088d9c3b…` pinned
    (`lib/xaas/bridges/ferroplan.ex:31`); artifact on disk, untracked,
    commit PENDING (WP-B)
  - beam4pm — classified head `813eb92` (`r9`); 2,495 dirty lines uncommitted
  - zcode-cli — `7fc62da` (`w58`); 18-file dirty stream committed nowhere
  - wasm4pm — head `32deb59f6` fmt-verified (`r10`)
  - gymact — `d3eb5e8` (`r8`, `w79`)
  - autofde-lab — `feat/doctrine-lab` @ `2a3d064e` (`r11`)
- **Final integration commit / PR**: `PENDING: coordinator commit lane`
  (w153-v2 order + w191 hazard map; tree still carries the convergence diff
  uncommitted — `_CLOSURE_PLAN.md` DoD 4).

## O / O*

- **O (raw observation base)**: 119 receipt files under `plans/` (W184b
  count); r1–r11 fleet audits, vectors 1–6, x1–x8, execution lanes w6–w198.
- **O\* (admitted)**: the receipt-backed state integrated by W123 into
  `_FRONTIER.md` and live-verified by W164 into `_WIRING_MATRIX.md`; the §5
  DoD walk (W206) distinguishing receipt-backed vs lane-reported-only
  evidence.
- **Lane-reported but NOT receipt-backed (known-O, not O\*)**: receipts named
  in taskings with **no file on disk** — `w150`, `w158`, `w161`, `w169`,
  `w171`, `w174`, `w185` (standalone), `w186` (standalone), `w20` (W206
  disclosure). Also dead-pointer disclosures from W230's link check: OS-9's
  w133b STOP report + w128; OS-11's w20; OS-12's "W183 findings".
  - `CLOSED: W171` — app-gaps PW lane; `w171-app-gaps.md` on disk
    (post-W171 adversarial re-run 6/6 passed, standing ALIVE).
  - `CLOSED: W158` — full-suite-with-token; `w158-suite-with-token.md` on
    disk (3125/3230, 105 failures classified). Class E (87, env pollution)
    adjudicated by `w280-async-env-isolation.md`; Class D (10, stale-beam)
    adjudicated zero-real-drift by `w281-class-d.md`.
  - `PENDING: W20` — ash_pplan adjudication; `w20-ash-pplan-adjudication.md`
    on disk but backfilled INTERIM (lane still running at backfill time,
    final verdict not yet appended).
  - `PENDING: W185` — batch6/r2rml fixture repair (3 disclosed failures);
    standalone receipt in flight (W318); capstone evidence
    w236 on disk; w263b/w312 verdicts via w176 appendices (no standalone files).
  - `CLOSED: W169` — marketplace PW regression; `w169-marketplace-regression.md`
    on disk (514/56 targeted, full 1956/58 = exactly W105 baseline).
  - `CLOSED: W150 / W161 / W174` — receipts on disk: auth-floor fixes
    (`w150-auth-floor-fixes.md`), E3-37 order-bound adjudication
    (`w161-order-bound.md`), Ontop health typing (`w174-ontop-health-typing.md`).
  - Dead-pointer disclosures from W230 (OS-9's w133b + w128, OS-11's w20,
    OS-12's "W183 findings") — all resolved: `w133b-compile-prose-stop.md`,
    `w128-oracle-final.md`, `w20-ash-pplan-adjudication.md`,
    `w183-token-revocation-findings.md` all exist on disk.

## Transport failures

Receipt-cited (executed, failed, classified — these ARE the record):

- `w30` — dev tree did not compile; 0 specs executed (BUILD_BROKEN, receipt).
- `w51` — Gate 1 compile BLOCKED (TokenMissingError `gymact_surface.ex:232`);
  priv/ eacces defect disclosed. (Both root causes later resolved: w42, pin
  advance; w91 permission sweep.)
- `w68` — full suite BLOCKED: external dep `ash_affidavit` capability-registry
  permission denied; resolved via `w91`/`w175`.
- `w70` — Playwright webServer spawn failed 2/2 (xattr denial); suite ran
  against a manually booted server: 49 pass / 37 fail (17 token-absent 503,
  6 spec bug, 6 app gap, 7 seed).
- `w90` — ash-extension re-pin sync refused at tip (falsifier N/A).
- `w103` — prod compile `--warnings-as-errors` exit 1: 16 app-code warnings.
- `w113` — a2a/mcp/ggen-workbench PW: token branch 11/7 (BLOCKED env:
  pending migrations, later migrated via `w151`); tokenless 3/15 = honest
  fail-closed 503 floor.
- `w132` — verify_and_commit rehearsal stages 2+ BLOCKED on ash_surface dep
  compile; test stage NOT RUN (resolved via `w175`).
- `w135` — witness PW webServer boot failed (`ash_a2a/resource.ex:46` dep
  compile); 0 tests executed.
- `w141` — `mix xaas.ash_surface` FAILED (UndefinedFunctionError
  `AshA2A.Dsl.dsl_patches/0`).
- `w146` — chicago suite compile exit 1, 0 tests (same `AshA2A.Dsl`
  shadowing class; floor fixed via `w175`).
- `w148` — bridges/ultracode suites BLOCKED (dep compile, pre-existing).
- `w118` — full PW 62 passed / 32 failed / 3 skipped (best full PW receipt).
- `w111` — interim PW exit 1, per-file counts recorded (25/6 residual).
- `w167` — Postgres connection saturation (FATAL 53300) diagnosed, test-env.
- `w229` — Autonomic.build_ctx single-repo suite-precedence defect (fixed,
  8/8; cited in `_FRONTIER.md` xaas row).
- `CLOSED: W171` — 6 app-gap PW failures: fixed + adversarially re-run 6/6
  (`w171-app-gaps.md`); app-gap class closed, no BLOCKED/UNSUPPORTED row
  required.
- `CLOSED: W158` — tokened full-suite run executed
  (`w158-suite-with-token.md`: 3125/3230, 105 failures); Class E env
  pollution isolated + fixed (`w280-async-env-isolation.md`), Class D
  stale-beam adjudicated zero real drift (`w281-class-d.md`).
- `CLOSED: final Playwright lane` — w317-pw-final-tokened.md: full tokened
  npx playwright test @ d1db2b03, 96/0/2 (98/98 --list match), webServer
  boot via W310 readiness gate, zero flaky; supersedes w118 as best
  full-PW receipt. Residual run-level classes pre-closed: seed (w180),
  app-gap (w171), marketplace regression (w169), server-death (w299b
  diagnosis + PW_PORT/stderr lease). (w310g 503-with-token residual
  re-witnessed FIXED 2026-10-06, w344-health-503-diagnosis.md: fresh-boot
  200 with token, ultracode_tick ok.)

## μ / diff

Receipt-cited landed state (μ = what the convergence wave actually
manufactured):

- **xaas**: gymact fail-closed adapter (`w42`); PPlan facade rewrite onto
  `AshPPlan.A2A.Facade` @ `5f10c979` (`w41`); Ferroplan digest-pinned bridge
  (`w53`/`w45`); explicit `length: 8_000_000` on Plug.Parsers + boundary
  tests (W22, `_CLOSURE_PLAN.md` §1 row 11); refusal batches 1–6 + VKG +
  plug + endpoint negative-test files (w13/w18/w67/w121/w185/w208; delta 50
  → 16 → 0 per `w176`); seller live un-skip (`_CLOSURE_PLAN.md` §1 row 10);
  castle.ex injection + regenerated castle-bridge outputs (W36, §1 row 13);
  `priv/ash_surface` regenerated under v26.10.6 (W73, §1 row 15); version
  seam `26.10.2` → `26.10.6` (`w72`); dev.exs program re-points
  autofde-lab/gymact → canonical checkouts (§1 row 20); receipt-schema v2/v1
  dual-version validator (`w107`); Autonomic.build_ctx fix (`w229`).
- **ash_surface**: version `26.10.6` (W19); doctrine=excluded decision for
  its ggen sync outputs (W37, §1 row 14); full-app generation works at EA35
  (`x8`: 410 actions, `surface_contract.json`, CommandCenterAdapter court
  9/0).
- **ggen_igniter**: pack promoted `test/fixtures/` → `priv/ggen/`
  (W6/W38/W114-C1; on tree, `PENDING: coordinator commit`); credo/format
  fixes (`w38`).
- **Sibling repos**: ggen 2 commits past tag (MU3 mutation sample 0/6, CA1
  hygiene, `r1`); ferroplan wasm artifact built + staged-ready untracked
  (`w45`, `PENDING: WP-B commit`); beam4pm rust4pm wasm artifact (`w74`);
  wasm4pm flake fix + version 26.10.6 (`w94`, `w165`); zcode-cli 18-file
  stream green but uncommitted (`PENDING: WP-C commit`); ggen-marketplace
  pack-gate fix UNCOMMITTED (`w126`).
- **Unlanded μ**: all integration commits per w153-v2/w191 —
  `PENDING: coordinator commit lane`.

## Generated vs handwritten

- **Generated (lawful generator, verified)**: castle-bridge set —
  deterministic byte-stable re-render (W36); `priv/ash_surface/*` via
  `mix xaas.ash_surface` under `generatorIdentity: ash_surface:v26.10.6`
  (W73); ash-surface full-app artifacts at EA35 (`x8`, 410 actions,
  `node --check` OK); zcode_event_registry generator byte-identical
  (`w85`); beam4pm 677 ex4pm-regenerated resources + rust4pm wasm artifact
  (`r9`, `w74`); ferroplan wasm via repo's own build path (`w45`).
- **Handwritten (irreducible residue)**: gymact adapter, PPlan facade,
  Ferroplan bridge, refusal negative-test fixtures, all court/test files
  (Chicago-style, real collaborators), version-seam edits via lawful script
  (W19).
- **Drift guards**: generator drift guard byte-identical green (`w69`);
  docs/ABI ash_surface corpus NO DRIFT 11/11 (vector6); marketplace/chicago/
  zcode zero-diff exemplars (vector4); `xaas-mapping.generated.ttl` generator
  permanent-UNKNOWN (`w85`); CI parity gates P2-1/P2-2
  `PENDING: coordinator CI lane`.
- **Not hand-edited**: generated outputs per repo doctrine (`_WIRING_MATRIX.md`
  front-door law: exactly one marketplace pack pin, no sibling fallback).

## Commands / exits

Receipt-cited executed gates (exact exits from lane receipts):

- `mix compile` / `MIX_ENV=test mix compile` — exit 0 (post-w175 floor;
  w69, w108 sibling 178 files, w52 beam4pm 677 resources, w81 ggen cargo
  check exit success 2m13s).
- `mix test` targeted: web layer 347/0 (`w120`); chicago 150/0 (w146
  appendix); bridges+origin_authority+anchor 24/0 (`w163`); semantics 29/0
  (`w196`); telemetry 33/0 (`w197`); sa2a 102p/18skip (`w198`); operations
  103/0 (`w131`); oracle suites r_projection 9/9, consistency 18/18, yield
  8/8, successor 8/8, origin_authority 10/10 (`w82`/`w108`); refusal gate
  combined 20/20 (`w208`); actuation/castle/boundary 16/17 (`w69`).
- Full suite: tokened receipt `w158-suite-with-token.md` — 3125/3230, 105
  failures classified (Class E env pollution → fixed by `w280`; Class D
  stale-beam → zero real drift by `w281`); untokened best `w68b` —
  3145/3201, 56 classified failures.
- ash_surface: mix 1288/1304 (16F confined to gitignored scratch) + npm
  367/0 (`w102`); post-resync 24/0 + npm 367/0 (w126 W193 appendix).
- Playwright: `w118` 62/32/3; `w180` full_surface 11/0 + marketplace 4/0;
  `w111` 25/6 residual; autofde 2/2 (`w111`). `CLOSED: final Playwright
  lane` — w317-pw-final-tokened.md: full tokened `npx playwright test` @
  d1db2b03, 96/0/2 (98/98 --list), zero flaky; (w310g 503-with-token
  residual re-witnessed FIXED 2026-10-06, w344-health-503-diagnosis.md:
  fresh-boot 200 with token, ultracode_tick ok).
- CI/YAML: 21 workflows 21 PASS + mock gate `[]` (`w87`).
- Strict flags: test-env green both repos (vector5); prod leg exit 1 with
  16 warnings (`w103`). `PENDING: P2-2` — prod leg wired into CI; advisory
  draft landed: `.github/workflows/closure-gates.yml` (w327, YAML-valid,
  continue-on-error); blocking promotion = operator transition.
- Sibling suites: ggen_igniter 1555 green / credo clean (`w108`; `w122`
  1555 tests / 1 failure — W38 format moved an anti-vacuity anchor, no fix
  per lane instructions); zcode-cli 1072/0 (`w58`); beam4pm 1506/1509 +
  wasm clears 13 invalid groups (`w52`/`w74`); gymact pytest 2356 pass /
  41 skip / 10 xfail exit 0 (`w95`); ash_r2rml 998/0 (`w76`); ash_a2a
  3707/3708 baseline proxy (`w77`); ferroplan pin_drift 7/7 + wasmtime
  court 54/0 (`w45`); ex4pm baseline (`w75`); marketplace 1956 passed
  (`w105`); wasm4pm vitest 25/25 (`w94`).

## Verification ladder

Per `_FRONTIER.md` ladder + x7 scope correction (playwright rung applies
ONLY to browser-surface repos):

- **C (compile)**: reached with receipts on every repo class (above).
- **T (test)**: reached with receipts on all 13 repo rows; open: ash_pplan
  7→8F `PENDING: W20` (interim receipt on disk, final verdict pending);
  gymact end-to-end UNKNOWN (adapter receipts exist, no executed e2e gate)
  `PENDING: r8 falsifier or typed BLOCKED`; full xaas tokened suite
  CLOSED (`w158-suite-with-token.md`; failure classes adjudicated by
  `w280-async-env-isolation.md` / `w281-class-d.md`).
- **W (wiring)**: `_WIRING_MATRIX.md` W164 — pins live-verified;
  ash_a2a `/a2a/v1` mount real at `86214551`; ash_pplan bridge on facade;
  ferroplan digest-pin court; ggen pack pin `518572b6`; ash_surface path
  dep + `/ash_surface` static serve. zcode `/internal-api/execution`
  router-present, no witnessed e2e. G1–G5 fleet-wiring falsifiers UNRUN
  (1/11 repos wired per `x2`) — `PENDING: ash_surface fleet falsifiers`.
- **PW (Playwright)**: browser repos only. Best full run `w118` 62/32/3;
  seed class CLOSED (`w180`); app-gap class CLOSED (`w171-app-gaps.md`,
  adversarial re-run 6/6); marketplace-regression class CLOSED
  (`w169-marketplace-regression.md`, exact W105 baseline match);
  a2a SSE spec surface witnessed (`w270-a2a-sse.md`: 3 passed / 4 failed,
  SSE test passing at spec :164 — its 4 failures remain final-PW residual,
  not a new class). Final full green run `CLOSED: final Playwright lane` —
  w317-pw-final-tokened.md (96/0/2 tokened full PW @ d1db2b03; w310g
  503-with-token residual re-witnessed FIXED 2026-10-06,
  w344-health-503-diagnosis.md: fresh-boot 200 with token, ultracode_tick
  ok). CLI/library/planner repos terminate at
  rung 3 with typed receipts (x7 correction — satisfied per `_FRONTIER.md`
  per-repo sections).

## R / replay

- **Receipt corpus identity**: 119 files under `docs/sjira/v26.10.6/plans/`
  (W184b `_INDEX.md` count). Coordinator-owned index; standings editable
  only with receipt path per `_FRONTIER.md` update rules.
- **Replayable elements (receipt-cited)**: beam4pm evidence chain
  sha-pinned (`r9`, REFUSED_SHA_DRIFT on dirty-tree edit); ferroplan wasm
  digest pin reproduces registry+ontology pin byte-identically (`w45`);
  drift guard byte-identical reruns (`w69`); castle re-render byte-stable
  (W36); receipt-schema dual-version validator 52/56 corpus with residual
  typed OS-9 (`w107`); gymact DCM witnessed closure-bound receipt
  `adae920d…` (`w129`); ash_a2a conformance report + TCK verdict doc
  (`r4`); `surface_contract.json` generation contract (`x8`).
- **Replay identity of the final subject**: `PENDING: coordinator commit
  lane` — no integration commit exists yet, so exact-head ALIVE for the
  milestone is not mintable; the receipt cannot bind a SHA that does not
  exist (a commit cannot contain its own hash — out-of-subject receipt
  landing is the coordinator's post-commit step).
- `PENDING: coordinator` — final commit SHA, PR, and receipt-to-commit
  binding after integration.

## Branch / SHA / PR

- **Branch**: `feat/playwright-surface` (xaas, integration).
- **Base SHA**: `d1db2b03` (current integration base, per all three
  definition files).
- **Integration commit**: `PENDING: coordinator commit lane` (w153-v2
  dependency order; w191 hazard classification: DO-NOT-COMMIT / PARKED /
  COMMIT-eligible; no `_build-lane*` in final commit per cleanup law).
- **PR**: `PENDING: coordinator` — no PR minted; merge only on explicit
  request.
- **Sibling heads** (receipt-cited): ggen `000bffb8f`, ggen-marketplace
  base `3ddbfeb7`, ggen_igniter `7dbcdb3` (r3)/rebuilt tree (w108),
  ash_a2a pin `86214551`, ash_pplan ref `5f10c979`, ferroplan `c037876`
  + wasm artifact untracked, zcode-cli `7fc62da` + 18 dirty files, gymact
  `d3eb5e8` + 3 dirty docs, beam4pm `813eb92` + 2,495 dirty lines,
  wasm4pm `32deb59f6` (+ version bumps w165), autofde-lab `2a3d064e`,
  ash_surface `db5a8899` audited / `26.10.6` bumped.

## Standing

Per-repo standings (from `_FRONTIER.md`, receipt-only — do not upgrade
without an executed gate):

| repo | standing | receipt |
|---|---|---|
| xaas | PARTIAL_ALIVE | audits + `w69`, `w82`, `w108`, `w120`, `w103`, `w87`, `w91`, `w111`, `w70`, `w30`, `w68`, `w51`, `w85`, `w229` (full row in `_FRONTIER.md`) |
| ash_surface | PARTIAL_ALIVE | `x2`, `w69`, `w80`, `w91` |
| ggen | ALIVE (repo-level @ `000bffb8f`) | `r1`, `w81` |
| ggen-marketplace | PARTIAL_ALIVE | `r2`, `w80`, `w105` |
| ggen_igniter | PARTIAL_ALIVE | `r3` (criterion invalidated), `w108`, `w82`, `w91`, `w114` (plan-only) |
| ash_a2a | PARTIAL_ALIVE | `r4`, `w109` (court 5/5), `w113`, `w150` (fix in flight, no receipt) |
| ash_pplan | PARTIAL_ALIVE | `r5`, `w41` (facade 5/5) |
| ferroplan | PARTIAL_ALIVE | `r6`, `w45` (blocker CLOSED, artifact untracked) |
| zcode-cli | ALIVE (repo-level @ `7fc62da`) | `r7`, `w46`, `w58`, `w40` |
| gymact | PARTIAL_ALIVE (adapter) / UNKNOWN end-to-end | `w42`, `w79`, `w129` |
| beam4pm | PARTIAL_ALIVE | `r9`, `w52`, `w74` |
| wasm4pm | PARTIAL_ALIVE | `r10`, `w94` |
| autofde-lab | PARTIAL_ALIVE | `r11`, `w35`, `w78`, `w110`, `w111` |

- **Milestone standing**: PARTIAL_ALIVE. DoD 1–6 all PENDING per the W206
  §5 walk (DoD 7 N-A until review); none may be upgraded to ALIVE in this
  skeleton.
- `PENDING: W20` (ash_pplan adjudication — interim receipt on disk, final
  verdict not appended), `PENDING: W185` (standalone receipt in flight
  (W318); capstone evidence w236 on disk, w263b/w312 via w176 appendices),
  `PENDING: P2-2` (CI prod leg; advisory draft landed:
  `.github/workflows/closure-gates.yml` (w327, YAML-valid,
  continue-on-error); blocking promotion = operator transition),
  `PENDING: r8 falsifier or typed
  BLOCKED` (gymact), `PENDING: coordinator commit lane` (all commit legs;
  w289/w299/w300 commit-series receipts not on disk).

## Falsifiers

The observations that would kill the closure claims (receipt-cited, UNRUN
unless noted):

- ggen `sync run` drift falsifier at pinned SHA — UNRUN (`r1`/`w81`).
- ash_surface G1–G5 fleet-wiring falsifiers — UNRUN (1/11 wired, `x2`);
  Tier-2 projections zero external consumers.
- ggen_igniter §6 shipped-pack falsifier (hex consumer resolves
  ash-manufacture-pack by name) — UNRUN; `REFUSED(PACK_NOT_SHIPPED)` /
  `UNSUPPORTED(hex)` stands until executed (`r3`).
- ash-extension re-pin render verification: `ggen sync` at new pin shows
  any non-`ggen.lock` delta kills byte-identical prediction (`w80`).
- ash_a2a e2e at scale at pin `86214551`: PendingMigrationError 500s,
  -32700-vs--32600 parse defect, 406-before-auth (`w113`, `w150` in
  flight).
- ferroplan downstream wiring hops (xaas bridge vendoring, pplan provider,
  ash_surface binding) — UNRUN at digest `088d9c3b…` (unblocked by `w45`).
- zcode-cli end-to-end CLI invocation; release version drift `3.14.4-1`
  vs npm `3.14.4-32` (`w40`, OS-2 operator-gated).
- gymact: witnessed crown — DCM-018 under `CROWN_REQUIRES_WITNESSED_DCM`
  (`w79`); OS-10 crown gate unwitnessed; gymact-dod suite + PW spec UNRUN.
- beam4pm split commits (OS-5 operator-gated); 2 AuthorshipGate failures +
  REFUSED_SHA_DRIFT (pre-existing, tree-owner's).
- Full `npx playwright test` green — the run whose failure would kill the
  browser-rung claim: `CLOSED: final Playwright lane` — executed and
  passed (w317-pw-final-tokened.md, 96/0/2 @ d1db2b03; the falsifier ran
  and did not fire).
- Refusal `comm -23` recount must stay at delta 0; any new `REFUSED_*`
  token without a test-side occurrence kills coverage 62/62 (`w176`
  appendix, `w208`).
- OS-1…OS-12 operator register: typed gates, unlifted (OS-2/OS-5 outside
  lane authority; OS-9 law_evolution BLOCKED → v26.10.7+; OS-10
  BLOCKED(new-code) → v26.10.7+; OS-11 unowned permission-bit stripping).

## BLOCKED / UNSUPPORTED / REFUSED

Receipt-cited typed entries (carry falsifier + blocking reason inline; a
blocker branches the graph, it does not close the row):

- **BLOCKED:release-artifacts** — ggen-marketplace frozen court identity
  ggen `v26.8.11` @ `402cecdf` pin bump, user-gated (`r2` §4.4, OS-6).
- **BLOCKED:local-deps-install** (resolved by `w94` install) — wasm4pm
  local `pnpm test` pre-fix.
- **BLOCKED(BUILD_BROKEN)** — w30, w68, w146, w148 (all resolved by later
  receipts w175/w193; recorded as the failure record, not open blockers).
- **BLOCKED (environment)** — w113 pending-migrations token branch
  (migrated via `w151`); w70 webServer spawn (xattr).
- **BLOCKED(law_evolution)** — OS-9: GC23 courts require retired
  compile_prose surface; v26.10.7+ (`w107`/`w128` cited; W230 flagged the
  w133b/w128 receipt pointers as dead).
- **BLOCKED(new-code)** — OS-10: gymact witnessed_crown flip needs
  standing-feedback overlay + crown-premark-law change (`w129` receipt
  `adae920d`).
- **BLOCKED** — OS-12(a): `:revoke_token` under MIX_ENV=test,
  ash_onetime `:store_invariant`; needs operator/owner fixture decision
  (W183 findings; receipt pointer flagged dead by W230).
- **UNSUPPORTED(hex)** — ggen_igniter ash-manufacture-pack hex-install
  path: fixture-only, `shipped_packs/0` rejects ash paths
  (`REFUSED(PACK_NOT_SHIPPED)` class, `r3`).
- **UNSUPPORTED** — ferroplan fleet wiring (typed absence in xaas
  registry.ex, unbound planner_identity, zero PW coverage, `r6`);
  zcode-cli ash_surface coupling (typed n/a, `r7`); wasm4pm + beam4pm
  executable wiring edges typed NOT_REQUIRED (`r10`, `x2` doctrine table).
- **REFUSED (witnessed, in-product)** — anchor 8/10 live `mu_on_O` REFUSED
  (`w108`); beam4pm REFUSED_SHA_DRIFT on dirty-tree edit (`w52`);
  Ferroplan bridge typed digest/runtime refusals (`w53`); gymact adapter
  `:gymact_not_configured` (`w42`); plug 503/401 fail-closed floor
  (`w13`); honest 503 tokenless PW floor (`w113`).
- **REFUSED (process)** — no standing asserted without executed output
  (`_FRONTIER.md` rules; W123 refused coordinator-cited absent receipts:
  w9/w19/w21/w36–w38/w40-partial/w42–w48-partial/w50/w53–w56/w59/w79-partial/
  w90/w92/w93/w95/w98–w102/w104–w107/w109/w112/w113/w115–w119/w121–w125 —
  only files that exist were admitted; W206 refused to rest verdicts on
  w150/w158/w161/w169/w171/w174/w185/w186/w20 without files on disk).
- `CLOSED: W171` — 6 app-gap PW failures dispositioned as real app gaps,
  fixed, adversarially re-run 6/6 (`w171-app-gaps.md`); no residual
  BLOCKED/UNSUPPORTED row required for this class.
- `CLOSED: final Playwright lane` — full green run now exists
  (w317-pw-final-tokened.md, 96/0/2 tokened @ d1db2b03, 98/98 --list,
  zero flaky); the browser rung is witnessed ALIVE, not BLOCKED.

---

### Finalization checklist (coordinator, post-wave)

1. Land integration commits per w153-v2 order under w191 hazard map; record
   final SHA in Exact subject + Branch/SHA/PR.
2. Collect verdicts: DONE for W171, W169, W158, W150, W161, W174 (receipts
   on disk, flipped to CLOSED in this file). Remaining: W20 final verdict
   (w20 file is interim), W185 standalone receipt (absent).
3. Final full Playwright run receipt (replaces w118 as best).
4. Gymact end-to-end falsifier or typed BLOCKED (r8).
5. P2-2 CI legs (prod-compile, sync drift) wired + receipted.
6. Delete this file's PENDING markers only when the named receipt file
   exists on disk; never upgrade a standing without an executed gate.
