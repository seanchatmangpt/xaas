# W982f — OPEN-row repair sweep + anti-staleness pass

- **Lane**: W982f, xaas v26.10.6 campaign, 2026-10-07. Canonical checkout `/Users/sac/xaas`
  (branch `feat/playwright-surface`). No commit (per lane contract).
- **Task**: pick highest-value OPEN row in `w859-typed-gap-register.md` not lane-hot;
  implement one real repair (production change + Chicago court + mutation kill).
- **Build**: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW982f`, pinned asdf toolchain
  (`PATH=$HOME/.asdf/shims:$PATH`). `mix compile` exit 0 (fresh lane root, ~10 min).

## Row-selection outcome: no eligible OPEN row remains

Fresh on-disk read of the register (17 OPEN rows) cross-checked against current
`git status --porcelain` lane-hot files and w891 triage classifications:

| Row | Status vs lane W982f |
|---|---|
| W722 gap-2 (`X-Org-Id` caller-asserted) | DESIGN (w891 row 4: "new plug surface, not a guard") |
| W729 multitenancy / atomic_update | DESIGN + lane-hot (`lib/xaas/billing/approval_*.ex` modified) |
| W731 EngineLimit gates | lane-hot (`lib/xaas/bridges/graphlaw.ex`, `bridges/registry.ex` modified) |
| W750-G2 detect/1 | DESIGN (migration + history-semantics rewrite; `capability_liveness_deepening_test.exs` hot) |
| W765 GAP-D freeze runtime gate | lane-hot (`lib/xaas/governance/freeze_window.ex` modified) |
| W770 RouteProjectsBackups | lane-hot (`lib/xaas/platform/**` modified + 4 deletions) |
| W784 TOFU | w891 row 22 recommends promote to TYPED-OPEN |
| W793 NO_CROSS_REFERENCE | DESIGN (w891 row 24: "New relationship/attribute → migration") |
| W796-G3 hold→Checkout mint | DESIGN (w891 row 26: "Transactional fulfillment flow, not a guard") |
| W799 reversal actions | DESIGN (w891 row 27) + ledger reversal test hot |
| W804 dev `mix ecto.migrate` | OPERATOR (w891 row 29) |
| W802/W819 graphql mount | DESIGN (auth/http-api-surface doctrine floor, CLAUDE.md API-auth) |
| W824 QuiescentStop MCP envelope | DESIGN (w891 row 32: both named options out of test-lane scope) |
| W849 backlog-2 CI/regen leg | DESIGN (w891 row 34: "New CI surface") |
| W902 shared-DB contamination | OPERATOR/infra (coordinator hygiene pass or per-lane test DBs) |

Every remaining OPEN row is DESIGN-class, OPERATOR-gated, promote-to-TYPED-OPEN
candidate, or sits on a lane-hot surface. **No cheap, unhot repair target exists.**
Per lane contract, executed the fallback: anti-staleness pass over REPAIRED rows.

## Anti-staleness pass

**Receipt existence (all rows)**: script over the register extracted 64 distinct cited
receipt filenames; every one exists at `docs/sjira/v26.10.6/plans/<name>.md`. 0 missing.

**Court spot-check (5 REPAIRED rows, unhot surfaces), fresh root, ×2 runs**:

| Row | Repair receipt | Court file | Result |
|---|---|---|---|
| W793 4-gap (incident guards, W818+W902) | w902-batch3-repairs.md | test/xaas/operations/incident_lifecycle_deepening_test.exs | 19 passed (×2) |
| W650c OPEN_GAP-3 (w865) | w865-gap3-fix.md | test/xaas/semantics/dataset_admission_test.exs | 9 passed (×2) |
| W838-G1 (w909+w918b) | w918b-awaiter-hardening.md | test/xaas/library/pubsub_publish_court_test.exs | 9 passed (×2) |
| W796-G2 (w809) | w809-return-guard.md | test/xaas/library/return_fulfills_hold_test.exs | 3 passed (×2) |
| W765 GAP-A (w900-batch2) | w900-batch2-repairs.md | test/xaas/governance/export_token_deepening_test.exs | 21 passed (×2) |

**Standing: GREEN — zero drift.
All 5 spot-checked REPAIRED rows' courts pass ×2 on a fresh lane root; all 64 cited
receipt files exist.** Aggregate: 61/61 ×2.

## Register row update

No OPEN→REPAIRED flip this lane (no eligible row). No register row edited; the register
header stats block should be updated by the coordinator only if it treats this receipt as
the w970b-pattern continuation, with the honest statement: 0 flips, 0 drift findings.

## Disclosure / honesty boundary

- w865's original court also included `test/eu_ai_act/art15_deepening_test.exs` with
  `--include eu_ai_act`; this spot-check ran the default tag-excluded suite, so the
  art15-tagged portion was not re-witnessed this lane (dataset_admission portion GREEN).
- No production code changed; no mutation kill performed (nothing to kill — repair sweep
  fell through to fallback). Prior lane-hot files untouched; lane wrote only this receipt.
- Lane build root `_build-laneW982f` deleted post-run.
