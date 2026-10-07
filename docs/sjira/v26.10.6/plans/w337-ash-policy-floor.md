# W337 — Ash Policy Floor Audit (v26.10.6 convergence diff)

Lane: W337, repo /Users/sac/xaas @ feat/playwright-surface, read-only audit, no fixes.
Base: feat/playwright-surface @ d1db2b03 working tree (v26.10.6 convergence diff, modified + untracked).
Date: 2026-10-06.

## Method

- Touched set = `git diff --name-only lib/` ∪ untracked `lib/` files.
- Resource set = touched files defining `use Xaas.Resource` / `use Ash.Resource`
  (repo convention wraps Ash.Resource via `lib/xaas/resource.ex`, which injects
  projection helpers only — no default policy injection; Ash's own semantics apply).
- Full `authorize?: false` census (lib/) classified against `_CLOSURE_PLAN.md` §1 row 6
  fenced inventory (the single fenced row: `mix xaas.ingest_capability_receipts` bypass).
- Sensitive-resource proof via `git diff --name-only | grep -i ledger` (empty) and
  router diff inspection.

## 1. Per-resource verdicts (touched Ash resources)

| resource file | diff on file | policies block | verdict |
|---|---|---|---|
| lib/xaas/accounts/token.ex | syntax only: `is_revoked_action_name(:is_revoked)` parenthesization | `bypass AshAuthenticationInteraction authorize_if(always())` + AshAuthentication defaults — unchanged | FLOOR-HELD (AshAuthentication-scoped bypass only) |
| lib/xaas/witness/certified_receipt.ex | formatting (blank lines, `end` indent) | `bypass action_type(:read)`, `bypass action(:ingest)`, `bypass action(:record_verification)`, `policy always() forbid_if(always())` — unchanged, catch-all forbid intact | FLOOR-HELD (scoped bypasses + catch-all deny) |
| lib/xaas/witness/verification_key.ex | none on policies | scoped bypasses + `policy always() forbid_if(always())` — unchanged | FLOOR-HELD |
| lib/xaas/operations/capability_liveness_receipt.ex | comment-only edits in/around policies (comment now says "No authorize?: false bypass remains") | read bypass via `bypass action_type(:read)`; :ingest via scoped system-authority bypass; comment-only diff | FLOOR-HELD (read carve-out via `bypass`, per floor rule) |
| lib/xaas/a2a/agent.ex, a2a/task.ex, conference/{attendee,event,registration,session,speaker,sponsor,track}.ex, igniter/{pack_manifest,refusal_code}.ex, marketplace/pack.ex, security/finding.ex | identity `pre_check_with:` additions / syntax — no policies hunks | (varies; no policy directives touched) | FLOOR-HELD (no policy surface changed) |
| lib/xaas_web/live/system/command_center_adapter.ex | doc-comment updates only; call sites `Ash.read!(action: :read_unscoped, authorize?: false)` pre-existing | (not a resource; consumer of documented `:read_unscoped` actions) | FLOOR-HELD (pre-existing fenced read_unscoped pattern, disclosed in-file) |

No resource in the diff gained an allow-all policy, an `authorizer: false` /
`Ash.Resource, authorizers: []` downgrade, or a `policy always() authorize_if(always())`
ambient allow. Zero removed policy directives (all removed lines matching
polic/forbid/authorize are comments/prose).

## 2. `authorize?: false` census (lib/, full-tree grep)

- Total grep hits: 306 lines, of which ~70 are comments/docstrings; ~236 real call-site
  occurrences across ~60 files.
- NEW in the v26.10.6 diff (added lines + untracked files): **3 added lines**, all classified:
  1. `lib/mix/tasks/xaas.capability_coverage.ex:112` — real call inside new
     `count_resource/1` helper, but a **relocation of a pre-existing** `Ash.count(..., authorize?: false)`
     coverage-count pattern (removed block re-added verbatim as a function). Mix-task
     operator path, same semantics as before the diff. Classified: **pre-existing pattern,
     relocated — not a new bypass surface**. Note: not itself listed in §1 row 6; if the
     closure plan wants a strict inventory, add it as a disclosed mix-task read bypass.
  2. `lib/xaas/operations/capability_liveness_receipt.ex:72` — comment only.
  3. `lib/mix/tasks/xaas.ingest_capability_receipts.ex:60` — comment ("No authorize?: false bypass remains" — documents the bypass's removal).
- Untracked files: one prose mention (gymact_surface.ex:148, comment). **Zero new real-code `authorize?: false` call sites in untracked files.**
- Against §1 row 6 fence: the row-6 bypass (`ingest_capability_receipts.ex:55-59`) is
  GONE — the diff replaced it with real policies (scoped `bypass action(:ingest)` on the
  resource). The fenced inventory is therefore not stale-open; it is closed-out.
- **NEW-undisclosed count: 0** (the one candidate, capability_coverage `count_resource/1`, is a relocation of a pre-existing disclosed-pattern usage, flagged as an inventory note only).

## 3. Sensitive resources untouched — proof

- `git diff --name-only | grep -i ledger` → empty (exit 1). No diff touches
  `Xaas.Ledger.Balance/Account/Transfer`. `Xaas.Accounts.User` has no diff; `Xaas.Accounts.Token`
  diff is syntax-only (parenthesization), no policy hunk. No untracked ledger/accounts files.
- Router diff adds: `live("/witness", WitnessLive)`, `forward("/v1", XaasWeb.A2A.V1TransportPlug)` (behind existing `:require_internal_api_token` pipeline, comment-disclosed), pipeline reordering (auth floor before content negotiation — a tightening), and workbench /api pipe_through reorder (tightening). **No new routes to Ledger/Accounts resources.** Both router changes are behind the existing token floor; the reordering is a tightening, not a relaxation.

## Verdict

- **Violations: 0.**
- Census: 306 grep lines (~236 real call sites, ~70 comment/docstring), 3 added lines in the diff (1 relocated real call, 2 comments), 0 new-undisclosed.
- Fenced row 6 (ingest bypass) is closed out by the diff itself (real scoped-bypass policies landed).
- One inventory note: `capability_coverage.count_resource/1` uses the pre-existing mix-task read pattern — suggest adding to the disclosed inventory if strict listing is wanted.
