# W947 — audit_export_token compile blocker status

- Date: 2026-10-07
- Subject: /Users/sac/xaas @ feat/playwright-surface (HEAD 910a2e22 + working tree)
- Blocker under test: W935's `increment/2` misuse at lib/xaas/governance/audit_export_token.ex:122 (tree-wide compile failure, escalated twice)

## Diff state (git diff HEAD -- lib/xaas/governance/audit_export_token.ex)

Fix is applied in the working tree:

```diff
-      change(increment(:use_count, 1))
+      change(increment(:use_count, amount: 1))
```

Also present in the same file's diff (pre-existing W935 work, not part of this blocker):
`patch(:use, route: "/:id/use")` / `patch(:revoke, route: "/:id/revoke")`.

## Compile gate

Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix compile`

- EXIT=0
- "Generated xaas app"; only warnings (AshAffidavit.Signing unused import; DatasetAdmission @doc redefine). No errors.

## Verdict

**CLEARED** at 2026-10-07 (compile green, exit 0). Blocker cleared for W946's gate.

## Standing

ALIVE (observed execution: real compile on exact working-tree subject, MIX_ENV=test, pinned asdf toolchain). No edits made by W947; receipt-only lane.
