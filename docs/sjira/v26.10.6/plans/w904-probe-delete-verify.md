# W904 — Probe Delete Verification (test/xaas/w838_probe_test.exs)

- **Verdict: DELETE-CONFIRMED**
- Date: 2026-10-07 · Lane: W904 (v26.10.6) · Adjudication source: W898 residue backfill item 3 (`docs/sjira/v26.10.6/plans/w898-residue-backfill.md`)
- Subject: `test/xaas/w838_probe_test.exs` (`Xaas.W838ProbeTest`)
- No deletion executed by this lane; coordinator owns deletion.

## (a) Probe asserts nothing SUT-relevant; fully shadowed

Read of `test/xaas/w838_probe_test.exs` (69 lines): the single test
"replicate court curation test then dump everything" creates a Book and a
Curation, subscribes relays on `recommendations:grade:6-8` and
`recommendations:curation_events`, then `dump/0` writes every received
message to stdout via `IO.puts` with an `after 3_000 -> IO.puts("DUMP_DONE")`
timeout. **Zero assertions on received PubSub content** — the only `assert`
is `assert_receive {:w838_ready, ...}` on its own relay handshake (test
infrastructure, not SUT). It cannot fail on SUT regressions, so it carries no
regression value. Classification: assertion-less debug dump, confirmed by
direct read.

**Shadowing court run (executed, real output):**

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  mix test test/xaas/library/pubsub_publish_court_test.exs
.........
Finished in 1.2 seconds (0.00s async, 1.2s sync)
Result: 9 passed
```

The court (`test/xaas/library/pubsub_publish_court_test.exs`, 11 `test` blocks
in 9 passing — 9 tests, 9 passed) asserts the exact behaviors the probe merely
prints: Curation create → `recommendations:grade:<grade_band>` carries the
Curation payload (`data.id == curation.id`), Curation update reflects the new
reason, curation events land on `recommendations:curation_events`, plus
checkout/return/notification courts. Every channel the probe dumps is
assertion-covered by the court. Fully shadowed: confirmed.

## (b) No other file references it

```
grep -rn "w838_probe\|W838Probe" across /Users/sac/xaas
→ code hits: only the file itself (line 1, defmodule)
→ non-code hits (docs receipts only, not load-bearing): 
  docs/sjira/v26.10.6/_COMMIT_MANIFEST_W850.md
  docs/sjira/b26.10.6/plans/w898-resource-backfill.md  [sic: w898-residue-backfill.md]
  docs/sjira/v26.10.6/plans/w885b-court-census.md
```

No lib/config/other-test references. Zero code dependents.

## (c) Verdict for coordinator

**DELETE-CONFIRMED** for `test/xaas/w838_probe_test.exs`. Deletion is
coverage-preserving (court green: 9/9) and reference-free in code. This lane
executed no deletion; coordinator may delete in the integration pass.
