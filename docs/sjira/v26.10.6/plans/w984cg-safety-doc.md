# W984cg — Safety-property invariants reference section (doc-deepening)

- Lane: W984cg, xaas v26.10.6 campaign, branch `feat/playwright-surface`.
- Subject: `/Users/sac/xaas` working tree (uncommitted, per dispatch; no commit).
- Writes: `docs/claude/diataxis/reference/actuation-and-semantics.md` (new
  `## Safety-property invariants` section, appended after `## Digest forms`)
  + this receipt. No lib/test edits, no mix commands (per dispatch).

## What was added

A compact reference section — one record per invariant (module, pinning
court, killing mutation, receipts), each line ≤100 chars, no tutorial prose:

1. LimitGate registry disposition (4/15 enforced seams, 11
   unmeasured-no-consumer) — `Xaas.Graphlaw.LimitGate` /
   `Xaas.Bridges.Registry`; w976, w981k. VERIFIED already present in the
   page (the full "Graphlaw bridge admission gate" section, lines ~174–225);
   the new section cross-references it rather than duplicating.
2. Audit-chain tamper evidence — `Xaas.Witness.AuditChain`; w984p; the
   `expected_head` last-link law from w984al's correction (a chain rebuilt
   from tampered content is self-consistent `:ok`; head tamper needs
   `expected_head: original_head` → `{:error, {:tampered, :head}}`).
3. Art. 13 information sufficiency (Shapley efficiency identity,
   faithful-record counterfactual) — `AdmissionAttribution` /
   `Counterfactual`; w984p.
4. OCEL determinism — `Xaas.Ocel.CaseView.derive_for_object/2` total order
   `(occurred_at unix-usec, id)`; w984h fix 1; KILL-verified w984au.
5. OCEL destroy floor — `Xaas.Ocel.Event` `defaults([:read])`; w984h fix 2;
   KILL-verified w984au.
6. Reverse sufficiency — `Xaas.Ledger.Changes.ReverseTransfer.run_sufficiency/2`;
   w983j; KILL-verified w984au.
7. SPEC-27 reversal guard — `already_reversed?/1`; KILL-verified w984au.
8. Re-approve guards (4 billing resources) — w984k; landed `32487e08`
   (w984u).
9. DevSeeds env gate — `Xaas.DevSeeds.refute_non_dev_target!/0`; w983f
   (disclosed sandbox-owned `:test` exception).

Mutation-kill standing is stated in-section: 4 rows KILL-verified by W984au's
real mutation runs; the rest carry their receipts' falsifiers.

## Sources read fresh (all on disk)

- `docs/claude/diataxis/reference/actuation-and-semantics.md` (full page)
- `docs/sjira/v26.10.6/plans/w984p-corpus-deepening-4.md`
- `docs/sjira/v26.10.6/plans/w984h-ocel-findings.md`
- `docs/sjira/v26.10.6/plans/w983j-reverse-sufficiency-fix.md`
- `docs/sjira/v26.10.6/plans/w984k-reapprove-guards.md`
- `docs/sjira/v26.10.6/plans/w983f-devseeds-gate.md`
- `docs/sjira/v26.10.6/plans/w984al-corpus-deepening-5.md`
- `docs/sjira/v26.10.6/plans/w984au-mutation-wave3.md`
- `docs/sjira/v26.10.6/plans/w984u-billing-commits.md`
- `lib/xaas/witness/audit_chain.ex` (verify_chain/2, expected_head contract)

## Corrections / disclosures

- The dispatch named `w984bn` for audit-chain tamper evidence. **No w984bn
  receipt exists on disk** (`ls plans/ | grep w984bn` → empty). The audit-
  chain facts are cited to w984p (the 26.1 chain court, real receipt-hash
  binding) and w984al (the `expected_head` correction), both read fresh.
  Verified against `audit_chain.ex` itself (moduledoc: expected_head is the
  documented mitigation for the rebuilt-chain limitation).
- LimitGate section verified present in the page (not re-documented).

## Verification

- `awk 'length($0)>100'` over the new section → zero lines over 100 chars.
- Edit confirmed on disk via the file-state check (no re-read needed);
  section is at the end of the page, after `## Digest forms`.

## Standing

- Doc section: ALIVE (facts re-read from receipts + module source at write
  time; no execution claimed — this is a documentation lane).
- No falsifier beyond content drift: any cited receipt or module contract
  changing invalidates the corresponding row.
- No build root created; nothing left for coordinator cleanup.
