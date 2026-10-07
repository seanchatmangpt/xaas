# W695 — ggen AIRo pin test (AIRo wiring extension)

Date: 2026-10-07
Lane: W695 (xaas v26.10.6 campaign)

## Subject

- Repo: `/Users/sac/ggen` (canonical checkout, no commits made)
- Branch/HEAD: `feat/v26.10.5-release-cut` @ `bc4d23909dbcfd51b368f182f94655860041b04f`
  (matches expected `bc4d23909`)
- Dirty tree (pre-existing, disclosed): `.claude-plugin/marketplace.json`,
  `.specify/repo-facts.ttl`, `Cargo.lock`, `crates/ggen-engine/Cargo.toml`,
  `crates/pm4pytest-cli/Cargo.toml`, `ggen.toml`, `scripts/check_airo.sh` (W684's
  fail-closed edit, untouched by this lane)
- New file (only write in ggen): `scripts/test_airo_pin.py`

## Ledger rows read

- `docs/cro/artifacts/airo-wiring-ledger.md` w614 row (618 triples after vocab union;
  15/15 vocab terms; 5/5 cited paths; script PASS)
- `docs/cro/artifacts/airo-wiring-ledger-verification-w668.md` w614 row (VERIFIED;
  8,306 B; bare parse 60 + vocab 558 = 618; script PASS)

## Test convention chosen

No pytest tree in ggen; system `python3` (3.14.3) carries pytest 9.0.3 + rdflib 7.6.0,
so a standalone pytest module at `scripts/test_airo_pin.py` was the lightest real
runner (consistent with other `scripts/test_*.py`-style checks). `/tmp/airo-venv`
has rdflib but no pytest, so system python3 was used.

## Pins (all real, no mocks)

| Pin | Expected | Observed |
|---|---|---|
| sha256 of `docs/airo-risk-description.ttl` | `7c79b80d…188acd8` | match (test passed) |
| byte size | 8,306 | 8,306 |
| bare rdflib triples | 60 | 60 |
| union triples (doc + `/tmp/airo.ttl` vocab) | 618 | 618 |
| cited paths (exact set) | 5 (2× ggen-sync-run workflows, publish-candidate, portable_receipt.rs, justfile) | 5/5 exist |

Vocabulary cache `/tmp/airo.ttl` is the same dependency `scripts/check_airo.sh`
relies on; the test fails loudly if it is missing rather than silently degrading.

## Execution (real output)

```
$ python3 -m pytest scripts/test_airo_pin.py -v
scripts/test_airo_pin.py::test_ttl_byte_hash_and_size PASSED             [ 25%]
scripts/test_airo_pin.py::test_triple_count_bare_rdflib_parse PASSED     [ 50%]
scripts/test_airo_pin.py::test_triple_count_union_with_vocabulary PASSED [ 75%]
scripts/test_airo_pin.py::test_cited_paths_grounded PASSED               [100%]
============================== 4 passed in 0.21s ===============================
```

Cross-check with the fail-closed script (unmodified, W684's version):

```
$ bash scripts/check_airo.sh
… 5/5 cited paths ok, 618 triples after vocabulary union, 15/15 vocab terms …
check_airo: PASS  (exit 0)
```

## Verification ladder

narrow (byte hash/size) → parse (rdflib bare 60) → integration (union 618 via real
vocabulary) → grounding (cited paths exist on disk). Pre-existing unrelated failures:
none observed; no test run was needed beyond the new pin (no pytest suite predates it
at repo root; the dirty tree is W684's script edit, not a failure).

## Standing

**ALIVE** — pins observed on the exact subject
(`feat/v26.10.5-release-cut @ bc4d23909`) via real rdflib parse, real sha256, and
real filesystem existence checks; corroborated independently by the fail-closed
`check_airo.sh` PASS on the same subject. No drift found; ledger rows (w614) are
consistent with observed reality.

## Falsifiers (all failed to falsify)

- hash/size drift → none
- triple-count drift (bare or union) → none
- cited-path grounding failure → none
- script/test disagreement → none (both PASS, same counts)

## Replay

```
cd /Users/sac/ggen && python3 -m pytest scripts/test_airo_pin.py -v
cd /Users/sac/ggen && bash scripts/check_airo.sh
```
