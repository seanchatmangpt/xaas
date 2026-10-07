# W984cq — Policy-ordering adjudication: AuditExportToken validation-vs-policy leak class

Lane W984cq · xaas v26.10.6 · branch `feat/playwright-surface` · working tree (uncommitted, per
lane dispatch — coordinator owns commits). Build roots `_build-laneW984cq` and `_build-laneW984cq2`
LEFT for coordinator: deletion was denied by the session permission system this session (two
attempts); per lane-dispatch fallback they are left in place for coordinator cleanup at
integration. Toolchain: asdf elixir 1.20.2-otp-28.

## Adjudicated question

Two lanes (W984ar on AuditExportToken; W984bp/W984ca hook deny-reason) independently surfaced an
information-leak class: do action validations run BEFORE the policy check, letting a foreign actor
distinguish revoked/used state by error type? If yes on AuditExportToken, apply a minimal ordering
fix; if it is an Ash runtime invariant (policy always precedes validations), type the class
DESIGN-ACCEPTED.

## Findings

1. **Ash runtime invariant confirmed (source + empirics).** In ash 3.34.4, every primary action
   pipeline orders `authorize` strictly before validations:
   - `lib/ash/actions/update/update.ex:332-339` (`do_run/4`): `changeset -> authorize ->
     add_atomic_validations -> commit`;
   - `deps/ash/lib/ash/actions/create/create.ex:185` and
     `deps/ash/lib/ash/actions/destroy/destroy.ex:148`: same `authorize` position.
   Non-atomic validations execute in `before_action` hooks inside `commit/3` — after `authorize`.
   Atomic validations are added via `add_atomic_validations/3` — after `authorize`. There is no
   per-resource config (`where`/delayed validation) that reorders this ahead of policy; `where` on
   a validation only gates it, never promotes it ahead of authorization.
   **Consequence: W984ar's stated leak ("validation refusal reveals revoked/used state to a
   foreign actor") does not exist for a foreign actor.** The empirical court proved a foreign
   actor observes `Ash.Error.Forbidden` on active, revoked, AND used tokens — identical error
   class regardless of state — and an authorized (home-org) actor still trips the
   already-revoked/used validations (court 4), so the ordering result is ordering, not dead
   validations. Courts passed on two runs including a cold fresh-root compile.
2. **The residual, bounded leak is the read surface — and it is disclosed design.** `:read` is a
   `bypass ... authorize_if always()` (internal-api-token gated at the router), documented in the
   resource itself as letting operators list token metadata. Any internal-api actor can read any
   token's `revoked_at`/`used_at`/`use_count` directly — a strictly stronger oracle than anything
   validation ordering could leak. With read open, "validation ordering leaks state existence" is
   moot: the same information is lawfully readable. W984bp/W984ca's hook deny-reason class is a
   different seam (error payload contents), out of this lane's file ownership; adjudication here
   does not amend it.
3. **Disposition: DESIGN-ACCEPTED (no lib fix warranted).** Ordering is an Ash runtime invariant
   (policy-first is the framework default, confirmed across create/update/destroy pipelines);
   the residual oracle is the disclosed open read bypass, not ordering. Minimal-fix criterion
   (unauthorized actor sees Forbidden first) is already satisfied; the court proves it. Only
   lib/ change this session: a one-line compile unblock in
   `lib/mix/tasks/xaas.release_audit.ex` (another lane's in-flight edit broke the shared compile
   mid-run; `~r{...}` delimiter conflict fixed to `~r|...|`, disclosed under the compile-freeze
   SLA — the owner should review before integration commit).

## Court

`test/xaas/governance/w984cq_policy_ordering_court_test.exs` — 5 real-Postgres (sandbox) courts,
real actors, real Ash actions, `authorize?: true`:

1. foreign actor, active token → Forbidden on `:revoke` and `:use` (baseline);
2. foreign actor, already-revoked token → Forbidden, identical class as active (THE adjudication);
3. foreign actor, already-used token → Forbidden, identical class as active (THE adjudication);
4. authorized actor trips already-revoked/used validations (`Ash.Error.Invalid` with typed
   message "token is already revoked"/"already used") after a fresh re-`Ash.get!` — proving the
   validations are live and ordered after policy; the fresh re-`Ash.get!` also surfaced that the
   guard reads changeset DATA (stale in-memory record defeats it — disclosed as a
   known-bound/idempotency-guard caveat, pre-existing, not touched);
5. nonexistent id → `NotFound` via the open read bypass; real foreign row → readable via bypass
   (disclosed design) then Forbidden on `:revoke`.

## Commands / exits (receipt ladder)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984cq \
  mix test test/xaas/governance/w984cq_policy_ordering_court_test.exs
# run 1 (cold, fresh root): 3/5 — the 2 failures were court artifacts
#   (stale in-memory record in court 4; for_update requires a record in court 5),
#   NOT product behavior; adjudication courts 1–3 passed on the cold run.
PATH=... MIX_BUILD_ROOT=_build-laneW984cq mix test <court> <w984ar depth test>
# → 12 passed (5 W984cq + 7 pre-existing W984ar policy-depth, no regression)
PATH=... MIX_BUILD_ROOT=_build-laneW984cq2 mix test <court>
# run 2 (cold, fresh root _build-laneW984cq2): 5 passed
```

## Standing

- Disposition DESIGN-ACCEPTED: **PARTIAL_ALIVE** — empirically witnessed on the exact subject
  (AuditExportToken, ash 3.34.4, two runs incl. fresh roots), invariant analysis cites real
  source lines; cross-resource generality asserted from the create/update/destroy pipeline
  reading, not per-resource courts (bounded UNKNOWN residue on resources with atomic validations
  that are themselves policy-relevant).
- Falsifier: any court showing a foreign actor receiving a validation-class error (not
  `Ash.Error.Forbidden`) on a state-distinguishing action of any Ash resource with an
  org-scoped policy would refute the invariant claim.
- Lane files written: `test/xaas/governance/w984cq_policy_ordering_court_test.exs` (new),
  `docs/sjira/v26.10.6/plans/w984cq-policy-ordering.md` (this receipt),
  `lib/mix/tasks/xaas.release_audit.ex` (one-line disclosed compile unblock, not lane-owned).
