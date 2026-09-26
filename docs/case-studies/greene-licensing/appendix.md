# Evidence appendix (proposal draft, not sent)

Case `greene-licensing-case` is bound to `seanchatmangpt/autofde-lab@d6becb595aedac4f18cab84f80bf5aa90e1a45e4`. Authority
ceiling NONE; evidence ceiling REPO_LOCAL_FIXTURE; human
gate USER_REVIEW_REQUIRED_NOTHING_SENT. Every digest below is repository-local evidence
recomputed from the exact subject named with it; none of it is evidence about
any real organization, market or conflict.

## Claims

| Claim | Standing | Evidence ceiling | Authority | Evidence | Exact subject | Falsifier |
|---|---|---|---|---|---|---|
| C01: At the bound commit the doctrine lab ran 252 episodes over 9 worlds and 2 seeds and sealed a 252-record ledger. | ALIVE_FIXTURE | REPO_LOCAL_FIXTURE | NONE | E01 `src/autofde_lab/simulation/doctrine_lab/seal.py` (ledger valid true; records 252; episode_count 252; world_count 9; key_kind fixture) | `seanchatmangpt/autofde-lab@d6becb595aedac4f18cab84f80bf5aa90e1a45e4` | F01 |
| C02: A second, separate process reproduces report.json and ledger.jsonl byte for byte. | ALIVE_FIXTURE | REPO_LOCAL_FIXTURE | NONE | E02 `src/autofde_lab/simulation/doctrine_lab/report.py` (report.json and ledger.jsonl sha256 identical across two processes) | `seanchatmangpt/autofde-lab@d6becb595aedac4f18cab84f80bf5aa90e1a45e4` | F02 |
| C03: verify_run with replay re-executes the run and reports it valid with zero failures. | ALIVE_FIXTURE | REPO_LOCAL_FIXTURE | NONE | E03 `src/autofde_lab/simulation/doctrine_lab/verify.py` (verify_run valid true; replayed true; failures empty; authority NONE) | `seanchatmangpt/autofde-lab@d6becb595aedac4f18cab84f80bf5aa90e1a45e4` | F03 |
| C04: In this model, two pairs of distinct doctrine compositions produced behaviourally identical policies. | ALIVE_FIXTURE | REPO_LOCAL_FIXTURE | NONE | E04 `src/autofde_lab/simulation/doctrine_lab/relations.py` (primitive_equivalence_clusters 2 (sd-13 with sd-14; sd-01 with sd-12)) | `seanchatmangpt/autofde-lab@d6becb595aedac4f18cab84f80bf5aa90e1a45e4` | F04 |
| C05: The strategic-doctrine catalog projection carries a licensing non-claim and is gated against excerpts. | ALIVE_FIXTURE | REPO_LOCAL_FIXTURE | NONE | E05 `packs/strategic-doctrine-pack/generated/catalog.json` (catalog projection sha256 recomputed at the bound commit) | `seanchatmangpt/ggen-marketplace@c0f27e5bed97b164ac267f86d8d9d989982319e8` | F05 |

## Receipt digests

| # | Kind | sha256 | Evidence |
|---|---|---|---|
| 1 | ledger tail digest | `f10e2294dbd5c6d7ee1c8b97b3af36fcb706326e6a6dc7ed88f5c8db441c8665` | E01 |
| 2 | report.json file sha256 | `9f1d03a3188430dde6c8fad00c63714daff73aa3600229d9f521ec41e2edc6d4` | E02 |
| 3 | ledger.jsonl file sha256 | `e5d42b8af2f25fe71f8f9bd18df245a5e2f1992b7e45c54ffdc60af5640e030b` | E02 |
| 4 | matrix digest | `762fab0feebe2109c4d1e1aef1618119a9e4f29ee5c425ad1931cb21af123ef7` | E03 |
| 5 | report digest | `5e4c530b1ef265d16401605972405399f6e0c9949ae11aaa4b7ee4a3c2371cf3` | E03 |
| 6 | strategic-doctrine catalog.json sha256 | `d279700226af68fd41fa6223359000333c351bec8bf75ca8625ffebf3991af44` | E05 |

## Replay commands

1. `git -C autofde-lab fetch origin feat/doctrine-lab && mkdir lab && git -C autofde-lab archive d6becb595aedac4f18cab84f80bf5aa90e1a45e4 -- src pyproject.toml | tar -x -C lab`
   Expected: lab/src holds the exact doctrine-lab tree
2. `PYTHONPATH=lab/src python -m autofde_lab.simulation.doctrine_lab --out run --replay`
   Expected: exit 0; ledger valid true; verify_run valid true with no failures; digests as listed above
3. `PYTHONPATH=lab/src python -m autofde_lab.simulation.doctrine_lab --out run2 && shasum -a 256 run/report.json run2/report.json run/ledger.jsonl run2/ledger.jsonl`
   Expected: report.json and ledger.jsonl hashes match between run and run2
4. `git -C ggen-marketplace show c0f27e5bed97b164ac267f86d8d9d989982319e8:packs/strategic-doctrine-pack/generated/catalog.json | shasum -a 256`
   Expected: d279700226af68fd41fa6223359000333c351bec8bf75ca8625ffebf3991af44

## Falsifiers

- F01: The ledger tail digest differs from the listed value, the record count is not 252, or ledger valid is false. Command: `PYTHONPATH=lab/src python -m autofde_lab.simulation.doctrine_lab --out run --replay`
- F02: A second process yields a different sha256 for report.json or ledger.jsonl. Command: `shasum -a 256 run/report.json run2/report.json run/ledger.jsonl run2/ledger.jsonl`
- F03: verify_run reports valid false or lists any failure. Command: `PYTHONPATH=lab/src python -m autofde_lab.simulation.doctrine_lab --out run --replay`
- F04: For the same seeds, worlds and rounds the report lists a cluster count other than 2. Command: `python -m json.tool run/report.json | grep -c behaviourally_identical`
- F05: The catalog projection hashes to a different value, or its licensing non-claim is absent. Command: `git -C ggen-marketplace show c0f27e5bed97b164ac267f86d8d9d989982319e8:packs/strategic-doctrine-pack/generated/catalog.json | shasum -a 256`

