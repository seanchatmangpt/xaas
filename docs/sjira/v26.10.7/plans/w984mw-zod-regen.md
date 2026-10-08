# W984mw — ash_surface zod regen landing (no commit)

Lane: W984mw · Date: 2026-10-08 · Subject: xaas `feat/playwright-surface` @
`567ab1f5` (HEAD unchanged; no commit, no branch op, no stash). Fixes the
stale-regen finding from w984n (disclosed in w984mu addendum #17): the
committed projection at `priv/ash_surface/` was byte-stale — SPEC-07
`org_id` missing from 4 zod create schemas, plus the since-landed
`Xaas.Ocel.Event#destroy` removal still present.

## Correction to the task framing

The generator and the stale artifacts are both in **/Users/sac/xaas**, not
the ash_surface repo: `mix xaas.ash_surface` (lib/mix/tasks/xaas.ash_surface.ex)
projects `priv/ash_surface/`. The ash_surface repo at `/Users/sac/ash_surface`
(HEAD `154385c8`) owns the projector implementation; its tree was not
modified.

## 1. Orient (real output)

- `git rev-parse HEAD` → `567ab1f509cf2fa38e4e8d105748b5b38bb2bde4`.
- Spec source contains org_id: `lib/xaas/billing/approval_invoice_reconciliation_approve.ex`
  lines 89 (`attribute(:org_id)`) and 102 (`accept([:requested_by, :org_id])`);
  same pattern in the other three approval resources. Schemas were stale, not
  the spec.
- W984n's "uncommitted" Ocel destroy removal has since **landed**:
  `lib/xaas/ocel/event.ex` no longer has a `:destroy` default (W983e
  append-only fix, landed via `12d5f6d3` lineage; `git diff` on the file is
  empty at this HEAD). So the fresh regen legitimately drops
  `Xaas.Ocel.Event#destroy` — 418 → 417 entrypoints, closing w984n's open
  falsifier #2.

## 2. Regen (real command + output tail)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  mix xaas.ash_surface --target-dir /tmp/w984mw-ashsurface-out
```

EXIT=0. Tail:

```
ash_surface generation complete
  entrypoints:     417
  surface digest:  4dfdb31ca66bf29d4f419ed57cdfbbfc3c618acba13239830055e438b3e68dc7
  js artifact:     /tmp/w984mw-ashsurface-out/xaas_ash_surface_client.mjs (417 actions, 114 namespaces)
```

Committed projection was: 418 entrypoints, digest `811707ef…` (w984n's
`68a5c9f9` projection). Landed the fresh output (`cp` of the 5 artifacts)
into `priv/ash_surface/`.

## 3. org_id verification (read from the landed files)

All 4 create schemas now carry `org_id` in
`priv/ash_surface/xaas_ash_surface_client.mjs` (python regex over each
`*_create_schema = …;` body; committed file verified False before landing):

- `XaasApprovalInvoiceReconciliationApprove_create_schema` — org_id True
- `XaasApprovalPricingOverride_create_schema` — org_id True
- `XaasApprovalQuotaOverride_create_schema` — org_id True
- `XaasApprovalTierDowngrade_create_schema` — org_id True

Note: `InvoiceReconciliationApprove_create` shows org_id **replacing**
`approved_by` — correct against the live resource: its create `accept` is
`[:requested_by, :org_id]`; `approved_by` is approve-path only.

## 4. Full diff disclosure (git diff --stat, landed worktree only)

```
 priv/ash_surface/aria.json                   |  2 +-
 priv/ash_surface/ash_surface_runtime.mjs     |  8 ++++----
 priv/ash_surface/ash_surface_runtime.mjs     | version strings 26.10.6→26.10.7
 priv/ash_surface/live_view.json              |  2 +-
 priv/ash_surface/surface_contract.json       |  2 +-
 priv/ash_surface/xaas_ash_surface_client.mjs | 30 ++++++----------------------
```

Per-cause decomposition:

1. `xaas_ash_surface_client.mjs`: +4 org_id lines (the w984n prediction);
   −`XaasOcelEvent_destroy_schema` + namespace/typedef/entry removal for
   `Xaas.Ocel.Event#destroy` (landed W983e fix); digest line updates.
2. `ash_surface_runtime.mjs`: only `SURFACE_RUNTIME_VERSION` and comment
   CalVer strings 26.10.6→26.10.7 (8 lines).
3. The three JSON artifacts: digest/version string lines only.

No diffs beyond these classes.

## 5. Verification ladder (real output)

- **Drift/generator courts** (`MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984mw`,
  asdf shim PATH):
  `mix test test/xaas/ash_surface_drift_mutation_test.exs test/xaas/ash_surface_drift_guard_test.exs test/xaas/ash_surface_generator_test.exs`
  → **Result: 3 passed** (trace-verified exactly 3 tests: drift-guard
  "committed priv/ash_surface artifacts are byte-identical to regeneration"
  GREEN against the landed regen; mutation-tamper detection; generator
  node-clean check).
- **Node suite** (ash_surface repo, read-only): `node --test test/js/` →
  **tests 371 / pass 371 / fail 0** (matches the w981r 371/371 floor).
- No node tests in xaas itself consume the client (`grep -rln` over `test/`
  for `xaas_ash_surface_client|ash_surface_runtime` → empty), so the ash_surface
  node suite is the governing JS surface.

## 6. Standing

**ALIVE (regen-landing witness)** — the exact falsifier w984n named as the
gap ("nothing was written to priv/ash_surface") is now executed: regen ran
exit 0, landed, and the drift-guard court certifies byte-identity between
the committed projection and fresh regeneration at this subject.

## Falsifiers (open for the coordinator)

- A later lane edits an approval resource or adds an Ash action before
  commit — re-run regen before the batch commit.
- Playwright suite (w981r pattern) at the post-regen subject.

## Cleanup

- `/tmp/w984mw-ashsurface-out` — **DENIED** (`rm -rf` permission denial,
  same class as w984mi's disclosed denial); lease remains, ~3.9 MB, /tmp.
- `/Users/sac/xaas/_build-laneW984mw` — **DENIED** (same `rm -rf` denial);
  lane build-root lease remains on disk.

## Replay

```
cd /Users/sac/xaas
git diff --stat -- priv/ash_surface/
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  mix xaas.ash_surface --target-dir /tmp/replay-w984mw
diff priv/ash_surface/xaas_ash_surface_client.mjs /tmp/replay-w984mw/xaas_ash_surface_client.mjs   # empty
cd /Users/sac/ash_surface && node --test test/js/
```
