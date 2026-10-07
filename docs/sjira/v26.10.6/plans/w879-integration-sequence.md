# W879 — Integration Sequence (receipt)

- **Lane**: W879, xaas v26.10.6 campaign, canonical checkout `/Users/sac/xaas`,
  branch `feat/playwright-surface`, HEAD `a0723bf6` (435 dirty entries in working tree —
  expected; coordinator owns commits).
- **Date**: 2026-10-07
- **Scope**: write-only lane — this receipt + a dated W879 section appended to
  `docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md`. No build root minted; no git operations.

## Sequence (full text in the runbook §Integration sequence (W879))

1. Lease cleanup — W878 census IN_FLIGHT; until it lands use the runbook's 2026-10-07
   ~04:5x inventory (18 roots / 5.7 GB; W663b/W787/W788 deletable-now). Live W879 recount:
   **70 `_build-lane*` roots ≈ 29.5 GB** (du -sh); hold W873/W788/W863/W866/W869/W872
   (small/partial — mid-write or incomplete) for the census.
2. `MIX_ENV=dev mix ecto.migrate` on xaas_dev — W786 (20261007111457 ash_onetime logical
   partitions, test-DB-verified) + W804 (20261007120000 epoch dedup + guarded unique index,
   PARTIAL_ALIVE, dev migrate owed). Both in manifest CG-01.
3. `ggen sync` at new HEAD — after committing W756's upstream pack ontology edit
   (ggen-marketplace `packs/xaas-castle-bridge-pack/ontology.ttl:101`); projection check:
   ERRC page reads "117 Ash resources via the Xaas.Resource wrapper (152 total use
   Ash.Resource) and 19 domains".
4. The 7 operator decisions (W867): dev.exs cluster_size 1->3 (W803); W786/W804 vs xaas_dev;
   platform route deletions; transients deletion; test.exs env port vs CI (W822);
   priv/semantic/generated generator path; incident_report.ex attribution.
5. Commits per `_COMMIT_MANIFEST_W850.md` groups CG-01..CG-15 — GATED on all ~17 in-flight
   lanes landing + W875's adjudication being applied to the manifest. HOLD rows (9 items +
   system_actor.ex) stay uncommitted.
6. Post-commit gate rerun (W663b successor): full suite (>=3247 green threshold),
   mock gate `[]`, `ggen sync` drift, `mix compile --warnings-as-errors` exit 0;
   replay at load <10 per runbook replay protocol.
7. Push `feat/playwright-surface`.

## Per-item receipts

| Item | Receipt (docs/sjira/v26.10.6/plans/) | Standing cited |
|---|---|---|
| Commit manifest (15 groups) | `w867-commit-manifest.md` (+ `_COMMIT_MANIFEST_W850.md`) | manifest staging ALIVE; coverage "missing: 0"; 7 operator decisions listed; 9 HOLD items + 1 unattributed file |
| W875 adjudication | `plans/w875-*.md` | **IN_FLIGHT — no receipt on disk** |
| W878 lease census | `plans/w878-*.md` | **IN_FLIGHT — no receipt on disk**; earlier inventory = runbook "Lane-lease inventory (2026-10-07 ~04:5x)" |
| Dev migrate A | `w786-onetime-partition.md` | migration verified on xaas_test; operator must run on xaas_dev |
| Dev migrate B | `w804-epoch-dedup.md` | PARTIAL_ALIVE — "operator still must run `mix ecto.migrate` on xaas_dev" |
| ggen sync regen | `w756-errc-rationale-refresh.md` | ALIVE (pack-level, uncommitted); sync explicitly deferred to xaas lane |
| Post-commit gates (prior run) | `w663b-postcommit-gates.md` | gates 1/2/3/5 PASS (3559/3599, `[]`, no drift, EXIT 0); gate 4 BLOCKED(CONTENTION + pre-existing dev-boot cluster_size=1 strict defect — resolved by decision 1, W803) |
| Pre-condition: census certified | `w821-terminal-census-2.md` | MET — deterministic, green gate 1347 passed exit 0 |
| Pre-condition: priority e2e | `w842-e2e-revalidation.md` | MET — ALIVE 24/1/0 exit 0 |
| Pre-condition: gate green | `w778-gate-fix-verify.md` | MET — F1 503 passed exit 0 |
| Pre-condition: doctor statuses | `w847-doctor-recal.md` | MET — PARTIAL_ALIVE, literal band 120..170 |

## Verification (this lane)

- Receipts confirmed on disk by `ls` + reads: w867, w786, w804, w756, w663b, w821, w842,
  w778, w847. Absence of w875/w878 confirmed by `ls | grep -E 'w8[0-9]{2}'` (no match).
- Manifest file `_COMMIT_MANIFEST_W850.md` exists (299 lines; W867's receipt says 274 at
  staging time — grew, disclosed, coordinator should re-run W867's coverage falsifier
  before step 5).
- Live lease recount executed (`du -sh _build-lane*`): 70 roots ≈ 29.5 GB — recorded in the
  runbook section as input to W878's census.

## Standing

- **Integration sequence: PARTIAL_ALIVE** — fully assembled and cited; steps 1, 5 are
  blocked on in-flight lanes (W875, W878 + ~17 others). Steps 2-4, 6, 7 are operator-ready
  once 5 unblocks.
- Falsifier: if any cited receipt's standing flips on re-read (e.g. W804's dev-migrate
  already executed, or W867's manifest coverage no longer 0-missing), this sequence must be
  re-assembled before the coordinator executes step 5.
- Consequence: two doc files written; no tree, config, or build state touched.

## Commands/exits

- `ls docs/sjira/v26.10.6/plans/` + greps for w875/w878 (exit 0; no w875/w878 files found)
- `sed -n` reads of w867/w786/w804/w756/w663b/w821/w842/w778/w847 (exit 0)
- `du -sh _build-lane*` (exit 0; 70 roots, ~29.5 GB)
- `cat >> _INTEGRATION_RUNBOOK.md` (exit 0); verified by `tail -5` re-read
- `Write` of this receipt (exit 0)

## Replay

- `grep -c 'Integration sequence (W879' docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md` → 1
- `ls docs/sjira/v26.10.6/plans/ | grep -E 'w87[58]'` → still absent until those lanes land
- `du -sh _build-lane* | wc -l` → grows/shrinks with lane lifecycle; 70 at assembly time
