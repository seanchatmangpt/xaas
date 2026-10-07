# W982w — eu_ai_act census-gate projection reconcile (W981v vs W981x)

Date: 2026-10-07 · Repo: /Users/sac/xaas · Branch: feat/playwright-surface @ 6f235905
Lane: W982w, xaas v26.10.6 campaign. Read-only documentation reconcile: no mix commands,
no source files modified, no commit. Writes: this receipt + a one-line census-gate note
appended to `docs/cro/CYCLE-LOG.md` CYCLE-3.

## 1. The divergence

| receipt | claim | gate |
|---|---|---|
| w981v-euaia-tag-audit.md | ba9703fb's two `@moduletag :eu_ai_act` lines (airo_grounding + counterfactual, +11 lines, 2 files) made **+33 tests newly visible** → projected total **≥1385** | ≥1385 (hedged: "or 1352 already included them") |
| w981x-census-rerun.md | real run `mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap` → **1352 passed / 1 excluded**, exit 0, identical to the certified fab56ae1 census | ≥1352 (unchanged) |

W981x refuted the projection as stated; this lane settles which number is lawful and why
the +33 arithmetic failed.

## 2. Provenance of each number

- **W981v's 1385** = 1352 (certified census) + 33 (airo_grounding 7 + counterfactual 26)
  read off W962b's "33 misattributed" finding. Pure static projection — no run behind it
  (W981v's own standing line admits this: PARTIAL_ALIVE, "static/structural audit only").
- **W981x's 1352** = actual gated run at HEAD 6f235905 on a fresh lane build
  (`_build-laneW981x`), full tail on disk in the receipt, `/tmp/w981x-run2.log`.
- **W962b's 33** = the 33 untagged tests (counterfactual 26 + airo_grounding 7) that ran
  inside W935b's **ungated** earlier census invocation
  (`mix test test/eu_ai_act --include eu_ai_act_open_gap`), producing W935b's "34
  collected" (33 passed + the 1 by-design 49.3 flunk). W962b's own §2: "The 33 were never
  open-gap-tagged; W935b's '34 open-gap-tagged' was a misattribution." And its §4, which
  is the decisive line: **"Why gated stayed 1352: untagged tests run under any
  invocation, so the 33 were already inside the gated 1352; the fix only changes their
  tag identity, not the count."**

## 3. Root cause of the projection error: visibility ≠ count delta

ExUnit default-excludes `:eu_ai_act` (test_helper.exs) but has no default filter against
untagged tests: untagged tests execute under every invocation, gated or census. The 33
tests were therefore already executing and passing inside the certified 1352 — they
merely did so as untagged tests. ba9703fb's `@moduletag :eu_ai_act` changed their tag
identity (making them gated-*visible*, i.e. matched by `--include eu_ai_act`), which
cleans up the open-gap exclusion math (`--only eu_ai_act_open_gap` no longer sweeps them
into the "collected" count) but adds zero tests to the gated run. W981v read W962b's
"33 misattributed" as a suite-size delta; it was a **tag-identity reclassification of
tests already in the count**. Visibility (membership in the gated filter's match set) is
not the same quantity as run-total delta.

Corollary confirmed by W981x: the fab56ae1 census (1352) and the post-ba9703fb run
(1352) are byte-identical in totals — the falsifier for "gate should read ≥1385" fired,
exactly as W981x recorded.

## 4. Settled gate statement

> **eu_ai_act census gate: ≥1352 passed / 0 failed, `--include eu_ai_act --exclude
> eu_ai_act_open_gap`, witnessed at 6f235905-era head by w981x.** ba9703fb's moduletag
> fix reclassified 33 tests as gated-visible without changing the count; W981v's ≥1385
> projection is retired (visibility ≠ count delta). Suite total: 1353 eu_ai_act tests
> = 1352 gated-pass + 1 open-gap-tagged (Art. 49.3 flunk-by-design).

Corrections to prior receipts:
- w981v-euaia-tag-audit.md's §"Census invariant (1)" projection (≥1385) — **REFUTED** by
  w981x's run; superseded by the settled statement above. W981v's tag table and
  exclusion-tag enumeration stand (they match W962b's on-disk census).
- No correction needed to w981x-census-rerun.md — its gate determination (1352, not
  1385) is confirmed as the settled number.
- W962b's §5 convention (honest gap count via `--only eu_ai_act_open_gap` = 1; total
  1353) — confirmed, unchanged.

## 5. Provenance chain

w935b (34-collected anomaly, ungated `--include eu_ai_act_open_gap` invocation) →
w962-tag-reconciliation.md (tag-site census, 4 sites, only 49.3 flunks) →
w962b-tag-reconcile-exec.md (root cause: ExUnit include-over-exclude + untagged tests
run everywhere; 33 already inside gated 1352; tag fix applied, later landed as
ba9703fb) → w981v (static audit, correct on tags, wrong on projection) →
w981x-census-rerun.md (real gated run at 6f235905: 1352/1, exit 0) → **w982w (this
receipt): settled gate ≥1352/0-failed, w981v projection retired.**

## 6. Standing

- **ALIVE (settled)** — the gate statement rests on w981x's real run at exact head
  6f235905 (fresh lane build, exit 0, full tail on disk), corroborated by W962b's
  after-fix gated run (also 1352/1) and the unchanged fab56ae1 census.
- This lane: PARTIAL_ALIVE as a documentation reconcile — no run executed here; standing
  inherited from w981x's witnessed execution.
- Falsifier for the settled statement: any future gated run at a descendant head yielding
  <1352 passed or >1 excluded without a receipted test-count change under
  `test/eu_ai_act/` since 6f235905.
