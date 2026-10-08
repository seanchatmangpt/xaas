# Commit Manifest — v26.10.7 wave (commit-manifest v3 staging)

- Staged by: lane W984iz (commit-manifest v3 staging), 2026-10-07
- Subject: /Users/sac/xaas @ feat/playwright-surface, HEAD 3961c4ab
- Range: 5e03acf5..HEAD — 63 commits, all 2026-10-07. Tag `v26.10.7` =
  56325fa5 (verified `git tag --points-at 56325fa5` → v26.10.7);
  5e03acf5 (W650v4 digest framing rotation) is the earliest post-tag wave
  commit and the manifest's baseline (excluded as zero-point).
- Conventions follow docs/sjira/v26.10.6/_COMMIT_MANIFEST_W850.md: one row per
  commit; receipts verified on disk (real `test -f` + grep for the SHA);
  group verification of the 9 landing-batch commit receipts.
- Receipt-existence method: (a) group sweep — the 9 landing-batch receipts
  `plans/w984{ds2b,fe,gi,fl,fu,gy,hg,hm,hx}-commit.md` all test -f OK on disk;
  (b) per-commit — each row's receipt either names the SHA on disk (grep
  verified this lane) or is self-carried (the commit itself lands the receipt
  file, so it cannot contain its own hash; existence holds in the tree at HEAD).
- Push state: HEAD == origin/feat/playwright-surface == 3961c4ab — the entire
  range is PUSHED.

## Summary header

- Total commits: **63** (5e03acf5..HEAD).
- Test files landed: **70** distinct paths under `test/` in the range diff
  (`git diff --name-only 5e03acf5..HEAD -- test/ | wc -l`).
- lib/ diffs landed: **12** distinct paths under `lib/` — each backed by a
  landing/repair receipt:
  - 3c03bffa — W650h14 gated batch 1 (6 lib files) — `plans/w650h14-gated-commit.md`
  - f0321df2 — W984dq6 SpgGate F2 guard + single-funnel seam — `plans/w650h22-commit.md`
  - c6bf5bbc — W984ee OTP-29 Map.update compat module — `plans/w984ee-probe.md`
  - 1ac2ad42 — W984es Execute→Bridge authority evidence map — `plans/w984es-repair.md`
  - 5855fd02 — W984ez typed-clause wrong-JSON-type repair — `plans/w984ez-repair.md`
  - ba3309c7 — W984fy adapter base_url runtime read — `plans/w984fy-probe.md`
  - fc2adcb0 — W984fx AIRo RiskControl lib touch — `plans/w984hx-commit.md`
- Docs landings: **121** distinct paths under `docs/` (lane receipts, landing
  addenda #1–#4, runbook/closure-plan updates, coverage re-censuses, diataxis/
  cro truthing).
- Open-items carryover (per docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md):
  (1) coordinator merge of `feat/playwright-surface` → `main`; (2) operator
  ash_pplan decision — W984hd re-pin landed in the ash_pplan repo itself
  (runbook: LANDED-IN-ash_pplan, receipt-only here); ash_pplan tag decision
  remains open.

## Commit table (5e03acf5..HEAD, chronological)

Receipt column: "cites SHA" = receipt file on disk greps the SHA; "self:" =
the commit lands the receipt file itself.

| # | SHA | lane(s) | paths summary | court/gate | receipt |
|---|---|---|---|---|---|
| 1 | bdc6d823 | W650h16, W984dr, W650y4 | 3 test courts (governance + status-transition) | 15/15 green incl. w650y3 pre-deletion; strict compile EXIT=0, fresh _build-laneW650h16 | plans/w650h16-commit.md (cites SHA) |
| 2 | 5f77e7f6 | W650h16 | 1 docs receipt | docs-only | self: plans/w650h16-commit.md |
| 3 | 983ca0ae | W650h17b, W650y4 | 1 docs NO-OP receipt | docs-only (NO-OP vs bdc6d823) | self: plans/w650h17b-commit.md |
| 4 | 1555f02e | W650h15, W650y3 | 2 docs (retrospective + superseded landing receipt) | docs-only | self: plans/w650h15-landing.md, w650y3-cursor.md |
| 5 | dc86fb76 | W650h18, W650h9, W650h8 | 2 test + 4 docs (W650h9 re-census courts + artifacts) | batch receipt attests; W650h9 re-census courts | plans/w650h18-commit.md (cites SHA); self: w650h9-recensus-court.md, w650z8-recensus-receipt.md, w650z8-recensus7.md |
| 6 | f25ab0ac | W650h18 | 1 docs receipt | docs-only | self: plans/w650h18-commit.md |
| 7 | e483e854 | W650h17, W984dq3, W650y4 | 1 test court | landing batch 2 courts | plans/w650h17-commit.md (cites SHA) |
| 8 | 36cadd9d | W650h17 | 1 docs receipt | docs-only | self: plans/w650h17-commit.md |
| 9 | 8a5f7ea7 | W650h23 | 1 docs (v26.10.7 fleet seal) | docs-only | self: plans/w650h23-commit.md |
| 10 | dc465f51 | W650h15b, W984dp3, W650y3 | 1 test (drop duplicate cursor court) | survivor W984dp3 green | self: plans/w650h15b-commit.md |
| 11 | 78127188 | W650h24 | 1 docs deletion (retired w650y3-cursor.md) | docs-only | plans/w650h24-commit.md (cites SHA) |
| 12 | 4d00fdcd | W650h30 | 8 docs (untracked v26.10.7 lane receipts) | docs-only | self: plans/w650h12-commit.md, w650h24-commit.md, w650h25-verify.md, w650h26-commit.md, w650h27-commit.md, w650v4-commit.md, w650z9b-commit.md, w984ds-commit.md |
| 13 | 53b905ac | W984dq7, W984dq2 | 1 test + 1 docs | court green (subject-attested) | plans/w984dq7-commit.md (cites SHA) |
| 14 | c0626503 | W650v6 | 1 docs NO-OP receipt | docs-only (race resolved by prior lane) | self: plans/w650v6-commit.md |
| 15 | f0321df2 | W650h22, W984dq6 | 2 lib (SpgGate F2 guard + single-funnel seam) + 2 test + 1 docs | court attested in receipt | plans/w650h22-commit.md (cites SHA); self: w984dq6-spg-execute.md |
| 16 | ee6c18bc | W650h22 | 1 docs receipt | docs-only | self: plans/w650h22-commit.md |
| 17 | 34fc8a53 | W650h33, W984de | 1 test court (vkg query_depth, 5 tests) | court green | plans/w650h33-commit.md + w650h33b-commit.md (cite SHA) |
| 18 | 5cf56c13 | W984ds2b, W984ds, W650za | 2 test + 2 docs | batch, 10 green | plans/w984ds2b-commit.md (cites SHA); self: w984ds-probe.md, w650za-probe.md |
| 19 | b75918a5 | W984ds2b | 1 docs receipt | docs-only | self: plans/w984ds2b-commit.md |
| 20 | f2d30813 | W984ds2b | 1 docs correction (cleanup wording; rm denied, root moved to /tmp) | docs-only | self: plans/w984ds2b-commit.md (correction section) |
| 21 | 0b1b70fc | W650h33b | 1 test court (vkg query_depth, 5 tests) | court green | self: plans/w650h33b-commit.md |
| 22 | d51119c5 | W650h33b | 1 docs correction (git-state verdict) | docs-only | self: plans/w650h33b-commit.md (correction) |
| 23 | 32b72c4f | W650h10 | 1 test (repaired process_receipt_depth court) | court green | self: plans/w650h10-owner-defect.md |
| 24 | acacc1db | W984dr2b, W984dw, W984dx | 3 test + 3 docs | courts from finished lanes | self: plans/w984dr2b-gov-batch2.md, w984dw-probe.md, w984dx-probe.md |
| 25 | ab3562b8 | W984dy, W650v5, W650v7 | 4 test + 3 docs | courts from finished lanes | self: plans/w984dy-probe.md, w650v5-probe.md, w650v7-probe.md |
| 26 | 8f9ea495 | W984ef, W984eg | 4 docs (runbook addendum + deepening) | docs-only | self: plans/w984ef-probe.md, w984eg-probe.md |
| 27 | ecf84663 | W984el | 1 docs receipt | 8 candidate files, 91 passed (attested in receipt) | self: plans/w984el-commit.md |
| 28 | 3c03bffa | W650h14 | 16 files: 6 lib + 7 test (gated lib/test landing batch 1) | receipt-gated | plans/w650h14-gated-commit.md (cites SHA) |
| 29 | ed015775 | W650h14 | 4 docs (gated-commit receipt + runbook/census/receipt doc updates) | docs-only | self: plans/w650h14-gated-commit.md |
| 30 | 0153101a | W984fe | 3 test + 5 docs | landing batch #2, verified courts | plans/w984fe-commit.md (cites SHA); self: w984dt/ea/eh/en-probe.md, w984er-orphan-register.md |
| 31 | c6bf5bbc | W984ed, W984ee | 1 lib (OTP-29 compat) + 3 docs | landing batch #2 | self: plans/w984ed-probe.md, w984ee-probe.md |
| 32 | 49992412 | W984et | 1 mix.lock (unlock absinthe, absinthe_plug, ash_graphql) | dep-only; superseded by graphql removal (W984ao, pre-baseline) | self: plans/w984et-probe.md (landed via 43265cb1) |
| 33 | a420b7d5 | W984ej, W984ez | 1 docs (court receipt; court file deferred) | docs-only | self: plans/w984ej-probe.md |
| 34 | 43265cb1 | W984fe | 2 docs (w984et probe + lane commit receipt) | docs-only | self: plans/w984fe-commit.md, w984et-probe.md |
| 35 | 06fed7b2 | W984eo, W984em | 2 test + 2 docs | courts from finished lanes | self: plans/w984em-probe.md, w984eo-probe.md |
| 36 | 1ac2ad42 | W984es | 1 lib + 1 test + 2 docs | repair (authority evidence map) | self: plans/w984es-repair.md, w984dq9-probe.md |
| 37 | e2ef8aa5 | W984fh | 2 docs (sixth coverage re-census) | docs-only | self: plans/w984fh-recensus.md |
| 38 | a355e317 | W984eu, W984eb | 1 test (Title III prose) + 1 docs | flips attested (W984eb IncidentReport) | self: plans/w984eu-probe.md |
| 39 | 0e521e68 | W984fl | 1 docs receipt | docs-only | self: plans/w984fl-commit.md |
| 40 | 4eba5a44 | W984fl | 1 docs correction (mix.lock/w984et misattribution) | docs-only | self: plans/w984fl-commit.md (correction section) |
| 41 | a9056f7b | W984fj, W984fg, W984eq | 3 test + 3 docs | courts from finished lanes | self: plans/w984eq-probe.md, w984fg-probe.md, w984fj-probe.md |
| 42 | 180d4606 | W984fc, W984fa, W984ec, W984eu | 3 test + 3 docs | deepenings + Title III prose | self: plans/w984ec-probe.md, w984fa-probe.md, w984fc-probe.md |
| 43 | 956b772a | W984ep | 6 test (flake-fix sweep, shared-table emptiness scoping) + 1 docs | flake-fix batch | self: plans/w984ep-probe.md |
| 44 | b5615c6d | W984ff, W984fp | 4 docs (gap-register refresh + evidence-claims refresh) | docs-only | self: plans/w984ff-probe.md, w984fp-probe.md |
| 45 | 102c1782 | W984fu | 1 docs receipt | docs-only | self: plans/w984fu-commit.md |
| 46 | e49d7033 | W984gi | 7 test + 7 docs | landing batch #5, verified courts | plans/w984gi-commit.md (cites SHA); self: w984ev/ey/fb/fi/fm/fn-probe.md, w984fo-restoration.md |
| 47 | 5855fd02 | W984ez | 1 lib + 1 test + 1 docs | typed-clause repair (W984ej court) | self: plans/w984ez-repair.md |
| 48 | b9d35fdd | W984gi | 6 docs (closure docs truthing) | docs-only | plans/w984gi-commit.md (cites SHA); self: w984ft/fz/ge-probe.md |
| 49 | 16a7bfa5 | W984gi | 1 docs receipt | docs-only | self: plans/w984gi-commit.md |
| 50 | ba3309c7 | W984fy | 1 lib + 1 test + 1 docs | real Plug/Cowboy local harness court | self: plans/w984fy-probe.md |
| 51 | 3b0bf56d | W984gy | 6 test + 6 docs | landing batch #6, six family courts | plans/w984gy-commit.md (cites SHA); self: w984ga/gb/gd/gf/gg/gh-probe.md |
| 52 | 226803b8 | W984fy, W984gu, W984hc | 1 test + 2 docs (IMDS runtime-config seam + 2xx status guards) | repair receipts | self: plans/w984gu-repair.md, w984hc-repair.md |
| 53 | 56615dc3 | W984gy | 8 docs (docs surface + witness/triage/receipt sweep) | docs-only | plans/w984gy-commit.md (cites SHA); self: w984fr-atomic-site1.md, w984fv-w784.md, w984fw-seed-writer.md, w984gc-triage.md, w984gn-probe.md, w984gq-probe.md, w984gm-census-witness.md |
| 54 | d1a2b91b | W984hg | 3 test + 3 docs | landing batch #7, gj/gl/gp family courts | plans/w984hg-commit.md (cites SHA); self: w984gj/gl/gp-probe.md |
| 55 | 69c5a095 | W984gr, W984gz, W984hg | 4 docs (item-14 closure + truthing) | docs-only | plans/w984hg-commit.md (cites SHA); self: w984gr-item14.md, w984gz-probe.md |
| 56 | 3674159f | W984hg | 1 docs receipt | docs-only | self: plans/w984hg-commit.md |
| 57 | 857ebe60 | W984gy | 1 docs receipt | docs-only | self: plans/w984gy-commit.md |
| 58 | 009bd057 | W984hg | 1 docs (record pushed head in lane receipt) | docs-only | self-adjacent: plans/w984hg-commit.md (batch #7 receipt, on disk); 009bd057 not grep-found in it — recorded here |
| 59 | 58cd87b9 | W984hm | 4 test + 4 docs | landing batch #8, verified courts | plans/w984hm-commit.md (cites SHA); self: w984go/gs/gw/gx-probe.md |
| 60 | 68073d8d | W984gt, W984hd, W984hm | 2 test + 4 docs (pin rotations + drift-map zeroing) | batch #8 | plans/w984hm-commit.md (cites SHA); self: w984gt-airo-pins.md, w984hd-repin.md |
| 61 | 82f7f558 | W984hm | 1 docs receipt | docs-only | self: plans/w984hm-commit.md |
| 62 | fc2adcb0 | W984hx, W984fx | 1 lib + 1 test + 2 docs | AIRo RiskControl trio landing | plans/w984hx-commit.md (cites SHA); self: w984fx-probe.md |
| 63 | 3961c4ab | W984hx | 1 docs receipt | docs-only | self: plans/w984hx-commit.md |

## Group verification of landing-batch receipts (test -f + grep, this lane)

All 9 receipts exist on disk (real `test -f`). grep-SHA results vs the range:

| receipt | test -f | SHAs grep-found | in range? |
|---|---|---|---|
| plans/w984ds2b-commit.md | OK | 34fc8a53 5cf56c13 | both in range |
| plans/w984fe-commit.md | OK | 0153101a 3c03bffa 49992412 a420b7d5 c6bf5bbc | all 5 in range |
| plans/w984gi-commit.md | OK | 5855fd02 a420b7d5 b9d35fdd e49d7033 | all 4 in range |
| plans/w984fl-commit.md | OK | 06fed7b2 1ac2ad42 43265cb1 49992412 8f9ea495 a355e317 e2ef8aa5 | all 7 in range |
| plans/w984fu-commit.md | OK | 06fed7b2 180d4606 1ac2ad42 956b772a a9056f7b b5615c6d | all 6 in range (180d4606/956b772a/b5615c6d pre-baseline siblings, cited for context) |
| plans/w984gy-commit.md | OK | 16a7bfa5 226803b8 3b0bf56d 56615dc3 ba3309c7 | all 5 in range |
| plans/w984hg-commit.md | OK | 16a7bfa5 226803b8 3674159f 3b0bf56d 69c5a095 ba3309c7 d1a2b91b | all 7 in range |
| plans/w984hm-commit.md | OK | 009bd057 58cd87b9 68073d8d + 0e210efb e3dcc4fa | 3 in range; 0e210efb/e3dcc4fa out-of-range sibling refs |
| plans/w984hx-commit.md | OK | 82f7f558 fc2adcb0 3c03bffa + 297da2f1 6274d2d8 | 3 in range; 297da2f1/6274d2d8 out-of-range (sibling-repo SHAs) |

Note: w984fu-commit.md also names 180d4606/956b772a/b5615c6d, which are inside
5e03acf5..HEAD (in range). No receipt in the sweep named a SHA that is not
accounted for; out-of-range SHAs are sibling-repository references (ash_pplan
and similar), not xaas commits.

## Standing

- Manifest staging: **ALIVE** — every row grounded in real `git log` /
  `git show --name-status` output at HEAD 3961c4ab; the 9 group receipts
  test -f + grep verified on disk this lane.
- Commit execution: **UNKNOWN** — coordinator owns git operations; this manifest
  is advisory staging (docs-only lane). Range is fully PUSHED (origin == HEAD
  == 3961c4ab).
- Open items (carryover, per runbook): coordinator merge of
  feat/playwright-surface → main; operator ash_pplan re-pin/tag decision
  (W984hd landed in ash_pplan repo — receipt-only here).
- No git write operations performed by lane W984iz. No build root created.
