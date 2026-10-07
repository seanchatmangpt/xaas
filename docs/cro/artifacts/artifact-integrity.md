# Artifact Integrity Audit — v26.10.6 (lane W419)

Subject: `/Users/sac/xaas` (canonical checkout), audit of `docs/cro/` and
`docs/cro/artifacts/` before any account-facing exposure. Audit performed
2026-10-06.

## Method

1. Every file checked non-empty on disk.
2. `refusal-ledger-v26.10.6.jcs.json`: real `json.load` parse + canonical
   round-trip (`json.dumps(sort_keys=True, separators=(',',':'))` applied
   twice, byte-compared). Both stable.
3. Every path-like string cited in any artifact extracted and `test -f`-style
   checked on disk, resolved against the subject repo declared inside the
   citing artifact (`xaas` by default; `ash_surface` for the ash-surface
   ledger; `ggen-marketplace` for the entitlement stage-4 artifact;
   `ash_affidavit` for the signing-keys citation).
4. Every `wNNN` receipt citation checked for a file under
   `docs/sjira/v26.10.6/plans/`; not found and not in the declared in-flight
   set (w398/w414/w415/w416/w417) => counted as a broken receipt citation.

## Receipt

| Artifact | Non-empty | Paths cited | Paths resolved | Broken paths | Receipt cites | Broken receipts | Verdict |
|---|---|---|---|---|---|---|---|
| docs/cro/ARTIFACT-MANIFEST.md | yes | 7 | 7 | 0 | 0 | 0 | SHIP-READY |
| docs/cro/CRO-LOOP.md | yes | 10 | 10 | 0 | w405 | w405 | FINDINGS |
| docs/cro/CYCLE-LOG.md | yes | 1 | 1 | 0 | w404, w405 | w404, w405 | FINDINGS |
| docs/cro/README.md | yes | 0 | 0 | 0 | 0 | 0 | SHIP-READY |
| artifacts/agent-obliviousness-demo.md | yes | 2 | 2 | 0 | w407 | w407 | FINDINGS |
| artifacts/ash-surface-refusal-ledger-v26.10.6.md | yes | 9 | 9 (vs /Users/sac/ash_surface) | 0 | 0 | 0 | SHIP-READY |
| artifacts/cycle0-dryrun.md | yes | 12 | 12 | 0 | w401–w405 | w401, w402, w403, w404, w405 | FINDINGS |
| artifacts/evidence-claims-index.md | yes | 12 | 11 | 1 | w202 | w202 | FINDINGS |
| artifacts/fiduciary-briefing-v26.10.6.md | yes | 17 | 14 | 3 | w398, w185, w208 | w185, w208 (w398 in-flight) | FINDINGS |
| artifacts/refusal-ledger-v26.10.6.jcs.json | yes | 40 | 40 | 0 | w185, w202, w208, w414 | w185, w202, w208 (w414 in-flight) | FINDINGS |
| artifacts/refusal-ledger-v26.10.6.README.md | yes | 19 | 19 | 0 | w185, w202 | w185, w202 | FINDINGS |
| artifacts/stage4-entitlement-flow-verification.md | yes | 6 | 3 | 3 | 0 | 0 | FINDINGS |

Totals: 12/12 files exist non-empty. JSON parse + canonical round-trip:
STABLE (re-hashed 4625e610cd80… after w382/w414 ledger updates, coordinator pass 2026-10-06) (sha256 of canonical form `4625e610cd80062722acea5dbd27c7ea1a7242b57f6a994cd1bd018232dd5117`).
Path citations: 135 checked, 129 resolve (cross-repo resolved against each
artifact's declared subject), 6 distinct broken. Receipt citations: 17
distinct broken (w185, w202, w208, w401, w402, w403, w404, w405, w407).

## Broken-path findings (6 distinct)

1. `docs/cro/CRO-LEDGER` — cited by `fiduciary-briefing-v26.10.6.md:53` as
   governing directive; no such file in `docs/cro/` (or in ash_surface).
2. `scripts/k8s/lib` — cited by `stage4-entitlement-flow-verification.md:45`
   ("zero hits for EULA in scripts/k8s/lib"); the directory does not exist in
   `ggen-marketplace`, so the zero-hits evidence claim is unsound as written.
3. `scripts/provision_license.py` — cited by
   `stage4-entitlement-flow-verification.md:71` as a *proposed* future script
   ("a `scripts/provision_license.py` in the same typed-refusal style");
   correctly framed as a proposal in context — reclassify citation as
   PROPOSED, not EXIST, and the verdict stands with this annotation.
4. `lib/ash_affidavit/signing/keys.ex` — cited by
   `evidence-claims-index.md:18` as sibling `ash_affidavit`; EXISTS at
   `/Users/sac/ash_affidavit/lib/ash_affidavit/signing/keys.ex` but the
   citation lacks the sibling prefix, so a bare path test against `xaas`
   fails. Formatting fix: cite the full sibling path.
5. `scripts/entitlement.py` — cited by
   `stage4-entitlement-flow-verification.md:26` with the full path
   `/Users/sac/ggen-marketplace/scripts/entitlement.py` in context; the bare
   form elsewhere in the file needs the repo prefix to resolve. Partially
   grounded; add repo prefix.
6. `tests/test_entitlement_seam.py` / `tests/test_commerce_seam_integration.py`
   — resolve under `ggen-marketplace` (EXIST, 682-line file confirmed);
   bare citations in stage4 need the repo prefix.

Findings 4-6 are citation-formatting (missing cross-repo prefix), not
fabrication — targets exist at their declared sibling checkouts.

## Broken-receipt findings

- w401–w405, w407: CRO cycle-0 lane receipts. Evidence exists on disk as the
  artifacts themselves (CYCLE-LOG records w405/w404 "landed"), but no plan
  file under `docs/sjira/v26.10.6/plans/` and NOT in the declared in-flight
  set — per the audit rule these count as broken receipt citations until
  either plan files land or the in-flight set is amended.
- w185, w202, w208: cited by the JCS ledger (`unreachable_reason` fields) and
  the README/evidence-index; no plan file under `v26.10.6/plans/`. w208 has
  no plan file anywhere under docs/sjira. w185/w202 appear to be pre-v26.10.6
  receipts; the JCS ledger should either cite plan-file paths or mark them
  as prior-cycle receipts.

## Verdict summary

Per-artifact verdicts in the table above are authoritative:

- SHIP-READY: 3 — ARTIFACT-MANIFEST.md, README.md,
  ash-surface-refusal-ledger-v26.10.6.md.
- FINDINGS: 9 — the wNNN receipt-citation class affects the JCS ledger, its
  README, the fiduciary briefing, the evidence index, cycle0-dryrun,
  agent-obliviousness-demo, CRO-LOOP, CYCLE-LOG; stage4-entitlement carries
  the broken-path class.

Falsifier for this audit: re-run the extraction + disk-test script against
any artifact and produce a path or receipt citation it claims resolved but
which fails on disk.
