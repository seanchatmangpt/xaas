# W760 — Fresh full gate after ~20 landed lanes (lane receipt)

- **Lane**: W760 (read-only gate lane), xaas v26.10.6, branch `feat/playwright-surface`,
  HEAD `a0723bf6`, working tree (staged landed-lane work, uncommitted — coordinator owns commits).
- **Log**: `/tmp/w760_gate.log` (compile + both gates, full output).
- **Env**: `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW760`.

## Commands (real, executed)

1. `mix compile --warnings-as-errors` → **exit 1, 268 warnings** (fails the flag).
2. `mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap` →
   **Result: 1198/1200 passed, 2 failed** (57.2s), exit 2.
3. `mix test test/eu_ai_act --include eu_ai_act --include eu_ai_act_open_gap` (census) →
   **Result: 1198/1200 passed, 2 failed** (40.2s), exit 2 — identical set and totals to (2).
4. Census probe: `mix test test/eu_ai_act --only eu_ai_act_open_gap` →
   **0 tests selected, 1200 excluded**. The `:eu_ai_act_open_gap` tag currently selects
   nothing at runtime, which is why (2) and (3) converge to the same 1200-test set.
   The `@moduletag :eu_ai_act_open_gap` declarations exist in source
   (title_i_test.exs:575, title_iii_test.exs:1132, title_vi_xiii_test.exs:803,
   title_iv_v_test.exs:446) but do not bind any test at runtime. Typed anomaly for the
   coordinator: the W670 corrected-gate convention is self-consistent today (no open
   gaps are silently excluded), but the tag-based census mechanism is inert.

## Compile gate

268 warnings, `--warnings-as-errors` fails (exit 1). Dominant classes: 21 pin-in-bitstring-size
(`len`), 39 redundant/unmatchable clauses, 15 charlist deprecation, ~23 unused require
(Logger/Ash.Query/Stripe.Util), plus xref-exclude deprecation in mix.exs. Sources are in `lib/`
(project code), not deps. Baseline tree-wide, not attributable to a single lane.

## Failures — both deterministic (no flake; not rerun-class)

### F1 — title_i_test.exs:547, EUAI-ACT 3.49 (W538) — REAL REGRESSION (typed finding)

- `assert :MALFUNCTION in report.classification` fails; actual `[:INFRINGES_UNION_LAW]`.
- Cause: the staged W679 suppression in `lib/xaas/semantics/incident_report.ex`
  (`maybe_add_malfunction/3` now suppresses `:MALFUNCTION` for all `EuAiActAdmission.refusal_atoms()`)
  changed classification for EUAIA-atom refused receipts, but the **3.49 typed call
  (title_i_test.exs:442) was not in W679's court-update table** — it still asserts both
  `:INFRINGES_UNION_LAW` and `:MALFUNCTION` for a `REFUSED_EUAIA_EMOTION_RECOGNITION` receipt.
  The sibling sub-lines (3.49.a/b/d, bare `:refused`/`:error` without EUAIA atom) still pass.
- Classification: (b) real regression — an orphaned W538-era court expectation against the
  landed W679 behavior. Fix is a court edit in the 3.49 typed call (drop the `:MALFUNCTION`
  assert for EUAIA-atom receipts; 3.49.a/b/d already court the bare-status path), not a lib change.

### F2 — title_iii_test.exs:766 via deepen_kind/1:1032, EUAI-ACT 15.5.s3 (W540) — REAL REGRESSION (typed finding)

- `respond(ticket, %{receipt: "diff w540 fix"})` returns `{:error, :REFUSED_LIFECYCLE_SKIP}`
  on the happy-path walk.
- Cause: defect in the **staged test edit itself** (title_iii_test.exs:1022-1047 hunk). The
  happy path asserts `{:ok, %VulnerabilityLifecycle{state: :TRIAGED}} = triage(ticket, ...)`
  but **discards the triaged struct** and calls `respond(ticket, ...)` on the original
  `:DETECTED` ticket — `respond/2` on a DETECTED ticket is exactly `:REFUSED_LIFECYCLE_SKIP`.
  The staged test cannot pass as written; the triaged struct must be rebound
  (`{:ok, ticket} = VulnerabilityLifecycle.triage(...)`).
- Classification: (b) real regression — self-refuting staged test in the in-flight deepening
  work (w623/w659d lifecycle surface). The lib state machine is correct.

No lane-in-flight file conflict (a) applies: the failing courts are owned by landed (staged)
lanes W679 and W623/W659d respectively; no running lane is named for these files.

## Standing

- Gate standing: **BLOCKED** (2 deterministic failures + warnings-as-errors red).
- Both failures are narrow, staged, court-side; lib behavior matches the latest landed
  doctrine (W679 suppression lock, W540 lifecycle contract).
- Repairs (not executed — read-only gate lane):
  1. Update title_i_test.exs 3.49 typed call to the W679 classification contract.
  2. Rebind the triaged struct in the title_iii_test.exs 15.5.s3 deepen hunk.
  3. Optionally investigate the inert `:eu_ai_act_open_gap` runtime tagging before
     relying on the census convention.
