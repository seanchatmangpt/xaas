# W756 — ERRC ELIMINATE-10 Rationale Refresh (xaas-castle-bridge-pack)

Standing: **ALIVE (pack-level, uncommitted)** — closes W754 finding F1 at the upstream source.
Falsifier: after the coordinator runs the regeneration command below, the regenerated ERRC page in xaas must contain the corrected counts; if it still says "69 Ash resources and seven domains", this receipt is REFUTED.

## Identity

- Repo: `/Users/sac/ggen-marketplace` (canonical checkout)
- Branch: `feat/aaif-gcp-roadmap-v26.10.5`
- HEAD at edit: `4bb5fbaff4ac8f1ace120e356d06d1b3ebe1cf86`
- Only file this lane touched: `packs/xaas-castle-bridge-pack/ontology.ttl` (one-line rationale literal, line 101). Not committed; no branch switch.
- Receipt: this file.

## Counts derived fresh (grep evidence)

Commands (cwd `/Users/sac/xaas`):

```bash
grep -rl "use Xaas.Resource"  /Users/sac/xaas/lib --include="*.ex" | wc -l   # → 117
grep -rl "use Ash.Resource"   /Users/sac/xaas/lib --include="*.ex" | wc -l   # → 152
grep -rl "use Ash.Domain"     /Users/sac/xaas/lib/xaas --include="*.ex" | wc -l  # → 19
```

W754's F1 cited 115/150/19; fresh derivation gives **117** wrapper resources, **152** total `use Ash.Resource`, **19** domains. The receipt and ontology use the fresh numbers (drift of +2/+2 in W754's numbers is itself another instance of the copy-drift class F1 flagged).

## Diff (scope proof)

`git diff packs/xaas-castle-bridge-pack/ontology.ttl` — exactly one changed line:

```diff
-xcb:eliminate10 a xcb:ERRCDecision ; xcb:category "ELIMINATE" ; xcb:priority 10 ; xcb:decision "duplicate CASTLE PaaS Ash resource plane inside XaaS" ; xcb:rationale "XaaS already owns 69 Ash resources and seven domains; compose through the native RouteCastle capability instead" ; xcb:expectedLeverage 9.8 ; xcb:reversibility 1.0 .
+xcb:eliminate10 a xcb:ERRCDecision ; xcb:category "ELIMINATE" ; xcb:priority 10 ; xcb:decision "duplicate CASTLE PaaS Ash resource plane inside XaaS" ; xcb:rationale "XaaS already owns 117 Ash resources via the Xaas.Resource wrapper (152 total use Ash.Resource) and 19 domains; compose through the native RouteCastle capability instead" ; xcb:expectedLeverage 9.8 ; xcb:reversibility 1.0 .
```

No other rows in the ontology touched; no other files touched by this lane. (`git status` in ggen-marketplace shows pre-existing uncommitted working-tree changes from other lanes — CHANGELOG.md, marketplace.active.toml, ash-extension-pack — none of which this lane modified.)

## Regeneration check (not run — coordinator owns the transition)

`ggen sync` was **not** run into xaas. Verified the rationale literal is the template's interpolation source instead:

- `packs/xaas-castle-bridge-pack/templates/castle-errc.md.tmpl` line 7 SPARQL selects `?rationale` from `xcb:ERRCDecision` rows in the ontology; line 18 renders `{{ row["rationale"] }}` directly into the page table. The ontology literal IS the interpolation source — no template-local copy of the counts exists.

Regeneration command for the coordinator (run from `/Users/sac/xaas`):

```bash
ggen sync
```

(`ggen.toml` in xaas binds the xaas-castle-bridge-pack; after sync, the ERRC page projection must read "117 Ash resources via the Xaas.Resource wrapper (152 total use Ash.Resource) and 19 domains".)

## Verification results (executed)

1. rdflib parse of edited ontology — clean: 332 triples parsed, exit 0.
2. `ERRCDecision` row count unchanged: **12** (rdflib count of subjects typed `xcb:ERRCDecision`).
3. Diff scope: single-line change, single file (shown above).

## Open transition (coordinator-owned)

- [ ] `ggen sync` in `/Users/sac/xaas` to regenerate the projected ERRC page from the corrected ontology.
- [ ] Commit the pack ontology change in ggen-marketplace (lane leaves it uncommitted per contract).
