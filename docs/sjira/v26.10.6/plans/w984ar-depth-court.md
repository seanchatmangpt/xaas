# W984ar — Depth court: AuditExportToken actor-policy layer

Lane W984ar · xaas v26.10.6 campaign · repo `/Users/sac/xaas` @
`feat/playwright-surface` (uncommitted campaign tree; no commit per
dispatch). Build root `_build-laneW984ar` (cold compile, pinned asdf
toolchain 1.20.2-otp-28, `MIX_ENV=test`) — deletion of the build root
was permission-denied in this lane's session; **left on disk for the
coordinator** (434 MB) per the dispatch's else-clause.

## Family selection (overlap check)

- `docs/sjira/v26.10.6/plans/w984aa-depth-batch2.md` and
  `w984ak-depth-batch3.md`: **not on disk** (checked) — cannot avoid
  their families from receipts; avoided instead the families named in
  on-disk receipts W984a (EU-AI-Act corpus lines 10.2.h/10.3), W980i
  (accounts org_membership destroy/role lifecycle, marketplace provider
  pre-approve lifecycle, generation ProjectionRecord admission), and
  W940b/W765/W801/W900/W935 lineage for export tokens.
- Chosen family: `Xaas.Governance.AuditExportToken` **policy layer with
  a real actor** — every existing court
  (`test/xaas/governance/export_token_deepening_test.exs`, 14 courts,
  W765/W801/W900/W935/W940b lineage) runs `authorize?: false`, so the
  `AuditExportTokenActorOrgMatches` SimpleCheck (twentieth-pass ERRC
  item-27 repair, live-HTTP-proven exploitable before the repair) had
  zero executable coverage as a policy. Verified by grep: no test in
  `test/` exercises `AuditExportToken` with `authorize?: true` + actor.
- No GraphQL surfaces (operator directive honored; resource carries an
  AshGraphql extension but courts never touch it).

## File + courts

`test/xaas/governance/audit_export_token_actor_policy_depth_test.exs`
— 7 courts, all green ×2:

1. matching-org actor mints via `:issue` through the real bypass+check
   (row persists, 64-hex hash, `aet_live_` prefix, scope `audit:read`,
   `active?` true);
2. foreign-org actor `:issue` for another org → `%Ash.Error.Forbidden{}`,
   no row persisted for either org;
3. matching-org `:revoke` succeeds through the policy (`revoked_at`
   stamped, `active?` flips false);
4. foreign-org `:revoke` → Forbidden, `revoked_at` stays nil (fresh
   token, see ordering disclosure);
5. matching-org `:use` succeeds (`use_count` 0→1, `used_at` stamped);
6. foreign-org `:use` → Forbidden, `used_at`/`use_count` untouched
   (fresh token);
7. fail-closed: blank/missing/whitespace `org_id` actors refused on
   `:issue`/`:revoke`/`:use` (the check's catch-all clause).

## Observed ordering finding (disclosed, not a defect in the court)

Ash runs changeset validations before the update-path policy check, so
on an already-revoked/used token the typed
`AuditExportTokenNotAlreadyRevoked`/`NotAlreadyUsed` validation refusal
preempts the foreign-org policy refusal (observed: `Ash.Error.Invalid`
"token is already revoked" instead of `Ash.Error.Forbidden`). Both
refusals are fail-closed; the information-leak delta is the token's
revoked/used state, readable by a foreign actor. The courts exercise
the policy refusal on fresh tokens, where it is real, and disclose the
ordering inline.

## Mutation rationale per family

- Deleting the `bypass action(:issue)` block (or the check's
  matching-org clause) → courts 1–2 fail (deny-by-default floor refuses
  every actor; no row persists).
- Deleting `bypass action(:revoke)` (or the check's `:revoke`
  `resolve_org_id` clause reading `changeset.data`) → courts 3–4 fail.
- Removing the SPEC-16 `bypass action(:use)` block → courts 5–6 fail.
- Replacing the check's catch-all clauses with an always-true fallback
  → court 7 fails.

## Verification (real tails, ×2)

Cold-lane build (434 MB, first run hit a `require Ash.Query` compile
error at line 75 — repaired, rerun from same root; the earlier
validation-preempts-policy failures drove the fresh-token restructure).

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ar \
  mix test test/xaas/governance/audit_export_token_actor_policy_depth_test.exs
```

- Run 1: `Result: 7 passed` — exit 0
- Run 2: `Result: 7 passed` — exit 0

Mock gate: `grep -nE "Mock\(|patch\(|jest.mock|mockall"` on the file →
zero matches (exit 1). Chicago discipline: real Postgres sandbox rows,
real Ash actions, typed refusals asserted (`Ash.Error.Forbidden`);
no interaction assertions.

## Standing

PARTIAL_ALIVE: the actor-policy surface of AuditExportToken is witnessed
executing on the exact lane subject (7/7 ×2). The functional
(action/validation) surface was already PARTIAL_ALIVE from W765/W935;
this lane extends the same resource's standing to the policy layer.
Falsifiers still open: the validation-before-policy ordering above is
observed but not courted as a contract; GraphQL exposure of this
resource is excluded per operator directive (UNKNOWN here).
