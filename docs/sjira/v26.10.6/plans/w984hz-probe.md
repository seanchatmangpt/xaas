# W984hz — truth-pass: docs/claude/diataxis/explanation/ontology-reactor-control-plane.md

Date: 2026-10-07. Lane W984hz, shared canonical checkout `/Users/sac/xaas`, branch
`feat/playwright-surface`. Docs-only: no commit, no build root, no branch switch, no stash.
Sibling-modified doc: read disk state (50 lines pre-edit), appended the verified block only,
no sibling edits reverted.

## Command-verified claims (all run this session)

1. `wc -l docs/claude/diataxis/explanation/ontology-reactor-control-plane.md` → 50 (pre-edit);
   post-edit carries a dated `## Verified 2026-10-07 (W984hz truth-pass)` block (W984gz/hv
   convention).
2. `grep -rn "defmodule Xaas.Actuation.Receipt" lib/` → **no matches**. The ledger resources
   are `Xaas.Operations.ActuationIntent` / `Xaas.Operations.ActuationReceipt`
   (`alias` at `lib/xaas/actuation.ex:23`). The doc's prose never named the wrong module,
   but the task brief's `Xaas.Actuation.Receipt` reference is corrected forward in the
   verified block.
3. `Xaas.Actuation.run/4` (`lib/xaas/actuation.ex:26`): atoms for resource/action, map input,
   required nonempty binary `:idempotency_key` (else `{:error, :idempotency_key_required}`,
   `inputs/4` at `actuation.ex:161`); `:authority` default `%{}`; whole DO inside
   `Ash.DataLayer.transaction/4` with `Reactor.run(Xaas.Actuation.Reactor, ..., async?: false)`
   inside (`run_reactor_or_rollback/2`, `actuation.ex:193-210`) — reactor error/halt rolls
   back intent+receipt+mutation together. Doc claim "synchronous Ash.Reactor DO inside the
   data-layer transaction" confirmed.
4. **SpgGate** (`lib/xaas/actuation/spg_gate.ex`): requires nonempty
   `[:graph_id, :graph_version, :node_id, :edge_id]` + `state` `:admitted`/`"ADMITTED"`;
   fail-closed. `git log --oneline -1 f0321df2` → "test(actuation): W650h22 — land W984dq6
   SpgGate integration (F2 guard + single-funnel seam + courts)". Single caller
   `admit_spg/1` (`actuation.ex:642`), called in `do_admit/2` at `actuation.ex:345` AFTER
   `admit_authority/2`; opt-in atom `:spg` key, absent = no-op, string `"spg"` ignored.
   Refusal surfaces bare as `{:spg_gate_refused, reason}` via `unwrap_reactor_error/1`
   (`actuation.ex:245-258`). Cited `w650h22-commit.md` in the doc block.
5. **Reactor steps** (`actuation.ex:263-320`): `:admit` → `:do` (with `undo:` =
   `Kernel.undo_actuate/3`, OCEL cancellation on later-step failure) → `:receipt`
   (`Kernel.seal/2`); replay short-circuits with no new DO. Matches the doc's
   projection→admission→intent→DO→receipt→replay pipeline.
6. **Receipt writing**: `Kernel.seal/2` updates `ActuationReceipt` (action `:seal`;
   `:succeeded`/`:failed`/`:refused`, result snapshot + hash + `completed_at`) and
   transitions the intent. Typed `Xaas.Actuation.Refusal` → `:refused`; W773 normalization
   to the W707 `%{"class","detail"}` map idiom. Both intent and receipt carry
   `ontology_projection_hash` — confirms the doc's "receipts bind the ontology projection"
   section.
7. **Authority ceiling**: `Xaas.Actuation.Validations.ReactorContext`
   (`lib/xaas/actuation/validations/reactor_context.ex`) rejects consequential actions
   lacking the `:xaas_actuation` changeset context (`intent_id`, `receipt_id`, projection
   hash equal to the resource's `ontology_projection_hash/0`); `authorize?: false` alone
   never suffices. W780: struct-shaped authority refused `:claim_shaped_authority_refused`.
   `Xaas.Semantics.Registry` appears only as admitted metadata in `do_admit/2` — **no code
   path grants authority from public projection**. Doc's central claim holds.
8. **Quiescent stop** (`lib/xaas/actuation/quiescent_stop.ex`): routes through
   `Xaas.Actuation.run/4` → `:actuate_status` on `Xaas.Marketplace.Provider`
   (`lib/xaas/marketplace/provider.ex:79`) guarded by the same `ReactorContext`
   validation; no side channel.
9. Convention + prior passes: `grep -rn "Verified 2026-10-07" docs/claude/diataxis/`
   found the W984gz (`fix-ash-admin-and-use-ggen-for-codegen.md`) and W984hv
   (`ash-typescript-adoption.md`) blocks; `docs/sjira/v26.10.6/plans/w984eg-probe.md`
   (reference-doc truth-pass, same date) cited in the doc block.

## Edit (before → after excerpt)

Before (doc ended at line 50):

> The repository's Chicago-style actuation test uses real Ash resources, real Reactor, and
> sandboxed Postgres to falsify direct bypass, receipt omission, replay duplication, and
> idempotency conflicts. These executable falsifiers outrank prose descriptions of intended
> architecture.

After: same text, then appended:

> ## Verified 2026-10-07 (W984hz truth-pass)
>
> Checked against the working tree at `feat/playwright-surface` (docs-only lane; no code
> changes). Corrections and confirmations, all read from source this session: ... (receipt
> resource naming correction to `Xaas.Operations.ActuationReceipt`; run/4 contract;
> SpgGate seam per f0321df2 / w650h22-commit.md; reactor step structure incl. undo/OCEL
> cancellation; receipt sealing statuses + projection-hash binding; ReactorContext
> authority ceiling + W780 claim-shaped refusal; quiescent-stop pattern; pointer to
> w984eg-probe.md for the reference-doc pass).

No substantive pre-existing claim in the doc required retraction; one naming precision
(corrections block item 1) and one forward-dating pass were added. Append-only; zero
sibling edits reverted.

## Standing

Docs-only ALIVE: claims verified by real grep/read of the working tree at HEAD 82f7f558
(dirty tree, feat/playwright-surface). No build root created; no commit made; falsifier
(the doc contradicting live code) did not fire beyond the naming precision above.
