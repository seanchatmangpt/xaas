# W632 — kanban_web drift diagnosis

**Verdict: STALE-AUDIT-REFERENCE.** Follow-up disposition (W631-compatible typed
finding): "reference removed" — update the audit check path, do NOT land a module.

## Archaeology (git, all-branch)

- `git log --all -- lib/kanban_web/` → last commits: c5f127cc, d0bf8c47, 28936f48...
- `git log --all --diff-filter=D -- lib/kanban_web/router.ex` → exactly one deletion:
  **c5f127cc** "refactor: rename kanban/KanbanWeb book-scaffold to xaas/XaasWeb"
  (2026-09-08, Sean Chatman). KanbanWeb was the "Engineering Elixir Applications"
  book scaffold identity, explicitly renamed away from per user direction.
- Successor exists: `lib/xaas_web/router.ex` is present on feat/playwright-surface.
- No kanban surface exists in any sibling repo checked (ggen, zcode-cli,
  ggen-ecosystem, ggen-marketplace, ash_a2a, autofde-lab, gymact) — this is not a
  cross-repo copy-paste; it is xaas's own renamed history.

## Reference census (tree grep, 20 files mention "kanban" case-insensitive)

Load-bearing code refs (the drift):
- `lib/mix/tasks/xaas.release_audit.ex:317` (also :323 area, `check_rpc_alignment`)
  — `File.read("lib/kanban_web/router.ex")` — stale path, post-rename survivor.
- `test/mix/tasks/xaas_release_audit_test.exs:57` — asserts `%File.Error{path:
  "lib/kanban_web/router.ex"}`, i.e. the test pins the stale path as expected
  behavior.
- `lib/xaas_web/gettext.ex:29` — doc-comment only ("prefer `use Gettext, backend:
  KanbanWeb.Gettext`") — stale prose, no functional impact.

Docs refs (historical/normative, non-code): docs/PRD-v26.8.21.md:84
(KanbanWeb.Plugs.RequireInternalApiToken — superseded naming in a versioned PRD),
plus w600-os19-fix.md / _CLOSURE_PLAN.md discussion of this very drift.

## Typing

- MISSING-MODULE is refuted: the module existed and was deliberately renamed
  (c5f127cc); its successor (lib/xaas_web/router.ex) is live in the tree. Nothing
  is planned-but-absent.
- The audit check survived the rename without being updated → the reference is
  stale, and the audit's refusal is a true positive of the check running, but the
  finding class is stale-reference, not missing capability.
- Secondary defect (already typed in _CLOSURE_PLAN.md OS-21 follow-up (b)):
  `check_rpc_alignment` fail-crashes via `File.read!` on the config path instead of
  a typed refusal (v26.10.7 one-liner).

## W631 disposition

Typed finding: `STALE_AUDIT_REFERENCE` — follow-up action "remove the reference":
- Point `check_rpc_alignment` at `lib/xaas_web/router.ex` (assertions otherwise
  unchanged; verify the same `post "/rpc/run"` / `post "/rpc/validate"` mounts
  exist there — read-only spot-check confirms lib/xaas_web/router.ex is the active
  Phoenix router).
- Update the test expectation (xaas_release_audit_test.exs:57) to the new path.
- Sweep `lib/xaas_web/gettext.ex:29` stale doc-comment.
- v26.10.7 candidate: typed refusal on unreadable router instead of File.Error.
