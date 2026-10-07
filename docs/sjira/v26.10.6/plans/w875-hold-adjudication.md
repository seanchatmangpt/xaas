# W875 — HOLD-path ownership adjudication (receipt)

- **Lane**: W875, v26.10.6 campaign
- **Subject**: `/Users/sac/xaas` @ `a0723bf6`, branch `feat/playwright-surface` (canonical checkout, no worktree, no build root)
- **Task**: adjudicate the 10 HOLD paths in `docs/sjira/v26.10.6/_COMMIT_MANIFEST_W850.md` (W867's list) by matching `git diff HEAD -- <path>` / untracked-file content against the Files-written sections of candidate-lane receipts under `docs/sjira/v26.10.6/plans/`.
- **Constraint honored**: no commits, no build root, no edits outside the manifest append + this receipt.

## Method

1. Extracted the HOLD list from the manifest (lines 212-223 + the CG-15
   system_actor/validation rows).
2. For each path: real `git diff HEAD -- <path>` (tracked) or `cat` of the
   untracked file(s); `git status --porcelain` for dir-level HOLD rows.
3. Grep over `plans/*.md` for each path basename and each candidate lane's
   W-number; read the Files-written sections of the receipts that claim the
   path; matched hunk content to the receipt's described diff. Candidate
   receipts that only *read* a file (W784, W830) or explicitly disclaim it
   (W741) were rejected as owners.

## Per-path findings and proposals

| # | Path | Diff evidence | Owner | Proposal |
|---|---|---|---|---|
| 1 | `lib/xaas_web/router.ex` [M] | Hunk = pipeline reorder (token floor first) + comment self-marked **W739** ("same class as W150/W299c"); byte-matches `plans/w739-406-leak-fix.md` Fix section, including the exact 3-element `pipe_through` list. W867's candidate set (W774/W800/W802/W813/W817/W836/W861/W862) contained no claimant; the true owner was W739 (not in the candidate list). | W739 | **COMMIT** — group with W739 (router + `test/xaas_web/require_internal_api_token_deepening_test.exs`) |
| 2 | `lib/xaas/operations/validations/incident_resolved_is_terminal.ex` [??] | Content = guard (b) exactly as W818's receipt describes: `changeset.data` + `Ash.Changeset.get_attribute/2` house idiom (the nonexistent `Ash.Changeset.OriginalDataNotLoaded` from W818's first cut is absent — confirming this is the repaired final), terminal-reopen message matches. Other claimants (W803/W804/W808/W809/W831) have no Files-written claim on it. | W818 | **COMMIT CG-05** — with W818's other artifacts (`incident.ex` wiring, `incident_lifecycle_deepening_test.exs`, `incident_test.exs` fixture fix) |
| 3 | `lib/xaas/ocel.ex` [M] | Single hunk = `fold_object_state/2`; `plans/w758-ocel-fold.md` claims exactly this ("Files touched (only): lib/xaas/ocel.ex, test/xaas/ocel_deepening_test.exs"). W741 explicitly disclaims ocel.ex (sibling in-flight edit); W745's claim is the `::` spec repair already folded into W758. | W758 | **COMMIT** — group with W758 |
| 4 | `lib/xaas/a2a/validations/forward_only_transition.ex` [??] | Sole file in the dir; `plans/w772-a2a-transition-guard.md` claims it ("new ... the guard; no other files touched"). W784 read it only. | W772 | **COMMIT** — group with W772 |
| 5 | `lib/xaas/ledger/validations/transfer_source_sufficiency.ex` [??] | Sole file in dir; `plans/w762-transfer-sufficiency.md` claims it as diff item 1. W746/W799/W663b do not claim it. | W762 | **COMMIT** — group with W762 |
| 6 | `lib/xaas/operations/validations/capability_liveness_receipt_status_gate.ex` [??] | `plans/w768-liveness-alive-gate.md` claims it as new file 1/3 of its diff; W830 lists it only under Sources read. | W768 | **COMMIT** — group with W768 |
| 7 | `route_orgs_custom_domain_approve.ex` [D] + `route_orgs_custom_domain_requires_approver.ex` [D] | W792: "Typed deletion (2 of 5 pairs)" — resources carry no approver metadata columns (receipt verified against the initial migration); deletion court-pinned by test (6d). | W792 | **OPERATOR** — owner resolved (W792, intentional receipted deletion); operator confirms and stages with the W792 group |
| 8 | `route_projects_backups_approve.ex` [D] + `route_projects_backups_requires_approver.ex` [D] | Same W792 deletion pair, same rationale + court (6d). | W792 | **OPERATOR** — same |
| 9 | `lib/xaas/checks/system_actor.ex` [M] | Diff adds `{Xaas.Platform.RouteSecrets,:approve}`, `{RouteProjects,:approve}`, `{RouteFeatureFlags,:approve}` to `@internal_api_actions` — W792's approver wiring; receipt names system_actor.ex's exact-subject allowlist and courts `Ash.Error.Forbidden` for non-system actors. Previously "unattributed" — now attributed. | W792 | **COMMIT** — group with W792 |
| 10 | `priv/semantic/generated/` [??] | Generated projection surface (`castle_bridge_shacl.ttl`, `MANIFEST.json`); manifest law: commit only via its lawful generator step. | — | **OPERATOR** — unchanged; regenerate via the generator step, never hand-commit |

## Summary

- 7 COMMIT proposals: W739 (router.ex), W818 (incident_resolved_is_terminal.ex, CG-05), W758 (ocel.ex), W772 (a2a/validations), W762 (ledger/validations), W768 (capability gate), W792 (system_actor.ex).
- 3 OPERATOR rows: the 2 platform deletion pairs (owner resolved to W792's receipted deletion — operator confirms intent) and priv/semantic/generated/ (generated surface, generator step required).
- 0 HOLD-for-lane: every owner lane has a landed receipt at HEAD a0723bf6; no still-running owner exists for any path.

## Falsifier

Any row whose diff does not byte-match its proposed owner receipt's described
change (e.g. a second unattributed hunk in router.ex beyond the W739 reorder,
or an `OriginalDataNotLoaded` reference surviving in incident_resolved_is_terminal.ex)
would refute the corresponding attribution. None observed.

## Standing

- **Adjudication**: PARTIAL_ALIVE — each row is a real diff/receipt match
  performed in this session at a0723bf6; proposals are advisory staging, the
  coordinator owns the actual git operations and re-grouping.
- **Commit execution**: UNKNOWN (coordinator-owned, per manifest standing).

## Verification commands (real)

```
git diff HEAD -- lib/xaas_web/router.ex lib/xaas/ocel.ex lib/xaas/checks/system_actor.ex
git status --porcelain lib/xaas/a2a/validations lib/xaas/ledger/validations priv/semantic/generated
grep -rln <path-basename> docs/sjira/v26.10.6/plans/
sed -n <Files-section> each candidate receipt
```
