# Evidence–Claims Index (lane W405)

Campaign v26.10.6 CRO-loop, honest-numbers directive. Subject: branch
`feat/playwright-surface`, head `d1db2b03179975213c14663b9dbd86b5ac2a14cf`,
repo `/Users/sac/xaas`. Date 2026-10-06.

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

BACKED 5 (#3, #8, #9, #10, #11) · BACKED-CORRECTED 3 (#2, #5, #6) ·
UNBACKED 4 (#1, #4, #7, #12 — #12 scoped out as rhetorical).
