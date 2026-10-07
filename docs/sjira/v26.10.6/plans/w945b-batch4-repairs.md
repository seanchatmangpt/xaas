# W945b — Batch 4 CHEAP-REPAIR (receipt)

- **Lane**: W945b, v26.10.6 campaign (batch 4 of W891's CHEAP-REPAIR triage)
- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` (canonical checkout, no worktree); no commit (lane contract — coordinator owns commits).
- **Build**: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW945b`, asdf toolchain (`PATH=$HOME/.asdf/shims:$PATH`).
- **Standing**: PARTIAL_ALIVE — 2 rows closed (1 code repair + 1 verify-first witness), suites green ×2, mutation-killed where new code exists; all other triage CHEAP rows found already closed or in-flight-owned by named lanes (selection audit below is the load-bearing part of this receipt).

## Row selection audit (W891 triage CHEAP-REPAIR set, re-derived from receipts on disk 2026-10-07)

Of the 15 CHEAP-REPAIR rows, at lane start only rows **2, 12, 28, 35** were neither
REPAIRED in the register nor closed by a landed receipt:

- **Row 12 (W745 rescue-arm)** — owned IN-FLIGHT by lane **W945c** (test-side court
  already staged in `test/xaas_web/execution_fabric_deepening_test.exs`, header
  "(f) W945c"). Not touched by this lane.
- **Row 2 (W674-GAP-1)** — found **already closed verify-first**: W674's staged lib
  fix + W928's hygiene landed; `docs/sjira/v26.10.6/plans/w928-gymact-hygiene.md`
  on disk with 11/11 ×2 (run A + run B). Register row 2/3 flip is a sweep-lane
  action, not mine.
- Remaining clean picks: rows **28** and **35**. A third code row does not exist
  without colliding with W945c / the W897-owned billing approval surface — batch
  size is 2, disclosed rather than padded.

## Row 28 — W799 UNSUPPORTED(credit-path-unfundable): REPAIRED (verify-first)

- **Surface**: `lib/xaas/billing/changes/approval_sla_credit_apply_approve.ex:119`
  (and the `approval_patch_` twin, same line): the `:transfer` create now carries
  `context: %{xaas_ledger: %{allow_overdraft: true}}` — the W785/W799-named
  sufficiency-exemption opt-in, landed in-tree (moduledoc cites W835).
- **Falsifier closed**: w799's pre-existing RED 3/5 in
  `test/xaas/billing/approval_sla_credit_apply_test.exs`.
- **Real runs** (this lane, fresh `_build-laneW945b`): **5 passed, exit 0** ×2.
- **Mutation rationale**: no new code this lane (verify-first) — the mutation
  evidence for the guard class lives in W785's `TransferSourceSufficiency`
  validation court; this lane witnesses the register row's falsifier is green.
- No code edited. Register flip OPEN → REPAIRED recommended (disclosing w799,
  status witness this receipt).

## Row 35 — W849 backlog-3 (McpScope moduledoc provenance form): REPAIRED (code)

- **Before**: `lib/xaas_web/mcp_scope.ex` regen command used absolute
  `/Users/sac/xaas/...` host-bound paths (w849: "TTL source outside priv/packs/
  conventions; consider normalizing to the pack-dir regen-command form").
- **Repair**: moduledoc regen command normalized to **repo-relative** form — the
  same convention the other PROVENANCE-ONLY surfaces pin
  (`ocel_envelope.ex`, `capital_census/facts.ex`, `xaas.library.manufacture`).
  Honesty boundary: the sources stay canonically at `priv/ggen_igniter/mcp_a2a/`;
  a literal `priv/packs/xaas_mcp_surface_pack/` migration would COPY the ontology
  (second source, drift fork) and is deliberately NOT done — that half of
  backlog-3 is design-class, disclosed here. The registry guard's provenance
  annotation for this surface was updated to match (no longer "not in pack-dir
  form — see W849 backlog item 3").
- **Pin update (designed flow)**: `mcp_scope.ex` is sha-pinned in
  `test/xaas/generated/registry_drift_guard_test.exs`; new pin
  `8713a4bc8486a9459d94d1779aa338f79f4071cb7155114b8fce6747e20d6c52`.
- **Court**: `mix test test/xaas/generated/registry_drift_guard_test.exs` →
  **1 passed ×2** (green ×2).
- **Mutation rationale + evidence**: corrupting the pin (`sed` →
  `deadbeef…`) → **guard FAILED** (hand-edit detection still load-bearing after
  the annotation edit); restored byte-identical, on-disk sha256 of
  `mcp_scope.ex` re-hashes to the pinned value, `git diff` shows exactly the 2
  intended line changes. The mutation proves the pin row was not vacuously
  updated.

## Files touched by this lane

- `lib/xaas_web/mcp_scope.ex` (moduledoc regen command, repo-relative)
- `test/xaas/generated/registry_drift_guard_test.exs` (provenance annotation + sha pin for mcp_scope.ex)

## Verification ladder (real outputs)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW945b \
  mix test test/xaas/billing/approval_sla_credit_apply_test.exs     # 5 passed, exit 0 (run 1)
  # → same command, run 2: 5 passed
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW945b \
  mix test test/xaas/generated/registry_drift_guard_test.exs        # 1 passed (run 1)
  # → run 2: 1 passed
$ # mutation: sed pin → deadbeef…; mix test registry_drift_guard     # Failed: 1 test (killed)
$ # restore: sed back; shasum -a 256 lib/xaas_web/mcp_scope.ex      # 8713a4bc… (matches pin)
```

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW945b \
  mix test test/xaas/billing/approval_sla_credit_apply_test.exs test/xaas/generated/registry_drift_guard_test.exs
```

## Handoff to coordinator / sweep lanes

- Recommended register flips (w859-typed-gap-register.md), dual-cited:
  - Row W799 credit-path-unfundable OPEN → REPAIRED (disclosing w799; witness this receipt, verify-first, 5/5 ×2).
  - Row W849 backlog-3 OPEN → REPAIRED (disclosing w849; repair this receipt, mutation-killed pin court).
  - Rows W674-GAP-1 / W674-GAP-2 OPEN → REPAIRED (witnessed by w928-gymact-hygiene.md 11/11 ×2 + w902's staged-lib verification — sweep lanes, not this lane).
- Row 12 (W745) stays with W945c (in-flight, staged test visible on tree).
- Register totals NOT edited by this lane (sweep-lane owns w859).

## Cleanup

`_build-laneW945b` deleted at lane end per lane contract.
