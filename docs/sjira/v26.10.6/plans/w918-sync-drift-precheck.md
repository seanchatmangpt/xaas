# W918 — ggen sync drift pre-check (predicted, not executed)

Standing: PREDICTED (one-line rationale drift; verbatim strings read from disk) +
BLOCKED for exact replay until pin advance. Sync NOT run per lane order — execution is
the operator's step 3 (W879).

Lane: W918, xaas v26.10.6 campaign. Repo: /Users/sac/xaas. Date: 2026-10-07.

## Subject / reads (all real)

- Page: `docs/claude/diataxis/reference/generated-castle-bridge-errc.md`
- Template: `ggen-marketplace:packs/xaas-castle-bridge-pack/templates/castle-errc.md.tmpl`
  (pack checked out at marketplace HEAD 4bb5fbaff; template unchanged since pin)
- Ontology: `ggen-marketplace:packs/xaas-castle-bridge-pack/ontology.ttl`
  - committed (at pin 518572b6 and at HEAD 4bb5fbaff): rationale = `XaaS already owns 69 Ash resources and seven domains; compose through the native RouteCastle capability instead`
  - W756 uncommitted working-tree edit (ontology.ttl line 101): rationale = `XaaS already owns 117 Ash resources via the Xaas.Resource wrapper (152 total use Ash.Resource) and 19 domains; compose through the native RouteCastle capability instead`
- Consumer wiring: `/Users/sac/xaas/ggen.toml` `[packs.xaas_castle_bridge]` pins
  `version = "518572b6b53103922ae8a27636a00e982a0907c4"`, subdir `packs/xaas-castle-bridge-pack`.
  Verified: pin is an ancestor of marketplace HEAD 4bb5fbaff.

## (a) Generation chain (W754 verification re-confirmed by read)

`castle-errc.md.tmpl` emits exactly: fixed H1 + provenance blockquote + ERRC table
(SPARQL SELECT ?category ?priority ?decision ?rationale ?expectedLeverage over all
xcb:ERRCDecision rows, ORDER BY category, priority) + fixed closing prose paragraph.
The template interpolates the ontology rationale literal verbatim into the "Why"
column. 13 ERRCDecision rows total; no other pack template interpolates `xcb:rationale`
(grep across all 7 templates: only castle-errc.md.tmpl matches).

## (b) Stale vs new text

- Page line 10, "Why" cell (stale, committed): `XaaS already owns 69 Ash resources and seven domains; compose through the native RouteCastle capability instead`
- Ontology (W756, new): `XaaS already owns 117 Ash resources via the Xaas.Resource wrapper (152 total use Ash.Resource) and 19 domains; compose through the native RouteCastle capability instead`
- Category/priority/decision/leverage cells of the ELIMINATE-10 row are unchanged in
  the ontology; only ?rationale differs.

## (c) Predicted post-sync diff — exactly one line changes (page line 10)

Condition: W756's ontology edit committed in ggen-marketplace AND `ggen.toml` pin
advanced, then `ggen sync`.

OLD (page line 10, verbatim from disk):

    | ELIMINATE | 10 | duplicate CASTLE PaaS Ash resource plane inside XaaS | XaaS already owns 69 Ash resources and seven domains; compose through the native RouteCastle capability instead | 9.8 |

NEW (template interpolates the W756 rationale verbatim):

    | ELIMINATE | 10 | duplicate CASTLE PaaS Ash resource plane inside XaaS | XaaS already owns 117 Ash resources via the Xaas.Resource wrapper (152 total use Ash.Resource) and 19 domains; compose through the native RouteCastle capability instead | 9.8 |

All other 12 table rows, header, blockquote, and closing paragraph are byte-identical
(only the rationale literal changed in the ontology; SPARQL result order unchanged).

## (d) Other sync-path facts and findings

1. Template blast radius: only `castle-errc.md.tmpl` consumes the rationale. The other
   6 templates (castle-bridge-shacl.ttl, castle-contract-inject.ex, castle-contract-test.exs,
   castle-contract.ex, castle-edge-catalog.ex, castle-innovation.json) do not reference
   ERRCDecision rationale — W756's edit cannot touch their outputs.
2. **Pin gate (BLOCKED for exact replay):** `ggen.toml` pins 518572b6, which does NOT
   contain W756's edit (edit is uncommitted in the marketplace working tree). `ggen sync`
   run now, at the current pin, resolves the OLD rationale — zero page delta. The (c)
   prediction applies only after marketplace commit + pin advance.
3. **Pin-advance side effect:** exactly one marketplace commit touched the pack since the
   pin (0ce47cc39, "make all 376 packs qualify through real ggen 26.9.28"; ERRCDecision
   rows identical at pin vs HEAD). Moving the pin to HEAD pulls that commit's
   qualification changes too — other pack bytes (templates/pack.toml) must be
   byte-compared after pin move, not assumed identical.
4. **Finding 2 — census-section loss on regen:** template output ends at the closing
   prose paragraph (template line 21 = page line 21). The page currently carries
   lines 22-41: the "SIBLING generated projections coverage (W849 census)" section with
   its 9-row table and the "8 DRIFT-CHECKED / 4 PROVENANCE-ONLY / 0 UNPINNED" tally.
   The template does NOT emit these — they are post-W754 hand-additions inside a
   "do not hand-edit" generated file. A plain `ggen sync` regen would DELETE page
   lines 22-41. Nothing currently guards this: the page is not pinned in
   `test/xaas/generated/registry_drift_guard_test.exs` (no path match; its drift check
   is regen-and-compare only, and the census text is not in the template). Post-sync
   integration must either re-add the census section deliberately or move it to a
   non-generated page.
5. Stale-literal sweep for the old numbers elsewhere in the sync path: the strings
   `69 Ash resources` / `seven domains` appear in the xaas tree only in
   `docs/PRD-v26.8.21.md` (historical PRD, non-authoritative), the W754/W756 plan
   receipts, and this page. No lib/test/config surface carries them.

## Falsifier

Post-pin-advance sync then `git diff docs/claude/diataxis/reference/generated-castle-bridge-errc.md`:
expected = exactly the line-10 rationale change + census-section deletion (lines 22-41).
Any other delta falsifies this prediction.

## Standing

PREDICTED (line-10 rationale drift) / BLOCKED (exact replay; pin advance prerequisite) /
new drift class found (hand-added census content inside generated page, unguarded).
No build root created. No sync executed. Not committed.
