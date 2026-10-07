# W149 — validate_receipt.py health check (post-W107 `known` diagnostic)

- **Subject**: `~/.claude/dfcm/validate_receipt.py` (untracked harness file, no SHA;
  session state at xaas HEAD `d1db2b03179975213c14663b9dbd86b5ac2a14cf`, branch
  `feat/playwright-surface`)
- **Trigger**: W107 version-discriminator edit; diagnostic reported unused `known`
  variable at line 62 — verify no latent NameError.
- **Date**: 2026-10-06 · **Lane**: W149 integration · **Python**: 3.14.3

## Findings

1. **No `known` binding exists in code.** `grep -n 'known'` matches only the
   docstring ("any top-level key outside the known set", line 23). W107's edit
   already removed the binding; the extension-namespace gate iterates `r` against
   `KNOWN_TOP_LEVEL_KEYS` (validate_receipt.py:91). **No fix needed; no edit made.**
2. **Compile**: `python3 -m py_compile ~/.claude/dfcm/validate_receipt.py` → `COMPILE_OK`.
3. **Self-test**: `ls ~/.claude/dfcm/ | grep -i test` → no matches (no test file exists
   to run). The adversarial matrix below is the substitute falsifier.

## Adversarial matrix (real output, exit recorded per run)

Receipts synthesized in /tmp; v2 receipts anchored at xaas HEAD
`d1db2b03` (real commit, passes `git cat-file -e <sha>^{commit}`).

| case | content | verdict (verbatim) |
|---|---|---|
| w149_v1.json | 5 R fields only | `ADMITTED /tmp/w149_v1.json` |
| w149_v2.json | 5 R fields + 4 ALOOP fields | `ADMITTED /tmp/w149_v2.json` |
| w149_v2_badext.json | v2 + un-namespaced `extension_junk` key | `REFUSED` — `extension_junk: top-level extension key is not namespaced as 'provider_ext.<provider>' (R_missing_identity); unattributed extension data is unadmittable` |
| w149_v2_badsha.json | v2, subject_sha = 0×40 | `REFUSED` — `identity.subject_sha: 0000…0000 is not a commit in /Users/sac/xaas (R_missing_identity); …` |
| w149_v2_alive_bad.json | v2, replay exit = 1, standing ALIVE | `REFUSED` — `standing: ALIVE with a non-zero replay exit (admission_vacuous)` |
| w149_malformed.json | partial v2 (only `provider`) | `REFUSED` — `<root>: 'work_order_id' is a required property` + `origin_authority` + `provider_execution_id` (validated as v2, as designed — partial v2 never downgrades to v1) |

Final full run: `python3 ~/.claude/dfcm/validate_receipt.py` over all six →
exit **1** (2 ADMITTED, 4 REFUSED, every refusal typed and on the intended path).

## Notes

- First matrix iteration: v2/v2_badext showed spurious `admission_vacuous` — cause
  was my own generator's `dict(v2)` shallow copy sharing the nested `replay` dict
  with `alive_bad`, not the validator. Clean rerun (fresh `full()` per case)
  ADMITTED both. Recorded for replay honesty.
- Validator code paths exercised: schema v1/v2 discrimination (line 54), git
  cat-file anchor check (75), extension-namespace gate (90–99), ALIVE/exit gate
  (61). All reachable paths ran; no `known`-dependent path exists.

## Standing

**ALIVE** (narrow): compile clean, no latent NameError possible, all six matrix
cells produce the designed verdict on the real validator. Falsifier: any matrix
cell above rerun producing a different verdict class.

## μ/diff

Zero-source-diff lane. Files touched: this receipt only. (Task authorized the
leftover-binding fix; finding was "already dead, nothing to remove".)
