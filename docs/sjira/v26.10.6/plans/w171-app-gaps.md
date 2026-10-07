# W171 — app gaps (zcode-cli fabric surface)

## Post-W171 standalone re-run — integration lane W269 (v26.10.6 convergence), 2026-10-06

Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, post-W171
(W171 added 6 adversarial courts + typed -32603 fail-close in
`e2e/zcode-cli-fabric.spec.cjs`).

Command (real output, tail -8):

```
lsof -ti :4000 | xargs kill -9   # stale beams cleared, authorized
PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token \
  npx playwright test e2e/zcode-cli-fabric.spec.cjs
```

```
  ✓  1 e2e/zcode-cli-fabric.spec.cjs:77:3 › /internal-api/execution/mcp token gate › refuses /execution/mcp without a token (fail-closed, typed body) (1.2s)
  ✓  2 e2e/zcode-cli-fabric.spec.cjs:101:3 › /internal-api/execution/mcp token gate › refuses /execution/mcp with an invalid token (401, typed body) (1.2s)
  ✓  3 e2e/zcode-cli-fabric.spec.cjs:131:3 › /internal-api/execution/mcp token gate › adversarial malformed bodies are typed JSON, never HTML (fail-closed) (7.8s)
  ✓  4 e2e/zcode-cli-fabric.spec.cjs:172:3 › /internal-api/execution/mcp surface (with token) › initializes and lists the real lease/fabric tool set (1.8s)
  ✓  5 e2e/zcode-cli-fabric.spec.cjs:204:3 › /internal-api/execution/mcp surface (with token) › unknown tool is a typed JSON-RPC tool error, never a silent success (583ms)
  ✓  6 e2e/zcode-cli-fabric.spec.cjs:224:3 › /internal-api/execution/mcp surface (with token) › claim -> admit -> close -> sealed receipt read-back (or honest typed refusal) (12.3s)

  6 passed (42.6s)
```

Standing: ALIVE — 6/6 passed on the post-W171 spec, no fixes applied.
