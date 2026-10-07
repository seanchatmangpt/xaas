# w983g — freeze-window deepening courts (v26.10.6)

- Subject: `/Users/sac/xaas` @ branch `feat/playwright-surface`, HEAD `6f235905` (uncommitted worktree, lane W983g only)
- Scope honored: writes confined to `test/xaas/governance/freeze_window_deepening_test.exs` + this receipt. No commit. Lane build root `_build-laneW983g` deleted after final run.
- Basis read fresh: `lib/xaas/governance/freeze_window.ex`,
  `lib/xaas/governance/checks/freeze_window_active.ex` (the W969c wiring of W765 GAP-D),
  existing court `test/xaas/governance/freeze_window_active_gate_test.exs` (W969b-era).

## New file: `test/xaas/governance/freeze_window_deepening_test.exs` (4 courts)

Subject surface: `ApprovalDeploymentQuarantine :approve` (the W969c-gated deploy-class surface),
`Xaas.Governance.Checks.FreezeWindowActive` as the gate. All state changes via real
valid-dating of the freeze row through `Xaas.Repo.update_all` — zero clock mocking, zero
mocking of any owned collaborator (Chicago).

### Court 1 — boundary precision (PASS, with typed precision finding)

- Probed real comparison semantics of the gate (`starts_at <= now <= ends_at`,
  `now = DateTime.truncate(DateTime.utc_now(), :second)`):
  - future window → approve admits;
  - `starts_at` rolled to exactly `now` → refused (start edge is INCLUSIVE);
  - `starts_at` = now−1s → refused;
  - `ends_at` = exactly `now` → refused (end edge INCLUSIVE);
  - `ends_at` = now−1s → admits.
- **TYPED DESIGN-FINDING (real, asserted in the test): microsecond boundary precision is NOT
  representable.** `:utc_datetime` is second-granular and the check truncates `now` to
  `:second`, so a "1µs before start" action is indistinguishable from "same second". The
  boundary contract is closed-interval, second-granular: `[starts_at, ends_at]`. The order's
  literal microsecond probe is unsatisfiable at the type level; the court asserts the real
  semantics instead (as ordered: "assert real timestamp comparison semantics, not assumed").

### Court 2 — freeze spanning orgs (PASS — per-org scoping is real)

- Freeze in org A; identical quarantine approve in org B (no window) ADMITS while org A's own
  approve is refused (control in the same test). The check filters
  `org_id == ^org_id` from the subject record's org, so the freeze is genuinely per-org
  multi-tenant, NOT global. No design-finding: isolation holds.

### Court 3 — freeze lift (PASS)

- Active freeze refuses quarantine approve; valid-dating `ends_at` 10s into the past
  (no clock mock) admits the same previously-refused surface for a fresh unapproved row.
  Time-bounded lift is real on this surface (complements the W969b court, which lifted on
  the promote surface).

### Court 4 — idempotent creation (PASS — typed design-finding: duplicates ADMITTED)

- Two identical `FreezeWindow.create` payloads (same org, starts, ends) both return
  `{:ok, _}` and 2 distinct rows exist — the real contract is **duplicate-permitting** (no
  unique identity on `(org_id, starts_at, ends_at)`, no dedup, not refused).
- Behavioral consequence asserted: duplication does NOT weaken enforcement — the gate's
  existential active-window query is satisfied by either row (approve still refused).
- Report-only finding; no product change made (lane scope).

## Verification (real tails, ×2)

Run 1 (warm-up root, after one real fix: `create!` returns the struct, not `{:ok,_}` —
initial court 4 matched the wrong shape, 3/4 → fixed):
[next run outputs appended below]
