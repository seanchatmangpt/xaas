# v26.10.7 Milestone Closure Plan

Lane W650k (v26.10.7 fleet seal, audit-remediation lane). Subject:
`/Users/sac/xaas` @ `feat/playwright-surface`, tagged `v26.10.7`
(tag object `ccad2a59`, peels `56325fa5`; see
`docs/sjira/v26.10.7/plans/w649-fleet-tag6.md` and
`docs/sjira/v26.10.7/plans/w650c-closure-v2.md`). Source of truth: the
receipt corpus under `docs/sjira/v26.10.7/plans/*.md` (85 receipts, all
resolve on disk). This plan contains ONLY closure work — no new features,
no surface expansion.

## 1. Checklist status (from the landed receipts)

| # | item | status | sources |
|---|---|---|---|
| 1 | Statutory eu_ai_act census 1352/0/1 at seal HEAD | CLOSED — witnessed run at exact seal HEAD `56325fa5` (fresh lane root, from-scratch compile; one disclosed async port-crash flake reclassified on isolated rerun); supersedes the never-landed W984dj draft basis | w650b-open-items.md, w633-playwright-live.md |
| 2 | OS-18 actuation identity tautology elimination | CLOSED — residual `checkpoint_external/2` tautology eliminated, negative court 7→10 legs, dual mutation kills witnessed ×2, commit `579454be` | w601-actuation-tautology.md, w601b-tautology-commit.md |
| 3 | Refusal-ledger canonicalization | CLOSED — 77 canonical entries, JCS digest replay MATCH, committed `d95defa2` | w616-refusal-ledger.md, w616b-ledger-commit.md |
| 4 | Playwright surface 371/371 + live-instance 6/6 | CLOSED — ash_surface re-verify, full PW suite green, live instance green | w611-ashsurface-reverify.md, w633-playwright-live.md, w634-seal-prep.md |
| 5 | Release-audit version baseline 26.10.7 | CLOSED — VERSION/mix.exs bumped, tag `v26.10.7` cut and fleet-verified 8/8 | w612-release-audit-pin.md, w617-version-bump.md, w635-fleet-tag.md, w649-fleet-tag6.md |
| 6 | Release-audit constants re-pin to the 19-domain / 116-resource surface | CLOSED this lane — `@domains`/`@resource_counts`/`@resource_total` advanced to the witnessed 19-domain surface; resource-source scanner extended to `use Ash.Resource,`; per-finding dispositions in w650k-audit-remediation.md | w645-release-audit.md, w650k-audit-remediation.md |
| 7 | W638 graphlaw WASM host | DRAFT(W638-commit-pending) — court ALIVE 8/8 ×2 roots; `lib/xaas/semantics/graphlaw_wasm.ex` + `priv/graphlaw.wasm{,.sha256}` still untracked at receipt time | w638-wasmex-host.md, w647-graphlaw-retry.md, w637b-graphlaw-commit.md |
| 8 | W640 differential SHACL court | DRAFT(W640-differential-pending) — unification receipt §7 DRAFT-PENDING, zero agreement rows | w643-unification-receipt.md, w640-differential-shacl.md, w650b-open-items.md |
| 9 | Fleet tags 8/8 | CLOSED — all 8 remote tags present, every peel exact vs audited SHAs, falsifier re-run passed | w635-fleet-tag.md, w649-fleet-tag6.md, w650c-closure-v2.md |
| 10 | PPlan pins | CLOSED | w650j-pplan-pins.md |
| 11 | a2a doc-version fix | CLOSED — commit `13dd1a57` pushed fast-forward on `feat/tck-vuln-hardening`; W628's arch-verifier timeout pre-existing | w628-a2a-suite.md, w628b-a2a-docfix.md |
| 12 | Receipts-sweep corpus commits | CLOSED — w650h/w650h2 sweeps landed as 4266712b/8c8549a3/50638a5e/de1db9e1 | w650h-receipts2.md, w650h2-receipts3.md |
| 13 | W650m path repair | CLOSED | w650m-path-repair.md |
| 14 | W650s pin-drift | CLOSED | w650s-pin-drift.md |

## 2. Remaining DRAFT items (honest open surface)

1. W638 commit-pending: graphlaw WASM host files untracked; needs one
   coherent commit by the coordinator.
2. W640 differential-pending: needs the differential run + agreement rows
   filled in the unification receipt.
3. This closure plan and the release-audit re-pin are unwritten-final until
   the coordinator's seal commit (this lane makes no commit, per contract).

## 3. Receipt corpus

The full receipt corpus is `docs/sjira/v26.10.7/plans/*.md` (85 receipts,
all resolve on disk; `w614-gate-log.json` is JSON, excluded by the glob).
The closure receipt `docs/sjira/v26.10.7/_CLOSURE_RECEIPT.md` is the DRAFT
seal record; DRAFT flags preserved as receipted (W638 commit-pending, W640
differential-pending). Every explicitly named receipt reference above
resolves on disk.
