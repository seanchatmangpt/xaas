# W761 — How-to Verify Receipt (provider lifecycle docs)

- **Lane**: W761, v26.10.6 campaign, repo /Users/sac/xaas, branch feat/playwright-surface, HEAD a0723bf6.
- **Scope**: verify `docs/claude/diataxis/tutorials/receipted-provider-lifecycle.md` and
  `docs/claude/diataxis/how-to/actuate-provider-lifecycle.md` against current code.
  Read-only verification + in-place doc corrections; no actuation run; no build root; no commit.
- **Standing**: PARTIAL_ALIVE (documentation verified by source read; falsifier test file not executed this lane — see Falsifier).

## Per-step verification

### Tutorial: receipted-provider-lifecycle.md

| Step | Claim | Verdict | Evidence |
|---|---|---|---|
| 2 | `Xaas.Marketplace.Provider` `:create` accepts `:name, :slug, :description, :org_id`; enters at `:pending` | VERIFIED | `lib/xaas/marketplace/provider.ex:70-74` (accept list + comment), `:105-111` (`status` default `:pending`, one_of pending/active/suspended) |
| 3 | Direct `:actuate_status` update fails without Reactor context | VERIFIED | `lib/xaas/marketplace/provider.ex:83-89` (`public?(false)`, `accept([:status])`, `validate(Xaas.Actuation.Validations.ReactorContext)`) |
| 4 | `Xaas.Actuation.run/4` signature and opts (`subject_id`, `idempotency_key`, `authorize?`, `authority`) | VERIFIED | `lib/xaas/actuation.ex:25-26` (spec + def), `:161-175` (opts parse) |
| 4 | `first.status == :succeeded`, `first.replay? == false` | VERIFIED | `lib/xaas/actuation.ex:466-483` (seal success envelope) |
| 4 | "sealed receipt carrying the ontology projection hash" | CORRECTED | Envelope: receipt carries `result` snapshot + `result_hash` (`actuation.ex:466-470`); projection hash rides on intent/admission (`ontology_projection_hash`, `actuation.ex:155`, `:657`). Doc reworded. |
| 5 | Re-read provider, status `:active` | VERIFIED | `:read` in defaults (`provider.ex:68`); status atom in constraints (`provider.ex:110`) |
| 6 | Same-key replay → `:replayed`, `replay?: true`, same receipt, no second mutation | VERIFIED | `lib/xaas/actuation.ex:446-453` (replay seal envelope), `:663-678` (`replay_succeeded/3` returns existing receipt) |
| 7 | `mix test test/xaas/actuation_test.exs` falsifier | VERIFIED (file exists; not executed this lane) | `test/xaas/actuation_test.exs` on disk |

### How-to: actuate-provider-lifecycle.md

| Step | Claim | Verdict | Evidence |
|---|---|---|---|
| Perform | `Xaas.Actuation.run/4` call shape, `actor:` opt, default `authorize?: true` | VERIFIED | `lib/xaas/actuation.ex:26,170-172` |
| Retry | same key + consequence → `:replayed`; mutation not re-executed | VERIFIED | `actuation.ex:446-453,663-678` |
| Retry | distinct consequence, same key → `{:error, {:idempotency_conflict, key}}` | VERIFIED | `actuation.ex:654-660` (conflict check in `replay_or_refuse`), `:245-255` (Reactor error unwrap preserves raw tuple) |
| Diagnose | `{:error, :idempotency_key_required}` | VERIFIED | `actuation.ex:162,177` |
| Diagnose | authority refusal | CORRECTED (added) | `{:error, :delegated_actuation_requires_authority_evidence}` — `actuation.ex:576-582`; required for `authorize?: false` with empty authority map. Was absent from the doc. |
| Diagnose | not-replayable refusal | CORRECTED (added) | `{:error, {:idempotency_not_replayable, key, status}}` — `actuation.ex:252,677`; non-terminal intent (e.g. `:executing`). Was absent from the doc. |
| Diagnose | direct `Ash.update` fence + Semantics.Registry projection before DO | VERIFIED | `provider.ex:83-89`; `lib/xaas/semantics/registry.ex:1-27` (public-ontology projection, projection-hash binding); admission binds projection hash (`actuation.ex:610,657`) |
| Verify | falsifier file | VERIFIED (exists; not executed) | `test/xaas/actuation_test.exs` |
| Do-not list | no `status` in `:update` accept; no JSON:API `:actuate_status` exposure | VERIFIED | `provider.ex:76-80` (`accept([:name, :description])`, status absent); `public?(false)` on `:actuate_status` |

## W723 / W747 consistency

- Neither doc names W723 (token floor) or W747 (replay law) explicitly; no stale pins found.
- W747 replay contract as described in `docs/sjira/v26.10.6/plans/w749-runtime-contract-refresh.md:29`
  (same-key replay returns original consequence, distinct keys no dedup, non-replayable typed refusal)
  matches doc text and code (`actuation.ex:446-453,646-678`).
- W723 token floor governs the HTTP surface (`RequireInternalApiToken`), which neither doc's
  Ash-level call examples traverse; no change needed. The how-to's actor/authority preconditions
  are the Ash-level analog and were verified instead.

## Falsifier (not run this lane — no build root per lane contract)

```bash
PATH=$HOME/.asdf/shims:$PATH mix test test/xaas/actuation_test.exs
```

## Changes made

1. `docs/claude/diataxis/tutorials/receipted-provider-lifecycle.md` — step 4 expectation reworded
   (receipt carries result snapshot + result_hash; projection hash on intent).
2. `docs/claude/diataxis/how-to/actuate-provider-lifecycle.md` — Diagnose refusals list extended
   with the two typed refusals (`:delegated_actuation_requires_authority_evidence`,
   `{:idempotency_not_replayable, key, status}`) and the direct-update fence now names
   `ReactorContext` validation + `public?(false)`.
