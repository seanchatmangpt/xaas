# W984dp — burn-down probe + court: Stripe transition allow-list refusal branch

Lane: W984dp · Campaign: xaas v26.10.6 · Subject: branch
`feat/playwright-surface`, working tree (uncommitted, shared checkout) ·
Date: 2026-10-07 · No commits made (lane law).

## Files written

- `test/xaas/billing/subscription_stripe_transition_court_w984dp_test.exs`
  (new, 5 tests)
- `docs/sjira/v26.10.6/plans/w984dp-probe.md` (this receipt)
- Transient, restored byte-identical (verified `git diff` = 0 lines vs
  HEAD after restore): one mutation round against
  `lib/xaas/billing/validations/subscription_stripe_transition_allowed.ex`
  (snapshot-swap via `git show HEAD:` + copy-back, no stash).

## Coordination against running probes

Checked sibling receipts on disk before selecting:
`w984dj4-ultracode.md` (ProcessGroup, landed), `w984dl-vault-probe.md`
(done), `w984dj2-spg-gate.md`, `w984dj3-parse-dt.md` — no receipt or
claim on `lib/xaas/billing/validations/` or the Stripe lifecycle
machine. W984dd's proration court (`w984dd` per task brief) took
`SubscriptionProrateTierChange`; this lane's target is disjoint.

## Census (fresh, two candidate families)

Method: CamelCase alias census — for every `lib/xaas/**/*.ex` module,
grep the test tree for the module basename; then **alias-level
re-check** of every census "uncovered" hit (the basename census alone
over-reports: change modules are exercised through their resource
actions, e.g. `SubscriptionChargeOnActivate` has zero basename refs but
three direct courts in `test/xaas/billing/subscription_test.exs`).

### Family A: `lib/xaas/billing/changes/` (other than W984dd's proration)

Disposition: **COVERED / not state-bearing** — typed disposition, no
court needed.

- `subscription_charge_on_activate.ex` — COVERED (3 direct courts in
  `subscription_test.exs`: first-activation -$29.00, double-charge
  idempotency, never-activated charges nothing).
- `approval_quota_override_approve.ex`, `approval_invoice_reconciliation_approve_approve.ex` —
  no-op `change/2` passthroughs (13 lines each, return the changeset
  unchanged; no state to bear). `approval_pricing_override_approve.ex`
  is a disclosed no-op stub with a trivial `atomic/3`.
- `approval_sla_credit_apply_approve.ex` (153), `approval_patch_sla_credit_apply_approve.ex` (148),
  `approval_tier_downgrade_approve.ex` (66) — COVERED via
  controller courts + `atomic_retrofit_court_test.exs` +
  `approval_lifecycle_deepening_court_test.exs`.

### Family B: `lib/xaas/generation/` (7 modules, basename census: 0 refs)

Disposition: **COVERED** — `test/xaas/generation_test.exs` (19 tests)
+ `generation_deepening_test.exs` (7) alias every one of
ModificationDetector / ProvenanceHeader / ResidueRegistry /
RegenerationVerifier / CapabilityRegistry / UnsupportedReceipt /
DependencyGraph. Refreshes the standing of my own earlier basename
census the same way W984dj4 refreshed W984cy3's.

### Census residue → court target

Remaining genuinely-uncovered state-bearing surface (alias census +
direct read):

- `Xaas.Billing.Validations.SubscriptionStripeTransitionAllowed`
  (77 lines, W897 repair of the w729
  `UNSUPPORTED(lifecycle-state-machine)` finding): every *admitted*
  edge is witnessed indirectly (subscription happy paths, webhook
  controller court), but **no test anywhere drives an illegal edge**
  — the terminal-is-terminal law (`:canceled` never re-activates) and
  the typed `InvalidChanges` refusal are unwitnessed. This is the
  exact validation whose absence w729's pin witnessed accepting
  `:canceled -> :active`.
- Lower-ranked residue, not courted (thin/indirect): `Xaas.AshTypescriptManifest` (74 lines, projection manifest), `Xaas.Billing.Validations.*` siblings (each `*_requires_approver` validation is witnessed by the lifecycle court's refusal tests), ultracode validations (witnessed by the ultracode family courts).

## Court: `Xaas.Billing.Validations.SubscriptionStripeTransitionAllowed`

Real Chicago-style court: real sandboxed Postgres, real `:create` rows
at each initial status (the resource's own `:create` accepts initial
status — the disclosed backfill path), real `:sync_from_stripe`
updates, real typed `Ash.Error.Changes.InvalidChanges` refusals. Zero
mocks. `async: false` (sibling-file ledger advisory-lock discipline).

Invariants + mutation rationale:

1. **Terminal-is-terminal**: `:canceled -> :active` via
   `:sync_from_stripe` refuses with typed `InvalidChanges` naming the
   edge and "not an admitted edge"; the row stays `:canceled`.
   Mutation: adding a `{:canceled, :active}` allow-list edge flips
   this RED (executed — see falsifier below).
2. **Terminal law is total**: all three non-self targets from
   `:canceled` (`incomplete`, `active`, `past_due`) refuse; only the
   `{canceled, canceled}` redelivery self-edge admits. Mutation:
   any `{:canceled, X}` forward-edge addition flips the loop RED.
3. **At-least-once redelivery self-edges admit for all four statuses**
   (Stripe redelivers; a redelivered event must not be refused).
   Mutation: removing self-edges from the allow-list flips this RED.
4. **Admitted dunning cycle**: `:incomplete -> :past_due -> :active`
   recovery plus re-entry into dunning all admit. Mutation: dropping
   `{:past_due, :active}` flips the recovery leg RED.
5. **Illegal non-terminal edge refused with no partial state**:
   `:active -> :incomplete` refuses with the typed refusal naming the
   edge; row persists `:active`. Mutation: allow-list weakening flips
   RED; deleting the validation from the action flips all five RED.

## Falsifier run (mutation kill, executed)

Mutation: added `{:canceled, :active}` to the allow-list (the exact
w729-witnessed defect class). Result: **3/5 passed, 2 failed** —
tests 1 and 2 (the terminal-law courts) flip RED; the court is
non-vacuous. File restored byte-identical (`git diff` vs HEAD: 0
lines) and the unmutated court re-run green.

## Commands + exits (real output, lane build root)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dp \
  mix test test/xaas/billing/subscription_stripe_transition_court_w984dp_test.exs
# -> Finished in 1.4 seconds ... Result: 5 passed  (exit 0)
# mutation round -> Result: 3/5 passed, Failed: 2 (court kills the mutation)
# post-restore rerun -> Result: 5 passed
```

## Standing + disposition

- Court standing: **ALIVE** — observed execution on the exact subject
  (5/5 green, mutation-killed, restored-clean).
- Disposition: `Xaas.Billing.Validations.SubscriptionStripeTransitionAllowed`
  refusal branch: **covered by this lane**. Families A and B: typed
  disposition COVERED / not-state-bearing (receipt above). No
  UNSUPPORTED or REFUSED arms were needed; no thin-court override was
  exercised.
- Residue for the coordinator: `Xaas.AshTypescriptManifest` and the
  ultracode validations family remain census residue (thin/indirect);
  next burn-down lane may rank them. `AshTypescriptManifest` is the
  larger of the two (74 lines, projection manifest).
- Lane build root `_build-laneW984dp`: deleted at integration below.
