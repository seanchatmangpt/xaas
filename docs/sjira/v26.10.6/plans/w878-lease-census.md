# W878 — Lane Lease Census (v26.10.6)

**Method**: live `du -sk` over `/Users/sac/xaas/_build-lane*` (2026-10-07, lane W878);
owner mapping by grepping `docs/sjira/v26.10.6/` (plans + manifests) for each lane id;
running-detection by `ps`/`lsof` (no beam/mix process holds any `_build-lane*` cwd or
open handle) plus `find -mmin -90` (flagged only fresh minting, not live processes).
All sizes are `du -sk` actuals, not doctor estimates. No deletion executed by this lane.

**Standing**: observed/verified on exact subject `feat/playwright-surface` @ a0723bf6.
Status key: receipt found → DELETABLE (coordinator deletes at integration per fanout
cleanup law); live in-flight lane → KEEP; no receipt found → CHECK.

## Totals

| class | entries | size |
|---|---|---|
| DELETABLE (xaas `_build-lane*`, receipt found) | 65 | ~28.01 GB |
| CHECK (xaas `_build-lane*`, no external receipt) | 2 (W856, W865) | ~0.86 GB |
| KEEP (in-flight at census time) | 2 (W880, W888) | ~0.37 GB |
| DELETABLE (sibling-repo lanes, receipts found) | 9 | ~3.19 GB |
| DELETABLE (`/tmp` lease dirs) | 6 | ~0.51 GB |
| **Deletable grand total** | **80** | **~31.71 GB** |
| Check + keep residue | 4 | ~1.23 GB |

Note: the W847 doctor figure (63 leases / 56.5 GB) overstates; measured 69 xaas lane
dirs / 28.91 GB at census close (68 dirs / 28.21 GB at first `du` — the campaign kept
minting lanes mid-census). All leases were minted today. `_build-coord*` does not exist
in xaas. `/Users/sac/xaas/_build` (main tree) is NOT a lease and is out of scope.

**Census-time caveat**: this campaign is live — receipts landed mid-census (e.g.
`w858-route-castle-surface.md`, `w879-integration-sequence.md` appeared between greps),
W880 and W888 were minted during the run, and W880 grew 0.02→0.35 GB while observed.
This census file itself self-references lane ids; any receipt-grep MUST exclude
`w878-lease-census.md`, and generated loops proved unreliable on the changing tree
(flaky between runs) — the explicit `rm` list below, built from direct per-lane
greps, is authoritative.

## Per-entry — /Users/sac/xaas/_build-lane* (68 entries, 28.21 GB)

Receipt-backed lanes (0.43 GB each unless noted):

| path | size | receipt in `docs/sjira/v26.10.6/` | status |
|---|---|---|---|
| `_build-laneW663b` | 0.43 GB | `plans/w663b-postcommit-gates.md` | DELETABLE |
| `_build-laneW752` | 0.43 GB | `plans/w752-e2e-validation.md` | DELETABLE |
| `_build-laneW774` | 0.43 GB | `plans/w774-dev-routes-court.md` | DELETABLE |
| `_build-laneW775` | 0.43 GB | `plans/w775-stripe-webhook-deepening.md` | DELETABLE |
| `_build-laneW778` | 0.43 GB | `plans/w778-gate-fix-verify.md` | DELETABLE |
| `_build-laneW779` | 0.43 GB | `plans/w779-opengap-tag.md` | DELETABLE |
| `_build-laneW780` | 0.43 GB | `plans/w780-claim-authority-guard.md` | DELETABLE |
| `_build-laneW782` | 0.43 GB | `plans/w782-claim-label-fix.md` | DELETABLE |
| `_build-laneW785` | 0.43 GB | `plans/w785-overdraft-policy.md` | DELETABLE |
| `_build-laneW786` | 0.43 GB | `plans/w786-onetime-partition.md` | DELETABLE |
| `_build-laneW787` | 0.43 GB | `plans/w787-embedding-deepening.md` | DELETABLE |
| `_build-laneW788` | 0.05 GB | `plans/w788-paper-trail-deepening.md` | DELETABLE |
| `_build-laneW791` | 0.66 GB | `plans/w791-doctor-task.md` | DELETABLE |
| `_build-laneW792` | 0.43 GB | `plans/w792-approver-wiring.md` | DELETABLE |
| `_build-laneW793` | 0.43 GB | `plans/w793-incident-lifecycle-deepening.md` | DELETABLE |
| `_build-laneW794` | 0.43 GB | `plans/w794-raw-body-fix.md` | DELETABLE |
| `_build-laneW795` | 0.43 GB | `plans/w795-conference-invariants.md` | DELETABLE |
| `_build-laneW796` | 0.43 GB | `plans/w796-checkout-policy-deepening.md` | DELETABLE |
| `_build-laneW799` | 0.43 GB | `plans/w799-reversal-deepening.md` | DELETABLE |
| `_build-laneW800` | 0.43 GB | `plans/w800-mcp-tools-deepening.md` | DELETABLE |
| `_build-laneW801` | 0.43 GB | `plans/w801-freeze-enforcement.md` | DELETABLE |
| `_build-laneW802` | 0.43 GB | `plans/w802-graphql-surface.md` | DELETABLE |
| `_build-laneW803` | 0.43 GB | `plans/w803-dev-boot-fix.md` | DELETABLE |
| `_build-laneW803-dev` | 0.52 GB | `plans/w803-dev-boot-fix.md` | DELETABLE |
| `_build-laneW804` | 0.43 GB | `plans/w804-epoch-dedup.md` | DELETABLE |
| `_build-laneW805` | 0.43 GB | `plans/w805-jsonapi-surface-court.md` | DELETABLE |
| `_build-laneW808` | 0.43 GB | `plans/w808-approve-route.md` | DELETABLE |
| `_build-laneW811` | 0.43 GB | `plans/w811-lease-kernel-deepening.md` | DELETABLE |
| `_build-laneW812` | 0.43 GB | `plans/w812-org-resolution-coverage.md` | DELETABLE |
| `_build-laneW813` | 0.43 GB | `plans/w813-rpc-surface-deepening.md` | DELETABLE |
| `_build-laneW814` | 0.43 GB | `plans/w814-release-audit-run.md` | DELETABLE |
| `_build-laneW816` | 0.43 GB | `plans/w816-155s3-residual.md` (landed mid-census) | DELETABLE |
| `_build-laneW817` | 0.43 GB | `plans/w817-negotiation-court.md` | DELETABLE |
| `_build-laneW821` | 0.43 GB | `plans/w821-terminal-census-2.md` | DELETABLE |
| `_build-laneW823` | 0.43 GB | `plans/w823-nextread-seed.md` | DELETABLE |
| `_build-laneW824` | 0.43 GB | `plans/w824-quiescent-fabric-tie.md` | DELETABLE |
| `_build-laneW825` | 0.43 GB | `plans/w825-doctor-tune.md` | DELETABLE |
| `_build-laneW828` | 0.43 GB | `plans/w828-castle-execute-court.md` | DELETABLE |
| `_build-laneW829` | 0.43 GB | `plans/w829-sensitive-routing-court.md` | DELETABLE |
| `_build-laneW831` | 0.43 GB | `plans/w831-exclusions-guard.md` | DELETABLE |
| `_build-laneW832` | 0.43 GB | `plans/w832-doctest-verify.md` | DELETABLE |
| `_build-laneW833` | 0.43 GB | `plans/w833-docstring-hygiene.md` | DELETABLE |
| `_build-laneW834` | 0.43 GB | `plans/w834-freeze-suites-rerun.md` | DELETABLE |
| `_build-laneW835` | 0.43 GB | `plans/w835-sla-exemption.md` | DELETABLE |
| `_build-laneW836` | 0.43 GB | `plans/w836-health-court.md` | DELETABLE |
| `_build-laneW837` | 0.43 GB | `plans/w837-ts-drift-court.md` | DELETABLE |
| `_build-laneW838` | 0.66 GB | `plans/w850-nextread-readme-verify.md` (refs W838) | DELETABLE |
| `_build-laneW839` | 0.43 GB | `plans/w839-kanban-residue.md` | DELETABLE |
| `_build-laneW840` | 0.43 GB | `plans/w840-clock-seam.md` | DELETABLE |
| `_build-laneW842` | 0.66 GB | `plans/w842-e2e-revalidation.md` | DELETABLE |
| `_build-laneW843` | 0.43 GB | `plans/w843-na-completeness.md` | DELETABLE |
| `_build-laneW844` | 0.43 GB | `plans/w844-quiescent-envelope.md` | DELETABLE |
| `_build-laneW845` | 0.43 GB | `plans/w845-audit-enoent.md` | DELETABLE |
| `_build-laneW846` | 0.43 GB | `plans/w846-schema-consistency.md` | DELETABLE |
| `_build-laneW847` | 0.43 GB | `plans/w847-doctor-recal.md` | DELETABLE |
| `_build-laneW851` | 0.43 GB | `plans/w851-jcs-doctests.md` | DELETABLE |
| `_build-laneW852` | 0.43 GB | `_COMMIT_MANIFEST_W850.md` (refs W852) | DELETABLE |
| `_build-laneW853` | 0.43 GB | `plans/w853-computation-doctests.md` | DELETABLE |
| `_build-laneW856` | 0.43 GB | none (this census is the only ref) | CHECK |
| `_build-laneW858` | 0.43 GB | `plans/w858-route-castle-surface.md` (landed mid-census) | DELETABLE |
| `_build-laneW860` | 0.43 GB | `_COMMIT_MANIFEST_W850.md` (refs W860) | DELETABLE |
| `_build-laneW863` | 0.43 GB | `_INTEGRATION_RUNBOOK.md` + `plans/w879-integration-sequence.md` | DELETABLE |
| `_build-laneW865` | 0.43 GB | none (this census is the only ref) | CHECK |
| `_build-laneW866` | 0.35 GB | `_INTEGRATION_RUNBOOK.md` + `plans/w879-integration-sequence.md` | DELETABLE |
| `_build-laneW869` | 0.35 GB | `_INTEGRATION_RUNBOOK.md` + `plans/w879-integration-sequence.md` | DELETABLE |
| `_build-laneW872` | 0.35 GB | `_INTEGRATION_RUNBOOK.md` + `plans/w879-integration-sequence.md` | DELETABLE |
| `_build-laneW873` | 0.24 GB | `_INTEGRATION_RUNBOOK.md` + `plans/w879-integration-sequence.md` (minted <90 min ago) | DELETABLE |
| `_build-laneW880` | 0.35 GB (grew 0.02→0.35 during census) | minted during this census | KEEP |
| `_build-laneW888` | 0.02 GB | minted at census close | KEEP |

Count check: 65 DELETABLE + 2 CHECK (W856, W865) + 2 KEEP (W880, W888) = 69 entries ✓.
Size check: 28.01 + 0.86 + 0.37 ≈ 29.24 GB vs 28.91 GB measured — gap is
rounding on the 0.43 GB averages plus W880's mid-census growth; table values are
snapshot actuals.

## Per-entry — sibling repos (all DELETABLE, receipts referenced in xaas `docs/sjira/v26.10.6/`)

| path | size | receipt |
|---|---|---|
| `/Users/sac/ash_pplan/_build-laneW291b` | 398 MB | referenced (1 ref) |
| `/Users/sac/ash_pplan/_build-laneW635` | 398 MB | referenced (8 refs) |
| `/Users/sac/ash_pplan/_build-laneW658e` | 398 MB | referenced (1 ref) |
| `/Users/sac/ash_pplan/_build-laneW682` | 398 MB | `plans/w682-ash-pplan-airo-pin.md` |
| `/Users/sac/beam4pm/_build-laneW634` | 583 MB | referenced (5 refs) |
| `/Users/sac/beam4pm/_build-laneW658` | 583 MB | referenced |
| `/Users/sac/beam4pm/_build-laneW658b` | 583 MB | `plans/w658b-beam4pm-admissions.md` |
| `/Users/sac/ggen_igniter/_build-laneW619` | 158 MB | referenced (7 refs) |
| `/Users/sac/ggen_igniter/_build-laneW686` | 158 MB | `plans/w686-ggen-igniter-airo-pin.md` |

## Per-entry — /tmp lease dirs (DELETABLE)

| path | size |
|---|---|
| `/tmp/w746-scratch` | 0.465 GB |
| `/tmp/w653b-target` | 0.038 GB |
| `/tmp/w653b-fixtures` | ~0 (16 KB) |
| `/tmp/w509-target` | ~0 |
| `/tmp/w129` | ~0 (112 KB) |
| `/tmp/w136c` | 0 |

Absent (already cleaned; referenced only by historical receipts): `/tmp/w645c-target`,
`/tmp/w334-scratch`, `/tmp/w390-scratch`, `/tmp/w392-scratch`, `/tmp/w501-target`.
Remaining `/tmp/w*.{log,exs,txt,json}` files are lane logs, not build-root leases —
out of census scope.

## One-shot cleanup command list (operator executes; this lane executed nothing)

```bash
# Group 1 — xaas lanes WITH receipts (65 dirs, ~28.01 GB).
# Explicit list is authoritative; generated loops were flaky on the live tree.
# Excludes CHECK {W856, W865} and KEEP {W880, W888}.
rm -rf /Users/sac/xaas/_build-laneW663b /Users/sac/xaas/_build-laneW752 \
  /Users/sac/xaas/_build-laneW774 /Users/sac/xaas/_build-laneW775 \
  /Users/sac/xaas/_build-laneW778 /Users/sac/xaas/_build-laneW779 \
  /Users/sac/xaas/_build-laneW780 /Users/sac/xaas/_build-laneW782 \
  /Users/sac/xaas/_build-laneW785 /Users/sac/xaas/_build-laneW786 \
  /Users/sac/xaas/_build-laneW787 /Users/sac/xaas/_build-laneW788 \
  /Users/sac/xaas/_build-laneW791 /Users/sac/xaas/_build-laneW792 \
  /Users/sac/xaas/_build-laneW793 /Users/sac/xaas/_build-laneW794 \
  /Users/sac/xaas/_build-laneW795 /Users/sac/xaas/_build-laneW796 \
  /Users/sac/xaas/_build-laneW799 /Users/sac/xaas/_build-laneW800 \
  /Users/sac/xaas/_build-laneW801 /Users/sac/xaas/_build-laneW802 \
  /Users/sac/xaas/_build-laneW803 /Users/sac/xaas/_build-laneW803-dev \
  /Users/sac/xaas/_build-laneW804 /Users/sac/xaas/_build-laneW805 \
  /Users/sac/xaas/_build-laneW808 /Users/sac/xaas/_build-laneW811 \
  /Users/sac/xaas/_build-laneW812 /Users/sac/xaas/_build-laneW813 \
  /Users/sac/xaas/_build-laneW814 /Users/sac/xaas/_build-laneW816 \
  /Users/sac/xaas/_build-laneW817 /Users/sac/xaas/_build-laneW821 \
  /Users/sac/xaas/_build-laneW823 /Users/sac/xaas/_build-laneW824 \
  /Users/sac/xaas/_build-laneW825 /Users/sac/xaas/_build-laneW828 \
  /Users/sac/xaas/_build-laneW829 /Users/sac/xaas/_build-laneW831 \
  /Users/sac/xaas/_build-laneW832 /Users/sac/xaas/_build-laneW833 \
  /Users/sac/xaas/_build-laneW834 /Users/sac/xaas/_build-laneW835 \
  /Users/sac/xaas/_build-laneW836 /Users/sac/xaas/_build-laneW837 \
  /Users/sac/xaas/_build-laneW838 /Users/sac/xaas/_build-laneW839 \
  /Users/sac/xaas/_build-laneW840 /Users/sac/xaas/_build-laneW842 \
  /Users/sac/xaas/_build-laneW843 /Users/sac/xaas/_build-laneW844 \
  /Users/sac/xaas/_build-laneW845 /Users/sac/xaas/_build-laneW846 \
  /Users/sac/xaas/_build-laneW847 /Users/sac/xaas/_build-laneW851 \
  /Users/sac/xaas/_build-laneW852 /Users/sac/xaas/_build-laneW853 \
  /Users/sac/xaas/_build-laneW858 /Users/sac/xaas/_build-laneW860 \
  /Users/sac/xaas/_build-laneW863 /Users/sac/xaas/_build-laneW866 \
  /Users/sac/xaas/_build-laneW869 /Users/sac/xaas/_build-laneW872 \
  /Users/sac/xaas/_build-laneW873
```

(Count: 65 paths — W856, W865 CHECK and W880, W888 KEEP excluded by design.)

```bash
# Group 2 — sibling-repo lanes (9 dirs, ~3.19 GB)
rm -rf /Users/sac/ash_pplan/_build-laneW291b \
       /Users/sac/ash_pplan/_build-laneW635 \
       /Users/sac/ash_pplan/_build-laneW658e \
       /Users/sac/ash_pplan/_build-laneW682 \
       /Users/sac/beam4pm/_build-laneW634 \
       /Users/sac/beam4pm/_build-laneW658 \
       /Users/sac/beam4pm/_build-laneW658b \
       /Users/sac/ggen_igniter/_build-laneW619 \
       /Users/sac/ggen_igniter/_build-laneW686

# Group 3 — /tmp lease dirs (~0.51 GB)
rm -rf /tmp/w746-scratch /tmp/w653b-target /tmp/w653b-fixtures \
       /tmp/w509-target /tmp/w129 /tmp/w136c
```

## Post-cleanup state

After Groups 1–3, remaining on disk = CHECK {W856, W865} + KEEP {W880, W888}
≈ 1.23 GB. W856/W865 resolve to DELETABLE as soon as their lanes' receipts land;
re-census then.

## Falsifier

```bash
du -sk /Users/sac/xaas/_build-lane* | awk '{s+=$1} END{printf "%.2f GB\n", s/1048576}'
```
should report ~1.23 GB (CHECK+KEEP residue), not 28 GB.
