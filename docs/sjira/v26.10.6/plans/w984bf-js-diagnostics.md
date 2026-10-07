# W984bf — JS/TS Editor Diagnostics Lane (NO-OP)

Date: 2026-10-07 · Repo: /Users/sac/xaas · Branch: feat/playwright-surface

## Provenance

Editor diagnostics reported two TS/JSDoc issues in `e2e/graphql-http.spec.cjs`.

## Verification (real commands)

- `ls e2e/graphql-http.spec.cjs` → `No such file or directory`. The file was
  deleted by lane W984ap (graphql removal). The two diagnostics point at a
  nonexistent subject → **stale**.
- Swept the remaining 25 `e2e/*.spec.cjs` + `e2e/*.ts` files for the same
  diagnostic class (`@param` name mismatch, implicit-any param):
  - `grep -n "@param" *.spec.cjs *.ts` — every annotation checked against its
    function signature:
    - a2a-v1.spec.cjs `rpc(id, method, params)` ↔ `@param {any} id / {string} method / {any} params` — match.
    - execution-fabric/internal-api/sparql-proxy/zcode-cli-fabric `authHeaders(token)` ↔ `@param {string} token` — match.
    - stripe-webhook.spec.cjs `stripeSignatureHeader(payload, secret, timestamp)` ↔ `@param {string} payload / {string} secret / {number} [timestamp]` — match.
    - chicago-pplan-deep / next-read-ml `@param {import("@playwright/test").Page} page` — match.
  - No `@param` named `query` anywhere in e2e; no name-mismatch or untyped-param
    diagnostics found in any surviving e2e file.
- `/Users/sac/xaas/tsconfig.json` `"include": ["test/**/*.ts", "e2e/**/*.ts"]`
  — `.ts` e2e files ARE type-configured; `.cjs` specs are not covered by
  checkJs (no `checkJs` flag), so `.cjs` diagnostics are editor-local only.

## Disposition

**NO-OP — stale diagnostics.** Subject file deleted upstream (W984ap); no
surviving e2e file carries the reported pattern. Zero code/config changes made.

## Standing

UNKNOWN→observed-resolved: the two diagnostics are dead references, not open
defects. Reopen only if an editor re-emits these diagnostics against a live
path. No falsifier pending; no follow-up work order.
