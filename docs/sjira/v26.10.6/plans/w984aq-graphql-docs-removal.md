# W984aq — GraphQL docs-removal counterpart (docs/ only)

Lane: W984aq, xaas v26.10.6 campaign, branch `feat/playwright-surface` (uncommitted).
Counterpart to the code-removal lane W984ao, per operator directive (2026-10-07:
remove graphql code, fix forward). Docs/ writes only; no mix commands; no commit.

## Authority

- Operator directive (in-session, 2026-10-07) — remove graphql code, fix forward.
- W984ao's receipt `w984ao-graphql-removal.md` was NOT on disk at edit time
  (checked: only `w984ao1-e2e-graphql-check.md` and `w984ap-e2e-removal.md`
  exist), so per instruction every edit cites the operator directive +
  `w984ap-e2e-removal.md` for the e2e removal.

## Per-doc edits

1. `docs/claude/diataxis/reference/http-api-surface.md` — deleted the entire
   `## /api/graphql — GraphQL (SPEC-30, W975b design-wave 4)` section (94 lines:
   section body, GraphQL census table, auth/policy floor subsection,
   typed-skip list, standing paragraph), leaving the surrounding Fabric and
   "Other HTTP surfaces" sections intact. Post-edit grep for
   `graphql|absinthe` (case-insensitive) on the file: **0 hits**.
2. `docs/claude/diataxis/reference/generated-surfaces.md` — checked; **0
   graphql/absinthe mentions**; no edit needed.
3. `docs/cro/artifacts/generated-surface-census-v26.10.6.md` — checked; **0
   graphql/absinthe mentions**; no edit needed.
4. `docs/claude/diataxis/reference/generated-castle-bridge-errc.md` — REDUCE
   row (weight 9.4): "RouteCastleRun remains read-only on JSON:API/GraphQL"
   → now "read-only on JSON:API" with a citation to the removal directive +
   `w984ap-e2e-removal.md` and w984ao-receipt-pending note.
5. `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md` — two rows flipped
   (re-read immediately before edit; post-W984ae-reconcile text edited as
   found):
   - W802/W819 graphql-http-surface row: `REPAIRED` →
     `OUT-OF-SCOPE(removed-by-operator, 2026-10-07)`, superseding the
     SPEC-30-era REPAIRED history (w975b/w973c/w982l/w983p citations
     replaced by removal citations).
   - GAP(graphql-domain-coverage) row: `OPEN` →
     `OUT-OF-SCOPE(removed-by-operator, 2026-10-07)`, demand moot (surface
     removed).

## Rows dispositioned

| Register row | Was | Now |
|---|---|---|
| W802/W819 UNSUPPORTED(graphql-http-surface) | REPAIRED | OUT-OF-SCOPE(removed-by-operator, 2026-10-07) |
| GAP(graphql-domain-coverage) | OPEN | OUT-OF-SCOPE(removed-by-operator, 2026-10-07) |

## Standing

- Docs-removal counterpart: LANDED-UNCOMMITTED on `feat/playwright-surface`
  (4 files edited, 2 checked-no-change).
- Residual: `w984ao-graphql-removal.md` citation is forward-looking until
  W984ao's receipt lands; when it does, the register rows and the
  castle-bridge ERRC row cite it directly (currently cite directive +
  w984ap).
- Out of scope here (historical narrative lines in the register body, e.g.
  the SPEC-27/30/31 sweep notes near lines 84/105/241, were left as
  history; code deletion, test deletion, mix.exs dep removal are W984ao's
  lane).
- Falsifier: grep `graphql|absinthe` over
  `docs/claude/diataxis/reference/http-api-surface.md` returns >0 hits, or
  the register rows regress to REPAIRED/OPEN.
