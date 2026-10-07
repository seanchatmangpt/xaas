# w984ci — governance depth court: deployment-quarantine :create-side lifecycle (v26.10.6)

- Subject: `/Users/sac/xaas` @ branch `feat/playwright-surface` (uncommitted worktree, lane W984ci only). No commit.
- Scope honored: writes confined to `test/xaas/governance/approval_deployment_quarantine_lifecycle_depth_test.exs` + this receipt, plus one disclosed cross-lane compile unblock (below).
- Basis read fresh: `lib/xaas/governance/approval_deployment_quarantine.ex`,
  `lib/xaas/governance/types/deployment_quarantine_reason.ex`,
  `lib/xaas/governance/checks/actor_org_matches.ex` (its moduledoc's real
  live-verified finding: the `:create` half is documented vacuous —
  multitenancy normalizes `org_id` from the tenant before policy),
  existing coverage: `test/xaas/governance/multitenant_approval_deepening_test.exs`
  (tenant isolation / maker-checker / state machine, all on `:approve`),
  `test/xaas/governance/freeze_window_deepening_test.exs` (W983g), and
  `test/xaas_web/controllers/approval_deployment_quarantine_controller_test.exs`
  (HTTP happy path, self-approve refusal, paper trail — all on `:approve`).

## Coverage analysis (governance family MINUS covered slices)

Covered (excluded per order): freeze window (W969b/c, W983g), audit
export token (W940b, W984ar), quarantine `:approve` (W983g incidental +
multitenant + controller). The uncourted remainder found: the
quarantine **`:create`-side payload contract and cross-tenant create
normalization**. No prior test asserts a negative enum payload for
`reason`/`environment`, cross-tenant create normalization, or the
approve-input contract on this resource.

## New file: `test/xaas/governance/approval_deployment_quarantine_lifecycle_depth_test.exs` (5 courts)

1. **`reason` closed enum negative**: create payload with
   `reason: "unauthorized_topology_change"` → real typed
   `Ash.Error.Invalid` whose message names `reason`; real query proves
   no row landed (Chicago: assert on persisted state, not the error
   alone). Mutation rationale: retyping `reason` to `:string` (or
   widening the enum) flips the first assert to a successful create.
2. **`environment` closed enum negative**: same contract for
   `environment: "disaster-recovery"` naming `environment`. Mutation
   rationale: retyping `environment` to `:string` breaks it.
3. **Cross-tenant create normalization**: payload asserting org B's
   `org_id` under tenant org A (actor org A, authorize?: true) yields
   `{:ok, row}` with `row.org_id == org_a.slug` — the row lands under
   the resolved tenant, never under the payload-asserted foreign org;
   org B gains no row. This asserts ActorOrgMatches' own documented
   vacuous-`:create` finding as a real behavioral invariant.
4. **Same-org authorized full lifecycle control**: authorized create →
   approve admits end to end (proves 1–3 refusals are contract, not
   breakage).
5. **Approve input contract**: an `:approve` payload carrying
   `deployment_name`/`environment`/`reason` is a real typed
   `Ash.Error.Invalid.NoSuchInput` refusal listing exactly
   `[:deployment_name, :environment, :reason]`, and the row stays
   pending with payload intact. DISCLOSED DESIGN-FINDING: the real
   contract is *refusal*, not the "silent ignore" I initially asserted
   — one test-side fix during run 1 (Ash's accept-list is stricter
   than an ignore; the court now asserts the real, stricter behavior).

## Verification (real tails, ×2)

- Run 1: `mix test test/xaas/governance/approval_deployment_quarantine_lifecycle_depth_test.exs`
  — `Finished in 0.8 seconds … Result: 5 passed`
- Run 2: `Finished in 0.6 seconds … Result: 5 passed`
- Both under pinned toolchain (`PATH=$HOME/.asdf/shims:$PATH`),
  `MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW984ci`.

## Cross-lane compile unblock (disclosed, per compile-freeze SLA)

During run 1 the shared compile was frozen twice by another lane's
in-flight untracked files: `lib/xaas/operations/authority_ledger_export.ex`
(missing `require Ash.Query` for its `^pin`s) and transiently
`lib/xaas/operations/approval_causal_anatomy.ex` (literal `...`
placeholder, resolved by its own lane). I applied the minimal fix to
`authority_ledger_export.ex` only: added `require Ash.Query` (with a
comment naming this lane). Test-side `^pin`s in my own file were fixed
by dropping to keyword-filter syntax (no pin needed) rather than
touching shared config.

## Standing

- Courts 1–2 (closed enums on `:create`): **ALIVE** — real typed
  refusals naming the offending field; no row on refusal.
- Court 3 (cross-tenant normalization): **ALIVE** — row lands under the
  resolved tenant, never the payload-asserted org; org B gains nothing.
  Matches ActorOrgMatches' documented vacuous-`:create` design finding
  as observed behavior.
- Court 4 (lifecycle control): **ALIVE** — authorized create→approve
  admits end to end same-org.
- Court 5 (approve input contract): **ALIVE** — tampering inputs are
  typed `NoSuchInput` refusals; row stays pending, payload intact.
- Full `:approve`-side freeze/tenant/maker-checker/state-machine
  standing: inherited from W969b/c, W983g, multitenant deepening, and
  the controller test (not re-asserted here).

## Lease note

`_build-laneW984ci` deletion attempted below this receipt's writing;
if it remains, it is left for the coordinator per the fanout cleanup
law. No commits made.