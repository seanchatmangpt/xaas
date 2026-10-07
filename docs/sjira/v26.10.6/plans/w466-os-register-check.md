# W466 — OS register internal-consistency check (§4 of _CLOSURE_PLAN.md)

Subject: /Users/sac/xaas @ feat/playwright-surface. Read-only audit; only this file written.
Method: read §4 register (lines 251–280), §1 inventory, "Resolved since W138" block,
W230 link-check block, W206 §5 walk block; every receipt citation `test -f`'d under
`docs/sjira/v26.10.6/plans/` (299 files) and in the repo tree.

## Verified clean

- **Numbering**: OS-1…OS-18 all present exactly once; no collisions, no gaps other
  than the documented ones. The OS-12-before-OS-11 ordering quirk is documented
  (OS-10 fold-in note + W230 note). OS-13/OS-14–OS-18 added rows are singletons.
- **Receipt citations all resolve on disk**: r1, r2, r3, r4, r7, r9, r11, r8 (refs),
  x2, x4, w20-ash-pplan-adjudication.md, w40, w91, w75, w151, w129, w107, w128-oracle-final.md,
  w133b-compile-prose-stop.md, w183-token-revocation-findings.md, w230-r2rml-skew.md,
  w126-pack-repin/w126-pack-gate-fix.md, w325, w333, w349-cloak-key-guard.md,
  w355, w363, w365-toolchain-coherence.md, w366, w379-actuation-kill.md, w393-cloak-prod-wiring.md,
  w401–w407 stubs, w422-dod-rewalk-v4.md — all present.
- **w319 / w423 resolve to in-place artifacts, not plans/ files**: w319 =
  `docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md` (header: "Lane W319 … refreshed by lane W409"),
  w423 = `docs/cro/artifacts/bias-awareness-measures-v26.10.6.md` (header: "Lane W423").
  Both exist; pointer style differs from the plans/-file convention but is unambiguous.
- w398 (cited by OS-18 as a serialization dependency, not owning receipt) has no
  receipt on disk — correctly disclosed as in-flight, not a dead citation.

## Findings (7)

**F1 — §1 row 5 stale vs OS-17 (contradiction).** `_CLOSURE_PLAN.md:23` still reads
"**PARTIAL (receipt)** … → OS-17 | OS-17 operator decision (prod guard)" while OS-17
(line 271) says **FIXED 2026-10-06** (w349 + w393, guard tests 4/4, CHANGELOG landed).
Corrected row-5 text for coordinator:

> | 5 | `lib/xaas/vault.ex:10-25` | committed `CLOAK_KEY` placeholder | **RESOLVED (receipt)** — OS-17 landed: `Xaas.Vault.init/1` prod branch returns `{:stop, {:cloak_key_missing, :prod_refuses_placeholder_key}}` (fail-closed; dev/test unchanged); guard tests 4/4 incl. source pin (w349 receipt + w393 wiring trace; CHANGELOG entry landed) | none — OS-17 closed | vector1, w349, w393 |

**F2 — OS-15 vs coverage map (contradiction).** OS-15 (line 269) says **CLOSED
(doc-class) 2026-10-06** and "Coverage-map GAP row narrows to the code-level
limitation", but the map (`docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md`) still
carries the pre-closure text: line 38 "`GAP(NO_BIAS_AWARENESS_DOC)` — PARTIAL
(unchanged this week; OS-15 open)" and line 157 "14(4)(e) doc-class PARTIAL —
`GAP(NO_BIAS_AWARENESS_DOC)` (OS-15, unchanged)".
The map was never narrowed. Corrected map text for coordinator:

> line 38: `| 14(4)(e) automation-bias awareness | No silent-proceed: every external-mismatch branch returns {:error, atom}, no fallback-to-proceed branch | lib/xaas/actuation.ex:537-547,770; fixtures test/xaas/actuation_refusal_negative_test.exs | EVIDENCED (code-level) + doc-class EVIDENCED-with-limitations (w423: docs/cro/artifacts/bias-awareness-measures-v26.10.6.md, 5 typed limitations incl. LIMITATION(NO_DEMOGRAPHIC_BIAS_DETECTION)) |`
> line 157: `- **Art. 14(4)(e)**: EVIDENCED code-level + doc-class EVIDENCED-with-limitations — GAP(NO_BIAS_AWARENESS_DOC) narrowed to the code-level limitation per w423 (OS-15 CLOSED 2026-10-06).`

**F3 — "Resolved since W138" block (lines 274–278) incomplete.** OS-17 FIXED and
OS-15 CLOSED both post-date W138 and are absent. Append for coordinator:

> - **OS-17 CLOAK_KEY prod guard** — **RESOLVED by w349+w393** (2026-10-06): prod
>   branch fail-closed on placeholder key; guard tests 4/4; §1 row 5 flips to
>   RESOLVED. Evidence: w349, w393.
> - **OS-15 Art. 14(4)(e) doc-class** — **CLOSED by w423** (2026-10-06):
>   bias-awareness measures doc authored with 5 typed limitations; coverage-map
>   GAP row narrows to the code-level limitation. Evidence: w423.

F3 also covers the trailing sentence (line 280) — after the append, keep
"OS-11 is an open operator investigation" (still true per the w365 watch note).

**F4 — W230 link-check block (lines 282–305) superseded.** Its three flagged-dead
links have since landed on disk: `w20-ash-pplan-adjudication.md`,
`w128-oracle-final.md`, `w133b-compile-prose-stop.md`, and
`w183-token-revocations…` → `w183-token-revocation-findings.md` (all test -f today).
Also its ordering note ("Row order is OS-1…OS-10, OS-12, OS-11") is stale — actual
order is OS-1…OS-10, OS-12, OS-13, OS-11, OS-14–OS-18. Corrected text for coordinator:
either delete the W230 block or replace with:

> ## W230 link check — SUPERSEDED by w466 (2026-10-06)
> All four originally-flagged dead links (w20, w128, w133b, w183) have landed on
> disk and now resolve. Ordering note updated: rows run OS-1…OS-10, OS-12, OS-13,
> OS-11, OS-14–OS-18 (OS-12-before-OS-11 quirk documented in the OS-10 fold-in
> note). Remaining dead pointer in the register: OS-13's "w37 doctrine" (see F5).

**F5 — OS-13 cites "w37 doctrine" — dead pointer.** No `w37*` receipt exists anywhere
in the repo (only w371–w379 files, which are unrelated lanes). Corrected OS-13
evidence cell:

> | … | w230-r2rml-skew.md, w126-pack-gate-fix.md | …

(drop "w37"; the excluded-outputs doctrine context is already carried by
w126-pack-gate-fix.md and w230-r2rml-skew.md).

**F6 — W206 §5 DoD walk block (lines 369–509) superseded by w422 v4.**
`plans/w422-dod-rewalk-v4.md` states "Supersedes the W206 walk" and contains a
"§5 Status Table Replacement (coordinator paste)" table. The in-plan W206 block's
summary table now disagrees with w422's verdicts (e.g. DoD 1: w206 best-receipt
w68b 3145/3201 vs w422's w300/w315 3235/0; DoD 7: "N-A" vs w422 "MET (provenance
legs)"; DoD 5: w317 96/0 exists). Corrected action for coordinator: replace the
W206 block's summary table with w422's replacement table verbatim, keeping a
"SUPERSEDED by w422 (2026-10-06); original walk preserved in
`plans/w422-dod-rewalk-v4.md`" pointer line.

**F7 — §5 DoD 6 leg "OS-1…OS-8" (line 354) and "OS-1…OS-12 register" (line 488)
range mentions stale.** Register now spans OS-1…OS-18. Corrected text: "OS-1…OS-8
(or later OS rows still unlifted)" / "OS-1…OS-18 register". Both lines sit inside
the F6-superseded W206 block, so F6's paste resolves them; listed separately only
in case the W206 block is preserved in place.

## Verdict

Register is **CONSISTENT WITH 7 FINDINGS** — no numbering collisions, no dead
owning-receipt pointers among the OS rows themselves (w319/w423 resolve to
in-place artifacts; w398 honestly in-flight), no row-to-row contradictions among
OS-1…OS-18; all findings are staleness between the register and its
surrounding blocks (§1 row 5, coverage map, W230/W206 historical blocks, one
dead "w37" pointer in OS-13).
