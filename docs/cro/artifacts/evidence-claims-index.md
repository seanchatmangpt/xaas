# Evidence–Claims Index (lane W405; refreshed W711, W855, W984fp, W984lg, W984lz)

Campaign v26.10.6 CRO-loop, honest-numbers directive. Subject: branch
`feat/playwright-surface`. W405 audit at head `d1db2b03…` 2026-10-06;
W711 refresh at head `a0723bf6` 2026-10-07; W855 refresh (rows 33–58) at
head `a0723bf6` 2026-10-07; W984fp refresh (rows 59–76) at head
`43265cb1` 2026-10-07; W984lg refresh (rows 77–92) at head `52ce8236`
2026-10-08; W984lz refresh (rows 93–95) at head `1ba31a97` 2026-10-08.
Repo `/Users/sac/xaas`.

Method: every pitch number checked against the on-disk artifact named in the
table. "Real" = number as stated in the receipt file, not the pitch copy.

## Claims table

| # | Pitch claim (as worded) | Real artifact (path + actual number) | Verdict |
|---|---|---|---|
| 1 | "mathematically unrepresentable" | No artifact proves mathematical unrepresentability. Nearest real evidence: fail-closed typed refusals — `docs/sjira/v26.10.6/plans/w236-refusal-capstone.md` (86 passed, 0 failures) and zero-config posture `w322-zero-config-posture.md` (posture HELD, zero safety-adjustable knobs). Rhetorical, not mathematical. | **UNBACKED** (qualify to "fail-closed deterministic refusal — out-of-bounds actions are refused, not repaired"; drop "mathematically") |
| 2 | "44 CASTLE negative fixtures" | `docs/sjira/v26.10.6/plans/w236-refusal-capstone.md` per-file table: CASTLE refusal-negative batches 1–6 = 19+12+7+3+3+18 = **62 tests**. "44" is the stale w67 interim combined run (`w67-castle-combined.md:16`, 44 passed) superseded by w236. | **BACKED-CORRECTED** → "62 CASTLE refusal-negative tests" |
| 3 | "7 auth-floor negative tests" | `docs/sjira/v26.10.6/plans/w236-refusal-capstone.md`: `test/xaas_web/plugs/require_internal_api_token_test.exs` = **7 passed**; grep -c confirms 7 test blocks in the file. | **BACKED** |
| 4 | "<15 ms WASI gate" | No latency receipt anywhere in `docs/sjira/v26.10.6/`, `bench/`, or `docs/cro/` measures the WASI/SHACL gate path. Only bench dirs are domain benches (sjira, prometheus proxy, etc.); no gate-latency benchmark exists on disk. | **UNBACKED** (remove, or measure first: add a real gate-latency bench + receipt before re-using the number) |
| 5 | "ML-DSA-65 signed receipts" / "every intercepted command generates a post-quantum cryptographic affidavit (NIST FIPS 204 ML-DSA)" | Real state: `lib/xaas/witness/catalog.ex:18` admits `"ML-DSA-65" => :ml_dsa65` as an ingest alias; `docs/claude/diataxis/reference/ash-configuration.md:180-181` documents it; sibling checkout `/Users/sac/ash_affidavit/lib/ash_affidavit/signing/keys.ex:32` lists `ML_DSA65` in `@algorithms` (repo prefix: `ash_affidavit/lib/ash_affidavit/signing/keys.ex`). The algorithm is assertion-exercised (w434: `:ml_dsa65` real assertions in catalog/live tests; hybrid ES256+ML-DSA-65 KAT vectors in `crypto_trust_kat.json`), but no receipt in `docs/sjira/v26.10.6/plans/` witnesses a runtime ML-DSA-signed receipt; the xaas witness surface ingests/records verification results, it does not sign; signing lives in the ash_affidavit sibling; and no artifact ties *every intercepted command* to a signed affidavit. | **BACKED-CORRECTED** → "ML-DSA-65 RUNTIME-SIGNED RECEIPT WITNESSED (w510: real OpenSSL 3.6.4 FIPS 204 sign/verify over JCS payload, tamper negative, persisted through Xaas.Witness.CertifiedReceipt, wired as AuditChain sig callback; engine-side wasm op UNSUPPORTED at pinned ABI — seam documented)|
| 6 | "RFC 8785 receipts, BLAKE3" | BLAKE3: computed **nowhere** in `lib/` — only `lib/xaas/deployment/release_snapshot.ex:15` accepts a `blake3:` prefix in a digest regex. Actual digest: `release_snapshot.ex:356` = **SHA-256 of `Jcs.encode(payload)`** ("RFC 8785/JCS closure identity" per its own comment, line 330). No witness receipt is 8785-canonical. | **BACKED-CORRECTED** → "SHA-256 digests over JCS (RFC 8785-style) canonical JSON in `Xaas.Deployment.ReleaseSnapshot`; BLAKE3 not used" |
| 7 | "FRE 902(14)" | Zero artifacts in repo (`grep -rn "902" docs/ lib/` — no FRE citation anywhere). Legal self-authentication claim has no technical or legal artifact behind it. | **UNBACKED** (typed: legal-evidence claim, no receipt — remove from InMail or have counsel substantiate before use) |
| 8 | "26/26 conformance" | `docs/sjira/v26.10.6/plans/w385-conformance-court.md:26`: "CONFORMANT 26/26 (100%) at HEAD 07180bd3"; EXIT=0 JSON report. Note its own scope caveat: in-repo pinned court corpus, **not** the official A2A TCK (refusal-ledger JCS scope_note concurs). | **BACKED** (with mandatory qualifier "pinned in-repo conformance court, not official A2A TCK") |
| 9 | "96/0 Playwright" | `docs/sjira/v26.10.6/plans/w317-pw-final-tokened.md:18`: "passed: 96" (96 + 2 skipped = 98 = `--list` count). | **BACKED** (say "96 passed / 2 skipped" if precision matters) |
| 10 | "62/62 refusal tokens" | `docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md` (5 rows) + `refusal-ledger-v26.10.6.jcs.json` `"coverage":"62/62"`, w202 delta-0 recount, w236 capstone. | **BACKED** |
| 11 | "86/0 capstone" | `docs/sjira/v26.10.6/plans/w236-refusal-capstone.md`: "Result: 86 passed", 12 files, 0 failures, per-file sum 86, subject `feat/playwright-surface` 2026-10-06. | **BACKED** |
| 12 | InMail: "uninsurable balance-sheet liability", "specialist talent blackmail", Caremark/Marchand/McDonald's case law | Out of technical-evidence scope; no artifact in repo. | **UNBACKED** (typed: rhetorical/legal — not a measured claim; outside this index's falsifier scope, flagged only) |

## Claims table — W711 refresh (rows added 2026-10-07)

Each row written after reading the cited receipt in full; the "witnesses"
column records what the receipt actually observes, not the wave's intent.

| # | Claim | Evidence artifact | What the receipt actually witnesses | Grade |
|---|---|---|---|---|
| 13 | OS-21 totality closures: 4 adversarial-input classes typed-refused, not raised | `docs/sjira/v26.10.6/plans/w640-os21-verify.md` | Fuzz suite 9 passed exit 0 (lane build `_build-laneW640`); 5 independent escape-probe recipes (P1–P4b) each run twice, deterministic typed verdicts (`REFUSED_MALFORMED_MARGIN_INPUT`, `REFUSED_BIAS_THRESHOLD`, `REFUSED_ARITHMETIC_OVERFLOW`, `ok: :admitted` for opaque list leaf); no FunctionClauseError/Protocol.UndefinedError/badarith. LANDED **on lane build, uncommitted** | witnessed |
| 14 | §4 OS register refresh (OS-1/15/16/19/21 status flips + OS-5 count correction) | `docs/sjira/v26.10.6/plans/w700-closure-plan-refresh.md` | Existence/grep spot-verification only (router.ex:202-228, w423 absent → OS-15 repoint, beam4pm 2,576 dirty files, release_audit.ex:14, fuzz-test marker, w665:77). **No test execution** in this receipt; the flips themselves rest on the underlying lane receipts (w640, w665, w600) | grep/existence |
| 15 | AIRo wiring ledger verified 14/14 repos, 0 drift | `docs/cro/artifacts/airo-wiring-ledger-verification-w668.md` | Read-only + real execution across 14 repos: 14 artifact paths exist at exact byte sizes; 3 durable vocab copies sha256 == pin `6274d2d8…8469`; 14 TTLs parse under real rdflib; cited test counts grep-verified; ggen + ferroplan `check_airo.sh` executed PASS; xaas mapping+pin tests 14 passed/1 skipped exit 0. Ledger rows cite "@ HEAD" with no pinned SHA (recorded, not counted as drift) | witnessed |
| 16 | ash_surface AIRo pin | `docs/sjira/v26.10.6/plans/w675-ash-surface-airo-pin.md` | New 3-group pin test executed at ash_surface `d55c576d`: standings valid?/validate! round-trips, REFUSED_* vocabulary contract, all VIA-cited paths re-derived from TTL exist. Ledger row confirmed, no drift | witnessed |
| 17 | gymact AIRo pin | `docs/sjira/v26.10.6/plans/w677-gymact-airo-pin.md` | Real pytest via repo venv rdflib 7.6.0: TTL size bounded, structure asserted (AISystem/Deployer/3 Risks/3 RiskSources/mapping); 4 cited test files exist, 7 passed 2 skipped. Ledger row CONFIRMED CONSISTENT | witnessed |
| 18 | autofde-lab AIRo pin ("8/8 cited paths") | `docs/sjira/v26.10.6/plans/w678-autofde-lab-airo-pin.md` | 6 pin tests + 6 court tests pass exit 0 at `2a3d064e`. **DRIFT (minor):** graph has **7** distinct `file:` seeAlso citations, not 8 — the literal count is wrong; all 7 exist, substance holds | witnessed + DRIFT (8→7 cited paths) |
| 19 | ex4pm AIRo pin | `docs/sjira/v26.10.6/plans/w680-ex4pm-airo-pin.md` | ex4pm surface is real and committed (`priv/ontologies/airo_risk_description.ttl` 7,956 B sha `766059ce…`, own w645b court, 77 triples, 20 pinned terms, pin tests pass). **DRIFT (coverage):** `airo-wiring-ledger.md` contains **no ex4pm row at all** — "ex4pm CONSISTENT" is unsupported by the ledger text; ledger coverage gap, not a wiring defect | witnessed + DRIFT (no ledger row) |
| 20 | wasm4pm AIRo pin | `docs/sjira/v26.10.6/plans/w681-wasm4pm-airo-pin.md` | Pin test executed at `32deb59f`: 8,511 B exact, real rdflib parse, 4 court tests re-run pass, all 5 cited paths resolve; TTL sha `b9316af2…` pinned. No drift | witnessed |
| 21 | ash_pplan AIRo pin | `docs/sjira/v26.10.6/plans/w682-ash-pplan-airo-pin.md` | Surface real and committed at `7eeaaa16` (11,609 B, sha `5d28a105…`, w635 court, vocab pin matches). **DRIFT (coverage):** ledger has **no ash_pplan row**; receipt's own standing PARTIAL_ALIVE pending a coordinator ledger row | witnessed + DRIFT (no ledger row) |
| 22 | zcode-cli AIRo pin | `docs/sjira/v26.10.6/plans/w683-zcode-cli-airo-pin.md` | New 5-test W683 court PASS at `eb97f76b`: 8,022 B exact, w356 contract shas recomputed in-test. Prior W615 bun court confirmed present, not re-run as gate. No drift | witnessed |
| 23 | ash_r2rml AIRo pin | `docs/sjira/v26.10.6/plans/w685-ash-r2rml-airo-pin.md` | Pin test executed at `b86a6a66`: fixture sha256 == `6274d2d8…8469` byte-verbatim vocab pin; standing ALIVE on exact subject | witnessed |
| 24 | ggen_igniter AIRo pin | `docs/sjira/v26.10.6/plans/w686-ggen-igniter-airo-pin.md` | `wc -c` 10,296 exact; sha `81ddec22…` pinned; 27 `airo:` terms all in AIRo 1.0 set asserted; VIA-cited pack paths exist; W618 court re-run 8 tests 0 failures. No drift | witnessed |
| 25 | ggen-marketplace AIRo pin | `docs/sjira/v26.10.6/plans/w687-ggen-marketplace-airo-pin.md` | Pin court at `4bb5fbaf`: sha256 byte-identical to `6274d2d8…8469`, 558 triples via real rdflib, real `marketplace.py validate` subprocess exit 0 (305 packs/503 ontologies). CONSISTENT | witnessed |
| 26 | ash_affidavit AIRo pin | `docs/sjira/v26.10.6/plans/w690-ash-affidavit-airo-pin.md` | 12,084 B exact; TTL sha `71d4f706…` newly pinned; 13 cited paths exist; every VIA-cited lib path resolves to a loadable module (`Code.ensure_loaded/1`; real module name `AshAffidavit.ABI` discovered). CONSISTENT | witnessed |
| 27 | ggen AIRo pin | `docs/sjira/v26.10.6/plans/w695-ggen-airo-pin.md` | Pin test at `bc4d2390` against w614 ledger row + w668 verification row (618 triples = 60 bare + 558 vocab; script PASS; 15/15 vocab terms; 5/5 cited paths) | witnessed |
| 28 | Refusal ledger 71-variant JCS refresh, coverage 71/71 | `docs/sjira/v26.10.6/plans/w705-ledger-refresh.md` + `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json` | 8 new entries, each source receipt read first; array 63→71, counts.declared corrected (was stale 62), coverage "71/71", mutant kills 9→12, mutation runs 10→13; final sha256 `96d539c2…` re-encoded and reproduced twice post-write | grep/existence (ledger) + witnessed (cited kills w676/w703/w640/w653b/w659d) |
| 29 | Margin hardening: malformed margin → typed refusal, not CaseClauseError | `docs/sjira/v26.10.6/plans/w676-margin-hardening.md` | Real pre-fix reproduction (string and fn margins → CaseClauseError); 1-guard fix in `robust_margin.ex`; 3 regression tests; mutation check: guard removal → 10/12 with 2 CaseClauseError, restored 37/37 green. Note: extreme-float dataset feature already typed-refused pre-lane; the W659e ArithmeticError was a test-helper defect, not a lib defect | witnessed |
| 30 | IncidentReport :MALFUNCTION misclassification fix | `docs/sjira/v26.10.6/plans/w679-malfunction-fix.md` | Fix reuses `EuAiActAdmission.refusal_atoms/0` closed set; 3 regression tests (all 8 EUAIA atoms → `[:INFRINGES_UNION_LAW]` exactly; non-EUAIA refusal and bare `:error` → `[:MALFUNCTION]`); mutation A killed (8/9), mutation B over-broad exclusion also killed | witnessed |
| 31 | Plug mount order: SyntheticMarkingPlug before EuAiActAdmissionPlug, courted | `docs/sjira/v26.10.6/plans/w703-plug-order-court.md` | 4/4 Chicago-style courts green via real `XaasWeb.Endpoint` pipeline: refused Art-5 POST is both refusal-enveloped and marked; **reorder mutation executed live** (test d, Plug.Conn level, endpoint unmutated) — halted refusal envelope ships UNMARKED, the kill observable test (c) pins at endpoint.ex:99-100 | witnessed |
| 32 | diataxis doc counts reconciled to code (19 domains / 116 resources) | `docs/sjira/v26.10.6/plans/w689-diataxis-reconciliation.md` | Grep derivation in this tree: 19 `ash_domains` entries (config.exs:13-33) + 19 `use Ash.Domain` files; per-domain `resource(` counts sum to 116; both docs corrected (13/92 → 19/116, 6 missing domain rows added, stale duplicate table deleted) | grep |

## Claims table — W855 refresh (rows added 2026-10-07, post-W711 landings)

Each row written after reading the cited receipt in full. "Grade" reflects
the receipt's own standing vocabulary, not the wave's intent.

| # | Claim | Evidence artifact | What the receipt actually witnesses | Grade |
|---|---|---|---|---|
| 33 | Fresh full gate green after repairs (census 1347/1348) | `docs/sjira/v26.10.6/plans/w778-gate-fix-verify.md` | F1 coordinator repair verified as-found (503/503 title_i+iii); F2 coordinator repair was **direction-inverted** (expected newest-first from `Enum.reverse |> take(2)`) — W778 corrected forward; then full gate `--exclude eu_ai_act_open_gap` → **1347 passed, 1 excluded, 0 failures, exit 0** on `_build-laneW778`. Mid-run concurrent-lane lib edits disclosed; final runs on settled tree. **STALE (2026-10-07, W984fp): totals superseded by W650h14's 1354/1355 census (row 70)** | witnessed |
| 34 | Terminal census CERTIFIED (1347/1348, deterministic) | `docs/sjira/v26.10.6/plans/w821-terminal-census-2.md` | Two census runs (incl. open gap) identical: 1347/1348, 1 failed = the 49.3 `flunk/1` open gap (W779/W815 ledger), via its own explicit flunk — not a regression; green gate 1347/1-excluded exit 0; delta 1348−1347=1 = open-gap count exactly. Closes the certification W662/W650c could not make. **STALE (2026-10-07, W984fp): totals superseded by W650h14's 1354/1355 census (row 70) — tree grew during the campaign; do not cite 1347/1348 as current** | witnessed |
| 35 | Checkout `:return` open-checkout guard (closes W796 (c)) | `docs/sjira/v26.10.6/plans/w809-return-guard.md` | Guard reads status FRESH FROM DB (in-memory variant proven vacuous by a real 10/12 failing run), 12/12 deepening courts + 19 pre-existing return-suite tests green; mutation rationale: guard-drop mutant killed by error-tuple AND inventory asserts independently. **Uncommitted**, PARTIAL_ALIVE | witnessed |
| 36 | Incident lifecycle guards (closes W793 gaps (a)/(b)) | `docs/sjira/v26.10.6/plans/w818-incident-guards.md` | `:resolved`-at-:create refused outright (guard (a) on :create); resolved→reopen refused via new `IncidentResolvedIsTerminal` on :update (guard (b)); 29/29 across deepening + migrated fixture; per-guard mutation falsifiers stated; 3 typed gaps (NO_RESOLVED_AT_GUARD, NO_POSTMORTEM_STATUS_GUARD, NO_CROSS_REFERENCE) pinned open, unfixed. ALIVE | witnessed |
| 37 | SA2A route exclusions guard (bare binary refused) | `docs/sjira/v26.10.6/plans/w831-exclusions-guard.md` | Terminal `admit_field("exclusions", _)` catch-all after the `is_list` clause routes non-lists to typed `{:refused, {:invalid_field, "exclusions"}}`; pinned-gap test converted to refusal court; 25/25 ×2 green. Clause-ordering bug (shadowing valid lists, 7 failures) caught and fixed in-lane. **Uncommitted**, PARTIAL_ALIVE | witnessed |
| 38 | SLA-credit path unfunded-platform fix (W785 overdraft exemption) | `docs/sjira/v26.10.6/plans/w835-sla-exemption.md` | Root cause: W785 exemption list omitted the one flow transferring FROM `platform:revenue:sla-credits`; fix adds `xaas_ledger.allow_overdraft` context to both SLA-credit change modules (`approval_sla_credit_apply_approve.ex`, `approval_patch_…`); 5/5 (was 3/5) + neighbors green, zero test-side exemptions. Closes the pre-existing RED W799 disclosed. **Uncommitted**, PARTIAL_ALIVE | witnessed |
| 39 | Fresh full gate status post-~20 lanes | `docs/sjira/v26.10.6/plans/w760-gate.md` | Real gate run: `--warnings-as-errors` exit 1 (268 warnings, baseline tree-wide); 2 deterministic court-side failures typed (F1 orphaned W538 expectation vs W679 suppression; F2 self-refuting staged test discarding the triaged struct); census tag `:eu_ai_act_open_gap` inert at runtime (0 selected). Standing **BLOCKED** at time of writing — both failures subsequently repaired (W778, row 33) | witnessed (superseded by #33) |
| 40 | Platform route-resource deepening (5 un-covered Route* resources) | `docs/sjira/v26.10.6/plans/w770-platform-deepening.md` | 14 new tests green (+26 pre-existing platform/authority, no regression): SystemActor gating on FeatureFlags/Secrets, cross-org refusals, RFC 1123 rule, certificate-secret rule, determinism, open reads. Honest typed gaps asserted in-file: approvals are vacuous pass-throughs (maker-checker half absent), no transition path on backups, RouteProjects dead-write | witnessed |
| 41 | Ledger reversal deepening (compensating-transfer round trip) | `docs/sjira/v26.10.6/plans/w799-reversal-deepening.md` | 5 tests green: credit→compensating-reverse round trip, conservation, determinism; no reversal action exists (grep 0 hits — UNSUPPORTED(reversal-action-absent)); double-reverse refusal is **by sufficiency accident**, not a guard (disclosed); SLA-credit path RED pre-existing (3/5) attributed to W785's lane — since closed by W835 (row 38) | witnessed |
| 42 | AshGraphql HTTP surface | `docs/sjira/v26.10.6/plans/w802-graphql-surface.md` | Typed finding: schema compiles (3 of 19 domains wired) but **serves no HTTP** — 0 route/plug/endpoint references (grep matrix reproduced); standing **UNSUPPORTED(graphql-http-surface)**, receipt-only, no invented tests | grep |
| 43 | Org-resolution coverage adjudication (W769 gap vs W743 courts) | `docs/sjira/v26.10.6/plans/w812-org-resolution-coverage.md` | Adjudicated genuinely distinct; 6 new Chicago courts on the token-mint org-binding path: 20/20 green; two new typed findings (dangling `%Org{}` struct escapes re-lookup — DB FK is the backstop; plug downgrade branch structurally unreachable under FK restrict); mock gate `[]`. RESOURCE_ALIVE | witnessed |
| 44 | AshTypescript RPC surface deepening | `docs/sjira/v26.10.6/plans/w813-rpc-surface-deepening.md` | 11 tests green (real router + pipeline + sandboxed Postgres): happy envelope, validate errors, action_not_found/missing_required_parameter, W723 auth floor (401/503 fail-closed), W636 repoint regression, determinism; corrected against real output through 6→11 iterations. Typed gaps: nil-actor reads are empty-set-scoped, not refused; RPC controller never sets an Ash actor. ALIVE | witnessed |
| 45 | JSON:API content-negotiation court | `docs/sjira/v26.10.6/plans/w817-negotiation-court.md` | 16/16 ×2 (different seeds), full unauthenticated×incompatible-Accept matrix: 401 floor never 406 (W739/W299c ordering holds both scopes); Content-Type discipline SPLIT (application/json → AshJsonApi 415 document; text/plain → Plug.Parsers raised UnsupportedMediaTypeError first); happy cells assert `application/vnd.api+json` response header. ALIVE | witnessed |
| 46 | closure-gates.yml verification | `docs/sjira/v26.10.6/plans/w826-closure-gates-verify.md` | Findings-only: YAML parses, 4 jobs, all step paths exist, receipt upload path self-consistent, action pins match ci_cd.yaml, advisory posture confirmed (`continue-on-error` on 3 legs, never required), superseded claims all true. External ggen pin unverifiable locally (UNKNOWN, mirrored from admitted ci_cd). ALIVE | grep/existence |
| 47 | Doctest surface verification | `docs/sjira/v26.10.6/plans/w832-doctest-verify.md` | Real run ×2: **6 doctests, 6/6 passed** (WorkerEnv 2 + ProviderRecovery 5 prompts→6 registered; the whole lib doctest surface is 2 modules); semantics modules carry zero doctests; top-3 doctest candidates identified, findings-only (no lib edits). ALIVE | witnessed |
| 48 | TS codegen drift court | `docs/sjira/v26.10.6/plans/w837-ts-drift-court.md` | Real `ash_typescript.codegen` executed in-process; byte-compare against tracked `assets/js/ash_rpc.ts` (12064 B) / `ash_types.ts` (33891 B) — IDENTICAL; determinism ×2; typed failures DRIFT_ASSET_STALE / NONDETERMINISTIC_CODEGEN; tracked artifacts untouched after runs. ALIVE | witnessed |
| 49 | Priority e2e revalidation post-W752 | `docs/sjira/v26.10.6/plans/w842-e2e-revalidation.md` | Fresh playwright boot on port 4126: 24 passed / 1 designed `test.fixme` skip / 0 failed across 6 priority specs — W752's PARTIAL_ALIVE closes to ALIVE; W822 fresh-boot acceptance closed. Typed finding W842-F1 (config-class, pre-existing): tokened boot probe header word-splits to a header REMOVAL in `playwright.config.cjs:67` — not fixed, recorded for coordinator | witnessed |
| 50 | Open-gap registration in corpus-README (Art. 49(3)) | `docs/sjira/v26.10.6/plans/w815-gap-registration.md` | Doc-only: exactly 1 typed open gap (49.3) registered; "zero open gaps" reading (W760) corrected in-place by pointer; census-vs-gate delta mechanism (1348−1347=1) witnessed with W779's runs copied verbatim; totals re-stamped 1347/1348 (was 1200). No test run by design | grep/existence |
| 51 | ash-configuration.md GraphQL overclaim fix | `docs/sjira/v26.10.6/plans/w819-graphql-doc-fix.md` | Doc-only correction from W802 evidence: "compiles, not mounted", 3-of-19 domains wired, standing UNSUPPORTED(graphql-http-surface) — falsifier was W802's own greps, reproduced pre-edit. ALIVE (doc) | grep |
| 52 | architecture-overview.md refresh | `docs/claude/diataxis/explanation/architecture-overview.md` via `docs/sjira/v26.10.6/plans/w827-arch-overview-refresh.md` | 12-row per-claim table: "eight lease verbs" **CORRECTED to 10** (code-counted in controller); Ultracode 8 resources, /a2a/v1 routing, plug ordering, raw-body paths, OcelEnvelope validation, A2A parse floor, card caching all added/verified against source file:line. PARTIAL_ALIVE (prose, read-verified, no execution) | grep |
| 53 | Standing-vocabulary diataxis reference page | `docs/claude/diataxis/reference/standing-vocabulary.md` via `docs/sjira/v26.10.6/plans/w830-standing-vocab-page.md` | New page; every code citation read live at a0723bf6 (status gate 8-member vocabulary + 2 typed refusals, registry 5 UNKNOWN / 5 UNSUPPORTED rows, w768/w768-prior receipts). Self-declared PARTIAL_ALIVE by its own ALIVE-requires-execution law | grep |
| 54 | kanban→xaas rename residue sweep | `docs/sjira/v26.10.6/plans/w839-kanban-residue.md` | Full grep sweep of lib/+config/: exactly 1 hit = historically accurate rename-commit comment (LEAVE, rewriting would make it false); zero stale text; `mix compile --force` exit 0. ALIVE | grep/existence |
| 55 | ash_admin/ggen how-to verification | `docs/claude/diataxis/how-to/fix-ash-admin-and-use-ggen-for-codegen.md` via `docs/sjira/v26.10.6/plans/w841-ashadmin-howto-verify.md` | 10-row per-claim table: stale counts **CORRECTED** (7 core / 12+ → 17 of 19 domains carry the admin block; "other 5" → 17 modules), example block replaced verbatim from `lib/xaas/accounts.ex:1-16`; verify commands form-verified only (no server run, no build root) | grep |
| 56 | Generated-surface census | `docs/sjira/v26.10.6/plans/w849-generated-surface-census.md` | 12 surfaces: 8 DRIFT-CHECKED (sha pin or byte-compare courts), 4 PROVENANCE-ONLY (`mcp_scope.ex`, library.manufacture, capital_census facts, ocel_envelope), 0 UNPINNED; registry guard is a sha256 pin court, not regen-and-compare — only the W837 TS court does real regen; P2-2 CI/regen leg open | grep |
| 57 | Next Read case-study README verify/correct | `docs/case-studies/next-read/README.md` via `docs/sjira/v26.10.6/plans/w850-nextread-readme-verify.md` | 4 corrections + 1 new section: stale seeds.exs claim corrected to DevSeeds chain, `.spec.js`→`.spec.cjs`, W809 return-guard + courts section added; W796 count discrepancy resolved receipt-wins (11/11, not the brief's 11/12); W838 marked in-flight, count not invented. PARTIAL_ALIVE (doc-only) | grep |
| 58 | ERRC ELIMINATE-10 rationale refresh (fleet, ggen-marketplace) | `/Users/sac/ggen-marketplace/packs/xaas-castle-bridge-pack/ontology.ttl` via `docs/sjira/v26.10.6/plans/w756-errc-rationale-refresh.md` | Fresh grep derivation in xaas: **117** `Xaas.Resource` wrappers / **152** total `use Ash.Resource` / 19 domains (W754's 115/150 was itself copy-drift); single-line ontology edit, rdflib parse clean (332 triples), 12 ERRCDecision rows unchanged. **Uncommitted in ggen-marketplace**; `ggen sync` regeneration into xaas NOT run (coordinator-owned). ALIVE pack-level | witnessed + DRIFT (supersedes row 32's 116-resource count) |

### DRIFT summary (W855)

- #58 w756 vs row 32 (w689): W689 reconciled diataxis docs to **116** resources;
  W756's fresh grep counts **117** `Xaas.Resource` wrapper resources (152 total
  `use Ash.Resource`). RESOLVED (W855 follow-up, coordinator recount 2026-10-07):
  the divergence is live-tree drift between two valid metrics — `resource(`
  declarations across the 19 domain files counted **118** and `use Xaas.Resource`
  wrapper files **115** at the same recount moment (the tree gains resources
  continuously during the campaign). Both metrics are scope-valid; the shipped
  docs should cite the metric they mean: W689's diataxis number = `resource(`
  declarations; W756's pack rationale = `use Xaas.Resource` wrapper files. Re-grep
  at use time; do not freeze either number into prose without a date stamp.
- #39 w760's "0 open gaps is real" reading was itself corrected by W779/W815
  (row 50): exactly 1 typed open gap (49.3). The gate convention was self-
  consistent but the census mechanism was inert; totals moved 1200 → 1347/1348.
- Uncommitted-landing caveat now spans #35 (W809), #37 (W831), #38 (W835),
  #58 (W756, in ggen-marketplace) plus the prior W711 note — coordinator
  integration still pending for all.

### DRIFT summary (W711)

- #18 w678: ledger's "8/8 cited paths" for autofde-lab is actually 7 distinct
  citations (all exist — count error, substance holds).
- #19 w680 / #21 w682: `airo-wiring-ledger.md` has no row for ex4pm or
  ash_pplan, though both carry committed AIRo surfaces — ledger coverage gap;
  the 14/14 verification (row 15) is over the ledger's own 14 repos only.
- #14 w700: OS-21/OS-19 landings are on the uncommitted lane build at
  a0723bf6 — coordinator integration still pending.

## Claims table — W984fp refresh (rows added 2026-10-07, the 2026-10-07 evening wave)

One row per wave commit, f0321df2 → 43265cb1 (20 commits), in landing order.
Refresh at head `43265cb1` 2026-10-07. Each receipt read in full; court
numbers re-read from the receipt, not the commit subject.

| # | Claim | Evidence artifact | What the receipt actually witnesses | Grade |
|---|---|---|---|---|
| 59 | SpgGate integration landed (F2 fingerprint guard + `admit_spg/1` seam) | `docs/sjira/v26.10.7/plans/w650h22-commit.md` | Exact subject `f0321df2`, FF `c0626503..f0321df2`; fresh-root compile EXIT=0; 18 passed / 0 failures (spg_integration 8, spg_gate 5, actuation_test 5); six-checkbox table re-verified on disk; disclosed out-of-pathspec `run_idempotency_deepening_test.exs` 7/10 (ActuationIntent persistence, not this lane's file). ALIVE | witnessed |
| 60 | SpgGate landing commit receipt | `docs/sjira/v26.10.7/plans/w650h22-commit.md` | `ee6c18bc` carries the w650h22 receipt itself (pushed in range `ee6c18bc..34fc8a53` per w650h33); nothing on disk cites `ee6c18bc` as subject — self-referential-limits class | grep |
| 61 | vkg query_depth court landed (unreceipted-owner) | `docs/sjira/v26.10.7/plans/w650h33-commit.md` | Exact subject `34fc8a53`, FF `ee6c18bc..34fc8a53`; strict compile fresh root EXIT=0; court 5 passed EXIT=0; owner receipt w984de **UNSUPPORTED (never minted)** — disclosed, retrospective coverage via w650h11 repair. Court ALIVE | witnessed |
| 62 | vkg query_depth court: commit-receipt leg + git-state correction | `docs/sjira/v26.10.7/plans/w650h33b-commit.md` | Subjects `d51119c5` (git-state verdict correction) and `0b1b70fc` (receipt-only commit); concurrently-landed `34fc8a53` verified identical bytes; re-run 5 passed exit 0; compile --strict EXIT=0. LANDED | witnessed |
| 63 | causal_receipt process_receipt_depth court: first-ever green on a committed subject | `docs/sjira/v26.10.7/plans/w650h33c-commit.md` | Exact subject `32b72c4f`, FF `d51119c5..32b72c4f`; fresh-root compile EXIT=0; court **5 passed / 0 failed** — previously CompileError'd, 0/5 ever executed; replay block included. ALIVE | witnessed |
| 64 | W984ds + W650za completed-lane courts landed | `docs/sjira/v26.10.7/plans/w984ds2b-commit.md` | Exact subject `5cf56c13` (full SHA in receipt), FF `34fc8a53..5cf56c13`; fresh-root compile EXIT=0; batch **10 passed / 0 failures** (validations 5 + incident-lifecycle 5); prior-landing check `git log` empty; build root moved to /tmp (rm denied), repo path verified absent. ALIVE | witnessed |
| 65 | W984ds2b receipt landing + cleanup-wording correction | `docs/sjira/v26.10.7/plans/w984ds2b-commit.md` | `b75918a5` carries the receipt; `f2d30813` is the cleanup-wording correction (rm denied; build root moved to /tmp). Doc-only; nothing on disk cites either SHA as subject | grep |
| 66 | Gov/actuation courts batch (W984dx/W984dw/W984dr2b) | `docs/sjira/v26.10.7/plans/w984el-commit.md` | `acacc1db`: 6 files +1166 (freeze_window_active, causal_admission, gov thin batch + 3 receipts); fresh re-verification in `_build-laneW984el`: mock gate `[]`, 7-file batch **91 passed / 0 failed exit 0** (14+14+20+33+5+5). ALIVE | witnessed |
| 67 | Adapters/billing/bridges courts batch (W984dy/W650v5/W650v7) | `docs/sjira/v26.10.7/plans/w984el-commit.md` | `ab3562b8`: 7 files +643 (ils_repo_fixture, aws_repo_adapters, sla_credit court + 3 receipts); same 91-passed batch gate. ALIVE | witnessed |
| 68 | Docs leg (W984ef runbook addendum + W984eg actuation-and-semantics deepening) | `docs/sjira/v26.10.7/plans/w984el-commit.md` | `8f9ea495`: 4 files +302/-1; disclosure: shared `actuation-and-semantics.md` carried sibling-lane working-tree content alongside; cited courts already landed. LANDED (docs) | grep |
| 69 | W984el landing-batch commit receipt | `docs/sjira/v26.10.7/plans/w984el-commit.md` | `ecf84663` carries the receipt itself; cited as stage-time base by w650h14 (`ecf84663` at stage time). Self-referential-limits class | grep |
| 70 | Gated lib/test landing batch 1 (16 files, v26.10.7 fleet seal) | `docs/sjira/v26.10.7/plans/w650h14-gated-commit.md` | Subject `3c03bffa`; fresh-root `mix compile --force` EXIT=0; eu_ai_act census **1354/1355** (1 failure = concurrent-lane mid-edit compile, isolated rerun 26/26 → floor ≥1352/0/1 MET with disclosure); staged batch 57 passed EXIT=0; typed exclusions table (SPG landed by own lane; ENV-DRIFT pin courts excluded). ALIVE for the gated landing | witnessed |
| 71 | W650h14 docs commit (runbook/census/receipt doc updates) | `docs/sjira/v26.10.7/plans/w650h14-gated-commit.md` | `ed015775`: v26.10.6 runbook, w984cj coverage map, w983g receipt; same receipt's gates. LANDED (docs) | grep |
| 72 | Landing batch #2 (courts w984eh/en/ea/dt + probes) | `docs/sjira/v26.10.7/plans/w984fe-commit.md` | `0153101a`: 5 court files; batch gate real run **28 passed, exit 0** (2+12+3+5+6); mock gate `[]`. ALIVE | witnessed |
| 73 | OTP-29 Map.update compat module (W984ee) + airo_risk_mapping lib trio | `docs/sjira/v26.10.7/plans/w984fe-commit.md` | `c6bf5bbc`: `lib/xaas/compat/otp29_map_update.ex` + probes; w984ed trio disclosed as **already landed by sibling lane in 3c03bffa** (not duplicated); w984ee court file ABSENT from tree (left to owning lane) — lib landed, court pending | witnessed |
| 74 | mix.lock 3-deletion unlock (absinthe, absinthe_plug, ash_graphql) | `docs/sjira/v26.10.7/plans/w984fe-commit.md` | `49992412`: `git diff mix.lock` verified exactly 3 deletions pre-stage. ALIVE (deps) | witnessed |
| 75 | w984ej security-parsing receipt (court file deferred) | `docs/sjira/v26.10.7/plans/w984fe-commit.md` | `a420b7d5`: receipt only; court file deferred to concurrent lane W984ez per batch contract. PARTIAL_ALIVE (court pending) | grep |
| 76 | w984et mix.lock probe + W984fe commit receipt landing | `docs/sjira/v26.10.7/plans/w984fe-commit.md` | `43265cb1` (HEAD at refresh time): carries w984et-probe.md (omitted from 49992412 by pathspec gap) + the receipt itself. **Nothing on disk cites `43265cb1`** — a commit cannot contain its own hash (out-of-subject receipt gap, catalog C21); content standing inherited from w984fe's batch gates | grep (receipt-absent-by-construction) |

### DRIFT summary (W984fp)

- Rows 33/34 (W778/W821): the certified census totals **1347/1348 are
  superseded** — W650h14's 2026-10-07 census is **1354/1355** (row 70). The
  1347/1348 numbers were correct at their subject; the tree grew since. Re-grep
  at use time; do not cite 1347/1348 as current.
- Row 70's census carries its own in-flight caveat (1 failure disclosed as a
  concurrent-lane compile artifact, isolated 26/26) — cite "≥1352/0/1 with
  disclosure", not a bare 1354/1355.
- Receipt-absent-by-construction now covers #76 (`43265cb1`) in addition to
  the W855 uncommitted-landing caveat list; out-of-subject receipts (C21)
  remain an open coordinator item.
- #59 w650h22 discloses a pre-existing out-of-pathspec RED leg
  (`run_idempotency_deepening_test.exs` 7/10, ActuationIntent persistence) —
  open, not fixed by any receipt in this wave.

### Counts

W984fp refresh (rows 59–76, 20 commits → 18 rows; batch commits share
receipts): witnessed 12 (#59, 61, 62, 63, 64, 66, 67, 70, 72, 73, 74 —
gates re-run or batch-run on the exact subject) · grep/existence 6 (#60,
65, 68, 69, 71, 75 — doc-only or receipt-carrier commits; #76 is
receipt-absent-by-construction, annotated). No receipt diverged from its
commit's claim; two disclosures recorded as-is (w650h22's out-of-pathspec
RED leg; w650h14's concurrent-edit census failure). All 20 wave SHAs
grep-verified against `docs/sjira/v26.10.{6,7}/plans/`; 18/20 have an
on-disk receipt citing or carrying them.

Total rows: 12 → 32 → 58 → 76.

## Ship-list (use these wordings)

- "62 CASTLE refusal-negative tests; 7/7 fail-closed auth-floor plug tests;
  86-test refusal-negative suite, 0 failures" (w236).
- "62/62 typed refusal tokens covered, delta 0" (w202/w236; ledger JCS).
- "One-command conformance court: 26/26 CONFORMANT, EXIT=0, machine-readable
  JSON — pinned in-repo court corpus (not the official A2A TCK)" (w385).
- "96 Playwright E2E passed (2 skipped) under real tokens" (w317).
- "SHA-256 digests over JCS (RFC 8785-style) canonical JSON for closure
  identity" (`lib/xaas/deployment/release_snapshot.ex`).
- "ML-DSA-65 (FIPS 204) admitted signing-surface algorithm in the witness
  catalog" — not "every intercepted command yields an ML-DSA affidavit".

## Remove / qualify before shipping

1. "<15 ms WASI gate" — remove; no latency receipt exists (measure first).
2. "RFC 8785 receipts, BLAKE3" — drop "BLAKE3"; qualify 8785 as JCS-style,
   scoped to `ReleaseSnapshot`, not all receipts.
3. "FRE 902(14)" — remove from InMail copy; no backing artifact.
4. "mathematically unrepresentable" — qualify to "fail-closed deterministic
   refusal".
5. "44 CASTLE negative fixtures" — replace with 62 (w236 per-file table).
6. "every intercepted command generates a post-quantum cryptographic
   affidavit (ML-DSA)" — qualify to admitted-algorithm support; runtime
   ML-DSA-signed receipts are not witnessed on this subject.

## Counts

W405 original audit (rows 1–12): BACKED 5 (#3, #8, #9, #10, #11) ·
BACKED-CORRECTED 3 (#2, #5, #6) · UNBACKED 4 (#1, #4, #7, #12 — #12 scoped
out as rhetorical).

W711 refresh (rows 13–32): witnessed 17 (#13, 15–27, 29–31 — of which
3 carry a DRIFT annotation: #18, #19, #21) · grep/existence 3 (#14, #28
ledger half — its kill evidence is witnessed in the source receipts — and
#32).
No row's receipt failed to support its claim outright; three DRIFT
annotations (count off-by-one, two ledger coverage gaps) and one
uncommitted-landing caveat (#13/#14, OS-19/OS-21) recorded above.

W855 refresh (rows 33–58, post-W711 landings): witnessed 18 (#33, 34, 35,
36, 37, 38, 39, 40, 41, 43, 44, 45, 47, 48, 49, 58 — of which #58 carries a
DRIFT annotation vs row 32, and #39's BLOCKED standing is superseded by
#33) · grep/existence 8 (#42, 46, 50, 51, 52, 53, 54, 55, 56, 57 — #42 is a
grep-based typed UNSUPPORTED finding, #46/54 grep/existence with ALIVE
standing, #50–53/55–57 doc-only lanes).
Receipt-absent lanes skipped, not invented: **W840-check** (no
`w840-*.md` in `docs/sjira/v26.10.6/plans/`) and **W854-check** (no
`w854-*.md`). 26 receipts read in full; 26 rows added; no receipt diverged
from its claim outright — one cross-row divergence (row 32's 116 vs W756's
117 resources) recorded as DRIFT above.

Total rows: 12 → 32 → 58 → 76 → 92 (W984lg, 2026-10-08).

## Claims table — W984lg refresh (rows added 2026-10-08, batches #9–#11)

One row per wave commit, 43265cb1 → 52ce8236 (16 commits), in landing
order. Refresh at head `52ce8236` 2026-10-08. Each receipt read in full;
court numbers re-read from the receipt, not the commit subject. All 16
SHAs grep-verified against `docs/sjira/v26.10.{6,7}/plans/`.

| # | Claim | Evidence artifact | What the receipt actually witnesses | Grade |
|---|---|---|---|---|
| 77 | W984gk doctor/stogaf fixes + 11-test family court | `docs/sjira/v26.10.7/plans/w984il-commit.md` | `6fbfb47a`: lib diffs verified to be exactly the two disclosed fixes (empty-SHA fallback; per-lane census walk cap, re-tightened 2,000→200/lane after a 120s court timeout against 127 orphaned lane roots). Batch gate 8 court files → **53 passed, 0 failures** (52/53 first run, timeout repaired in-lane); compile EXIT=0; mock gate `[]`; doctor smoke EXIT=0 with disclosed truncation. ALIVE | witnessed |
| 78 | 8 family/remainder courts from finished lanes (batch #9 courts) | `docs/sjira/v26.10.7/plans/w984il-commit.md` | `c58a8cea`: W984hf(11)/hh(10)/hj(8)/he(3)/hi(3)/ho(7)/hq(6)/hp(10); same batch gate 53/53. ALIVE | witnessed |
| 79 | Diataxis truth-pass doc edits + receipt-only probes (batch #9 docs) | `docs/sjira/v26.10.7/plans/w984il-commit.md` | `663786f5`: W984hv/hy/hz/ik truth-pass edits + probes w984hk/hs/hv/hy/hz/ik; already-tracked files skipped, out-of-contract dirty files untouched. LANDED (docs) | grep |
| 80 | W984il landing-batch commit receipt | `docs/sjira/v26.10.7/plans/w984il-commit.md` | `145b5659` carries the receipt itself; cited as base by w984jm-commit and reconciled by w984kb-push (`145b5659` ancestor of HEAD, exit 0). Self-referential-limits class | grep |
| 81 | Disclosed lib repairs + test repairs + their courts (batch #10) | `docs/sjira/v26.10.7/plans/w984jm-commit.md` | `ad159c18`: W984ht/W984ii lib repairs (ii lib/ diff byte-verified to be exactly the entries-shape guard in `recompute_root`) + W984ig/W984iq test repairs; 11 files. Batch gate 13 files → **160 passed, 0 failures** (12.2s); compile EXIT=0; mock `[]`. ALIVE | witnessed |
| 82 | hn/ib/io/is/iv/ix/jb courts + owner probes (batch #10 courts) | `docs/sjira/v26.10.7/plans/w984jm-commit.md` | `ef2e8714`: 14 files; all 12 owner receipts read and confirmed green pre-landing (w984hn 7+32, ib 18, ig 12+119 dir, io 6, is 5+36 dir, iq 78, iv 16 ×2, ix 1, jb 5, ii 19, ht 45, ew 8); same batch gate 160/0. ALIVE | witnessed |
| 83 | Art. 13.x counterfactual deepening court (batch #10) | `docs/sjira/v26.10.7/plans/w984jm-commit.md` | `79581cf6`: W984ew court (2 files), owner receipt w984ew 8 passed; same batch gate. ALIVE | witnessed |
| 84 | Registers, manifests, truth-pass doc sections, witness receipts (batch #10 docs) | `docs/sjira/v26.10.7/plans/w984jm-commit.md` | `127dc790`: 18 files, docs-only. LANDED (docs) | grep |
| 85 | W984jm landing-batch commit receipt | `docs/sjira/v26.10.7/plans/w984jm-commit.md` | `f446d9c5` carries the receipt itself; push state independently confirmed by w984kb-push (`rev-parse HEAD origin/...` → both `f446d9c5…`, `origin..HEAD` empty). Self-referential-limits class | grep |
| 86 | Push-state reconciliation (jy's stale origin reading corrected) | `docs/sjira/v26.10.7/plans/w984kb-push.md` | `b6fad269` (doc-only): real git outputs — fetch, rev-parse both lines identical `f446d9c5…`, `origin/feat/playwright-surface..HEAD` empty, `merge-base --is-ancestor 145b5659 HEAD` exit 0. Nothing pushed; W984ir audit state recorded-not-committed. ALIVE (observed) | grep/existence (git outputs recorded verbatim in receipt) |
| 87 | release_audit `ref_resolves?/1` glob-class widening + audit-zero repair | `docs/sjira/v26.10.7/plans/w984kc-commit.md` | `4a308950` (full SHA `4a3089500bc35b0a…` in receipt): diff verified as exactly one hunk (+15/−1); gates — compile EXIT=0, release_audit suite **19 passed exit 0**, `mix xaas.release_audit` **exit 0 zero findings** (version=26.10.7, ash_resources=122), mock `[]`. Disclosed: w984gv-probe.md does not exist (vacuous condition); the 4 first-run audit findings were the scanner self-trigger class, repaired per the w467 hyphenation precedent. ALIVE | witnessed |
| 88 | W984kc landing receipt commit+push update | `docs/sjira/v26.10.7/plans/w984kc-commit.md` | `7d9968d0` appends the push block (`b6fad269..4a308950` FF, origin==HEAD==`4a308950` verified) to the receipt. Doc-only | grep |
| 89 | W984fv TOFU pinning for agent-card trust surface (W784) | `docs/sjira/v26.10.7/plans/w984kf-commit.md` | `9a00385c`: `lib/xaas/a2a/tofu.ex` + `test/xaas/a2a/tofu_test.exs` + receipt; batch gate 16 court files → **99 passed, 0 failures, 6 excluded** (excluded = `support_court_w984jo` behind `eu_ai_act` tag, re-run `--include eu_ai_act` → 6 passed exit 0; total 105/0); mock `[]`; compile via test run EXIT=0. Disclosed task-path typo (tofu.ex is lib/, not test/). ALIVE | witnessed |
| 90 | 16 family/remainder courts from finished lanes (batch #11 courts) | `docs/sjira/v26.10.7/plans/w984kf-commit.md` | `caf91669`: courts ie/hr/hw/hu/ip/iu/ij/jo/jq/jj/jf/ji/jk/je/jd + 14 owner probes; same batch gate 105/0. Scope disclosures: w984jv court skipped (no owner receipt); hh/hj already landed in batch #9. ALIVE | witnessed |
| 91 | W784/W902 register flips, W984kd tally addendum, jy runbook addendum, jl/kd/fs receipts (batch #11 docs) | `docs/sjira/v26.10.7/plans/w984kf-commit.md` | `86c69061`: docs-only (w859-typed-gap-register flips, tally, runbook addendum #6, 4 receipt files). LANDED (docs) | grep |
| 92 | W984kf landing-batch commit receipt | `docs/sjira/v26.10.7/plans/w984kf-commit.md` | `52ce8236` (HEAD at refresh) carries the receipt itself; independently cited as HEAD subject by `docs/sjira/v26.10.6/plans/w984lf-probe.md` (batch #11 = 9a00385c/caf91669/86c69061, lane receipt commit 52ce8236). Self-referential-limits class | grep |
| 93 | 10 family/remainder courts from finished lanes (batch #12 courts) | `docs/sjira/v26.10.7/plans/w984kn-commit.md` | `fcef478b`: 6 files — courts `family_court_w984jc` (OCEL), `stragglers_court_w984jv`, `library_pack_render_court_w984ju` + owner probes w984jc/ju/jv. Batch gate: 10 candidate court files → **58 passed, 0 failures, exit 0** (exact sum of per-lane counts 2+6+9+6+8+5+3+11+3+5); mock gate `[]` exit 0; cold lane build `_build-laneW984kn`. Disclosed: 14 of the original 16 pathspec members already landed by `caf91669`; one PromEx/Grafana `:nxdomain` compile warning (environment). ALIVE | witnessed |
| 94 | Receipt-only lanes jn/kl/kh (batch #12 docs) | `docs/sjira/v26.10.7/plans/w984kn-commit.md` | `6ff734f2`: docs-only — `w984jn-shacl-drift.md`, `w984kl-probe.md`, `w984kh-w729.md` (kh receipt on disk TODO-free; its W729 flip already landed in `86c69061`). Disclosed: runbook addendum #7 (kl) already landed in `86c69061`; the uncommitted runbook diff at commit time was W984li's in-flight edit, not staged. LANDED (docs) | grep |
| 95 | W984kn landing-batch commit receipt | `docs/sjira/v26.10.7/plans/w984kn-commit.md` | `1ba31a97` (HEAD at refresh) carries the receipt itself; independently cited as HEAD subject by `docs/sjira/v26.10.6/plans/w984lt-probe.md` and `w984lx-probe.md` (batch #12 = fcef478b/6ff734f2/1ba31a97; lx confirms origin==HEAD==`1ba31a97…` via fetch+rev-parse, zero commits since lt's boundary). Self-referential-limits class | grep |

### DRIFT summary (W984lg)

- No prior row contradicted. Row 76's receipt-absent-by-construction note
  (`43265cb1`) stands unchanged; nothing on disk newly cites `43265cb1`
  as subject.
- Receipt-absent-by-construction now also covers #80 (`145b5659`),
  #85 (`f446d9c5`), #88 (`7d9968d0`), #92 (`52ce8236`) — each is a
  receipt-carrier commit cited only by later probes/receipts, not by an
  on-disk receipt naming it as a tested subject. Out-of-subject receipts
  (C21) remain an open coordinator item, now spanning 5 of the last 36
  wave commits.
- W984lf-probe (on-disk at `52ce8236`) records a Blocker 1 for the seal:
  `git merge-base --is-ancestor 56325fa5 origin/main` → exit 1 (seal not
  reachable from origin/main at this head). Recorded here as observed
  tree state, not adjudicated by this lane.
- w984kc receipt: `mix xaas.release_audit` zero-findings run reports
  `ash_resources=122` — newer than W756's 117/152 wrapper metrics
  (rows 58/DRIFT W855); tree still growing, re-grep at use time.

### Counts

W984lg refresh (rows 77–92, 16 commits → 16 rows; each commit its own
row, batch commits sharing receipts): witnessed 8 (#77, 78, 81, 82, 83,
87, 89, 90 — batch gates re-run on the exact subjects per receipt) ·
grep/existence 8 (#79, 80, 84, 85, 86, 88, 91, 92 — doc-only or
receipt-carrier commits; #86's git outputs are recorded verbatim in the
receipt). No receipt diverged from its commit's claim; disclosures
recorded as-is (w984il timeout repair; w984kc missing w984gv-probe and
scanner self-trigger audit findings; w984kf jv-skip and task-path typo).
All 16 wave SHAs grep-verified against `docs/sjira/v26.10.{6,7}/plans/`;
16/16 have an on-disk receipt citing or carrying them.

### DRIFT summary (W984lz)

- No prior row contradicted. Rows 1–92 re-skimmed at `1ba31a97`; none of
  the batch #12 changes restate or invalidate an earlier claim.
- Receipt-absent-by-construction now additionally covers #95
  (`1ba31a97`), alongside #80/#85/#88/#92 — each a receipt-carrier commit
  cited only by later probes/receipts (`w984lt-probe.md`, `w984lx-probe.md`)
  rather than by an on-disk receipt naming it as a tested subject. Now
  6 of the last 39 wave commits; C21 (out-of-subject receipts) remains
  an open coordinator item.
- W984lo batch #13: NOT landed at write time (zero `w984lo*` files in
  either plans tree, zero log hits beyond runbook negative mentions) —
  rows for it are not owed yet. W984lp (falsifier PASS, exit 0) and
  W984lq (8th re-census, 95.3%) receipts remain untracked/in-flight;
  their rows are owed when landed.
- Batch #12's own disclosure recorded here: `fcef478b` carried 6 of the
  original 16 files (14 already landed by `caf91669`), so row 93's
  "10 courts" refers to the batch gate subject, not this commit's file
  count.

### Counts (W984lz refresh)

Rows 93–95: 3 commits → 3 rows (one per commit, batch commits sharing
the `w984kn-commit.md` receipt): witnessed 1 (#93 — batch gate 58/0
re-run on the exact court subjects per receipt) · grep 2 (#94 docs-only;
#95 receipt-carrier). No prior row contradicted; disclosures recorded
as-is (fcef478b's 14-file pre-landing by caf91669; kn's PromEx
`:nxdomain` compile warning; 6ff734f2's not-staged W984li runbook edit).
All 3 wave SHAs grep-verified against `docs/sjira/v26.10.{6,7}/plans/`;
3/3 have an on-disk receipt citing or carrying them. Cumulative index:
**95 rows** (rows 1–92 unchanged from W984lg; 93–95 appended).
