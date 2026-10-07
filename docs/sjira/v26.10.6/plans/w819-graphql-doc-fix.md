# W819 — ash-configuration.md GraphQL overclaim fix

- **Lane**: W819, v26.10.6 campaign, repo `/Users/sac/xaas`
  (branch `feat/playwright-surface`, HEAD `a0723bf6`).
- **Input**: W802 receipt
  `docs/sjira/v26.10.6/plans/w802-graphql-surface.md` —
  `UNSUPPORTED(graphql-http-surface)`; `Xaas.GraphqlSchema` compiles with 3
  domains wired (`Xaas.Operations`, `Xaas.Library`, `Xaas.Marketplace`), no
  `Absinthe.Plug` forward anywhere in `lib/xaas_web/` or `config/`.

## Changes (docs/claude/diataxis/reference/ash-configuration.md only)

1. **New subsection "GraphQL surface status"** inserted directly after the
   19-domain extensions table (after the `Xaas.Witness` row): states the
   schema compiles, is not mounted over HTTP at v26.10.6, only 3 of 19
   domains are wired (Operations, Library, Marketplace), extension presence
   ≠ HTTP exposure, standing `UNSUPPORTED(graphql-http-surface)`, citing the
   W802 receipt and HEAD `a0723bf6`.
2. **Table-intro clarification** (end of the paragraph re-verifying at
   `a0723bf6`): added two sentences stating the Extensions column records
   code wiring only, not proof the protocol is served over HTTP, with an
   anchor link to the new subsection.

Per-change citations:

- "compiles, not mounted" — W802 receipt, evidence table
  (`grep -i "graphql|gql" lib/xaas_web/router.ex` → 0 hits;
  `GraphqlSchema|Absinthe.Plug` → definition only;
  `config/*.exs` → 1 hit, `config/config.exs:169`, runtime config not a
  route).
- "3 domains wired, not most" — W802 receipt: `use AshGraphql, domains:
  [Xaas.Operations, Xaas.Library, Xaas.Marketplace]`
  (`lib/xaas/graphql_schema.ex`); GAP(graphql-domain-coverage).
- Standing `UNSUPPORTED(graphql-http-surface)` — W802 receipt conclusion.

No other sections touched; no lib/config/test files modified.

## Verification

- Pre-edit greps: `grep -n -i graphql` on the doc listed `AshGraphql.Domain`
  only in table rows 67-84 (extension facts — kept verbatim); router grep in
  W802 receipt independently confirmed no mount.
- Post-edit: file re-read confirmed both edits landed; extension table rows
  unchanged.

## Standing

ALIVE (doc-only, factual correction on the exact subject HEAD `a0723bf6`;
falsifier was W802's own grep evidence, reproduced pre-edit). Not committed
per lane instructions — coordinator owns integration commit.
