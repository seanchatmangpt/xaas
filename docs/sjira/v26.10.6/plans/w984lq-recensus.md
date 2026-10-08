# Receipt — W984lq coverage re-census (eighth dated re-run)

- **Lane**: W984lq, xaas v26.10.6 campaign, 2026-10-08
- **Subject**: /Users/sac/xaas @ 52ce8236 (feat/playwright-surface, uncommitted
  working tree as-walked — including the 2 disclosed W984ks lib deletions
  `lib/xaas/billing/changes/approval_invoice_reconciliation_approve_approve.ex`
  and `lib/xaas/billing/changes/approval_quota_override_approve.ex`, present in
  the walk-by-filesystem census as absent, hence TOTAL_FILES 831 → 829)
- **Task**: eighth re-census of the W984cj coverage map, following W984it's
  method exactly (seventh re-run:
  `docs/sjira/v26.10.6/plans/w984it-recensus.md`, 831/747/65/19 @ 3961c4ab).

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH elixir /tmp/w984lq_coverage.exs > /tmp/w984lq_run.txt  # exit 0
# TOTAL_FILES=829 TESTABLE=810 COVERED=772 UNCOVERED=38 NON_TESTABLE=19
```

Script = byte-copy of `/tmp/w984it_coverage.exs` with output redirected to
`/tmp/w984lq_run.txt`. **Incident disclosed**: the W984it script hardcodes
`File.open!("/tmp/w984it_map.txt", [:write])` as its map output path, so the
first run overwrote W984it's 65-row map in place; the copy
`/tmp/w984lq_coverage.exs` reproduces that behavior, so the surviving
`/tmp/w984it_map.txt` is now the W984lq 38-row map. No coverage fact is lost —
W984it's top entries were named in
`docs/sjira/v26.10.6/plans/w984it-recensus.md` and addendum 7 of the coverage
map, and the delta below is reconstructed from those citations plus the
structural argument under "Zero newly-uncovered" (the receipt's own
"regenerable" claim was stale — regeneration over the moved-forward tree
yields the new map, not the old one; per
[[no-overclaiming-conversational]] receipt-cited counts re-read at use time).
Future lanes should patch the map path when copying the script.

Output redirected to file per W984du's SIGPIPE disclosure. Delta commands
over the (regenerated, now-W984lq-content) map plus real `grep -rl` spot
checks over `test/**/*.exs` — all exit 0.

## Delta table

| Run | Files | Covered | Uncovered | Non-testable |
|---|---|---|---|---|
| W984cj as-written | 825 | 629 | 193 | 15 |
| W984cj re-run | 826 | 629 | 194 | 15 |
| W650h8 re-run | 829 | 634 | 176 | 19 |
| W650z8 re-run | 829 | 639 | 171 | 19 |
| W984du re-run | 829 | 677 | 133 | 19 |
| W984fh re-run | 830 | 718 | 93 | 19 |
| W984it re-run | 831 | 747 | 65 | 19 |
| **W984lq re-run** | **829** | **772** | **38** | **19** |
**Uncovered 65 → 38 (−27); zero newly-uncovered.** Structural proof, since
W984it's original 65-row map was clobbered before a `comm` could run:
coverage in this census is module-name-presence in the test corpus; every
commit since 3961c4ab only added or modified test files and modified no
module name; `git diff --name-status 3961c4ab..HEAD -- lib` shows exactly
7 lib paths touched (3 mix tasks = non-testable, `a2a/tofu.ex` ADDED and
covered by `test/xaas/a2a/tofu_test.exs`, `eds/executable_research_claim.ex`,
`eds/falsifier.ex`, `operations/authority_ledger_export.ex` — names
unchanged, corpus superset ⇒ status can only improve). The only newly absent
files are the 2 disclosed W984ks deletions (both were covered — named in
`test/xaas/billing/gov_long_tail_court_w984ea_test.exs`), which reduce
TOTAL_FILES 831 → 829, not the uncovered set. 95.3% covered, up from 92.0%.

## The 27 retirements, grouped (court citations)

Court landings since W984it's subject (3961c4ab → 52ce8236, 16 commits):
landing batches #9 (6fbfb47a/c58a8cea/663786f5), #10
(ad159c18/ef2e8714/79581cf6/127dc790), #11 (9a00385c/caf91669/86c69061).
Batches #12/#13 are not in HEAD's log — only #9–#11 are citable at this
subject. The single court retiring the old top-5 is the working-tree-tracked
`test/xaas/operations/fortune_batch_court_w984iv_test.exs`:

- **Operations Castle-verb fortune batch** —
  `ApprovalCastleVerbScheduleApprove`,
  `ApprovalK8sFaultRemediateSuggestApprove`,
  `CastleVerbFortune5RequirementsApprove`,
  `ApprovalK8sFaultRemediateSuggestRequiresApprover`,
  `CastleVerbFortune5RequirementsRequiresApprover` →
  `fortune_batch_court_w984iv` (tracked in git; grep-verified, 5/5 hit).
- **Platform Route validations** — `RouteFeatureFlagsRequiresApprover`
  REMAINS uncovered (still in the new 38); the old list's
  `RouteSecretsApprove` retired → `fortune_batch_court_w984iv`
  (grep-verified). `RouteProjectsRequiresApprover` REMAINS uncovered.
- Plus retirements across the governance/ultracode/trimtab remainder landed
  by batches #9–#11's 31 courts (8 + 7 + 16 family/remainder courts), which
  name the modules directly.

## New top-10 uncovered

The flat 2-pub tail is gone — now mixed depths:

1. `Xaas.Platform.Validations.RouteFeatureFlagsRequiresApprover` (2)
2. `Xaas.Platform.Validations.RouteOrgsCustomDomainActiveRequiresCertificateSecret` (2)
3. `Xaas.Platform.Validations.RouteOrgsCustomDomainValidHostname` (2)
4. `Xaas.Platform.Validations.RouteProjectsBackupsValidProjectName` (2)
5. `Xaas.Platform.Validations.RouteProjectsRequiresApprover` (2)
6. `Xaas.PromEx.CpuPlugin` (2)
7. `Xaas.Runtime.ProviderFabric.Budget` (2)
8. `Xaas.Trimtab.ZcodeAdapter` (2)
9. `UNKNOWN_postgrex_types` (0, `lib/xaas/postgrex_types.ex`)
10. `Xaas.Governance.Types.ChangeOfControlEventType` (0)

Full 38-row list: `/tmp/w984it_map.txt` (which now holds W984lq content —
see incident note above; regenerate the W984lq map with
`/tmp/w984lq_coverage.exs` after patching its output path).

Standing: ALIVE (as a map). Lane hygiene: no `_build-laneW984lq` created,
no commit, script-only.
