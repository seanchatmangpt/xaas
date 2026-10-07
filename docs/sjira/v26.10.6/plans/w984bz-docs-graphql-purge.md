# W984bz — docs/ graphql purge, phase 2 (post-removal)

Lane: W984bz, xaas v26.10.6 campaign. Subject: branch
`feat/playwright-surface`, working tree at read time (HEAD `12d5f6d3`).
No mix commands; no commits; docs/ only plus this receipt.

## Method

Real grep sweep (`grep -rniE 'graphql|absinthe|SPEC-30|SPEC-31'`) over
`docs/claude/diataxis/**`, `docs/cro/**`, `_COMMIT_MANIFEST_W850.md`,
`_INTEGRATION_RUNBOOK.md`; code-state check (`grep` over `lib/ config/
mix.exs mix.lock`) to ground dispositions; per-file context read before
every edit.

## Code state (grounding)

- Zero `AshGraphql.*` extension wiring, zero `Xaas.GraphqlSchema`, zero
  Absinthe deps in `lib/`, `config/`, `mix.exs`, `mix.lock`.
- Post-removal domain extension lists confirmed in source, e.g.
  `lib/xaas/library.ex`: `[AshJsonApi.Domain, AshAdmin.Domain, AshAi]`.
- Remaining graphql tokens in `lib/` are comments ("no GraphQL surface")
  and the unrelated `Xaas.Semantics.VKG.graphql/2` AshR2RML consumer
  function (`lib/xaas/semantics/vkg.ex:67`) — not the removed
  GraphQL-over-HTTP surface.

## Hit table + dispositions

1. diataxis/reference/ash-configuration.md — lines 66, 71-88, 91-101
   class (b) living doc → UPDATED. Stripped `AshGraphql.Domain` from
   all 13 extension rows; replaced "GraphQL surface status" section
   with "GraphQL removal status" citing operator directive + w984ao
   (12d5f6d3, c0ba9f20), W984bu, W984bk.
2. diataxis/explanation/architecture-overview.md — line 39, class (b)
   → UPDATED. Removed `AshGraphql.Domain` from extension-profile
   sentence.
3. diataxis/explanation/ash-is-the-xaas.md — lines 16, 42, 51, 60,
   75, 85, 116; class (b) → UPDATED. Dropped GraphQL from convergence
   thesis, mermaid node+edge, traditional-stack bullet, code example
   (extensions + `graphql do` block), produced-interfaces list; added
   removal note citing w984ao.
4. diataxis/explanation/ash-typescript-adoption.md — line 43, class
   (b) → UPDATED. `AshGraphql.Resource` removed from example
   extension list.
5. diataxis/how-to/fix-ash-admin-and-use-ggen-for-codegen.md — line
   29, class (b) → UPDATED. `AshGraphql.Domain` removed from example
   extension list.
6. diataxis/reference/generated-castle-bridge-errc.md — line 17,
   class (b) → LEAVE. Already states removal (cites w984ap/w984ao);
   W984aq phase-1 work.
7. diataxis/reference/actuation-and-semantics.md — line 140, class
   (b) negation → LEAVE. "no HTTP/GraphQL/RPC surface" remains true
   post-removal.
8. diataxis/reference/eu-ai-act-semantics.md — lines 341, 468, class
   (b) accurate → LEAVE. Documents live `Xaas.Semantics.VKG.graphql/2`
   (AshR2RML consumer, still in lib).
9. diataxis/explanation/errc-innovation-grid.md — line 1551, class
   (a) evidence text → LEAVE. Quoted historical grep evidence;
   statement still true.
10. cro/CYCLE-LOG.md — lines 424-461, class (a) history → LEAVE.
    CYCLE-4 addendum narrates the removal arc itself; accurate.
11. cro/artifacts/evidence-claims-index.md — lines 72, 81, class (a)
    history → LEAVE. Historical evidence rows with standing-at-time
    citations.
12. _COMMIT_MANIFEST_W850.md — line 469, class (c) pending table →
    UPDATED. W975b SPEC-30 row flipped to OUT-OF-SCOPE
    (removed-by-operator), citing w984ao/bu/bk.
13. _COMMIT_MANIFEST_W850.md — line 536 (b2 update), class (c) →
    UPDATED. RESOLVED row extended with OUT-OF-SCOPE
    (removed-by-operator) annotation.
14. _COMMIT_MANIFEST_W850.md — lines 362, 508, 510, class (c) commit
    rows → LEAVE. Landed-commit rows (w819 receipt name; 691e0a93;
    39e9d77f) record landed history.
15. _INTEGRATION_RUNBOOK.md — line 670, class (a) history → LEAVE.
    W981u staged-commit addendum records staging state at HEAD
    6f235905.

## Edits made (7 files incl. receipt)

1. docs/claude/diataxis/reference/ash-configuration.md
2. docs/claude/diataxis/explanation/architecture-overview.md
3. docs/claude/diataxis/explanation/ash-is-the-xaas.md
4. docs/claude/diataxis/explanation/ash-typescript-adoption.md
5. docs/claude/diataxis/how-to/fix-ash-admin-and-use-ggen-for-codegen.md
6. docs/sjira/v26.10.6/_COMMIT_MANIFEST_W850.md (2 rows)
7. docs/sjira/v26.10.6/plans/w984bz-docs-graphql-purge.md (this
   receipt)

## Post-edit residual

Final grep (excluding plans/ receipts): every remaining hit is class
(a) history, an accurate negation, a landed-commit row, or the live
VKG function — no living doc describes GraphQL as a current XaaS
capability.

## Standing

- UPDATED edits: ALIVE (doc) — grounded in real greps on both sides
  (pre-edit doc text vs post-removal lib/ source); no test or compile
  claims made.
- Manifest OUT-OF-SCOPE flips: ALIVE (doc) — landed-commit rows
  preserved untouched per manifest-immutability rule.
- Disclosure: w984ao receipt file presence NOT verified on disk
  (CYCLE-LOG flags it MISSING_RECEIPT); edits cite the landed commits
  12d5f6d3 and c0ba9f20, verified in `git log` at read time. No mix
  commands run, per lane constraints.
