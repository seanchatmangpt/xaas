# W984aw — graphql-era register-row citation sweep (lane receipt)

- **Lane**: W984aw, xaas v26.10.6, repo `/Users/sac/xaas`, branch
  `feat/playwright-surface` (uncommitted shared campaign tree; no commit —
  coordinator owns commits).
- **Scope**: docs/ only — `w859-typed-gap-register.md` + this receipt. No mix
  commands (per dispatch); all verification is grep/ls/file-presence, no test
  execution claimed.
- **Trigger**: operator graphql removal (code lane W984ao; docs lane W984aq
  landed OUT-OF-SCOPE flips on the W802/W819 rows). This lane swept the
  register for OTHER rows whose REPAIRED evidence cites graphql-era
  courts/surfaces now deleted.

## Method

1. Read the register fresh on disk (post-W984aq/W984w concurrent edits).
2. Grep all 51 rows for `graphql_schema` / `graphql_domain_wiring` /
   `graphql_http_surface` / `Absinthe` / `SPEC-30` / `SPEC-31`.
3. For each hit, re-read the row and the cited receipt(s) to determine whether
   the load-bearing evidence is graphql-dependent.
4. Verified surface deletion + surviving courts on tree (`ls`/`grep`, no mix).

## Sweep table

| Register row | graphql-era citations found | Load-bearing evidence graphql-dependent? | Action |
|---|---|---|---|
| W802/W819 UNSUPPORTED(graphql-http-surface) | w975b/w973c/w982l/w983p SPEC-30 history | Yes — surface itself removed | (Already flipped OUT-OF-SCOPE by W984aq — no change) |
| W819 GAP(graphql-domain-coverage) | w973c/w982a/w982u SPEC-31 era | Yes — demand moot (surface removed) | (Already flipped OUT-OF-SCOPE by W984aq — no change) |
| W729 UNSUPPORTED(multitenancy) | w975b (SPEC-30 wave receipt) | No — w975b cited for its billing/multitenancy commits `ddb19522`/`39c405fc`; SPEC-30 half superseded | Annotated in-row; status stands |
| W731 GAP(graphlaw-limits-not-enforced) | w982l (status only) + w983p (re-witness) | No — load-bearing courts are graphlaw_limit_gate_test.exs + graphlaw_limit_seams_test.exs at the `Xaas.Bridges.LimitGate`-independent `Xaas.Bridges.Graphlaw.do_assess/3` seams; both confirmed on disk | Annotated in-row; status stands |
| W750-G2 (detect/1 regression blindness) | w982l (status only) + w983p (re-witness) | No — SPEC-14 landing + commit `fd471722`; capability_liveness_deepening_test.exs on disk | Annotated in-row; **0 flips** |
| W765 GAP-D (FreezeWindow runtime gate) | w982l (status only) + w983p (re-witness) | No — SPEC-18 + w969c wiring + commit `5a853130`; freeze_window_active_gate_test.exs on disk | Annotated in-row; status stands |

Last row's `commit \`5a853130\`` — corrected to that value in the register
annotation (the receipt-table shorthand was a draft artifact; the register row
itself carries the correct `5a853130`).

## Findings

- **0 register rows flipped by this lane.** After W984aq's two OUT-OF-SCOPE
  flips, no surviving row's ONLY evidence was a graphql court.
- The keynote/name-spec court (`test/xaas/conference/keynote_graphql_surface_court_test.exs`)
  — graphql-only evidence — is cited by **no** register row (grep 0 hits) and
  is itself deleted on tree; nothing to disposition.
- w983p's "44 passed" combined re-witness run bundled 3 graphql court files
  with the 4 graphql-independent courts; the rows citing w983p name the
  non-graphql court files explicitly, all confirmed on disk post-removal.
- Verified on tree: `lib/xaas/graphql_schema.ex` absent; `lib/xaas_web/router.ex`
  0 graphql hits; deleted graphql test files absent; surviving courts
  (graphlaw_limit_gate_test.exs, graphlaw_limit_seams_test.exs,
  capability_liveness_deepening_test.exs, freeze_window_active_gate_test.exs
  all present). Zero-`mix` grep/ls verification only — no test execution
  claimed.
- **Fresh awk tally**: 51 rows = 40 REPAIRED / 7 OPEN / 2 TYPED-OPEN /
  2 OUT-OF-SCOPE(removed-by-operator). (W824's OPEN→REPAIRED flip by W984w
  landed concurrently mid-sweep — its court is graphql-independent; W984w's
  note's "9 OPEN" predates W984aq's graphql-domain-coverage flip.)

## Standing

- **LANDED-UNCOMMITTED** on `feat/playwright-surface`: register edits
  (status-vocabulary OUT-OF-SCOPE bullet, 4 in-row annotations, W984aw sweep
  note) + this receipt. Totals section (line ~78) still carries the
  pre-sweep baseline totals; the W984aw note supersedes them with the fresh
  tally (prior lanes' baseline notes are kept as history, per register
  convention — same pattern as W971/W980j).
- Concurrent-edit disclosure: W984w's W824 flip landed on disk mid-sweep;
  re-read before each edit; kept intact.
- Falsifier: `grep -c 'W984aw' w859-typed-gap-register.md` ≥ 4 hits on disk
  (actual: 5).
