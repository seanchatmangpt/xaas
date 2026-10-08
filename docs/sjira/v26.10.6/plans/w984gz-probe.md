# W984gz — truth-pass: fix-ash-admin-and-use-ggen-for-codegen.md

Lane: W984gz, checkout /Users/sac/xaas (canonical), branch feat/playwright-surface.
Scope: docs-only truth-pass of
`docs/claude/diataxis/how-to/fix-ash-admin-and-use-ggen-for-codegen.md`.
Sibling-modified file (it appears in `git status` modified list): disk state read
first; edits are append-only (one verification blockquote); no sibling edits
reverted. No commit, no build root.

## Before (excerpt, status block at head of file)

> Status at v26.10.6 (branch `feat/playwright-surface`, HEAD `a0723bf6`): verified
> claim-by-claim against the tree by lane W841; see
> `docs/sjira/v26.10.6/plans/w841-ashadmin-howto-verify.md`.

## After (appended immediately below it)

> **Verified 2026-10-07** (lane W984gz, re-check of the W841 pass): all actionable
> claims below re-verified against the current tree — 19 domains in
> `config :xaas, ash_domains` (`config/config.exs`), 17 carry `AshAdmin.Domain` +
> `admin do show?(true) end` (exceptions still `Xaas.Generation`,
> `Xaas.TemporalMemory`); `accounts.ex` excerpt matches disk; `/admin` mount at
> `lib/xaas_web/router.ex:364-373` (dev-only); `ggen.toml` still binds
> `ontology.ttl` + `templates-hooks` + locked pack `xaas_castle_bridge`; 55
> `xar:RenderTarget` individuals; `.ash-gen-receipts/` populated (88 files). No
> "generate admin/graphql" steps exist in this guide to correct — GraphQL was
> excised this campaign (91 lib files, W984ao; residue sweep receipt
> `docs/sjira/v26.10.6/plans/w984et-probe.md`; `mix.lock` unlocked of
> `ash_graphql`/`absinthe*`); the sole live exception is
> `lib/xaas/semantics/vkg.ex:66-67` `graphql/2` via the `ash_r2rml` consumer,
> which is not the AshGraphql surface this guide never referenced. The guide's
> JSON:API (`AshJsonApi.Domain`, `/internal-api`) assertions remain live. No
> SpgGate/actuation-path or ggen_igniter `ash-manufacture-pack` claims appear in
> this guide; nothing to correct on those axes.

## Code-verified claims (commands + observed output)

- `sed -n '13,40p' config/config.exs` → `ash_domains` list has 19 entries
  (Xaas.Library … Xaas.Witness), lines 13-33. Matches doc's "19 domains".
- `grep -l 'AshAdmin.Domain' lib/xaas/*.ex` → 17 files (a2a, library, operations,
  billing, conference, coupling, accounts, governance, igniter, graphlaw, ledger,
  marketplace, ocel, platform, security, ultracode, witness). Generation and
  TemporalMemory absent — matches doc.
- `grep -rl 'admin do' lib/xaas/*.ex` → 17 files (same set).
- `sed -n '1,16p' lib/xaas/accounts.ex` → byte-matches the doc's code excerpt
  (extensions list, `admin do show?(true) end`, `typescript_rpc` block, resources).
- `grep -n 'ash_admin\|AshAdmin' lib/xaas_web/router.ex` → lines 364-373:
  comment "real AshAdmin.Router mount, dev-only", `import AshAdmin.Router`,
  `ash_admin("/")`. Matches doc.
- `grep -n 'source\|dir\|pack' ggen.toml` → `source = "ontology.ttl"` (line 17),
  `[packs.xaas_castle_bridge]` (line 19), `dir = "templates-hooks"` (line 25).
  Matches doc.
- `grep -c 'xar:RenderTarget' ontology.ttl` → 55. Matches doc.
- `ls .ash-gen-receipts | wc -l` → 88 (doc says "populated from prior syncs" — true).
- `grep -n 'graphql\|admin' templates-hooks/ash-gen-resource.txt.tmpl` → no hits.
  Template drives `mix ash.gen.resource` only; no GraphQL step to correct.
- `grep -n 'graphql\|admin'` over the guide body (read in full): the only
  GraphQL-adjacent text is the accurate `AshJsonApi.Domain` extension in the
  accounts.ex excerpt and the `/internal-api` JSON:API assertion — both live
  surfaces, both distinct from the excised AshGraphql.

## Cross-references

- Removal receipt trail: `docs/sjira/v26.10.6/plans/w984et-probe.md` (non-lib
  residue sweep; mix.lock unlock; vkg.ex graphql/2 = AshR2RML, kept). Cited in
  the appended note.
- ggen_igniter `ash-manufacture-pack` profile: bound in ggen_igniter per repo
  CLAUDE.md; this guide makes no claim on that path, so no correction needed
  (recorded explicitly so the absence is a verified absence, not an unexamined one).
- SpgGate/actuation path references: none present in the guide (verified absence).

## Standing

ALIVE for the docs-only truth-pass: every actionable claim in the guide is
code-verified current; zero stale assertions found requiring in-place correction;
one dated verification note appended; sibling edits untouched. No commit, no
build root.
