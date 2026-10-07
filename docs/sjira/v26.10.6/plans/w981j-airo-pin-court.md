# W981j — AIRo pin court (ledger W981e/W981f rows) receipt

- Date: 2026-10-07
- Subject: xaas @ `feat/playwright-surface`, HEAD
  `6f235905b6e071c236c5abb0ce0bf872e0bfd7b4` (working tree, uncommitted —
  coordinator owns commits)
- Build: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW981j`
  (left on disk for coordinator deletion at integration)
- Court module: `test/xaas/airo/airo_pin_court_test.exs`
  (`Xaas.Airo.PinCourtTest`, 6 tests, Chicago: real filesystem, real
  `git rev-parse` subprocess, real file bytes; zero mocks)

## What the court asserts

1. Ledger `docs/cro/artifacts/airo-wiring-ledger.md` parses to exactly
   9 extension rows (3 W981e + 6 W981f; 7-column rows with 40-hex HEAD).
2. Absent checkouts are counted and reported, never silently skipped
   (observed both runs: `skipped (checkout absent): 0`).
3. Per present row: real `git -C ~/<repo> rev-parse HEAD` equals the
   ledger-pinned SHA; every cited path resolves on disk (repo-rooted,
   lib/<app>-relative, or relative to a dir the row itself cites, globs
   expanded); the falsifier names a concrete artifact path
   (`.ttl`/`.rq`).
4. Canonical vocab re-verified from real bytes:
   `shasum -a 256 priv/semantic/airo/airo.ttl` =
   `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469`
   (match, executed this lane); the blob at
   `HEAD:priv/semantic/airo/airo.ttl` =
   `c4274ab083f7cff1fe18f03e7a18e79d752ecf93` (real `git rev-parse`,
   asserted in-test); pin doc `docs/airo/pin-court-vocab.md` carries both.
5. xaas-local row driven toward ALIVE: `docs/airo/pin-court-vocab.md`
   pins the exact content sha256 `6274d2d8…` verified from the real
   vendored AIRo 1.0 bytes (DelaramGlp/airo@6c67de4, CC-BY-4.0) —
   verifiable locally, so no REFUSED(unverifiable-sha) was needed.

## Executed commands (real tails)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW981j \
    mix test test/xaas/airo/airo_pin_court_test.exs
[pin-court] skipped (checkout absent): 0
Finished in 0.2 seconds
Result: 6 passed          # run 1, seed 986457
Result: 6 passed          # run 2, seed 760092
```

Two green executions on the lane's fresh `_build-laneW981j` root. Red
intermediate runs during court development (backtick-wrapped SHAs broke
the row parser; cited-path resolution needed repo-root/lib/app/row-cited
prefix candidates; wave-2 falsifiers named no concrete artifact path)
were all fixed forward, each fix re-run to green.

## Per-row pass/skip table (both runs identical)

All 9 checkouts present — skip count 0, recorded not silent.

| repo | ledger HEAD | HEAD match | cited paths | falsifier concrete | standing |
|---|---|---|---|---|---|
| ash_graphlaw | 1d89ba5f… | PASS | PASS | PASS (`priv/airo_risk_description.ttl` row) | UNKNOWN→pin-gated |
| ggen-ecosystem | 7e107f18… | PASS | PASS (glob `admission/courts/ws1-*.rq` → 50 hits) | PASS | UNKNOWN→pin-gated |
| chatman-ecosystem | 83ceef8a… | PASS | PASS | PASS (`crates/gall/airo_risk_description.ttl`) | UNKNOWN→pin-gated |
| ash_atlassian | 43e3d21b… | PASS | PASS | PASS (amended, see below) | UNKNOWN→pin-gated |
| ash_dspy | 5d985d53… | PASS | PASS | PASS (amended) | UNKNOWN→pin-gated |
| ash_kudzu | 2d600ffd… | PASS | PASS | PASS (amended) | UNKNOWN→pin-gated |
| ash_planning_center | 5ee26cbd… | PASS | PASS | PASS (amended) | UNKNOWN→pin-courted |
| ash_expo | 59a80d5e… | PASS | PASS | PASS (amended) | UNKNOWN→pin-gated |
| ash_autofde | 65cd05e1… | PASS | PASS | PASS (amended) | UNKNOWN→pin-gated |

The pin court does not flip these rows to ALIVE — ALIVE requires each
repo's own TTL artifact to exist and parse at its pinned SHA; the court
pins the gate so the falsifier is now executable. Standing per ledger
row remains UNKNOWN until each repo's artifact lands.

## Ledger amendment (disclosed)

The six W981f falsifiers named no concrete artifact path ("risk-description
TTL w/ vocab sha…"). The court refused these; amendment, disclosed here:
7 falsifier cells across W981e/W981f tables now name
`priv/airo_risk_description.ttl` (fleet convention; chatman-ecosystem
already named `crates/gall/airo_risk_description.ttl`). No SHA, branch,
or cited-surface cell changed.

## Shared-compile SLA fixes (disclosed, lane W982a's files)

Lane W982a's in-flight SPEC-31 edits added `graphql do` blocks to
`lib/xaas/ocel/event.ex` and `lib/xaas/security/finding.ex` without the
`AshGraphql.Resource` extension — hard CompileError freezing the shared
compile. Minimal unblock fix applied per the compile-freeze SLA:
`extensions: [AshGraphql.Resource]` added to each `use Xaas.Resource`.
Disclosed for W982a's integration. A third transient break
(`lib/xaas/generated/regen_check.ex` unclosed delimiter) resolved itself
before retry; not touched by this lane.

## Standing

- Court ALIVE on the exact subject: 6/6 ×2 runs, real subprocess +
  filesystem evidence.
- Vocab pin (xaas-local row): pinned and verified — content sha256
  `6274d2d8…` re-verified from bytes; carried in
  `docs/airo/pin-court-vocab.md`.
- 9 ledger rows: gate now executable; per-repo ALIVE still open until
  each repo's `airo_risk_description.ttl` lands (falsifier unchanged in
  substance).
- REFUSED: none. UNSUPPORTED: none. BLOCKED: none.

## Files written/modified by this lane

- NEW `test/xaas/airo/airo_pin_court_test.exs`
- NEW `docs/airo/pin-court-vocab.md`
- MOD `docs/cro/artifacts/airo-wiring-ledger.md` (falsifier cells only)
- SLA-fix MOD `lib/xaas/ocel/event.ex`,
  `lib/xaas/security/finding.ex` (W982a's files; disclosed)
- Receipt `docs/sjira/v26.10.6/plans/w981j-airo-pin-court.md`

## Carry-forward to coordinator

1. Delete `_build-laneW981j` at integration.
2. At integration, re-run the court (it is the executable falsifier for
   the 9 rows) and diff-check the ledger falsifier amendment against
   W981f's receipt wording before commit.
3. `docs/airo/` now contains W981e's three reference dirs, W981f's six,
   and this lane's `pin-court-vocab.md`.
