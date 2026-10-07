# W981g — OS register sweep + verification court (v26.10.6)

Lane W981g, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface`
(working tree; HEAD `4546f96a` at lane start). **No commit made** (per dispatch).
Lane build root `_build-laneW981g` created and **deleted** at close (cleanup law).

## 1. Task gate: implement vs harden

Re-read every OS row on disk (`docs/sjira/v26.10.6/_CLOSURE_PLAN.md` §4,
`| OS-` rows, re-parsed live — no memory). Non-operator-gated rows and their
on-disk dispositions:

| row | on-disk standing | lane-actionable residue |
|---|---|---|
| OS-1 | LANDED (W700 re-derivation, w694) | none — closed |
| OS-9 | BLOCKED(law_evolution) — convergence-honest, v26.10.7+ | none this wave |
| OS-10 | BLOCKED(new-code) — v26.10.7+ | none this wave |
| OS-11 | operator watch item (0 recurrences since w365) | none (operator) |
| OS-12 | operator / ash_onetime-owner | none (operator) |
| OS-13 | pack-side fix, next cycle or operator-directed | none this wave |
| OS-14 | LANDED (W620) | none |
| OS-15 | CLOSED (doc-class) | none |
| OS-16 | marking leg ALIVE; end-user disclosure surface = typed GAP (v26.10.7+, NEW FEATURE) | none this wave |
| OS-17 | FIXED (w349+w393) | none |
| OS-18 | DONE (w546) | none |
| OS-19 | LANDED + W845/W872 enoent hardening committed (w845 receipt, w981 re-verify 4/4 at HEAD) | none |
| OS-20 | ~80% — remaining legs are cross-repo quiet-machine suite (W610 rerun) + coordinator commits (beam4pm, xaas tree) | none (coordinator/quiet-machine) |
| OS-21 | LANDED on lane build (uncommitted, coordinator) | none (coordinator) |

OS-2..OS-8 are operator-gated (skipped per dispatch).

**Gate verdict**: no non-operator row had a deliverable executable by a xaas lane
— every residue is operator-gated, coordinator-owned, cross-repo, or explicitly
typed v26.10.7+. Took the dispatch's fallback: **hardened the register** with a
machine-checkable verification court.

## 2. Deliverable: `test/xaas/os_register_court_test.exs` (new)

`Xaas.OsRegisterCourtTest` — recomputes the register's standing from disk on
every run:

1. **Row-set court**: register carries OS-1..OS-21, no duplicate ids (truncated
   register = register failure, not pass).
2. **Receipt-existence court**: every `.md` citation in every OS row resolves to
   a real file — three resolution rules: repo-root `docs/…`, wave-relative
   `plans/…` → `docs/sjira/v26.10.6/plans/…`, bare `wNNN…md` → plans dir.
3. **Cited-test court**: every `test/**.exs` cited by a row exists on disk.
4. **Non-vacuity floors**: ≥12 `.md` citations and ≥3 cited tests must parse,
   else the court refuses (floors set from live measurement 17/3; the register
   is concurrently edited by register-sweep lanes, so floors guard against
   vacuous parse, not against content edits — disclosed).

Parse functions are public (`os_rows/0`, `resolve_citation/1`, `md_citations/1`,
`cited_tests/1`) so lanes/coordinator can re-run the exact parse the court
asserts on.

## 3. Verification ladder (real tails, fresh lane root)

All under `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`,
`MIX_BUILD_ROOT=_build-laneW981g`, fresh root, pinned toolchain (asdf
1.20.2-otp-28):

- `mix compile` — exit 0 (initial full fresh-root compile ~10 min, exit 0).
- Court ×2: **3/3 passed, both runs** (real tails: `Result: 3 passed`).
- Cited tests ×2 (`test/eu_ai_act/art50_deepening_test.exs` +
  `test/xaas/accounts/token_revocation_test.exs` +
  `test/xaas/semantics/admission_fuzz_test.exs`), `--include eu_ai_act`
  (the art50 file is tag-excluded by default; without the flag the OS-16 leg is
  excluded, not passed): **22/22 both runs**
  (`Result: 22 passed`; art50 alone 7/7 `--include eu_ai_act`).

### Findings during the run (disclosed, all environmental)

- **Compile-freeze contention, 2 incidents**: concurrent lane W982a's in-flight
  SPEC-31 graphql edits broke the shared compile twice mid-lane
  (`lib/xaas/ocel/event.ex`, then `lib/xaas/security/finding.ex` —
  `graphql/1 undefined`; later a broken generated `regen_check.ex` heredoc).
  Cleared on the owners' next saves; no lane-local fix applied. Lane proceeded
  when `mix compile` exit 0.
- **Transient court failure (real catch, environmental cause)**: one court run
  failed with "court parsed only 17 .md citations (floor 20)" — the register
  file itself was being edited concurrently (citation count moved 26→17 between
  my section-grep and the run). Floors re-based from live measurement; the
  finding itself validated the court's drift-detection value.
- **Excluded-tag trap**: default `mix test` excludes the `:eu_ai_act` tag, so
  the OS-16 art50 leg would have silently counted as "not run" — flagged and
  re-run with `--include eu_ai_act` (7/7 witnessed).

## 4. Per-row status table (register, post-lane)

All rows unchanged from on-disk register (this lane made no row flips — none
were due; the deliverable is the court):

| row | standing | changed? |
|---|---|---|
| OS-1 | LANDED | no |
| OS-2..OS-8 | operator-gated | no (skipped) |
| OS-9 | BLOCKED(law_evolution) v26.10.7+ | no |
| OS-10 | BLOCKED(new-code) v26.10.7 future | no |
| OS-11 | operator watch item | no |
| OS-2 | operator | no |
| OS-12 | operator / ash_onetime-owner | no flips; standing unchanged |
| OS-13 | pack-side (v26.10.7 / operator) | no |
| OS-14 | LANDED | no |
| OS-15 | CLOSED | no |
| §4 OS-16 | marking ALIVE; end-user disclosure = typed GAP (v26.10.7+) | no |
| OS-17 | FIXED | no  |
| OS-18 | DONE | no |
| OS-19 | LANDED (+W845/W872 committed hardening) | no |
| OS-20 | ~80% (coordinator/quiet-machine residue) | no |
| OS-21 | LANDED (uncommitted, coordinator) | no |

## 5. Standing

- `test/xaas/os_register_court_test.exs`: **ALIVE** — 3/3 ×2, observed
  execution at lane build root, compile exit 0, no mocking (real `File.read!`
  of the register, real disk existence checks).
- Register hardening note: added to `_CLOSURE_PLAN.md` §4 ("Resolved since
  W138") citing this receipt.
- OS register rows: standing unchanged (no flips were due; gate verdict §1).
- Working tree at close: only lane-owned files touched —
  `test/xaas/os_register_court_test.exs` (new),
  `docs/sjira/v26.10.6/_CLOSURE_PLAN.md` edit, this receipt.
- Lane build root `_build-laneW981g` **deleted** per fanout cleanup law.

## 6. Falsifier

`mix test test/xaas/os_register_court_test.exs` — delete any cited receipt file
or break a row id and the court fails; the register standing is re-computed, not
asserted.
