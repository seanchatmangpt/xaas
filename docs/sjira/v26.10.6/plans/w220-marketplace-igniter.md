# W220 — Targeted test receipt: marketplace + igniter

Repo: `/Users/sac/xaas`, branch `feat/playwright-surface` (working tree, no new commits).
Scope: W115-touched marketplace/igniter resources. Verification only — no fixes, no git.

## Command

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/marketplace test/xaas/igniter
```

## Counts (verbatim, real output)

Combined run (both dirs):

```
Finished in 71.9 seconds (0.5s async, 71.4s sync)
Result: 33 passed, 3 excluded
```

Per directory:

- `test/xaas/marketplace`:
  ```
  Result: 23 passed, 3 excluded
  ```
- `test/xaas/igniter`:
  ```
  Result: 10 passed
  ```

23 + 10 = 33; consistent with the combined run.

## Failures

Zero failures, zero errors. Nothing to classify.

## Notes

- One compiler warning observed (not a failure): unused `require Ash.Query` at
  `test/xaas/igniter/igniter_catalog_test.exs:9:3`.
- Each run exits with normal `[os_mon]` supervisor shutdown lines; pre-existing,
  unrelated to results.
- Toolchain: asdf shims prepended to PATH per repo memory (avoids Homebrew elixir
  1.19.5 shadowing); MIX_ENV=test.
