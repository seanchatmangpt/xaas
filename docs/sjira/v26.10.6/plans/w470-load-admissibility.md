# W470 — Load-Admissibility Adjudication of v26.10.6 Receipts

- Lane: W470 (sole write: this file), v26.10.6 convergence, repo `/Users/sac/xaas`
- Rule applied: W461 addendum (`_INTEGRATION_RUNBOOK.md:354-388`) — a replay receipt
  minted at load >50 is NOT admissible as ALIVE evidence for contention-sensitive
  classes (a) Postgres-sandbox concurrency/timeouts and (c) shared-build races;
  isolate-twice protocol required; heavy suites must mint at <10 load.
- Method: each receipt's own quiescence/contention notes were read (w300 §1,
  w315 run-1 precondition, w438 "Fleet Quiet" title, w452 §"Contemporaneous
  contention evidence", w449 "W394 lane quiet") and each suite classified by its
  own nature — deterministic sync exunit/court suites are LOAD-INSENSITIVE;
  multi-process/multi-worker suites (Playwright webServer runs, conn/LiveView
  sandbox slices) are CONTENTION-SENSITIVE.
- Date: 2026-10-06.

## RE-MINT LIST (contention-sensitive, verdict could flip)

| Receipt | What | Why re-mint |
|---|---|---|
| **w452** (85-92 pass / 4-10 fail) | Full tokened PW suite on the POST-FIX tree | w452's own receipt documents active cross-lane PW contention (foreign beam on 4094, ports 4100-4102, fleet NOT drained). Its headline verdict is explicitly contention-attributed, so no quiet full-suite post-fix baseline exists. The two ash-admin specs pass only in isolation (w449); the full-suite green claim is exactly the class (d) hydration-race surface. Re-mint the full tokened suite on a quiet machine (<10 load) — this is the single most load-bearing re-mint. |
| **w416** (377/0 web+accounts slice) | `test/xaas_web/ + test/xaas/accounts/` at final tree | The slice never completed as one green run: it halted at compile on the in-flight foreign prometheus edit, the 377 green came from the partial same-root run, and the completing fix (W408 rewrite) was only witnessed file-locally by w445 (4/0). Web/conn slices are sandbox+server class (a)/(d). Re-mint the whole slice at quiet load to convert partial+patchwork into one admissible receipt. |

Pending lanes (not re-mints — must MINT under the rule):
- **w316b** (pending): mint at <10 load; any failure → isolate-twice before classifying real.
- **w398b** (pending): this IS the isolate-twice protocol run; same load precondition applies.

## CLEAN LIST (no re-mint needed)

| Receipt | Result | Class | Reason |
|---|---|---|---|
| w300 | 3235/0 full suite | mixed | Quiescence precondition OBSERVED (0 mix processes at launch; 2 mid-run lane beams disclosed, run completed). Quiet-mint, admissible. |
| w315 | 3235/0 (run 1) | mixed | Explicit post-quiescence check (`wc -l` → 0) before the authoritative run. Run 2's 3 castle failures already adjudicated env-class via isolate-twice lineage (w398b). |
| w317 | 96/0/2 PW tokened | contention-sensitive | Minted green under fleet, BUT it is the PRE-fix baseline and is superseded for the post-fix tree by w449 (isolation) + the w452 re-mint above. Admissible as historical baseline; no re-mint of w317 itself. |
| w236 | 86/0 refusal capstone | class (b)-adjacent | Deterministic refusal courts; castle CLI overlap now mutex-locked (w297d `with_castle_lock/1`); the one build-dir-lock retry cleared. Consolidated green is deterministic. |
| w385 | 26/26 conformance court | load-insensitive | One-command deterministic court over pinned corpus, separate repo (ash_a2a), warm build root, exit 0. |
| w425 | 1400/0 ultracode | load-insensitive | Deterministic unit slice, 752s serial sync; named-file cross-check 16/2 matches baseline; no failures to classify. |
| w429 | 23/0 marketplace | load-insensitive | 4.9s deterministic non-stress files, exit 0. |
| w432 | 33/0 telemetry | load-insensitive | Deterministic, matches w197-era 33/0 exactly. |
| w433 | 49/0 operations | load-insensitive | Deterministic; cross-lane edit stability checked (6h mtimes) before run. |
| w434 | 9/0 witness | load-insensitive | 1.9s deterministic slice. |
| w435 | 152/0 chicago | load-insensitive | Deterministic; delta vs w154 (+2) accounted for by w399 seller edits. |
| w436 | 48/1s/15e mix tasks | load-insensitive | Deterministic; "no isolation needed" per its own receipt. |
| w438 | 94/2/2 PW | contention-sensitive, already quiet | Minted FLEET-QUIET by design (its whole purpose); its 2 failures are the pre-fix real regression (w391), since independently fixed and isolation-verified (w449). Admissible; superseded post-fix by w452 re-mint. |
| w442 | 107/0 sjira | load-insensitive | Deterministic dir slice, matches w329 anchors. |
| w443 | 28/0 receipt | load-insensitive | Deterministic; first-run 2-skip classified env-gated (`GGEN_IGNITER_DIR`), not contention; corrected re-run green. |
| w445 | 4/0 + kind 5 skipped | load-insensitive | Single deterministic controller file + compile/skip check. |
| w446 | compile exit 0 | load-insensitive | `--warnings-as-errors` compile verdict is load-independent (class (c) races would corrupt, not silently pass; clean `Generated xaas app` is determinate). |
| w447 | 29/0 semantics | load-insensitive | Deterministic slice incl. refusal negatives; no failures to isolate. |
| w449 | 2/0 ash-admin | contention-sensitive, already isolated | IS an isolation mint ("W394 lane quiet", 2 workers, 2 specs); isolate-twice satisfied. |
| w455 | 102/0 library | load-insensitive | Deterministic slice, 0 failures. |

## Bottom line

- **Re-mint count: 2** (w452 full tokened PW post-fix; w416 full web+accounts slice) —
  both minted/patched under active fleet contention on genuinely
  contention-sensitive surfaces.
- 2 pending lanes (w316b, w398b) must mint at <10 load per the W461 replay card.
- 20 receipts stand clean as minted; the two marquee full-suite greens
  (w300/w315) carry observed-quiescence preconditions and are admissible.
