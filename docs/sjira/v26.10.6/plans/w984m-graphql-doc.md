# W984m — GraphQL surface doc census + receipt (lane W984m, docs-only)

Standing: **PARTIAL_ALIVE** (docs-only lane; census re-read from disk, edits
verified on disk; uncommitted — coordinator owns the commit).

## Identity

- Lane: W984m, xaas v26.10.6, checkout `/Users/sac/xaas`, branch
  `feat/playwright-surface`, in-flight tree.
- Task: extend the `/api/graphql` section of
  `docs/claude/diataxis/reference/http-api-surface.md` with the TRUE
  post-W982l census, auth floor, policy floor, typed-skip list.
- No mix commands run (per lane constraint); no commits made.

## Sources read (fresh, on disk)

- `lib/xaas/graphql_schema.ex` — 19 domains in `domains:`; custom query root
  = `say_hello` only; zero custom mutations/subscriptions.
- `grep -rl "graphql do"` over `lib/xaas` — 78 resource files with graphql
  blocks; `grep -A4 "queries do"` extracted every get/list/action
  declaration. Per-file counts cross-checked.
- Batch receipts: `w973c-design-wave8.md` (exists, landed at `39e9d77f`),
  `w982a-conference-graphql-deepening.md`, `w982u-graphql-batch3.md`
  (batch 3, 10→12/19), `w983h-graphql-batch4.md` (batch 4, 12→14/19).
- `git log -- lib/xaas/graphql_schema.ex` — SPEC-31 landing commit
  `39e9d77f`; `git status` — `lib/xaas/graphlaw/capability.ex` modified
  (w984l evidence).
- `docs/claude/diataxis/reference/http-api-surface.md` (previous section,
  W975b-era) — replaced the stale census bullet + standing block.

## Census (as measured, not recalled)

- 19 domains listed in `Xaas.GraphqlSchema`.
- **16/19 domains** expose ≥1 query root field (resource-level
  `graphql do ... queries do` blocks).
- **32 query root fields**: 15 `get` + 15 `list` + 1 custom action
  (`projectMeasureJson`) + `say_hello`; **0 mutations**, **0 subscriptions**
  (no resource declares `mutations do`).
- Per-domain table, auth floor, deny-by-default policy floor (W982a
  precedent: `bypass read` + `policy always() forbid_if always()` with
  narrow write carve-outs), and 3-row typed-skip list (Ledger / Ultracode /
  A2a with reasons) now in the doc section.
- w984l (Graphlaw + TemporalMemory) marked IN-FLIGHT: no receipt file on
  disk at write time; both rows verified directly in the resource files
  (`capability.ex` is git-modified).

## Files written (only the two permitted paths)

- `docs/claude/diataxis/reference/http-api-surface.md` — GraphQL section
  replaced/extended (census table 16 rows, auth + policy floor bullets,
  typed-skip table, standing block with batch receipts cited; all new lines
  ≤100 chars, verified by awk).
- `docs/sjira/v26.10.6/plans/w984m-graphql-doc.md` — this receipt.

## Falsifier / replay

- Falsifier: re-run `grep -rn -A4 "queries do" lib/xaas --include="*.ex"`
  and diff against the doc's census table; any divergence (a wired resource
  missing from the table, or a table row with no on-disk block) refutes.
- Replay: `awk 'length>100' docs/claude/diataxis/reference/http-api-surface.md`
  scoped to the GraphQL section returns no lines from this lane's edits.
- Skips: none beyond the doc-level typed-skip list (Ledger/Ultracode/A2a),
  which reflects absence of graphql blocks on disk, not lane choice.
