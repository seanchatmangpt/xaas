# W324 — Frontier DoD-6 Audit (2026-10-06)

Repo: `/Users/sac/xaas` @ `feat/playwright-surface` (canonical checkout, no writes outside this file; `_FRONTIER.md` untouched — coordinator integrates).

Method: every receipt cited in the frontier table was `test -f`-checked against
`docs/sjira/v26.10.6/plans/`; verdict/standing lines of the decisive receipts
were read and compared to the row's claimed standing.

## Flag counts

| class | count | rows |
|---|---|---|
| (a) rows still UNKNOWN | 0 | — |
| (b) dead receipt paths | 2 paths, 1 row | xaas row cites `w231` and `w263b` — neither file exists |
| (c) standing–receipt contradictions | 0 | — |
| (d) newest cited receipt predates a later closure | 3 rows | xaas (w270/w289 "in flight" are now closed by receipts on disk), gymact (w95 2356/0 closure not cited), ash_pplan (W291 verdict pending — marked IN-FLIGHT, not guessed) |

Rows passing all four checks untouched: ash_surface, ggen, ggen-marketplace, ggen_igniter, ash_a2a, ferroplan, zcode-cli, beam4pm, wasm4pm, autofde-lab (10/13).

## Per-row table

| row | claimed standing | receipts exist? | consistent? | flag |
|---|---|---|---|---|
| xaas | PARTIAL_ALIVE | 2 dead (`w231`, `w263b`); all others OK | yes (standing is a fair summary; but in-flight citations stale) | b + d |
| ash_surface | PARTIAL_ALIVE | all 4 exist | yes (x2 verdict PARTIAL_ALIVE; w69/w80/w91 match) | — |
| ggen | ALIVE (repo-level @ 000bffb8f) | yes (r1, w81) | yes (w81 cargo check exit 0 on exact subject) | — |
| ggen-marketplace | PARTIAL_ALIVE | yes (r2, w80) | yes | — |
| ggen_igniter | PARTIAL_ALIVE | yes (r3, w108, w82, w91, w114) | yes (r3 UNSUPPORTED(hex) verdict preserved as open falsifier) | — |
| ash_a2a | PARTIAL_ALIVE | yes (r4, w109, w113, w150; w261 corroborates 3708/0) | yes | — |
| ash_pplan | PARTIAL_ALIVE | yes (r5, w41) | w41 5/5 consistent; but W291 verdict pending | d (IN-FLIGHT) |
| ferroplan | PARTIAL_ALIVE | yes (r6, w45) | yes (w45 54/0, digest reproduces pin) | — |
| zcode-cli | ALIVE (repo-level @ 7fc62da) | yes (r7, w46, w58, w40) | yes (w58 1072/0) | — |
| gymact | PARTIAL_ALIVE | yes (w42, w79, w129) | yes but row misses the later w95 closure (2356 passed / 0 failed, exit 0) | d |
| beam4pm | PARTIAL_ALIVE | yes (r9, w52, w74) | yes (w52 qualification executed; w74 wasm built, 34/0) | — |
| wasm4pm | PARTIAL_ALIVE | yes (r10, w94) | yes — r10 verdict PARTIAL_ALIVE; w94 is file-scoped ALIVE (25/25), CI exact-head confirmation still pending, so row standing is correct and conservative. (w165 bump scope ALIVE exists but does not close the row's open falsifier.) | — |
| autofde-lab | PARTIAL_ALIVE | yes (r11, w35, w78, w110, w111) | yes (r11 gaps remain open) | — |

## Corrected row text for coordinator paste-in (flagged rows only)

### xaas

Two dead receipt citations must be dropped and the in-flight citations closed.

Delete: `w231` (witness fresh-boot 3/3 — no such receipt on disk) and
`w263b` (consolidated refusal capstone 86/0 — no such receipt on disk). Note:
`w236-refusal-capstone.md` exists; if the coordinator means that receipt, rename
the citation to `w236-refusal-capstone.md` — otherwise delete. All other
citations in the xaas row verified present.

Replace the stale in-flight clauses:

- "`w289` in flight" → closed: `w289-final-dod-suite.md` on disk —
  3230/3232 (run 1, 2F subprocess-infra class), run 2 2358, run 3 3230/3235
  (5F, all real-OS-subprocess infra); W158 105-class collapsed to zero;
  DoD-1 real residue = 5 subprocess-infra tests.
- "`w270` in flight" → closed: `w270-a2a-sse.md` — a2a-v1 spec 7/7 (incl. SSE
  TASK_STATE_COMPLETED), witness 3/3, ggen-workbench 6/6, exit 0; but per
  `w302-pw-post-w270.md`, the streaming court asserted an unimplemented
  capability — real streaming remains open lib-side.
- Newest closure receipts the row should now cite (all on disk, all read):
  `w315-final-dod-suite.md` (full `mix test` ×2, run 1 fully green, run 2
  3232/3235; mock gate `[]`; 245-env-class falsifier confirmed dead;
  standing ALIVE, DoD-1 measurement complete) and `w317-pw-final-tokened.md`
  (full Playwright rung final leg: 96 executable / 0 failed / 0 flaky on exact
  subject `d1db2b03`, zero failures — the long-open "full PW green not
  witnessed" item is now CLOSED by a witnessed run).

### gymact

Add the later closure the row predates:

- `w95-gymact-full-suite.md` — full pytest 2356 passed / 0 failed / 41 skipped
  (typed), 10 xfailed, exit 0; replay
  `cd /Users/sac/gymact && ~/gymact/.venv/bin/python -m pytest`.
- Full suite closure does not close the crown falsifier: `w129` re-confirms
  DCM-018 UNKNOWN under `CROWN_REQUIRES_WITNESSED_DCM`, `witnessed_crown:
  false` — standing stays PARTIAL_ALIVE with the crown falsifier intact.

### ash_pplan — IN-FLIGHT

Per campaign direction, mark IN-FLIGHT pending the W291 verdict; do not guess a
standing change. No W291 receipt exists on disk at audit time. The row's cited
receipts (r5, w41 5/5) are real and consistent; the only edit is the status
marker:

```
| ash_pplan | IN-FLIGHT (W291 verdict pending) | r5-pplan.md (W31). Execution: w41-pplan-facade.md (facade 5/5) | Ref advanced to 5f10c979 (mix.exs:252-254, origin/main — A2A durable Facade present); W41 facade courts 5/5 green. IN-FLIGHT: W291 verdict pending — standing frozen, not guessed. UNRUN: adjudicate the net-new test failure at 414a393; exact-head consumer-side court unrun |
```

## Suggested corrected table rows (full text, coordinator paste-in)

### gymact (paste-in)

```
| gymact | PARTIAL_ALIVE | `w42` (adapter 9/9, config seam), `w79-gymact-dcm.md` (DCM 17 STRUCTURAL / 1 UNKNOWN; crown OS-10 unwitnessed), `w129-gymact-crown.md` (witnessed ALIVE transition, receipt_id adae920d…; DCM-018 unwitnessed-crown blocker classified in-repo), `w95-gymact-full-suite.md` (full pytest 2356 passed / 0 failed / 41 typed skips, 10 xfailed, exit 0) | Adapter EXISTS on tree (w42 9/9, config seam landed); full suite GREEN (w95). Falsifier (unchanged): witnessed crown — DCM-018 UNKNOWN under `CROWN_REQUIRES_WITNESSED_DCM` (`w79`); OS-10 crown gate unwitnessed; `witnessed_crown: false` per w129; gymact-dod suite + Playwright spec unrun |
```

### xaas (paste-in skeleton — coordinator fills/merges citations)

```
| xaas | PARTIAL_ALIVE | …existing citations minus `w231` and `w263b`… Execution additions: `w289-final-dod-suite.md`, `w315-final-dod-suite.md`, `w317-pq-final-tokened.md`→correct name `w317-pw-final-tokened.md`, `w270-a2a-sse.md` closed (per w302: real streaming remains open lib-side), `w299-pw-final2.md` / `w310g-pw-final.md` | RUN: …existing RUN lines… CLOSED: full `npx playwright test` green now WITNESSED — `w317` 96 executable / 0 failed / 0 flaky on exact subject `d1db2b03`; full `mix test` green (`w315` run 1 fully green; `w289` DoD-1 residue 5 subprocess-infra tests). FAILED/OPEN (supersedes the old "full PW green NOT witnessed" item): `/internal-api/health` 503-with-token real defect (`w310g`); ggen-workbench tokenless 406-vs-401/503 (`w299`); real streaming lib-side open (`w302`); server-death mechanism classified (`w299b`: dispatch paths ALIVE 30/30, run-2 attribution probable not witnessed) |
```

## Verification

- 62 distinct receipt paths tested with `test -f`; 60 exist, 2 missing (`w231`, `w263b`).
- Decisive verdict lines read for: w81 (ggen), w58/w46 (zcode-cli), w42/w79/w129/w95 (gymact), w52/w74 (beam4pm), r10/w94/w165 (w4pm), r5/w41 (pplan), w289/w315/w317/w270/w302/w299/w299b/w310g/w310d (xaas), r4/w109/w261 (a2a), r11/w35/w78/w110/w111 (autofde).
- No row remains UNKNOWN; no standing contradicts its receipts' verdict lines; 2 dead paths and 3 stale-citation rows found and given corrected paste-in text above.
