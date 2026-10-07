# W221 — Targeted test receipt: conference + a2a (W115 touched resources)

- Repo/checkout: /Users/sac/xaas, branch `feat/playwright-surface`
- Date: 2026-10-06
- Command (real, run under pinned asdf toolchain):

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/conference test/xaas/a2a
```

## Verbatim counts

```
.........
Finished in 0.7 seconds (0.00s async, 0.7s sync)

Result: 9 passed
```

- 9 passed, 0 failures, 0 errors, 0 skipped, 0 excluded
- Test files covered: `test/xaas/conference/conference_test.exs`, `test/xaas/a2a/catalog_test.exs`
- Duration 0.7s (0.00s async, 0.7s sync)

## Failure classification

None. Zero failures.

## Warnings observed (pre-existing, not introduced by this lane; not test failures)

- Compile warnings: `@envelope_domain_tag` set but never used (`test/xaas/a2a/catalog_test.exs:11`);
  repeated `redefining module AshR2RML.*` (stale dual-loaded beams in `_build/test` from ash_r2rml).
- Runtime log warnings: `AshA2A legacy_compat profile` (outbox_key_missing, outbox_dir_not_durable,
  receipt_store_in_memory, capability_release_mode_legacy, authority_broker_missing) — expected
  dev/test config profile, informational.

## Standing

ALIVE for the targeted surface: W115's touched conference/a2a resources pass under the
pre_check_with changes. No fixes made, no git operations.

## W250 post-parse-floor

Date: 2026-10-06. Lane W250, v26.10.6 convergence. Subject: d1db2b03179975213c14663b9dbd86b5ac2a14cf
(feat/playwright-surface).

Re-verify of W150's a2a parse floor (endpoint.ex, before Plug.Parsers) against W221's a2a tests,
which postdate it. Command:

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/a2a test/xaas_web/a2a
```

- Exit 0. Result: **28 passed**, 0 failures, 0 errors (0.00s async, 3.6s sync).
- Confirmed via `--trace`: `4b. malformed application/json body also answers -32700
  (W150 parse floor)` [test/xaas_web/a2a/v1_protocol_test.exs:172] passed (0.5ms),
  plus `4. malformed JSON body returns typed -32700 parse error` [:151] and
  Xaas.A2a.CatalogTest in full.
- Transient note: single-test and one trace run hit `ERROR 42701 (duplicate_column)
  spg_graph_id on actuation_intents` while concurrent lane beam instances held the
  `_build/test` lock and raced shared-DB migrations; clean re-run passed. Pre-existing
  concurrency artifact, not introduced by this lane.

No fixes, no git operations. Standing: ALIVE for the a2a parse floor + v1_protocol/catalog
courts on d1db2b03.

## W275 conference post-format

Post-format conference receipt: registration.ex formatted in W237, checked against
W115's pre_check_with contract. Command:

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/conference 2>&1 | tail -4
```

- Exit 0. Real output tail: `Result: 3 passed` (0.3s, 0.00s async / 0.3s sync;
  seed 744872). Followed only by benign os_mon memsup/cpu_sup shutdown notices.
- Ambient noise unrelated to the suite: PromEx.DashboardUploader Grafana
  nxdomain warnings (no local Grafana), pre-existing.
- Target green confirmed: 0 failures, 0 errors.

No fixes, no git operations. Standing: ALIVE for the conference courts on d1db2b03.
2026-10-06T21:39Z
