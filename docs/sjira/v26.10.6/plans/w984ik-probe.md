# W984ik — truth-pass: docs/claude/diataxis/explanation/ash-is-the-xaas.md

Lane: W984ik, checkout /Users/sac/xaas (canonical), branch feat/playwright-surface.
Scope: docs-only truth-pass of the Ash-is-the-XaaS explanation doc. Sibling-modified
file (in `git status` modified list): disk state read first; append/patch-only, no
sibling edits reverted. No commit, no build root.

## Before (excerpts)

- Section 2 sample: `use Xaas.Resource, otp_app: :kanban, ...` (stale app name).
- Section 4: "Verified with Playwright (`e2e/next-read-ml.spec.js`)" (wrong extension).
- Section 5 header note: "VERIFY 2026-09-26 ... 13-domain / 92-resource surface" on
  top of the original "8 Ash domains spanning 74 declarative resources" census.
- GraphQL note (Section 2) citing `w984ao-graphql-removal.md` — present before this
  lane (sibling edit), not ours.

## After

- Patched `otp_app: :kanban` → `otp_app: :xaas` (real file `lib/xaas/library/book.ex:16`).
- Patched `e2e/next-read-ml.spec.js` → `e2e/next-read-ml.spec.cjs` (real file on disk).
- Appended dated "Verified 2026-10-07" blockquote (W984gz/hv/hy/hz convention) at end
  of file with claim-by-claim verification. No other sibling content touched.

## Command-verified claims

- `grep -n "ash_domains" -A 25 config/config.exs` → 19 domains listed
  (config/config.exs:13-33); the 13-domain/92-resource note and the 8-domain/74-resource
  census are both stale snapshots; live counts recorded in the doc block.
- `grep -rl "use Xaas.Resource" lib/xaas --include='*.ex' | wc -l` → 115.
- `sed -n '1,80p' lib/xaas/library/book.ex` → real extensions
  `[AshJsonApi.Resource, AshAdmin.Resource, AshAi]`; BLOCKED pgvector `vectorize`
  block in moduledoc + DSL; `borrow_copy` atomic_update at book.ex:144-151;
  `is_available` calc at :259; json_api block at :95.
- `lib/xaas/library/reactors/circulation_borrow_reactor.ex:44-81` → Checkout.borrow +
  DecrementBookInventory → Book.borrow_copy in one transaction (Section 3 narrative current).
- `ggen.toml` → `[ontology] ontology.ttl`, `[templates] templates-hooks`,
  `[packs.xaas_castle_bridge]` pinned `b58d7854142bacbd3aeffb83501646cae56c858a`;
  no marketplace `ash-*` sibling binding. Doc itself makes no ggen claim.
- `grep -rni graphql lib/ config/` → no AshGraphql surface; sole residue
  `lib/xaas/semantics/vkg.ex:66-67` (ash_r2rml consumer, not HTTP);
  `lib/xaas/operations/audit_log_entry.ex:20` "no GraphQL surface remains";
  cross-confirmed `docs/claude/diataxis/reference/ash-configuration.md:104-109`.
  Section 2 GraphQL note is current-truth. Residue sweep: w984et-probe.md.
- `grep -n` on `lib/xaas_web/router.ex` → `/next-read` :65, `/mcp` scope :190,
  `/a2a` scope :210, `/internal-api` :286, `/api` :330; `books_by_grade_band` tool at
  `lib/xaas/library.ex:20`.
- Actuation narrative: Section 1(4) governed-Reactor framing, no
  projection-grants-authority claim present.
- `ls docs/sjira/v26.10.6/plans/w650h22-commit.md` → No such file. Not cited.

## Standing

PARTIAL_ALIVE: doc claims verified current-truth on disk; patches are docs-only,
uncommitted (per lane contract); no executable subject exercised (docs-only lane).
